-- Etapp 14: automatisk bevakning av kundkännedomens giltighet (PTL 3 kap. 13 §).
--
-- Regelefterlevnadsgranskningen 2026-08-25 fann att has_kyc_clearance() prövar
-- giltig_till men saknar verkställande anropare, och att aml_run_checks() bara körs
-- från en knapp i UI:t. När en godkänd bedömning löper ut går ingen notifiering ut,
-- ingen flagga skapas och ingenting spärras — trots att UI:t skriver "automation
-- spärrad" och kallar det "AUTO-grind".
--
-- Det här jobbet bevakar ENBART kalendern: saknad, utgången eller snart utgående
-- kundkännedom. Det anropar medvetet INTE aml_run_checks — den funktionen skapar
-- aml_installningar med standardtrösklar "on conflict do nothing", dvs. utan att en
-- människa fattat beslutet, och transaktionsövervakningens trösklar är verksamhets-
-- utövarens ansvar enligt den allmänna riskbedömningen (2 kap. 1 §).
--
-- Flaggorna landar i aml_flags (typ 'kyc_saknas', som redan finns i CHECK-listan)
-- och syns därmed i byråns befintliga AML-vy. Dedup-nyckeln gör att samma
-- omständighet flaggas en gång, inte varje natt.

create or replace function public.cron_kyc_bevakning()
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  r record; n_nya int := 0; v_giltig date; v_dagar int;
begin
  for r in
    select bk.klient_bolag_id as company_id, c.name
    from public.byra_klient bk
    join public.companies c on c.id = bk.klient_bolag_id
    where bk.status = 'aktiv'
  loop
    select k.giltig_till into v_giltig
    from public.kyc_assessments k
    where k.company_id = r.company_id and k.status = 'godkand'
    order by k.beslutad_at desc nulls last, k.created_at desc
    limit 1;

    if not found then
      -- Ingen godkänd bedömning alls. En flagga per månad så länge det består.
      insert into public.aml_flags (company_id, typ, allvarlighet, beskrivning, dedup_nyckel)
      values (r.company_id, 'kyc_saknas', 'hog',
              'Ingen godkänd kundkännedomsbedömning finns för bolaget. Kundkännedom ska vara genomförd innan affärsförbindelsen inleds (PTL 3 kap. 4 §).',
              'kyc_saknas:' || to_char(current_date, 'YYYY-MM'))
      on conflict (company_id, dedup_nyckel) do nothing;
      if found then n_nya := n_nya + 1; end if;

    elsif v_giltig is not null and v_giltig < current_date then
      insert into public.aml_flags (company_id, typ, allvarlighet, beskrivning, dedup_nyckel)
      values (r.company_id, 'kyc_saknas', 'hog',
              format('Kundkännedomen löpte ut %s. Förnya bedömningen — fortlöpande uppföljning krävs (PTL 3 kap. 13 §).', v_giltig),
              'kyc_utgangen:' || v_giltig)
      on conflict (company_id, dedup_nyckel) do nothing;
      if found then n_nya := n_nya + 1; end if;

    elsif v_giltig is not null and v_giltig <= current_date + 30 then
      v_dagar := v_giltig - current_date;
      insert into public.aml_flags (company_id, typ, allvarlighet, beskrivning, dedup_nyckel)
      values (r.company_id, 'kyc_saknas', 'normal',
              format('Kundkännedomen löper ut %s (om %s dagar). Planera förnyelse.', v_giltig, v_dagar),
              'kyc_utgar:' || v_giltig)
      on conflict (company_id, dedup_nyckel) do nothing;
      if found then n_nya := n_nya + 1; end if;
    end if;
  end loop;

  perform public.record_worker_health('kyc_bevakning', true);
exception when others then
  perform public.record_worker_health('kyc_bevakning', false, left(sqlerrm, 300));
  raise;
end $fn$;

revoke execute on function public.cron_kyc_bevakning() from public, anon, authenticated;

select cron.schedule('kyc-bevakning-natt', '35 4 * * *', 'select public.cron_kyc_bevakning()');

-- Registrera i driftövervakningen — och registrera samtidigt vakten själv, som
-- saknades i sitt eget register (etapp 11). Den kan inte larma om sig själv, men
-- driftstatus() visar då TYST vid manuell kontroll om den slutat köra.
insert into public.driftkomponenter (namn, typ, max_tyst_timmar, max_fel_i_rad, beskrivning) values
  ('kyc-bevakning-natt', 'cron', 36, 1, 'Bevakar kundkännedomens giltighet per byråklient 04:35 (PTL 3 kap. 13 §)'),
  ('driftkontroll-natt', 'cron', 36, 1, 'Driftvakten själv 03:50 — larmar vid statusförändring')
on conflict (namn) do nothing;
