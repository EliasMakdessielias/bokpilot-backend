-- makulera_verifikation fallerade i låst period av två skäl:
--   1. motverifikationen bokfördes på originalets (låsta) datum
--   2. statusuppdateringen saknade undantagsflaggan app.rattelse_link
-- Båda hanteras nu på samma sätt som i ratta_verifikation.

create or replace function public.makulera_verifikation(p_ver_id uuid, p_orsak text default null::text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_orig public.verifikationer%rowtype;
  v_mot_id uuid;
  v_mot_nr text;
  v_locked boolean := false;
  v_datum date;
begin
  select * into v_orig from public.verifikationer where id = p_ver_id;
  if not found then
    raise exception 'FEL: Verifikationen finns inte.';
  end if;
  if v_actor is not null and not exists (
    select 1 from public.user_companies uc where uc.user_id = v_actor and uc.company_id = v_orig.company_id
  ) then
    raise exception 'ATKOMST_NEKAD: Du har inte åtkomst till detta företag.';
  end if;
  if v_orig.status = 'makulerad' then
    raise exception 'MAKULERAD: Verifikation % är redan makulerad.', v_orig.ver_nr;
  end if;
  if v_orig.status = 'motverifikation' then
    raise exception 'FEL: En motverifikation kan inte makuleras. Bokför en ny verifikation i stället.';
  end if;
  if v_orig.status in ('rattad', 'rattelse') then
    raise exception 'FEL: Verifikation % ingår i en rättelsekedja (%) och kan inte makuleras.', v_orig.ver_nr, v_orig.status;
  end if;

  -- Ligger originalet i låst period bokförs motverifikationen på första öppna
  -- datum. Det förflutna rörs inte – motposten läggs framåt.
  begin
    perform public.assert_period_open(v_orig.company_id, v_orig.datum);
  exception when others then
    v_locked := true;
  end;
  v_datum := case when v_locked
                  then public.first_open_booking_date(v_orig.company_id)
                  else v_orig.datum end;

  v_mot_nr := public.next_ver_nr(v_orig.company_id, v_orig.ver_serie);
  perform set_config('app.makulera_insert', 'on', true);
  insert into public.verifikationer(company_id, ver_nr, ver_serie, datum, beskrivning,
                                    total_debet, total_kredit, created_by, status, motverkar)
  values (v_orig.company_id, v_mot_nr, v_orig.ver_serie, v_datum,
          left('Makulering av ' || v_orig.ver_nr || coalesce(': ' || nullif(trim(p_orsak), ''), ''), 200),
          v_orig.total_kredit, v_orig.total_debet, v_actor, 'motverifikation', v_orig.id)
  returning id into v_mot_id;
  insert into public.verifikation_rows(verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
  select v_mot_id, r.account_nr, r.account_name, coalesce(r.kredit, 0), coalesce(r.debet, 0), r.transaction_info, r.sort_order
  from public.verifikation_rows r where r.verifikation_id = v_orig.id;
  perform set_config('app.makulera_insert', 'off', true);

  perform set_config('app.rattelse_link', 'on', true);
  update public.verifikationer set status = 'makulerad', makulerad_av = v_mot_id where id = v_orig.id;
  perform set_config('app.rattelse_link', 'off', true);

  update public.supplier_invoices set bokford = false, verifikation_id = null where verifikation_id = v_orig.id;
  update public.supplier_invoices set paid_amount = 0, paid_date = null, status = 'unpaid', betalning_ver_id = null
    where betalning_ver_id = v_orig.id;
  update public.invoices set status = 'sent', betalning_ver_id = null where betalning_ver_id = v_orig.id;
  update public.bank_transactions set status = 'unmatched', verifikation_id = null where verifikation_id = v_orig.id;
  update public.invoices set verifikation_id = null where verifikation_id = v_orig.id;

  perform public.log_accounting_audit(
    'verification_voided', 'verifikation', v_orig.id::text, null,
    jsonb_build_object('ver_nr', v_orig.ver_nr, 'motverifikation_id', v_mot_id, 'motverifikation_nr', v_mot_nr,
                       'orsak', left(nullif(trim(p_orsak), ''), 200),
                       'makuleringsdatum', v_datum, 'period_locked_original', v_locked),
    v_orig.company_id,
    jsonb_build_object('status', 'aktiv'),
    jsonb_build_object('status', 'makulerad', 'makulerad_av', v_mot_id));

  return jsonb_build_object('ok', true, 'motverifikation_id', v_mot_id, 'motverifikation_nr', v_mot_nr,
                            'datum', v_datum, 'period_locked_original', v_locked);
end $function$;
