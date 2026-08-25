-- Bokföringsassistenten v1 (2026-07-21): användningslogg + intern kanalnyckel.
-- Assistenten (edge bokforingsassistent, Claude Sonnet 5) återanvänder MCP-serverns
-- verktyg via assistentkanalen; denna logg bär kvottaket och kostnadskalkylen.

create table public.assistent_logg (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null,
  in_tokens integer not null default 0,
  out_tokens integer not null default 0,
  cache_read_tokens integer not null default 0,
  verktygsanrop integer not null default 0,
  bokford boolean not null default false,
  created_at timestamptz not null default now()
);
create index assistent_logg_company_manad on public.assistent_logg (company_id, created_at);
alter table public.assistent_logg enable row level security;
-- Bolagets medlemmar får läsa sin egen användning; skrivningar går endast via
-- edge-funktionens service-roll (ingen insert/update-policy).
create policy assistent_logg_select on public.assistent_logg
  for select using (company_id in (select public.user_company_ids()));

-- Kanalnyckeln (genereras i databasen, lämnar den aldrig — kivra-mönstret).
insert into public.interna_nycklar (namn, varde)
values ('assistent_kanal', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (namn) do nothing;
