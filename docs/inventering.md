# Inventering – bokpilot-sverige (2026-08-20)

Projekt: `bokpilot-sverige`, ref `vzeqvapebkbapwflozbi`, eu-north-1.

Totalsiffror (public-schemat): **123 tabeller** (samtliga med RLS aktivt), **0 vyer**, **253 egna funktioner** (exkl. extension-ägda), **76 triggrar**, **160 RLS-policies**, **191 index** (som inte backar constraints), **77 migrationer**, **32 edge functions**, **7 pg_cron-jobb**, **5 storage-buckets**. (Uppdaterat 2026-08-25 efter etapp 4–9: search_path-låsning och anon-indragning, täckande FK-index, RLS-InitPlan-omskrivning, behörighetskoll utan uid-beroende, indragna tabellrättigheter för anon, BFL-spärr vid bolagsradering samt nattlig avstämning mellan databas och Storage.) Inga egna enum-typer. Enda schema med egna objekt är `public`.

Efter etapp 4 och 7 har `anon` **ingen åtkomst alls** till vårt schema: rollen kan varken exekvera någon egen funktion i `public` eller nå någon tabell. De 188 kvarvarande EXECUTE-rättigheterna avser uteslutande btree_gist-extensionens egna funktioner (`gbt_*`, `gbtreekey*`, `*_dist`), som inte tillhör vår kodbas, och tabellgrant-avsnittet i `schema/grants.sql` innehåller inte längre en enda anon-rad. `authenticated` är oförändrad (107 tabeller).

## Installerade extensions

pg_net 0.20.3 (public), pg_cron 1.6.4, pgcrypto 1.3 (extensions), uuid-ossp 1.1 (extensions), btree_gist 1.7 (public), supabase_vault 0.3.1, pg_stat_statements 1.11, plpgsql 1.0.

## Edge functions (32)

| Slug | verify_jwt | Senast uppdaterad (version) |
|---|---|---|
| admin | ja | v8 |
| annual-report-ai | ja | v9 |
| annual-report-pdf | ja | v7 |
| ansokan-notis | nej | v7 |
| assistent-ai | ja | v8 |
| bokfor-ai | ja | v9 |
| bokforingsassistent | ja | v9 |
| bokslut-ai | ja | v12 |
| byra-inbjudan | ja | v5 |
| byra-medarbetare | ja | v2 |
| byrastod-jobb | nej | v1 |
| ekonomichef-ai | ja | v8 |
| granska-ai | ja | v8 |
| hamta-foretag | ja | v7 |
| inbound-email | nej | v10 |
| kivra-skicka | ja | v7 |
| kivra-sync | ja | v7 |
| konsol | nej | v13 |
| losenord-notis | nej | v1 |
| manadskontroll-ai | ja | v9 |
| mcp-server | ja | v18 |
| notif-unsubscribe | nej | v8 |
| ocr-folio | ja | v7 |
| report-error | nej | v8 |
| robo-bp-chat | ja | v8 |
| skattekonto-sync | ja | v7 |
| stadning-underlag | nej | v2 |
| stripe-checkout | ja | v7 |
| stripe-portal | ja | v7 |
| stripe-webhook | nej | v8 |
| support-ai | ja | v9 |
| tolka-underlag | ja | v8 |

## Storage-buckets

| Bucket | Publik | Storleksgräns | MIME-begränsning |
|---|---|---|---|
| annual-report-exports | nej | – | – |
| arkiv | nej | 50 MB | pdf, bilder, xml, text/csv, zip, office-format |
| shimo-audio | **ja** | – | – |
| support | nej | 10 MB | – |
| underlag | nej | 50 MB | – |

## pg_cron-jobb

Se `schema/cron_jobs.sql`. Sammanfattning: dagliga notifierings-/abonnemangsjobb (06:00, 06:15), månadskontroller (03:15), kivra-sync var 10:e minut, byråstöd nattjobb (04:10), lagringsintegritet (03:25), GDPR-gallring (03:40).

