-- Konsol: Rex-baserad kundlivscykel (Srf konsulternas standard för
-- redovisnings- och lönetjänster). Ett steg per (bolag, steg_key) med status —
-- historiken ges av konsol_audit_logg (varje ändring loggas av edge-funktionen).
-- Stegdefinitionerna (texter, ordning, Rex-referenser) bor i konsolens frontend
-- (src/lib/livscykel.js); databasen validerar bara nyckel-/statusformat.
-- Spegel: bokpilot-admin/supabase/konsol_livscykel_v1.sql

create table if not exists public.konsol_livscykel_steg (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  steg_key text not null check (steg_key ~ '^[a-z_]{2,40}$'),
  status text not null default 'ej_paborjad'
    check (status in ('ej_paborjad', 'pagar', 'klar', 'ej_relevant')),
  notering text check (char_length(notering) <= 2000),
  uppdaterad_av_email text not null,
  updated_at timestamptz not null default now(),
  unique (company_id, steg_key)
);

alter table public.konsol_livscykel_steg enable row level security;
revoke all on public.konsol_livscykel_steg from anon, authenticated;

create index if not exists konsol_livscykel_company_idx
  on public.konsol_livscykel_steg (company_id);
