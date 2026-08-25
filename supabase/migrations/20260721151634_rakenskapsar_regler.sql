-- Räkenskapsårsregler i databasen (2026-07-15) — BFL 3 kap som hårda spärrar,
-- oavsett klient (UI, MCP, edge, konsol). Klientlagret (src/lib/rakenskapsar.js)
-- ger samma regler som begripliga svenska fel FÖRE insert.

-- Överlappande räkenskapsår i samma bolag = omöjligt (dubbelräknade IB/UB, trasig SIE).
create extension if not exists btree_gist;
alter table public.fiscal_years add constraint fiscal_years_ingen_overlappning
  exclude using gist (company_id with =, daterange(start_date, end_date, '[]') with &&);

-- Hela kalendermånader (kalenderår ELLER brutet år), slut efter start, högst 18 månader.
alter table public.fiscal_years add constraint fiscal_years_bfl_check check (
  end_date > start_date
  and extract(day from start_date) = 1
  and end_date = (date_trunc('month', end_date::timestamp) + interval '1 month - 1 day')::date
  and end_date < start_date + interval '18 months'
);
