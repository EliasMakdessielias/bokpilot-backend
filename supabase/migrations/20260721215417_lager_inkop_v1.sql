-- Lager etapp 2 (Fortnox-strukturen): INKÖPSORDRAR + INKOMMANDE GODS.
-- Inköpsorder: löpande ordernr per bolag, status ej_skickad→skickad→fullt_mottagen
-- (försenad härleds ur lev_datum), rader med beställt/mottaget antal.
-- Inkommande gods: mottagning mot en order — skapar en lagerleverans (inleverans)
-- vars händelser uppdaterar saldot; mottaget ackumuleras på orderraderna.
create table if not exists public.inkopsordrar (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  ordernr int not null,
  supplier_id uuid references public.suppliers(id) on delete set null,
  intern_referens text,
  best_datum date not null default current_date,
  lev_datum date,
  anteckning text,
  status text not null default 'ej_skickad' check (status in ('ej_skickad', 'skickad', 'fullt_mottagen', 'makulerad')),
  skickad_at timestamptz,
  created_by uuid,
  created_at timestamptz default now(),
  unique (company_id, ordernr)
);
create table if not exists public.inkopsorder_rader (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  order_id uuid not null references public.inkopsordrar(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  antal numeric not null,
  a_pris numeric,
  mottaget numeric not null default 0
);
create table if not exists public.inkommande_gods (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  godsnr int not null,
  order_id uuid references public.inkopsordrar(id) on delete set null,
  foljesedel text,
  datum date not null default current_date,
  anteckning text,
  status text not null default 'slutford' check (status in ('paborjad', 'slutford', 'makulerad')),
  leverans_id uuid references public.lager_leveranser(id) on delete set null,
  created_by uuid,
  created_at timestamptz default now(),
  unique (company_id, godsnr)
);
alter table public.inkopsordrar enable row level security;
alter table public.inkopsorder_rader enable row level security;
alter table public.inkommande_gods enable row level security;
drop policy if exists inkopsordrar_policy on public.inkopsordrar;
create policy inkopsordrar_policy on public.inkopsordrar for all
  using (company_id in (select user_company_ids())) with check (company_id in (select user_company_ids()));
drop policy if exists inkopsorder_rader_policy on public.inkopsorder_rader;
create policy inkopsorder_rader_policy on public.inkopsorder_rader for all
  using (company_id in (select user_company_ids())) with check (company_id in (select user_company_ids()));
drop policy if exists inkommande_gods_policy on public.inkommande_gods;
create policy inkommande_gods_policy on public.inkommande_gods for all
  using (company_id in (select user_company_ids())) with check (company_id in (select user_company_ids()));
create index if not exists inkopsorder_rader_order_idx on public.inkopsorder_rader (order_id);
