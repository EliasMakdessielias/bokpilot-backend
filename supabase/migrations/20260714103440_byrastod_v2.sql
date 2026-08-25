-- Byråstöd etapp B: deadline-motorn och Uppdragsregistret.
-- (Innehållet är identiskt med supabase/byrastod_v2.sql i repot.)

alter table public.companies drop constraint if exists companies_foretagsform_check;
alter table public.companies add constraint companies_foretagsform_check check (
  foretagsform is null or foretagsform in (
    'Aktiebolag', 'Enskild näringsidkare', 'Handelsbolag/Kommanditbolag',
    'Ekonomisk förening', 'Ideell förening', 'Bostadsrättsförening', 'Övrigt'
  )
);

create table if not exists public.deadline_regel (
  id uuid primary key default gen_random_uuid(),
  uppgiftstyp text not null check (uppgiftstyp in
    ('lopande_bokforing', 'momsdeklaration', 'lon_agi', 'bokslut', 'arsredovisning', 'inkomstdeklaration')),
  bolagsform text check (bolagsform in ('Aktiebolag', 'Enskild näringsidkare')),
  variant text,
  parametrar jsonb not null,
  kalla text,
  giltig_fran date not null default current_date,
  giltig_till date,
  uppdaterad_at timestamptz not null default now()
);
create unique index if not exists deadline_regel_nyckel_idx
  on public.deadline_regel (uppgiftstyp, coalesce(bolagsform, ''), coalesce(variant, ''), giltig_fran);
alter table public.deadline_regel enable row level security;
create policy deadline_regel_select on public.deadline_regel
  for select to authenticated using (public.ar_byra_medlem());

create table if not exists public.ink2_deklarationstidpunkt (
  id uuid primary key default gen_random_uuid(),
  bokslutsar int not null,
  bokslutsmanad_fran int not null check (bokslutsmanad_fran between 1 and 12),
  bokslutsmanad_till int not null check (bokslutsmanad_till between 1 and 12),
  deadline date not null,
  kalla text,
  unique (bokslutsar, bokslutsmanad_fran)
);
alter table public.ink2_deklarationstidpunkt enable row level security;
create policy ink2_tidpunkt_select on public.ink2_deklarationstidpunkt
  for select to authenticated using (public.ar_byra_medlem());

create table if not exists public.uppdrag (
  id uuid primary key default gen_random_uuid(),
  byra_klient_id uuid not null references public.byra_klient(id) on delete restrict,
  byra_bolag_id uuid not null references public.companies(id) on delete restrict,
  klient_bolag_id uuid not null references public.companies(id) on delete restrict,
  uppdragstyp text not null check (uppdragstyp in
    ('lopande_bokforing', 'momsdeklaration', 'lon_agi', 'bokslut', 'arsredovisning', 'inkomstdeklaration')),
  uppdragsansvarig_anvandare_id uuid,
  bokforingstakt text check (bokforingstakt in ('dag', 'manad', 'kvartal', 'rakenskapsar')),
  byraanstand_aktiv boolean not null default false,
  revisionsplikt boolean not null default false,
  startdatum date not null default current_date,
  status text not null default 'aktiv' check (status in ('aktiv', 'pausad', 'avslutad')),
  skapad_av uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (byra_klient_id, uppdragstyp),
  check (bokforingstakt is null or uppdragstyp = 'lopande_bokforing'),
  check (not revisionsplikt or uppdragstyp = 'bokslut'),
  check (not byraanstand_aktiv or uppdragstyp in ('momsdeklaration', 'inkomstdeklaration'))
);
create index if not exists uppdrag_byra_idx on public.uppdrag (byra_bolag_id, status);
create index if not exists uppdrag_klient_idx on public.uppdrag (klient_bolag_id);
alter table public.uppdrag enable row level security;

create or replace function public.byrastod_validera_uppdrag() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_form text;
  v_bk record;
begin
  select byra_bolag_id, klient_bolag_id into v_bk from public.byra_klient where id = new.byra_klient_id;
  if v_bk is null then raise exception 'byra_klient saknas'; end if;
  if new.byra_bolag_id <> v_bk.byra_bolag_id or new.klient_bolag_id <> v_bk.klient_bolag_id then
    raise exception 'uppdragets bolagskoppling matchar inte klientkopplingen';
  end if;
  select foretagsform into v_form from public.companies where id = new.klient_bolag_id;
  if new.uppdragstyp = 'arsredovisning' and coalesce(v_form, '') <> 'Aktiebolag' then
    raise exception 'Årsredovisning är endast valbar för aktiebolag';
  end if;
  if new.byraanstand_aktiv and coalesce(v_form, '') <> 'Enskild näringsidkare' then
    raise exception 'Byråanstånd gäller endast enskild näringsverksamhet';
  end if;
  new.updated_at = now();
  return new;