## Tabeller (123, samtliga med RLS)

account_import_batches, accounts, agi_deklarationer, ai_bokforing_logg, ai_call_log, ai_checklista_korningar, ai_cooldowns, ai_error_log, ai_usage_log, aml_flags, aml_installningar, annual_report_draft_sections, annual_report_drafts, annual_report_exports, annual_report_validation_items, arkiv_filer, arkiv_mappar, article_templates, assistent_logg, audit_log, bank_accounts, bank_transactions, bas_accounts, beta_ansokningar, bokslut_ai_suggestions, bokslut_attachments, bokslut_audit_log, bokslut_checks, bokslut_denied_log, bokslut_engagements, bokslut_sync_operations, bookkeeping_templates, byra_installningar, byra_klient, byra_medlemmar, byra_medlemskap, companies, company_ai_features, company_invites, company_lookup_cache, company_lookup_rate, company_subscriptions, customers, deadline_regel, documents, download_audit_log, employees, extraction_corrections, fiscal_years, help_feedback, inbound_email_log, inbox_addresses, ink2_deklarationstidpunkt, inkommande_gods, inkopsorder_rader, inkopsordrar, interna_nycklar, invoice_rows, invoices, kivra_utskick, konsol_abonnemangsfakturor, konsol_arenden, konsol_audit_logg, konsol_kundanteckningar, konsol_kundprofiler, konsol_livscykel_steg, konsol_support_samtycken, kyc_assessments, lager_handelser, lager_inventering_rader, lager_inventeringar, lager_leveranser, lonebesked, lonekorningar, mcp_audit_log, mcp_confirm_tokens, monthly_control_comments, monthly_control_events, monthly_control_items, monthly_controls, notification_deliveries, notification_events, notification_preferences, notification_provider_logs, notification_queue, notification_subscriptions, notification_templates, ocr_provider_config, platform_admins, platform_audit_log, platform_user_roles, products, robo_bp_audit_log, robo_bp_checks, robo_bp_control_runs, robo_bp_conversations, robo_bp_messages, robo_bp_rules, robo_bp_settings, salaries, sie_imports, skattekonto_regler, stripe_event_log, subscription_plans, supplier_accounting_rules, supplier_invoices, suppliers, support_ai_events, support_attachments, support_internal_notes, support_messages, support_reads, support_tickets, swish_regler, system_error_log, uppdrag, uppdragsuppgift, user_companies, vat_reports, verifikation_andringar, verifikation_rows, verifikationer, worker_health

Största (total relationsstorlek): audit_log ~17 MB, accounts ~5,5 MB, documents ~232 kB, notification_queue ~200 kB, bas_accounts ~200 kB, mcp_audit_log ~184 kB.

## Migrationer (77)

Från `20260710135627_bfl_skydd_v3_rpc_created_by` till `20260825161147_etapp_9_lagringsintegritet_foraldralosa_spar_v2`. Fullständig lista med en fil per migration i `supabase/migrations/`. Grupperna i historiken: BFL-skydd v3–v6 (2026-07-10), lager v1 (07-10), konsol/beta/byråstöd (07-11–07-14), räkenskapsårsregler + bokföringsassistent + lager etapp 2–3 (07-21), arkiv v1 + åtkomst/KYC/AML-scoping + SIE-import + BFL-skydd lön/levfaktura (07-25), etapp 1a/1b audit-triggrar + makuleringsfix (08-14), GDPR-gallring + bank_accounts-unikhet (08-17), etapp 2 spärr av bokföringsdata (08-24), etapp 3 åtkomst/rättelsejournal + audit-cascade-fixar (08-25), etapp 4 rättighetshärdning (08-25), etapp 5 prestanda: FK-index + RLS-InitPlan (08-25), etapp 6 behörighetskoll utan uid-beroende (08-25), etapp 7 anon utan tabellrättigheter (08-25), etapp 8 BFL-skydd vid bolagsradering (08-25), etapp 9 lagringsintegritet (08-25).

