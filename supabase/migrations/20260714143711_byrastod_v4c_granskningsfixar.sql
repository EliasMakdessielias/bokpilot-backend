-- Byråstöd v4c (2026-07-14): granskningsfixar efter domängranskning av v4.
-- H1: byra_synliga_bolag_ids scopas per roll + klientstatus.
-- M3: sista admin-skyddet radlåser (TOCTOU).
-- M4: byra_skapa_klient hoppar momsdeklaration utan momsperiod + rapporterar hoppade typer.
-- L1: grant-härdning. L2: org.nr-validering i byra_uppdatera_uppgifter.
-- L3: CHECK på standard_uppdragstyper.

-- ── H1: rollscopad companies-läsning ─────────────────────────────────────
-- Speglar byra_klient_select: konsult ser endast klienter där hen är kundansvarig,
-- och endast aktiva klientrelationer. Admin ser byråns alla klienter (inkl. inaktiva
-- — namnet behövs för uppdragshistorik/dokumentationskraven i PTL).
create or replace function public.byra_synliga_bolag_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select bm.byra_bolag_id from byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv
  union
  select bk.klient_bolag_id from byra_klient bk
  join byra_medlemskap bm on bm.byra_bolag_id = bk.byra_bolag_id
  where bm.anvandare_id = auth.uid() and bm.aktiv
    and (bm.roll = 'admin'
         or (bk.kundansvarig_anvandare_id = auth.uid() and bk.status <> 'inaktiv'))
$$;

-- ── M3: radlåsning i sista admin-skyddet ─────────────────────────────────
create or replace function public.skydda_sista_byra_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.roll = 'admin' and old.aktiv
     and (tg_op = 'DELETE' or new.roll <> 'admin' or not new.aktiv) then
    -- Radlås byråns medlemskap: två samtidiga transaktioner kan annars
    -- inaktivera varandras "sista admin" (TOCTOU).
    perform 1 from byra_medlemskap where byra_bolag_id = old.byra_bolag_id for update;
    if not exists (
      select 1 from byra_medlemskap
      where byra_bolag_id = old.byra_bolag_id and id <> old.id and aktiv and roll = 'admin'
    ) then
      raise exception 'Byråns sista administratör kan inte inaktiveras, nedgraderas eller tas bort';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;

