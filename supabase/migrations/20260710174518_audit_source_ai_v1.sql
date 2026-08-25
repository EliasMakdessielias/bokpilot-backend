-- Audit source 'ai'/'mcp' (REGELEFTERLEVNAD 2.5): bokfor_verifikation får valfri
-- p_source som sätts som transaktionslokal GUC app.audit_source; audit-triggrarna
-- läser den före ui/system-fallbacken. AI-flödena i appen skickar 'ai', MCP-
-- connectorn 'mcp'. Signaturbyte kräver drop (annars PostgREST-överlagring).

drop function if exists public.bokfor_verifikation(uuid, text, date, text, jsonb, text, uuid);

create or replace function public.bokfor_verifikation(
  p_company_id uuid, p_serie text, p_datum date, p_beskrivning text, p_rader jsonb,
  p_motpart text default null, p_created_by uuid default null, p_source text default null
) returns public.verifikationer
language plpgsql as $$
declare
  v_nr text;
  v_ver public.verifikationer;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  rad jsonb;
  i int := 0;
begin
  if p_source is not null and p_source in ('ai', 'mcp') then
    perform set_config('app.audit_source', p_source, true);   -- läses av audit-triggrarna
  end if;
  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'Verifikationen saknar rader';
  end if;
  select coalesce(sum(coalesce((x->>'debet')::numeric, 0)), 0),
         coalesce(sum(coalesce((x->>'kredit')::numeric, 0)), 0)
    into v_debet, v_kredit
    from jsonb_array_elements(p_rader) x;
  if round(v_debet, 2) <> round(v_kredit, 2) then
    raise exception 'Verifikationen balanserar inte (debet %, kredit %)', v_debet, v_kredit;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || '|' || p_serie, 0));
  v_nr := public.next_ver_nr(p_company_id, p_serie);

  insert into public.verifikationer
    (company_id, ver_nr, ver_serie, datum, beskrivning, motpart, total_debet, total_kredit, created_by)
  values
    (p_company_id, v_nr, p_serie, p_datum, left(p_beskrivning, 500),
     nullif(trim(coalesce(p_motpart, '')), ''), round(v_debet, 2), round(v_kredit, 2),
     coalesce(p_created_by, auth.uid()))
  returning * into v_ver;

  for rad in select * from jsonb_array_elements(p_rader) loop
    insert into public.verifikation_rows
      (verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
    values
      (v_ver.id, rad->>'account_nr', rad->>'account_name',
       coalesce((rad->>'debet')::numeric, 0), coalesce((rad->>'kredit')::numeric, 0),
       nullif(rad->>'transaction_info', ''), coalesce((rad->>'sort_order')::int, i));
    i := i + 1;
  end loop;

  return v_ver;
end $$;

grant execute on function public.bokfor_verifikation(uuid, text, date, text, jsonb, text, uuid, text) to authenticated, service_role;

-- Audit-triggrarna: GUC:en vinner över ui/system-härledningen.
create or replace function public.audit_verifikation() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                               case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if tg_op = 'INSERT' then
      perform public.log_accounting_audit('verification_created', 'verifikation', new.id::text, v_src,
        jsonb_build_object('ver_nr', new.ver_nr, 'ver_serie', new.ver_serie, 'datum', new.datum,
          'total_debet', new.total_debet, 'total_kredit', new.total_kredit), new.company_id, null, null);
    elsif tg_op = 'UPDATE' then
      perform public.log_accounting_audit('verification_updated', 'verifikation', new.id::text, v_src,
        jsonb_build_object('ver_nr', new.ver_nr), new.company_id,
        jsonb_build_object('beskrivning', old.beskrivning, 'total_debet', old.total_debet, 'total_kredit', old.total_kredit, 'is_locked', old.is_locked),
        jsonb_build_object('beskrivning', new.beskrivning, 'total_debet', new.total_debet, 'total_kredit', new.total_kredit, 'is_locked', new.is_locked));
    elsif tg_op = 'DELETE' then
      perform public.log_accounting_audit('verification_deleted_current_legacy_flow', 'verifikation', old.id::text, v_src,
        jsonb_build_object('warning', 'Legacy deletion flow, should be replaced by reversal flow'), old.company_id,
        jsonb_build_object('ver_nr', old.ver_nr, 'ver_serie', old.ver_serie, 'datum', old.datum, 'beskrivning', old.beskrivning,
          'total_debet', old.total_debet, 'total_kredit', old.total_kredit,
          'rader', (select coalesce(jsonb_agg(jsonb_build_object('konto', vr.account_nr, 'debet', vr.debet, 'kredit', vr.kredit) order by vr.sort_order), '[]'::jsonb)
                    from public.verifikation_rows vr where vr.verifikation_id = old.id)), null);
    end if;
  exception when others then null;   -- audit får aldrig stoppa bokföringen
  end;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

create or replace function public.audit_supplier_invoice_booked() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                               case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if (tg_op = 'INSERT' and coalesce(new.bokford, false))
       or (tg_op = 'UPDATE' and coalesce(new.bokford, false) and not coalesce(old.bokford, false)) then
      perform public.log_accounting_audit('supplier_invoice_booked', 'supplier_invoice', new.id::text, v_src,
        jsonb_build_object('invoice_nr', new.invoice_nr, 'supplier_id', new.supplier_id, 'verifikation_id', new.verifikation_id,
          'total_amount', new.total_amount, 'vat_amount', new.vat_amount, 'is_credit_invoice', new.kreditfaktura),
        new.company_id, null, null);
    end if;
  exception when others then null;
  end;
  return new;
end $$;

create or replace function public.audit_customer_invoice_booked() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                               case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if (tg_op = 'INSERT' and new.verifikation_id is not null)
       or (tg_op = 'UPDATE' and new.verifikation_id is not null and old.verifikation_id is null) then
      perform public.log_accounting_audit('customer_invoice_booked', 'invoice', new.id::text, v_src,
        jsonb_build_object('invoice_nr', new.invoice_nr, 'customer_id', new.customer_id, 'verifikation_id', new.verifikation_id,
          'total_amount', new.total_amount, 'vat_amount', new.vat_amount),
        new.company_id, null, null);
    end if;
  exception when others then null;
  end;
  return new;
end $$;
