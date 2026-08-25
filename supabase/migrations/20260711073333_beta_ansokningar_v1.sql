-- Beta-ansökningar: registreringen är en ansökan som Elias godkänner i
-- operatörskonsolen innan bolaget släpps in (companies.suspended -> false).
-- Spegel: bocker-app/supabase/beta_ansokningar.sql

create table if not exists public.beta_ansokningar (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  company_id uuid references public.companies(id) on delete set null,
  epost text not null,
  bolagsnamn text not null,
  org_nr text,
  meddelande text check (char_length(meddelande) <= 2000),
  status text not null default 'vantar' check (status in ('vantar', 'godkand', 'avvisad')),
  hanterad_av_email text,
  hanterad_at timestamptz,
  avvisad_orsak text,
  created_at timestamptz not null default now()
);

alter table public.beta_ansokningar enable row level security;

-- Sökanden får skapa och läsa sin egen ansökan; ändras endast av konsolen (service role).
create policy "Egen ansökan kan skapas"
  on public.beta_ansokningar for insert to authenticated
  with check (
    user_id = auth.uid()
    and epost = coalesce(auth.jwt() ->> 'email', '')
    and status = 'vantar'
  );

create policy "Egen ansökan kan läsas"
  on public.beta_ansokningar for select to authenticated
  using (user_id = auth.uid());

-- Högst en väntande ansökan per användare.
create unique index if not exists beta_ansokningar_en_vantande
  on public.beta_ansokningar (user_id) where status = 'vantar';

create index if not exists beta_ansokningar_status_idx
  on public.beta_ansokningar (status, created_at desc);
