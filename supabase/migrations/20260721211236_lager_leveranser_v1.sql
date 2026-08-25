-- Lager etapp 1 (Fortnox-strukturen): MANUELLA LEVERANSER med egen nummerserie.
-- En leverans (inleverans/utleverans/lagerflytt) grupperar lagerhändelser och får
-- ett löpande leveransnr per bolag. Händelseloggen förblir sanningskällan för
-- saldo/värde; makulerad leverans tar bort sina händelser (lagervärdesbokningen
-- är diffbaserad och självkorrigerar).
create table if not exists public.lager_leveranser (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  typ text not null check (typ in ('inleverans', 'utleverans', 'lagerflytt')),
  leveransnr int not null,
  datum date not null default current_date,
  anteckning text,
  status text not null default 'klar' check (status in ('ej_klar', 'klar', 'makulerad')),
  created_by uuid,
  created_at timestamptz default now(),
  unique (company_id, leveransnr)
);
alter table public.lager_leveranser enable row level security;
drop policy if exists lager_leveranser_policy on public.lager_leveranser;
create policy lager_leveranser_policy on public.lager_leveranser for all
  using (company_id in (select user_company_ids()))
  with check (company_id in (select user_company_ids()));

alter table public.lager_handelser add column if not exists leverans_id uuid references public.lager_leveranser(id) on delete set null;
create index if not exists lager_handelser_leverans_idx on public.lager_handelser (leverans_id);
