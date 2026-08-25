-- ML 17 kap: kreditfaktura ska hänvisa till ursprungsfakturan; omvänd betalnings-
-- skyldighet ska anges på fakturan. Kundfakturor får typ + hänvisning + omvänd-flagga.
alter table public.invoices add column if not exists typ text not null default 'faktura'
  check (typ in ('faktura','kreditfaktura'));
alter table public.invoices add column if not exists krediterar_id uuid references public.invoices(id);
alter table public.invoices add column if not exists omvand_moms boolean not null default false;
create index if not exists idx_invoices_krediterar on public.invoices(krediterar_id) where krediterar_id is not null;
