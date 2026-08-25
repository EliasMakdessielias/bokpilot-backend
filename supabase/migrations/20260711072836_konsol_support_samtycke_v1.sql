-- BokPilot Konsol — tidsbegränsat samtycke till supportåtkomst.
-- Spegel: bokpilot-admin/supabase/konsol_support_samtycke_v1.sql

create table if not exists public.konsol_support_samtycken (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  beviljad_av_user_id uuid not null,
  beviljad_av_email text not null,
  giltig_till timestamptz not null,
  aterkallad_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.konsol_support_samtycken enable row level security;
revoke all on public.konsol_support_samtycken from anon;

create policy "Kund kan läsa egna supportsamtycken"
  on public.konsol_support_samtycken
  for select to authenticated
  using (company_id in (select user_company_ids()));

create policy "Kund kan bevilja supportsamtycke"
  on public.konsol_support_samtycken
  for insert to authenticated
  with check (
    company_id in (select user_company_ids())
    and beviljad_av_user_id = auth.uid()
    and beviljad_av_email = coalesce(auth.jwt() ->> 'email', '')
    and giltig_till > now()
    and giltig_till <= now() + interval '30 days'
  );

create policy "Kund kan återkalla supportsamtycke"
  on public.konsol_support_samtycken
  for update to authenticated
  using (company_id in (select user_company_ids()))
  with check (company_id in (select user_company_ids()));

create index if not exists konsol_support_samtycken_company_idx
  on public.konsol_support_samtycken (company_id, giltig_till desc);
