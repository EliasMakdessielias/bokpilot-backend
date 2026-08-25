-- Lagermodul v1 (Fortnox-modellen): händelselogg som sanningskälla, saldo och
-- lagervärde beräknas ur händelserna (vägt genomsnittspris, BFN/K2-förenligt).

-- Artiklar: lagerflagga + inköpsdata
alter table public.products
  add column if not exists lagervara boolean not null default false,
  add column if not exists inkopspris numeric,
  add column if not exists bestallningspunkt numeric,
  add column if not exists lagerplats text;

-- Fakturarader kan peka på artikeln (grunden för automatisk utleverans)
alter table public.invoice_rows
  add column if not exists product_id uuid references public.products(id) on delete set null;

-- Lagerhändelser: inleverans (+), utleverans (−), justering (±), inventering (±diff).
-- antal är TECKNAT (utleverans lagras negativt). a_pris anges vid inleverans;
-- ut/justering värderas till vägt genomsnitt i beräkningen.
create table if not exists public.lager_handelser (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  typ text not null check (typ in ('inleverans', 'utleverans', 'justering', 'inventering')),
  antal numeric not null,
  a_pris numeric,
  datum date not null default current_date,
  kommentar text,
  invoice_id uuid references public.invoices(id) on delete set null,
  supplier_invoice_id uuid references public.supplier_invoices(id) on delete set null,
  created_by uuid,
  created_at timestamptz default now()
);
create index if not exists lager_handelser_idx on public.lager_handelser (company_id, product_id, datum);

alter table public.lager_handelser enable row level security;
drop policy if exists lager_handelser_policy on public.lager_handelser;
create policy lager_handelser_policy on public.lager_handelser for all
  using (company_id in (select user_company_ids()))
  with check (company_id in (select user_company_ids()));