Etapp 3-migrationerna (2026-08-25):

- `20260825123334_etapp_3_atkomst_rattelsejournal_v1` – huvudmigrationen: anon/authenticated fråntas skrivrättigheter på verifikationer/verifikation_rows/verifikation_andringar/audit_log/ai_bokforing_logg (endast `select` + `update (avstamd)` kvar för authenticated), `bokfor_verifikation` och `radera_senaste_verifikation` konverteras till SECURITY DEFINER med explicit åtkomstkontroll, och rättelsejournalen får sina triggrar (`trg_journalfor_andring`, `trg_andringar_appendonly`).
- `20260825123816_etapp_3_audit_cascade_fix_v1` – cascade-fix i `audit_verifikation`: FK-brott mot audit_log vid företagsradering sväljs, alla andra auditfel kastas.
- `20260825124009_etapp_3_audit_rader_cascade_fix_v1` – samma cascade-hantering i `audit_verifikation_rows` (pre-existerande bugg).
- `20260825124113_etapp_3_audit_cascade_central_fix_v1` – central cascade-säkring i `log_accounting_audit`, som alla audit-triggrar går genom.
- `20260825124236_etapp_3_accounts_audit_cascade_fix_v1` – sista cascade-fixen: `accounts_audit` (skriver direkt till audit_log) får samma felhantering + explicit search_path.

Sedan etapp 3 fylls `verifikation_andringar` (rättelsejournalen) automatiskt vid makulering/rättelse via `trg_journalfor_andring` och är append-only.

Etapp 4-migrationerna (2026-08-25):

- `20260825132024_etapp_4_advisor_atgarder_v1` – search_path låses på de 36 funktioner som saknade den, `anon` (och implicit PUBLIC) fråntas EXECUTE på samtliga egna funktioner, triggerfunktioner görs oanropbara för API-rollerna, default privileges ändras så nya funktioner inte blir anropbara av anon/PUBLIC, och `revoke all ... from anon, authenticated` körs på elva interna tabeller (ai_call_log, ai_cooldowns, bas_accounts, bokslut_sync_operations, company_lookup_cache, company_lookup_rate, interna_nycklar, konsol_audit_logg, ocr_provider_config, stripe_event_log, system_error_log).
- `20260825132424_etapp_4_lasa_automationsfunktioner_v2` – automations- och notisfunktioner utan intern behörighetskontroll (notify_event, run_scheduled_notifications, report_system_error, record_worker_health, byrastod_markera_forsenade, plangräns- och bokslutshjälpare m.fl.) låses till service_role/cron.
- `20260825132659_etapp_4_audit_forfalskningsskydd_v3` – förfalskningsskydd i `log_accounting_audit`: bolagsåtkomsten kontrolleras även vid direktanrop med explicit `p_company_id` (`pg_trigger_depth() = 0`), så en inloggad användare inte kan skriva påhittade rader i ett främmande bolags audit_log.

Etapp 5-migrationerna (2026-08-25):

- `20260825134118_etapp_5_index_frammande_nycklar_v1` – 83 täckande index skapas för de främmande nycklar som saknade ett, så radering/uppdatering i föräldratabellen slipper seq scan i barntabellen (märks särskilt vid bolagsradering med ON DELETE CASCADE).
- `20260825134244_etapp_5_rls_initplan_v2` – 37 RLS-policies skrivs om så att `auth.uid()`/`auth.jwt()`/`auth.role()` lindas i `(select ...)` och utvärderas en gång per fråga (InitPlan) i stället för en gång per rad; semantiken är oförändrad.

Etapp 6-migrationen (2026-08-25):

