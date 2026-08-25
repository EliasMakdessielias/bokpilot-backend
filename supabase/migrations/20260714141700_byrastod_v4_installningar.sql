-- Byråstöd v4: Byråinställningar (2026-07-14)
-- 1) byra_installningar — byråns egna inställningar (en rad per byrå)
-- 2) companies-läsning för byråmedlemmar (byråns bolag + klientbolagen)
-- 3) Sista admin-skyddet på byra_medlemskap
-- 4) RPC byra_uppdatera_uppgifter — byrå-admin redigerar byråns bolagsuppgifter
-- 5) byra_skapa_klient v2 — skapar även standarduppdrag från byra_installningar

-- ── 1) Byråns inställningar ──────────────────────────────────────────────
create table public.byra_installningar (
  byra_bolag_id uuid primary key references public.companies(id) on delete cascade,
  -- Standardval för "Bjud in kundens användare": null = alla funktioner
  -- (samma semantik som user_companies.moduler, se src/lib/moduler.js).
  standard_moduler text[],
  -- Uppdragstyper som automatiskt läggs på nya klienter (tom = inga).
  -- Ogiltiga typer för klientens bolagsform hoppas över vid skapandet.
  standard_uppdragstyper text[] not null default '{}',
  updated_at timestamptz not null default now(),
  updated_av uuid
);
alter table public.byra_installningar enable row level security;
create policy byra_installningar_select on public.byra_installningar
  for select using (byra_bolag_id in (select public.min_byra_ids()));
create policy byra_installningar_insert on public.byra_installningar
  for insert with check (public.ar_byra_admin(byra_bolag_id));
create policy byra_installningar_update on public.byra_installningar
  for update using (public.ar_byra_admin(byra_bolag_id));

-- ── 2) Byråmedlemmar får LÄSA byråns bolag + klientbolagen ───────────────
-- (Behövs för Byråinställningar och för att konsulter utan user_companies-
-- koppling ska se klientnamnen i Klientöversikten. Endast select — skrivning
-- går via RPC:er med ar_byra_admin-kontroll.)
create or replace function public.byra_synliga_bolag_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select bm.byra_bolag_id from byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv
  union
  select bk.klient_bolag_id from byra_klient bk
  join byra_medlemskap bm on bm.byra_bolag_id = bk.byra_bolag_id
  where bm.anvandare_id = auth.uid() and bm.aktiv
$$;
create policy companies_byra_select on public.companies
  for select using (id in (select public.byra_synliga_bolag_ids()));

-- ── 3) Sista admin-skyddet ───────────────────────────────────────────────
-- Byråns sista aktiva administratör kan inte nedgraderas, inaktiveras eller
-- raderas — annars låses byrån ute från sin egen administration.
create or replace function public.skydda_sista_byra_admin()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_gammal record := coalesce(old, new);
begin
  if old.roll = 'admin' and old.aktiv
     and (tg_op = 'DELETE' or new.roll <> 'admin' or not new.aktiv) then
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
create trigger byra_medlemskap_sista_admin
  before update or delete on public.byra_medlemskap
  for each row execute function public.skydda_sista_byra_admin();

-- ── 4) Byrå-admin redigerar byråns bolagsuppgifter ───────────────────────
-- (Byråmedlemskap =/= user_companies — RLS-policyn users_own_companies räcker
-- inte för byrå-admins utan egen bolagskoppling, därav security definer + egen check.)
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

-- ── 5) byra_skapa_klient v2: standarduppdrag från byråinställningarna ────
-- Samma signatur som v1 (byrastod_v3*) — create or replace. Nya beteendet:
-- efter klientskapandet läggs uppdrag för byra_installningar.standard_uppdragstyper,
-- filtrerat mot bolagsformens giltiga typer (spegel av valbaraUppdragstyper i
-- src/lib/byrastod.js: årsredovisning endast AB; inkomstdeklaration AB + enskild firma).
create or replace function public.byra_skapa_klient(
  p_byra_bolag_id uuid, p_namn text, p_org_nr text default null,
  p_foretagsform text default null, p_momsperiod text default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_namn text := trim(coalesce(p_namn, ''));
  v_orgnr text := regexp_replace(coalesce(p_org_nr, ''), '\D', '', 'g');
  v_form text := nullif(trim(coalesce(p_foretagsform, '')), '');
  v_klient uuid;
  v_bk uuid;
  v_epost text;
  v_typ text;
  v_antal_uppdrag int := 0;
begin
  if auth.uid() is null then raise exception 'Ej inloggad'; end if;
  if not public.ar_byra_admin(p_byra_bolag_id) then
    raise exception 'Endast byråns administratör får lägga till klienter';
  end if;
  if length(v_namn) < 2 then raise exception 'Ange klientens bolagsnamn'; end if;
  if length(v_orgnr) <> 10 then raise exception 'Ange ett giltigt organisationsnummer (10 siffror)'; end if;

  insert into public.companies (name, org_nr, foretagsform, momsperiod, suspended, abonnemang_status)
  values (v_namn, trim(p_org_nr), v_form, nullif(trim(coalesce(p_momsperiod, '')), ''), false, 'testperiod')
  returning id into v_klient;

  insert into public.byra_klient (byra_bolag_id, klient_bolag_id, status, kundansvarig_anvandare_id, tillagd_av)
  values (p_byra_bolag_id, v_klient, 'aktiv', auth.uid(), auth.uid())
  returning id into v_bk;

  select email into v_epost from auth.users where id = auth.uid();
  insert into public.user_companies (user_id, company_id, role, email)
  values (auth.uid(), v_klient, 'admin', v_epost)
  on conflict (user_id, company_id) do nothing;

  -- Standarduppdrag (Byråinställningar → Klientstandarder)
  for v_typ in
    select distinct t from byra_installningar bi, unnest(bi.standard_uppdragstyper) t
    where bi.byra_bolag_id = p_byra_bolag_id
      and t in ('lopande_bokforing','momsdeklaration','lon_agi','bokslut','arsredovisning','inkomstdeklaration')
      and (t <> 'arsredovisning' or v_form = 'Aktiebolag')
      and (t <> 'inkomstdeklaration' or v_form in ('Aktiebolag','Enskild näringsidkare'))
  loop
    insert into public.uppdrag (byra_klient_id, byra_bolag_id, klient_bolag_id, uppdragstyp,
      bokforingstakt, startdatum, status)
    values (v_bk, p_byra_bolag_id, v_klient, v_typ,
      case when v_typ = 'lopande_bokforing' then 'manad' end, date_trunc('month', now())::date, 'aktiv');
    v_antal_uppdrag := v_antal_uppdrag + 1;
  end loop;

  return jsonb_build_object('klient_bolag_id', v_klient, 'byra_klient_id', v_bk,
    'namn', v_namn, 'antal_uppdrag', v_antal_uppdrag);
end $$;
