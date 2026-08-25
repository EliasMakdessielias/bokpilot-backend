-- Byråstöd etapp A (byrastod_v1, 2026-07-11). Spegel: supabase/byrastod.sql.

-- ── Medlemskap: vilka användare som tillhör en byrå och med vilken roll ──
create table if not exists public.byra_medlemskap (
  id uuid primary key default gen_random_uuid(),
  byra_bolag_id uuid not null references public.companies(id) on delete cascade,
  anvandare_id uuid not null,
  roll text not null default 'konsult' check (roll in ('admin', 'konsult')),
  namn text,
  epost text,
  aktiv boolean not null default true,
  tillagd_av uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (byra_bolag_id, anvandare_id)
);
alter table public.byra_medlemskap enable row level security;

-- ── Klientkoppling: en rad = ett klientbolag hos en byrå ──
create table if not exists public.byra_klient (
  id uuid primary key default gen_random_uuid(),
  byra_bolag_id uuid not null references public.companies(id) on delete cascade,
  klient_bolag_id uuid not null references public.companies(id) on delete cascade,
  status text not null default 'aktiv'
    check (status in ('onboarding', 'vantar_godkannande', 'aktiv', 'inaktiv')),
  kundansvarig_anvandare_id uuid,
  tillagd_av uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  avslutad_at timestamptz,
  unique (byra_bolag_id, klient_bolag_id),
  check (byra_bolag_id <> klient_bolag_id)
);
create index if not exists byra_klient_byra_idx on public.byra_klient (byra_bolag_id, status);
alter table public.byra_klient enable row level security;

-- ── Behörighetshelpers (SECURITY DEFINER — undviker rekursiv RLS) ──
create or replace function public.min_byra_ids() returns setof uuid
language sql stable security definer set search_path = '' as $$
  select bm.byra_bolag_id from public.byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv
$$;
revoke all on function public.min_byra_ids() from public, anon;
grant execute on function public.min_byra_ids() to authenticated;

create or replace function public.ar_byra_admin(p_byra_bolag_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.byra_medlemskap bm
    where bm.byra_bolag_id = p_byra_bolag_id
      and bm.anvandare_id = auth.uid() and bm.aktiv and bm.roll = 'admin'
  )
$$;
revoke all on function public.ar_byra_admin(uuid) from public, anon;
grant execute on function public.ar_byra_admin(uuid) to authenticated;

-- ── RLS: byra_medlemskap ──
create policy byra_medlemskap_select on public.byra_medlemskap
  for select to authenticated using (byra_bolag_id in (select public.min_byra_ids()));
create policy byra_medlemskap_insert on public.byra_medlemskap
  for insert to authenticated with check (public.ar_byra_admin(byra_bolag_id));
create policy byra_medlemskap_update on public.byra_medlemskap
  for update to authenticated using (public.ar_byra_admin(byra_bolag_id));

-- ── RLS: byra_klient ──
create policy byra_klient_select on public.byra_klient
  for select to authenticated using (
    byra_bolag_id in (select public.min_byra_ids())
    and (public.ar_byra_admin(byra_bolag_id) or kundansvarig_anvandare_id = auth.uid())
  );
create policy byra_klient_insert on public.byra_klient
  for insert to authenticated with check (public.ar_byra_admin(byra_bolag_id));
create policy byra_klient_update on public.byra_klient
  for update to authenticated using (public.ar_byra_admin(byra_bolag_id));

-- ── ar_byra_medlem() pekas om till nya tabellen (KYC/AML-lagret följer med) ──
create or replace function public.ar_byra_medlem() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from byra_medlemskap where anvandare_id = auth.uid() and aktiv);
$$;

-- ── Seed: AcountX Redovisningsbyrå AB som första byrå ──
do $$
declare
  v_elias uuid;
  v_byra uuid;
begin
  select id into v_elias from auth.users where lower(email) = 'admin@bokpilot.se';
  if v_elias is null then
    raise exception 'seed: användaren admin@bokpilot.se saknas';
  end if;

  select id into v_byra from public.companies where name = 'AcountX Redovisningsbyrå AB';
  if v_byra is null then
    insert into public.companies (name, foretagsform)
    values ('AcountX Redovisningsbyrå AB', 'Aktiebolag')
    returning id into v_byra;
  end if;

  insert into public.user_companies (user_id, company_id, role, email)
  values (v_elias, v_byra, 'admin', 'admin@bokpilot.se')
  on conflict (user_id, company_id) do nothing;

  insert into public.byra_medlemskap (byra_bolag_id, anvandare_id, roll, namn, epost, tillagd_av)
  values (v_byra, v_elias, 'admin', 'Elias', 'admin@bokpilot.se', v_elias)
  on conflict (byra_bolag_id, anvandare_id) do nothing;

  insert into public.byra_klient (byra_bolag_id, klient_bolag_id, status, kundansvarig_anvandare_id, tillagd_av)
  select v_byra, uc.company_id, 'aktiv', v_elias, v_elias
  from public.user_companies uc
  where uc.user_id = v_elias and uc.company_id <> v_byra
  on conflict (byra_bolag_id, klient_bolag_id) do nothing;
end $$;
