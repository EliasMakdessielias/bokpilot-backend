-- AI-spårbarhet (AI-förordningen/BFL 5:11): koppla AI-förslaget till den bokförda
-- verifikationen så granskare kan gå åt båda hållen.
alter table public.ai_bokforing_logg add column if not exists verifikation_id uuid references public.verifikationer(id) on delete set null;
create index if not exists idx_ai_logg_verifikation on public.ai_bokforing_logg(verifikation_id) where verifikation_id is not null;
