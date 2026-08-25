-- AI-checklistan: körningslogg för spårbarhet + kostnadsmätning (antal AI-anrop
-- per körning matar kostnadskalkylen). Själva bokföringen spåras som vanligt via
-- verifikationer/audit_log (source 'ai') — loggen här är körningens sammanfattning.
-- Spegel: bocker-app/supabase/ai_checklista.sql

create table if not exists public.ai_checklista_korningar (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  created_by uuid,
  resultat jsonb not null default '{}'::jsonb,
  antal_ai_anrop integer not null default 0 check (antal_ai_anrop >= 0),
  created_at timestamptz not null default now()
);

alter table public.ai_checklista_korningar enable row level security;
create policy ai_checklista_korningar_policy on public.ai_checklista_korningar for all
  using (company_id in (select user_company_ids()))
  with check (company_id in (select user_company_ids()));

create index if not exists ai_checklista_korningar_idx
  on public.ai_checklista_korningar (company_id, created_at desc);
