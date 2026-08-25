-- Org.nr är obligatoriskt när byrån skapar klientbolag (Elias 2026-07-14).
create or replace function public.byra_skapa_klient(
  p_byra_bolag_id uuid,
  p_namn text,
  p_org_nr text default null,
  p_foretagsform text default null,
  p_momsperiod text default null
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_namn text := trim(coalesce(p_namn, ''));
  v_orgnr text := regexp_replace(coalesce(p_org_nr, ''), '\D', '', 'g');
  v_klient uuid;
  v_bk uuid;
  v_epost text;
begin
  if auth.uid() is null then raise exception 'Ej inloggad'; end if;
  if not public.ar_byra_admin(p_byra_bolag_id) then
    raise exception 'Endast byråns administratör får lägga till klienter';
  end if;
  if length(v_namn) < 2 then raise exception 'Ange klientens bolagsnamn'; end if;
  if length(v_orgnr) <> 10 then raise exception 'Ange ett giltigt organisationsnummer (10 siffror)'; end if;

  insert into public.companies (name, org_nr, foretagsform, momsperiod, suspended, abonnemang_status)
  values (
    v_namn,
    trim(p_org_nr),
    nullif(trim(coalesce(p_foretagsform, '')), ''),
    nullif(trim(coalesce(p_momsperiod, '')), ''),
    false, 'testperiod'
  )
  returning id into v_klient;

  insert into public.byra_klient (byra_bolag_id, klient_bolag_id, status, kundansvarig_anvandare_id, tillagd_av)
  values (p_byra_bolag_id, v_klient, 'aktiv', auth.uid(), auth.uid())
  returning id into v_bk;

  select email into v_epost from auth.users where id = auth.uid();
  insert into public.user_companies (user_id, company_id, role, email)
  values (auth.uid(), v_klient, 'admin', v_epost)
  on conflict (user_id, company_id) do nothing;

  return jsonb_build_object('klient_bolag_id', v_klient, 'byra_klient_id', v_bk, 'namn', v_namn);
end $$;