end $$;
drop trigger if exists trg_validera_uppdrag on public.uppdrag;
create trigger trg_validera_uppdrag before insert or update on public.uppdrag
  for each row execute function public.byrastod_validera_uppdrag();

create policy uppdrag_select on public.uppdrag
  for select to authenticated using (
    byra_bolag_id in (select public.min_byra_ids())
    and (
      public.ar_byra_admin(byra_bolag_id)
      or uppdragsansvarig_anvandare_id = auth.uid()
      or exists (select 1 from public.byra_klient bk
                 where bk.id = uppdrag.byra_klient_id and bk.kundansvarig_anvandare_id = auth.uid())
    )
  );
create policy uppdrag_insert on public.uppdrag
  for insert to authenticated with check (public.ar_byra_admin(byra_bolag_id));
create policy uppdrag_update on public.uppdrag
  for update to authenticated using (public.ar_byra_admin(byra_bolag_id));

create table if not exists public.uppdragsuppgift (
  id uuid primary key default gen_random_uuid(),
  uppdrag_id uuid not null references public.uppdrag(id) on delete restrict,
  byra_bolag_id uuid not null references public.companies(id) on delete restrict,
  klient_bolag_id uuid not null references public.companies(id) on delete restrict,
  uppdragsansvarig_anvandare_id uuid,
  period_start date not null,
  period_slut date not null,
  etikett text not null,
  ordinarie_forfallodatum date,
  revisionsstart_datum date,
  justerat_forfallodatum date,
  justering_anledning text,
  justerad_av uuid,
  justerad_at timestamptz,
  status text not null default 'ej_paborjad' check (status in ('ej_paborjad', 'pagar', 'klar', 'forsenad')),
  klarmarkerad_av uuid,
  klarmarkerad_at timestamptz,
  kommentar text,
  kopplat_underlag_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (uppdrag_id, period_start)
);
create index if not exists uppgift_byra_status_idx
  on public.uppdragsuppgift (byra_bolag_id, status, coalesce(justerat_forfallodatum, ordinarie_forfallodatum));
create index if not exists uppgift_ansvarig_idx
  on public.uppdragsuppgift (uppdragsansvarig_anvandare_id, status);
alter table public.uppdragsuppgift enable row level security;

create policy uppgift_select on public.uppdragsuppgift
  for select to authenticated using (
    byra_bolag_id in (select public.min_byra_ids())
    and (
      public.ar_byra_admin(byra_bolag_id)
      or uppdragsansvarig_anvandare_id = auth.uid()
      or exists (select 1 from public.uppdrag u join public.byra_klient bk on bk.id = u.byra_klient_id
                 where u.id = uppdragsuppgift.uppdrag_id and bk.kundansvarig_anvandare_id = auth.uid())
    )
  );
create policy uppgift_update on public.uppdragsuppgift
  for update to authenticated using (
    byra_bolag_id in (select public.min_byra_ids())
    and (
      public.ar_byra_admin(byra_bolag_id)
      or uppdragsansvarig_anvandare_id = auth.uid()
      or exists (select 1 from public.uppdrag u join public.byra_klient bk on bk.id = u.byra_klient_id
                 where u.id = uppdragsuppgift.uppdrag_id and bk.kundansvarig_anvandare_id = auth.uid())
    )
  );

revoke update on public.uppdragsuppgift from authenticated;
grant update (status, klarmarkerad_av, klarmarkerad_at, kommentar, kopplat_underlag_id, revisionsstart_datum, updated_at)
  on public.uppdragsuppgift to authenticated;

create or replace function public.byrastod_uppgift_fore_update() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_revisionsplikt boolean;
  v_dagar int;
begin
  if new.revisionsstart_datum is distinct from old.revisionsstart_datum then
    select u.revisionsplikt into v_revisionsplikt from public.uppdrag u where u.id = new.uppdrag_id;
    if coalesce(v_revisionsplikt, false) then
      select (parametrar->>'dagar_fore')::int into v_dagar
      from public.deadline_regel
      where uppgiftstyp = 'bokslut' and variant = 'revisionsstart'
        and (giltig_till is null or giltig_till >= current_date)
      order by giltig_fran desc limit 1;
      new.ordinarie_forfallodatum = case
        when new.revisionsstart_datum is null then null
        else new.revisionsstart_datum - coalesce(v_dagar, 14)
      end;
    end if;
  end if;
  if new.status = 'klar' and old.status <> 'klar' and new.klarmarkerad_at is null then
    new.klarmarkerad_at = now();
  end if;
  new.updated_at = now();
  return new;
