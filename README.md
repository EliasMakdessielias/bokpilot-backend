# BokPilot – dump av `bokpilot-sverige` (Supabase)

Ögonblicksbild av backendens hela kodbara innehåll, hämtad **2026-08-20** via Supabase-MCP från projektet `bokpilot-sverige` (ref `vzeqvapebkbapwflozbi`, eu-north-1, org `wtxdxhnzcxrbzpvysdyh`).

## Innehåll

| Sökväg | Innehåll |
|---|---|
| `supabase/migrations/` | Alla 77 migrationer ur `supabase_migrations.schema_migrations`, en fil per migration (`<version>_<namn>.sql`) |
| `supabase/functions/<slug>/` | Källkod för alla 32 edge functions; delade moduler (claudeChat, ocr, serviceState, deadlines m.fl.) ligger i `supabase/functions/_shared/` så att `../_shared/`-importerna stämmer |
| `schema/tables.sql` | CREATE TABLE för alla 123 tabeller i `public` (kolumner, defaults, not null) + RLS-aktivering |
| | *Schemafilerna uppdaterade 2026-08-25 efter etapp 4–9 (search_path-låsning + anon-indragning, FK-index, RLS-InitPlan, behörighetskoll utan uid-beroende, anon utan tabellrättigheter, BFL-spärr vid bolagsradering, avstämning databas mot Storage; 253 funktioner, 76 triggrar)* |
| `schema/constraints.sql` | PK/FK/unique/check-constraints |
| `schema/indexes.sql` | De 191 index som inte backar constraints |
| `schema/functions.sql` | Alla 253 egna databasfunktioner (exkl. extension-ägda) |
| `schema/triggers.sql` | Alla 76 triggrar |
| `schema/policies.sql` | Alla 160 RLS-policies |
| `schema/grants.sql` | Tabell-, kolumn- och funktionsrättigheter för `anon`/`authenticated`/`service_role`; efter etapp 7 har `anon` inga tabellrättigheter kvar (RLS är inte längre enda skyddet) |
| `schema/cron_jobs.sql` | De 7 pg_cron-jobben |
| `types/database.types.ts` | Genererade TypeScript-typer |
| `docs/inventering.md` | Inventering: tabeller, edge functions, extensions, storage-buckets, migrationslista |

## Vad som INTE ingår

- **Tabelldata** — detta är struktur och kod, inga rader ur användartabeller. Särskilt `interna_nycklar` (hemligheter) är medvetet inte dumpad.
- **Auth-användare, storage-filinnehåll, edge function-secrets** (miljövariabler) — nås inte via MCP.
- **Frontendkoden** — den finns inte i Supabase; arbetskopian ligger inte på den här datorn.

## Notera

- Dumpen är en ögonblicksbild — databasen är sanningskällan. Migrationsfilerna motsvarar det som faktiskt är applicerat; `schema/*.sql` är det *nuvarande* tillståndet (rekonstruerat ur pg_catalog, inte via pg_dump, så exakta formuleringar kan avvika från originalskripten).
- Cron-jobben innehåller projektets **publicerbara nyckel** (`sb_publishable_...`) i klartext — den är publik per design, men mappen ligger i `Projekt\` (utanför OneDrive-synk) i linje med hur kodprojekt hanteras på den här datorn. Nyckeln ersatte den tidigare anon-JWT:n vid nyckelrotationen; de hemliga cron-nycklarna läses ur `interna_nycklar` vid körning och ingår inte i dumpen.
- Äldre miljön `Bokpilot` (ref `bypebgvxdmbzxqecllao`, eu-central-1) ingår inte i dumpen.
