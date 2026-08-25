-- bfl_skydd v5: sluter kontoutdragsarkivets skyddshål (ultragranskning 2026-07-10).
-- 1) Bokförda bankhändelser (verifikation_id satt) kan inte raderas – kedjan
--    verifikation → bankhändelse → import_batch → kontoutdrag är räkenskapsinformation.
--    Ångra-flödena påverkas inte: makulera/radera-senaste nollar verifikation_id via
--    on_verifikation_delete INNAN någon radering av bankhändelser blir aktuell.
-- 2) Arkiverade kontoutdrag (documents.kategori='kontoutdrag') skyddas via
--    import_batch-kedjan – de har ALDRIG verifikation_id och täcktes inte av v1-skyddet.
-- 3) Storage-policyn skärps på samma sätt.
-- 4) reset_company sätter bypass-GUC:en överst så att ALLA raderingsval i den
--    auditerade totalåterställningen fungerar (tidigare bara bookkeeping-grenen).

-- 1) Bankhändelser
create or replace function public.forbjud_bokford_banktx_radering() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then return old; end if;
  if not exists (select 1 from public.companies where id = old.company_id) then
    return old;   -- cascade vid företagsradering
  end if;
  if old.verifikation_id is not null then
    raise exception 'BANKHÄNDELSEN ÄR BOKFÖRD: den är kopplad till en verifikation och kan inte raderas (BFL 7 kap 2 §). Ångra bokföringen först.';
  end if;
  return old;
end $$;
drop trigger if exists trg_forbjud_banktx_delete on public.bank_transactions;
create trigger trg_forbjud_banktx_delete
  before delete on public.bank_transactions
  for each row execute function public.forbjud_bokford_banktx_radering();

-- 2) Kontoutdrag via import_batch-kedjan
create or replace function public.skydda_bokfort_underlag() returns trigger
language plpgsql as $$
begin
  if current_setting('app.periodlas_bypass', true) = 'on'
     or current_setting('app.radera_senaste', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if tg_op = 'DELETE' then
    if old.verifikation_id is not null then
      raise exception 'Underlaget hör till bokföringen och ska bevaras i 7 år (BFL 7 kap 2 §) – det kan inte raderas';
    end if;
    if old.kategori = 'kontoutdrag' and old.import_batch is not null
       and exists (select 1 from public.bank_transactions bt
                   where bt.import_batch = old.import_batch and bt.verifikation_id is not null) then
      raise exception 'Kontoutdraget är underlag för bokförda verifikationer (BFL 7 kap 2 §) – det kan inte raderas. Ångra bokföringarna först.';
    end if;
    return old;
  end if;
  if old.verifikation_id is not null and new.verifikation_id is null then
    raise exception 'Underlagets koppling till bokföringen kan inte tas bort (BFL 7 kap 2 §)';
  end if;
  if old.kategori = 'kontoutdrag' and old.import_batch is not null
     and new.import_batch is distinct from old.import_batch
     and exists (select 1 from public.bank_transactions bt
                 where bt.import_batch = old.import_batch and bt.verifikation_id is not null) then
    raise exception 'Kontoutdragets koppling till bokförda verifikationer kan inte tas bort (BFL 7 kap 2 §)';
  end if;
  return new;
end $$;

-- 3) Storage: även kontoutdragsfiler med bokförd batch blockeras
drop policy if exists "underlag_delete" on storage.objects;
create policy "underlag_delete" on storage.objects for delete to authenticated
  using (
    bucket_id = 'underlag'
    and (storage.foldername(name))[1] in (
      select company_id::text from user_companies where user_id = auth.uid())
    and not exists (
      select 1 from public.documents d
      where d.storage_path = name and d.verifikation_id is not null)
    and not exists (
      select 1 from public.documents d
      join public.bank_transactions bt on bt.import_batch = d.import_batch
      where d.storage_path = name and d.kategori = 'kontoutdrag' and bt.verifikation_id is not null)
  );

-- 4) reset_company: bypass sätts överst (auditerad, behörighetsstyrd totalradering)
create or replace function public.reset_company(p_company uuid, p_opts jsonb)
returns jsonb language plpgsql security definer as $$
declare
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
  v jsonb := '{}'::jsonb; n int;
begin
  perform public._assert_company_access(p_company);
  perform set_config('app.periodlas_bypass', 'on', true);  -- avsiktlig total-radering, auditas nedan
  if coalesce((p_opts->>'bookkeeping')::boolean, false) then
    delete from public.verifikationer where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('verifikationer', n);
  end if;
  if coalesce((p_opts->>'customer_invoices')::boolean, false) then
    delete from public.invoices where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('invoices', n);
  end if;
  if coalesce((p_opts->>'supplier_invoices')::boolean, false) then
    delete from public.supplier_invoices where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('supplier_invoices', n);
  end if;
  if coalesce((p_opts->>'bank_transactions')::boolean, false) then
    delete from public.bank_transactions where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('bank_transactions', n);
  end if;
  if coalesce((p_opts->>'documents')::boolean, false) then
    delete from public.documents where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('documents', n);
  end if;
  if coalesce((p_opts->>'salaries')::boolean, false) then
    delete from public.salaries where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('salaries', n);
  end if;
  if coalesce((p_opts->>'products')::boolean, false) then
    delete from public.products where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('products', n);
  end if;
  if coalesce((p_opts->>'customers')::boolean, false) then
    update public.invoices set customer_id = null where company_id = p_company and customer_id is not null;
    delete from public.customers where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('customers', n);
  end if;
  if coalesce((p_opts->>'suppliers')::boolean, false) then
    update public.supplier_invoices set supplier_id = null where company_id = p_company and supplier_id is not null;
    delete from public.suppliers where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('suppliers', n);
  end if;
  if coalesce((p_opts->>'chart_of_accounts')::boolean, false) then
    perform set_config('app.bulk_import', 'on', true);
    perform set_config('app.allow_locked_change', 'on', true);  -- tillåt radering av låsta vid full återställning
    delete from public.accounts where company_id = p_company;
    get diagnostics n = row_count; v := v || jsonb_build_object('accounts', n);
  end if;
  if coalesce((p_opts->>'settings')::boolean, false) then
    begin
      update public.companies set onboarded = false where id = p_company;
      v := v || jsonb_build_object('settings_reset', true);
    exception when undefined_column then
      v := v || jsonb_build_object('settings_reset', false);
    end;
  end if;
  insert into public.audit_log(company_id, entity, action, new_data, changed_by, changed_by_email)
  values (p_company, 'company', 'reset', p_opts || jsonb_build_object('result', v), v_uid, v_email);
  return jsonb_build_object('ok', true, 'deleted', v);
end;
$$;