- `20260825135353_etapp_6_behorighetskoll_utan_uid_beroende_v1` – behörighetskoll frikopplad från auth.uid()-beroende; ny hjälpare `_ar_betrodd_backend`. Fyra funktioner (`makulera_verifikation`, `ratta_verifikation`, `run_monthly_control`, `byrastod_markera_forsenade`) hoppade tidigare över kollen så snart `auth.uid()` var null och gör det nu bara för bevisat betrodda backendkontexter (service_role, samt cron/migrationer utan PostgREST-kontext).

Etapp 7-migrationen (2026-08-25):

- `20260825142721_etapp_7_anon_utan_tabellrattigheter_v1` – `anon` fråntas samtliga tabellrättigheter på de 101 tabeller där rollen fortfarande hade full DML kvar sedan Supabases standardgrants, plus `alter default privileges ... revoke all on tables from anon` för framtida tabeller. RLS är därmed inte längre enda skyddet mot anonym åtkomst — rättigheten saknas nu redan innan policyn utvärderas. `authenticated` lämnas helt oförändrad.

## Etapp 8 – BFL-spärr vid bolagsradering (2026-08-25)

Utgångsläget: 72 tabeller har `on delete cascade` mot `companies(id)` — däribland `verifikationer`, `verifikation_andringar`, `documents` och `audit_log`. En enda `delete from companies` raderade alltså hela bokföringen **och** beviskedjan. Det enda som i praktiken stoppade det var sidoeffekter av andra spärrar (`forbjud_sista_admin_bort`, `forbjud_bokford_radering`); ett bolag utan verifikationer men med underlag, fakturor eller lönedata hade inget skydd alls.

Etapp 8 inför ett uttryckligt, namngivet skydd på companies-nivå som gäller alla vägar in, inklusive `service_role` och SQL-editorn, samt en sanktionerad väg förbi det.

**Spärren.** Triggerfunktionen `forbjud_radera_bolag_med_rakenskapsinfo()` (BEFORE DELETE på `companies`, triggern `trg_forbjud_radera_bolag_med_rakenskapsinfo`) räknar raderna i elva tabeller med räkenskapsinformation — verifikationer, rättelsejournal, underlag, kund- och leverantörsfakturor, bankhändelser, momsrapporter, lönekörningar, lönebesked, löneposter och AGI-deklarationer. Finns något av det avbryts raderingen med felkoden `BFL_SKYDD` och en uppräkning av vad som hittades, med hänvisning till bokföringslagen 7 kap. 2 § (sju års bevarandetid räknat från utgången av det kalenderår då räkenskapsåret avslutades).

**Den sanktionerade vägen.** `avveckla_bolag(bolags_id uuid, orsak text)` kräver plattformsadministratör och en ifylld orsak, sammanställer omfattningen av det som ska försvinna, skriver en permanent post i `platform_audit_log` och genomför sedan raderingen med spärrarna tillfälligt undantagna. Funktionen har EXECUTE för `authenticated` (behörigheten kontrolleras inuti funktionen); triggerfunktionen är oanropbar för samtliga API-roller.

**Varför `platform_audit_log` och inte `audit_log`.** `audit_log.company_id` har en FK med `on delete cascade` mot `companies`. En avvecklingspost skriven i `audit_log` skulle alltså raderas i samma transaktion som bolaget — loggen vore värdelös för just den händelse den ska dokumentera. `platform_audit_log` kaskaderar inte bort med bolaget och överlever därför avvecklingen.

Undantaget styrs av sessionsflaggan `app.bfl_avveckla`, som bara sätts av `avveckla_bolag()` och alltid begränsas till `TG_OP = 'DELETE'` — insert och update påverkas inte, så spärrarnas egentliga syfte (att skydda levande bolags data) är intakt.

