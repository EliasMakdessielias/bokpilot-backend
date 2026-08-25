-- Radera senaste verifikationen i serien, v2 (Fortnox-modellen, nu även från UI:t).
-- Nummerserien förblir obruten (endast seriens högsta nummer får tas bort), periodlåset
-- kontrolleras av sina triggers vid delete. NYTT i v2: kopplade poster återställs
-- konsekvent i SAMMA transaktion — FK:erna nollar bara id:t men lämnade flaggorna:
--  - leverantörsfaktura som bokfördes av verifikationen → åter obokförd i reskontran
--  - betalning (betalning_ver_id) → fakturan åter obetald (paid_amount minskas med
--    verifikationens belopp), bankhändelsen åter unmatched
--  - underlag återgår till Inkorgen via FK set null (som tidigare)
create or replace function public.radera_senaste_verifikation(p_ver_id uuid)
returns jsonb
language plpgsql
as $function$
declare
  v public.verifikationer;
  v_max_nr int;
  v_nr int;
begin
  -- SECURITY INVOKER: select:en är RLS-filtrerad, så användaren måste tillhöra bolaget.
  select * into v from public.verifikationer where id = p_ver_id;
  if not found then
    raise exception 'Verifikationen finns inte eller tillhör inte ditt bolag';
  end if;
  if coalesce(v.status, 'aktiv') <> 'aktiv' then
    raise exception 'Endast aktiva verifikationer kan tas bort – makulerade/rättade poster bevaras';
  end if;
  select max(nullif(regexp_replace(ver_nr, '\D', '', 'g'), '')::int) into v_max_nr
    from public.verifikationer
   where company_id = v.company_id and ver_serie = v.ver_serie;
  v_nr := nullif(regexp_replace(v.ver_nr, '\D', '', 'g'), '')::int;
  if v_nr is distinct from v_max_nr then
    raise exception 'Endast den senaste verifikationen i serien kan tas bort (nummerserien måste vara obruten) – använd Makulera';
  end if;

  -- Transaktionslokal flagga som släpper förbi raderings- och avkopplingsskydden
  -- för exakt denna sanktionerade väg. Periodlåset kontrolleras fortfarande av
  -- sina egna triggers vid delete.
  perform set_config('app.radera_senaste', 'on', true);

  -- Bokföringsverifikation för leverantörsfaktura → fakturan åter OBOKFÖRD.
  update public.supplier_invoices
     set bokford = false, verifikation_id = null
   where company_id = v.company_id and verifikation_id = p_ver_id;

  -- Betalningsverifikation → fakturan åter obetald (beloppet backas), bankhändelsen åter omatchad.
  update public.supplier_invoices
     set status = 'unpaid', paid_date = null, betalning_ver_id = null,
         paid_amount = greatest(0, round(coalesce(paid_amount, 0) - coalesce(v.total_debet, 0), 2))
   where company_id = v.company_id and betalning_ver_id = p_ver_id;

  update public.bank_transactions
     set status = 'unmatched', verifikation_id = null
   where company_id = v.company_id and verifikation_id = p_ver_id;

  delete from public.verifikationer where id = p_ver_id;
  perform set_config('app.radera_senaste', '', true);
  return jsonb_build_object('ok', true, 'ver_nr', v.ver_nr);
end $function$;
