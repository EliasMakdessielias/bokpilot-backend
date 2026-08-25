-- Lager etapp 3 (Fortnox-strukturen): INVENTERINGAR som modul + BATCHSPÅRNING.
-- Inventering: planera (välj artiklar) → räkna (räknat antal per rad, saldo-
-- snapshot) → slutför (diffar blir lagerhändelser typ 'inventering' kopplade via
-- inventering_id). Batch: valfritt batchnr på lagerhändelser (anges vid in-/
-- utleverans och mottagning) — spårning via söksidan Batch.
create table if not exists public.lager_inventeringar (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  nr int not null,
  datum date not null default current_date,
  benamning text not null,
  ansvarig text,
  status text not null default 'under_planering' check (status in ('under_planering', 'paborjad', 'slutford', 'makulerad')),
  created_by uuid,
  created_at timestamptz default now(),
  unique (company_id, nr)
);
create table if not exists public.lager_inventering_rader (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  inventering_id uuid not null references public.lager_inventeringar(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  raknat numeric,
  saldo_vid_rakning numeric,
  unique (inventering_id, product_id)
);
alter table public.lager_inventeringar enable row level security;
alter table public.lager_inventering_rader enable row level security;
drop policy if exists lager_inventeringar_policy on public.lager_inventeringar;
create policy lager_inventeringar_policy on public.lager_inventeringar for all
  using (company_id in (select user_company_ids())) with check (company_id in (select user_company_ids()));
drop policy if exists lager_inventering_rader_policy on public.lager_inventering_rader;
create policy lager_inventering_rader_policy on public.lager_inventering_rader for all
  using (company_id in (select user_company_ids())) with check (company_id in (select user_company_ids()));

alter table public.lager_handelser
  add column if not exists inventering_id uuid references public.lager_inventeringar(id) on delete set null,
  add column if not exists batchnr text;
create index if not exists lager_handelser_batch_idx on public.lager_handelser (company_id, batchnr) where batchnr is not null;
