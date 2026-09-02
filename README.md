# BokPilot – dump av `bokpilot-sverige` (Supabase)

Ögonblicksbild av backendens hela kodbara innehåll, hämtad **2026-08-20** via Supabase-MCP från projektet `bokpilot-sverige` (ref `vzeqvapebkbapwflozbi`, eu-north-1, org `wtxdxhnzcxrbzpvysdyh`). Senast synkad mot databasen **2026-09-02** (etapp 10–16).

## Innehåll

| Sökväg | Innehåll |
|---|---|
| `supabase/migrations/` | Alla 86 migrationer ur `supabase_migrations.schema_migrations`, en fil per migration (`<version>_<namn>.sql`), MD5-verifierade mot databasen |
| `supabase/functions/<slug>/` | Källkod för alla 32 edge functions; delade moduler (claudeChat, ocr, serviceState, deadlines m.fl.) ligger i `supabase/functions/_shared/` så att `../_shared/`-importerna stämmer. Ingen edge function har uppdaterats sedan dumpen (senaste `updated_at` 2026-07-26) |
| `schema/tables.sql` | CREATE TABLE för alla 127 tabeller i `public` (kolumner, defaults, not null) + RLS-aktivering |
| | *Schemafilerna uppdaterade 2026-09-02 efter etapp 10–16 (backupunderlag, driftövervakning, rollstyrning på lönetabellerna, KYC-datamodell med bucket, KYC-bevakning, append-only operatörslogg, KYC-arkiv vid avveckling; 261 funktioner, 85 triggrar) — dessförinnan 2026-08-25 efter etapp 4–9 (search_path-låsning + anon-indragning, FK-index, RLS-InitPlan, behörighetskoll utan uid-beroende, anon utan tabellrättigheter, BFL-spärr vid bolagsradering, avstämning databas mot Storage)* |
| `schema/constraints.sql` | PK/FK/unique/check-constraints |
| `schema/indexes.sql` | De 197 index som inte backar constraints |
| `schema/functions.sql` | Alla 261 egna databasfunktioner (exkl. extension-ägda) |
| `schema/triggers.sql` | Alla 85 triggrar |
| `schema/policies.sql` | Alla 166 RLS-policies i `public` |
| `schema/grants.sql` | Tabell-, kolumn- och funktionsrättigheter för `anon`/`authenticated`/`service_role`; efter etapp 7 har `anon` inga tabellrättigheter kvar (RLS är inte längre enda skyddet) |
| `schema/cron_jobs.sql` | De 9 pg_cron-jobben |
| `types/database.types.ts` | Genererade TypeScript-typer (från 2026-08-20, inte regenererade efter etapp 10–16 — saknar `driftkomponenter`, `kyc_huvudman`, `kyc_bilagor`, `kyc_arkiv` och de nya kolumnerna i `kyc_assessments`) |
| `docs/inventering.md` | Inventering: tabeller, edge functions, extensions, storage-buckets, migrationslista och etappbeskrivningar |

## Vad som INTE ingår

- **Tabelldata** — detta är struktur och kod, inga rader ur användartabeller. Särskilt `interna_nycklar` (hemligheter) är medvetet inte dumpad. Registret `driftkomponenter` (etapp 11) är också data och speglas bara via migrationerna.
- **Auth-användare, storage-filinnehåll, edge function-secrets** (miljövariabler) — nås inte via MCP.
- **Storage-schemat** — bucketdefinitioner och policies på `storage.objects` (t.ex. `kyc_obj_select`/`kyc_obj_insert` från etapp 13b och 16) ingår inte i `schema/`, som bara speglar `public`. Bucketarna listas i `docs/inventering.md`; storage-policyerna finns enbart i migrationsfilerna.
- **Frontendkoden** — den finns inte i Supabase; arbetskopian ligger inte på den här datorn.

## Notera

- Dumpen är en ögonblicksbild — databasen är sanningskällan. Migrationsfilerna motsvarar det som faktiskt är applicerat; `schema/*.sql` är det *nuvarande* tillståndet (rekonstruerat ur pg_catalog, inte via pg_dump, så exakta formuleringar kan avvika från originalskripten).
- Verifiering: varje migrationsfil är `statements[1]` + radbrytning och jämförs med `md5(statements[1] || E'\n')` serverside; tables/constraints/indexes/policies/triggers jämförs som hela filer mot samma rekonstruktion i databasen, och functions.sql funktion för funktion mot `pg_get_functiondef`. Kända, avsiktliga avvikelser: `reset_lonekorning_on_makulering` innehåller CR-byte i databasen och jämförs CR-strippad; PG17:s `maintain`-privilegium redovisas inte i `grants.sql`.
- Cron-jobben innehåller projektets **publicerbara nyckel** (`sb_publishable_...`) i klartext — den är publik per design, men mappen ligger i `Projekt\` (utanför OneDrive-synk) i linje med hur kodprojekt hanteras på den här datorn. Nyckeln ersatte den tidigare anon-JWT:n vid nyckelrotationen; de hemliga cron-nycklarna läses ur `interna_nycklar` vid körning och ingår inte i dumpen.
- Äldre miljön `Bokpilot` (ref `bypebgvxdmbzxqecllao`, eu-central-1) ingår inte i dumpen.