- `20260825155819_etapp_8_bfl_skydd_vid_bolagsradering_v1` – spärren, triggern och `avveckla_bolag()`.
- `20260825155920_etapp_8_avveckling_forbi_sista_admin_v1` – `forbjud_sista_admin_bort` blockerade även den sanktionerade avvecklingen via kaskaden till `user_companies`; kravet på kvarvarande administratör är meningslöst när hela bolaget avvecklas.
- `20260825160109_etapp_8_avvecklingsundantag_i_ovriga_sparrar_v1` – fem spärrar respekterade inte `app.periodlas_bypass` och stoppade därför avvecklingen: `enforce_company_write_lock` (15 tabeller), `protect_locked_account`, `arkiv_skydda_rakenskapsinfo`, `arkiv_mapp_fore_radering` och `forbjud_bokford_faktura_radering`.
- `20260825160249_etapp_8_avveckla_bolag_rensar_relationer_v2` – sju främmande nycklar mot `companies` har RESTRICT/NO ACTION och måste rensas uttryckligen och i rätt ordning: `uppdragsuppgift`, `uppdrag`, `byra_klient`, `byra_medlemskap`, `aml_flags`, `kyc_assessments`, `kivra_utskick`. AML/KYC har egna bevarandetider enligt penningtvättslagen som skiljer sig från BFL:s sju år, så omfattningen loggas innan posterna tas bort. Samtidigt får `skydda_sista_byra_admin` samma avvecklingsundantag.
- `20260825160413_etapp_8_arkiv_audit_kaskadskydd_v1` – samma kaskadfälla som i etapp 3, nu i arkivlagret: `arkiv_fil_logga_radering` fångar specifikt `foreign_key_violation` (som bara kan betyda att bolaget försvinner) och släpper igenom den; allt annat avbryter fortfarande transaktionen.

## Etapp 9 – lagringsintegritet (2026-08-25)

Supabases databasbackuper omfattar **inte** objekt i Storage — databasen innehåller bara metadata (`documents.storage_path`, `arkiv_filer.storage_path`). Den farliga felmoden är därför tyst: en återställning ger en databas som ser komplett ut, med verifikationer, konteringsrader och dokumentrader, medan varje `storage_path` pekar på en fil som inte finns. Ingenting i systemet upptäckte det.

`kontrollera_lagringsintegritet()` jämför båda hållen:

- **Saknade filer** – databasrad finns, filen är borta. Räkenskapsinformation kan vara förlorad; larmas som `critical` med felkoden `STORAGE_MISSING_FILES`.
- **Föräldralösa filer** – filen finns, ingen databasrad pekar på den. Ingen förlust, men en lagringsminimeringsfråga (GDPR art. 5.1 c och e). Rapporteras utan larm.

`cron_lagringsintegritet()` kör kontrollen nattetid via pg_cron-jobbet `lagringsintegritet-natt` (`25 3 * * *`) och registrerar hjärtslag i `worker_health`, så att en funktion som slutar köra inte kan se ut som en frisk. Föräldralösa filer loggas i `system_error_log` **enbart när antalet ändras** — det finns i dag 21 kända sådana, och ett dagligt larm om ett statiskt tillstånd tränar bara bort uppmärksamheten. Raden skrivs direkt till tabellen och inte via `report_system_error`, eftersom den funktionen alltid eskalerar till en `urgent`-notis till samtliga plattformsadmins oavsett angiven severity.

`kontrollera_lagringsintegritet` har EXECUTE för `authenticated`; `cron_lagringsintegritet` är låst till postgres/service_role.

- `20260825160906_etapp_9_lagringsintegritet_v1` – båda funktionerna, rättigheterna och cron-jobbet.
- `20260825161147_etapp_9_lagringsintegritet_foraldralosa_spar_v2` – rättelse: notisen om föräldralösa filer skickades tidigare in i `record_worker_health`, som rensar `last_error` vid lyckad körning och alltså kastade bort den omedelbart. Spåret flyttas till `system_error_log` och skrivs bara vid förändring.
