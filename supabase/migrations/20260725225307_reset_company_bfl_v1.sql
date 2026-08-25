create or replace function public.reset_company(p_company uuid, p_opts jsonb)
returns jsonb
language plpgsql
security definer
as $function$
declare
  v_email text := auth.jwt() ->> 'email';
  v_uid uuid := auth.uid();
  v jsonb := '{}'::jsonb; n int;
  v_har_bokforing boolean;
  v_rakenskapsdelar text[] := array[
    'bookkeeping','customer_invoices','supplier_invoices',
    'bank_transactions','documents','salaries','chart_of_accounts'
  ];
  v_begard text[];
begin
  perform public._assert_company_access(p_company);

  if not (public.ar_bolagsadmin(p_company) or public.is_platform_admin()) then
    raise exception 'ATKOMST_NEKAD: Endast bolagets administratör kan återställa företaget.';
  end if;

  select coalesce(array_agg(k), '{}')
    into v_begard
  from jsonb_each(p_opts) as e(k, val)
  where k = any(v_rakenskapsdelar)
    and coalesce((val #>> '{}')::boolean, false);

  if array_length(v_begard, 1) > 0 then
    select exists(select 1 from public.verifikationer where company_id = p_company)
      into v_har_bokforing;

    if v_har_bokforing then
      raise exception 'BFL_SKYDD: Bolaget har bokföring och kan inte återställas. Räkenskapsinformation måste bevaras i sju år (BFL 7 kap. 2 §). Rätta i stället med makulering/omvänd verifikation, eller avsluta bolaget med arkivexport.';
    end if;

    perform set_config('app.periodlas_bypass', 'on', true);
  end if;

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
    perform set_config('app.allow_locked_change', 'on', true);
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
$function$;

revoke execute on function public.reset_company(uuid, jsonb) from anon;