end $$;
drop trigger if exists trg_uppgift_fore_update on public.uppdragsuppgift;
create trigger trg_uppgift_fore_update before update on public.uppdragsuppgift
  for each row execute function public.byrastod_uppgift_fore_update();

create or replace function public.justera_uppgift_deadline(
  p_uppgift_id uuid, p_nytt_datum date, p_anledning text
) returns public.uppdragsuppgift
language plpgsql security definer set search_path = '' as $$
declare
  v_u public.uppdragsuppgift;
  v_behorig boolean;
begin
  select * into v_u from public.uppdragsuppgift where id = p_uppgift_id;
  if v_u is null then raise exception 'uppgiften finns inte'; end if;
  select (
    public.ar_byra_admin(v_u.byra_bolag_id)
    or v_u.uppdragsansvarig_anvandare_id = auth.uid()
    or exists (select 1 from public.uppdrag u join public.byra_klient bk on bk.id = u.byra_klient_id
               where u.id = v_u.uppdrag_id and bk.kundansvarig_anvandare_id = auth.uid())
  ) and v_u.byra_bolag_id in (select public.min_byra_ids()) into v_behorig;
  if not coalesce(v_behorig, false) then
    raise exception 'endast byråns ansvariga får justera förfallodatum';
  end if;
  if length(trim(coalesce(p_anledning, ''))) < 3 then
    raise exception 'anledning krävs vid justering av förfallodatum';
  end if;
  update public.uppdragsuppgift set
    justerat_forfallodatum = p_nytt_datum,
    justering_anledning = trim(p_anledning),
    justerad_av = auth.uid(),
    justerad_at = now(),
    status = case when status = 'forsenad' then 'ej_paborjad' else status end,
    updated_at = now()
  where id = p_uppgift_id
  returning * into v_u;
  return v_u;
end $$;
revoke all on function public.justera_uppgift_deadline(uuid, date, text) from public, anon;
grant execute on function public.justera_uppgift_deadline(uuid, date, text) to authenticated;

create or replace function public.byrastod_markera_forsenade() returns int
language plpgsql security definer set search_path = '' as $$
declare v_antal int;
begin
  if auth.uid() is not null and not public.ar_byra_medlem() then
    raise exception 'endast byråmedlem eller systemjobb';
  end if;
  update public.uppdragsuppgift set status = 'forsenad', updated_at = now()
  where status in ('ej_paborjad', 'pagar')
    and coalesce(justerat_forfallodatum, ordinarie_forfallodatum) < current_date;
  get diagnostics v_antal = row_count;
  return v_antal;
end $$;
revoke all on function public.byrastod_markera_forsenade() from public, anon;
grant execute on function public.byrastod_markera_forsenade() to authenticated, service_role;