-- ── M4: momsuppdrag kräver momsperiod + hoppade typer rapporteras ────────
create or replace function public.byra_skapa_klient(
  p_byra_bolag_id uuid, p_namn text, p_org_nr text default null,
  p_foretagsform text default null, p_momsperiod text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_namn text := trim(coalesce(p_namn, ''));
  v_orgnr text := regexp_replace(coalesce(p_org_nr, ''), '\D', '', 'g');
  v_form text := nullif(trim(coalesce(p_foretagsform, '')), '');
  v_moms text := nullif(trim(coalesce(p_momsperiod, '')), '');
  v_klient uuid;
  v_bk uuid;
  v_epost text;
  v_typ text;
  v_antal_uppdrag int := 0;
  v_hoppade text[] := '{}';
begin
  if auth.uid() is null then raise exception 'Ej inloggad'; end if;
  if not public.ar_byra_admin(p_byra_bolag_id) then
    raise exception 'Endast byråns administratör får lägga till klienter';
  end if;
  if length(v_namn) < 2 then raise exception 'Ange klientens bolagsnamn'; end if;
  if length(v_orgnr) <> 10 then raise exception 'Ange ett giltigt organisationsnummer (10 siffror)'; end if;

  insert into public.companies (name, org_nr, foretagsform, momsperiod, suspended, abonnemang_status)
  values (v_namn, trim(p_org_nr), v_form, v_moms, false, 'testperiod')
  returning id into v_klient;

  insert into public.byra_klient (byra_bolag_id, klient_bolag_id, status, kundansvarig_anvandare_id, tillagd_av)
  values (p_byra_bolag_id, v_klient, 'aktiv', auth.uid(), auth.uid())
  returning id into v_bk;

  select email into v_epost from auth.users where id = auth.uid();
  insert into public.user_companies (user_id, company_id, role, email)
  values (auth.uid(), v_klient, 'admin', v_epost)
  on conflict (user_id, company_id) do nothing;

  -- Standarduppdrag (Byråinställningar → Klientstandarder). Typer som inte kan
  -- bevakas läggs INTE tyst: de returneras i hoppade_typer så UI:t kan varna
  -- (momsdeklaration utan momsperiod genererar aldrig deadlines i byrastod-jobb).
  for v_typ in
    select distinct t from byra_installningar bi, unnest(bi.standard_uppdragstyper) t
    where bi.byra_bolag_id = p_byra_bolag_id
      and t in ('lopande_bokforing','momsdeklaration','lon_agi','bokslut','arsredovisning','inkomstdeklaration')
  loop
    if (v_typ = 'arsredovisning' and coalesce(v_form, '') <> 'Aktiebolag')
       or (v_typ = 'inkomstdeklaration' and coalesce(v_form, '') not in ('Aktiebolag','Enskild näringsidkare'))
       or (v_typ = 'momsdeklaration' and v_moms is null) then
      v_hoppade := v_hoppade || v_typ;
      continue;
    end if;
    insert into public.uppdrag (byra_klient_id, byra_bolag_id, klient_bolag_id, uppdragstyp,
      bokforingstakt, startdatum, status)
    values (v_bk, p_byra_bolag_id, v_klient, v_typ,
      case when v_typ = 'lopande_bokforing' then 'manad' end, date_trunc('month', now())::date, 'aktiv');
    v_antal_uppdrag := v_antal_uppdrag + 1;
  end loop;

  return jsonb_build_object('klient_bolag_id', v_klient, 'byra_klient_id', v_bk,
    'namn', v_namn, 'antal_uppdrag', v_antal_uppdrag, 'hoppade_typer', to_jsonb(v_hoppade));
end $$;

-- ── L2: org.nr-validering i byråuppgifterna ──────────────────────────────
create or replace function public.byra_uppdatera_uppgifter(
  p_byra_bolag_id uuid, p_namn text, p_org_nr text default null,
  p_adress text default null, p_postnr text default null, p_postort text default null,
  p_telefon text default null, p_epost text default null, p_webb text default null
) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Ej inloggad'; end if;
  if not public.ar_byra_admin(p_byra_bolag_id) then
    raise exception 'Endast byråns administratör får ändra byråuppgifterna';
  end if;
  if length(trim(coalesce(p_namn, ''))) < 2 then raise exception 'Ange byråns namn'; end if;
  if nullif(trim(coalesce(p_org_nr, '')), '') is not null
     and length(regexp_replace(p_org_nr, '\D', '', 'g')) <> 10 then
    raise exception 'Ange ett giltigt organisationsnummer (10 siffror)';
  end if;
  update companies set
    name = trim(p_namn),
    org_nr = nullif(trim(coalesce(p_org_nr, '')), ''),
    address = nullif(trim(coalesce(p_adress, '')), ''),
    postnr = nullif(trim(coalesce(p_postnr, '')), ''),
    postort = nullif(trim(coalesce(p_postort, '')), ''),
    phone = nullif(trim(coalesce(p_telefon, '')), ''),
    email = nullif(trim(coalesce(p_epost, '')), ''),
    website = nullif(trim(coalesce(p_webb, '')), '')
  where id = p_byra_bolag_id;
end $$;

-- ── L1: grant-härdning (v1/v3-mönstret) ──────────────────────────────────
revoke all on function public.byra_synliga_bolag_ids() from public, anon;
grant execute on function public.byra_synliga_bolag_ids() to authenticated;
revoke all on function public.byra_uppdatera_uppgifter(uuid, text, text, text, text, text, text, text, text) from public, anon;
grant execute on function public.byra_uppdatera_uppgifter(uuid, text, text, text, text, text, text, text, text) to authenticated;

-- ── L3: CHECK på standard_uppdragstyper ──────────────────────────────────
alter table public.byra_installningar add constraint byra_installningar_typer_check
  check (standard_uppdragstyper <@ array['lopande_bokforing','momsdeklaration','lon_agi','bokslut','arsredovisning','inkomstdeklaration']::text[]);