insert into public.deadline_regel (uppgiftstyp, bolagsform, variant, parametrar, kalla) values
  ('momsdeklaration', null, 'manad12',
   '{"typ":"dag_i_manad","manad_forskjutning":2,"dag":12,"undantag":[{"manad":1,"dag":17},{"manad":8,"dag":17}],"helgforskjut":true}',
   'https://www.skatteverket.se/foretag/moms/deklareramoms/narskajagdeklareramoms.4.6d02084411db6e252fe80008988.html'),
  ('momsdeklaration', null, 'manad26',
   '{"typ":"dag_i_manad","manad_forskjutning":1,"dag":26,"undantag":[],"helgforskjut":true}',
   'https://www.skatteverket.se/foretag/moms/deklareramoms/narskajagdeklareramoms.4.6d02084411db6e252fe80008988.html'),
  ('momsdeklaration', null, 'kvartal',
   '{"typ":"dag_i_manad","manad_forskjutning":2,"dag":12,"undantag":[{"manad":8,"dag":17}],"helgforskjut":true}',
   'https://www.skatteverket.se/foretag/moms/deklareramoms/narskajagdeklareramoms.4.6d02084411db6e252fe80008988.html'),
  ('momsdeklaration', 'Aktiebolag', 'ar',
   '{"typ":"grupp_efter_bokslutsmanad","helgforskjut":true,"grupper":[{"fran":1,"till":4,"manad":12,"dag":12,"ar_offset":0},{"fran":5,"till":6,"manad":1,"dag":17,"ar_offset":1},{"fran":7,"till":8,"manad":4,"dag":12,"ar_offset":1},{"fran":9,"till":12,"manad":8,"dag":17,"ar_offset":1}]}',
   'https://www.skatteverket.se/foretag/moms/deklareramoms/narskajagdeklareramoms.4.6d02084411db6e252fe80008988.html'),
  ('momsdeklaration', 'Enskild näringsidkare', 'ar',
   '{"typ":"fast_datum_per_ar","helgforskjut":true,"ordinarie":{"manad":5,"dag":12},"byraanstand":{"manad":6,"dag":15}}',
   'https://www.skatteverket.se/foretag/moms/deklareramoms/narskajagdeklareramoms.4.6d02084411db6e252fe80008988.html'),
  ('lon_agi', null, null,
   '{"typ":"dag_i_manad","manad_forskjutning":1,"dag":12,"undantag":[{"manad":1,"dag":17},{"manad":8,"dag":17}],"helgforskjut":true}',
   'https://www.skatteverket.se/foretag/arbetsgivare/lamnaarbetsgivardeklaration.4.41f1c61d16193087d7fcaeb.html'),
  ('lopande_bokforing', null, 'manad',
   '{"typ":"dagar_efter_period","dagar":50}', 'BFL 5 kap — 50 dagar efter månadens utgång'),
  ('lopande_bokforing', null, 'kvartal',
   '{"typ":"dagar_efter_period","dagar":50}', 'BFL 5 kap — nettooms ≤ 3 mkr: 50 dagar efter kvartalets utgång'),
  ('lopande_bokforing', null, 'rakenskapsar',
   '{"typ":"dagar_efter_period","dagar":60}', 'BFL 5 kap — mikroföretag: 60 dagar efter räkenskapsårets utgång'),
  ('bokslut', null, 'revisionsstart',
   '{"typ":"bokslut_revisionsstart","dagar_fore":14}', 'Internt (BokPilot) + klientens revisor'),
  ('bokslut', null, 'internt_sla',
   '{"typ":"bokslut_internt_sla","dagar_fore":30}', 'Internt SLA (BokPilot)'),
  ('arsredovisning', 'Aktiebolag', null,
   '{"typ":"manader_efter_bokslut","manader":7,"helgforskjut":true}',
   'https://bolagsverket.se/foretag/aktiebolag/arsredovisningforaktiebolag'),
  ('inkomstdeklaration', 'Aktiebolag', null,
   '{"typ":"grupp_efter_bokslutsmanad","helgforskjut":true,"grupper":[{"fran":1,"till":4,"manad":12,"dag":1,"ar_offset":0},{"fran":5,"till":6,"manad":1,"dag":15,"ar_offset":1},{"fran":7,"till":8,"manad":4,"dag":1,"ar_offset":1},{"fran":9,"till":12,"manad":8,"dag":1,"ar_offset":1}]}',
   'https://www.skatteverket.se/foretag/inkomstdeklaration/deklareraatettaktiebolagellerenekonomiskforening.4.46ae6b26141980f1e2d1261.html'),
  ('inkomstdeklaration', 'Enskild näringsidkare', null,
   '{"typ":"fast_datum_per_ar","helgforskjut":true,"ordinarie":{"manad":5,"dag":2},"byraanstand":{"manad":6,"dag":15}}',
   'https://www.skatteverket.se/privat/etjansterochblanketter/allaetjanster/tjanster/inkomstdeklaration1.4.18e1b10334ebe8bc80005676.html')
on conflict do nothing;

insert into public.ink2_deklarationstidpunkt (bokslutsar, bokslutsmanad_fran, bokslutsmanad_till, deadline, kalla) values
  (2025, 9, 12, '2026-08-03', 'SKV: räkenskapsår sep–dec 2025 → 3 augusti 2026'),
  (2026, 1, 4,  '2026-12-01', 'SKV: räkenskapsår jan–apr 2026 → 1 december 2026'),
  (2026, 5, 6,  '2027-01-15', 'SKV: räkenskapsår maj–jun 2026 → 15 januari 2027'),
  (2026, 7, 8,  '2027-04-01', 'SKV: räkenskapsår jul–aug 2026 → 1 april 2027')
on conflict do nothing;
