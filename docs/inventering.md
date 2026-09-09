# Inventering – bokpilot-sverige (2026-08-20, senast uppdaterad 2026-09-09)

Projekt: `bokpilot-sverige`, ref `vzeqvapebkbapwflozbi`, eu-north-1.

Totalsiffror (public-schemat, räknade ur databasen 2026-09-09): **128 tabeller** (samtliga med RLS aktivt), **0 vyer**, **265 egna funktioner** (exkl. extension-ägda), **85 triggrar**, **166 RLS-policies**, **199 index** (som inte backar constraints), **99 migrationer**, **33 edge functions**, **10 pg_cron-jobb**, **6 storage-buckets**. (Uppdaterat 2026-09-09 efter etapp 11b/11c — driftvakten bedömer bara avslutade körningar och `imap-import` är avregistrerad — samt kundappens tio migrationer samma dag: `byrastod_scope_v1`, `ai_kvot_v1`, `inbound_avsandare_v1`, `ai_kvot_v2`, `backup_underlag_v1`, `backup_underlag_v2`, `gdpr_gallring_ai_call_log_v1`, `notis_inkommande_kalla_v1`, `mfa_aal2_plattformsadmin_v1` och `beta_ansokan_orgnr_v1` (se de fyra sista avsnitten); edge-funktionerna synkade mot driftsättningen 2026-09-09 kl. 09:46 UTC, då `backup-underlag` tillkom som nummer 33. Dessförinnan 2026-09-02 efter etapp 10–16: backupunderlag, driftövervakning, rollstyrning på lönetabellerna, KYC-datamodell med bucket, KYC-bevakning, append-only-skydd av operatörsloggen samt KYC-arkiv vid avveckling. Dessförinnan 2026-08-25 efter etapp 4–9: search_path-låsning och anon-indragning, täckande FK-index, RLS-InitPlan-omskrivning, behörighetskoll utan uid-beroende, indragna tabellrättigheter för anon, BFL-spärr vid bolagsradering samt nattlig avstämning mellan databas och Storage.) Inga egna enum-typer. Enda schema med egna objekt är `public`.

Efter etapp 4 och 7 har `anon` **ingen åtkomst alls** till vårt schema: rollen kan varken exekvera någon egen funktion i `public` eller nå någon tabell. De 188 kvarvarande EXECUTE-rättigheterna avser uteslutande btree_gist-extensionens egna funktioner (`gbt_*`, `gbtreekey*`, `*_dist`), som inte tillhör vår kodbas, och tabellgrant-avsnittet i `schema/grants.sql` innehåller inte längre en enda anon-rad. Det gäller fortfarande efter etapp 10–16 (kontrollräknat 2026-09-02: 0 egna funktioner, 0 tabeller). `authenticated` har tabellrättigheter på 110 tabeller — de 107 sedan tidigare samt `kyc_huvudman` och `kyc_bilagor` (etapp 13a) och `kyc_arkiv` (etapp 16, enbart select). Registret `driftkomponenter` (etapp 11) nås bara av `service_role`/`postgres`. Av de nya funktionerna har `driftstatus` och `mina_lonebolag` EXECUTE för `authenticated`; `lista_lagringsobjekt`, `cron_driftkontroll`, `cron_kyc_bevakning` och triggerfunktionerna `audit_personuppgifter`, `konsol_audit_appendonly`, `kyc_arkiv_skydd` har det inte. Sedan 2026-09-09 är även `ai_kvot_klaim` och den omsignerade `byrastod_markera_forsenade(uuid[])` låsta till `service_role`.

## Installerade extensions

pg_net 0.20.3 (public), pg_cron 1.6.4, pgcrypto 1.3 (extensions), uuid-ossp 1.1 (extensions), btree_gist 1.7 (public), supabase_vault 0.3.1, pg_stat_statements 1.11, plpgsql 1.0.

## Edge functions (32)

Kontrollerat 2026-09-09: fortfarande 32 funktioner. **Alla 31 funktioner i kundappens repo driftsattes på nytt 2026-09-07 kl. 20:23 UTC** av GitHub Actions-workflowen `deploy-edge-functions.yml` (repot `EliasMakdessielias/bokpilot`, commit 85a56cc) — första gången den gick igenom sedan repohemligheten `SUPABASE_ACCESS_TOKEN` lades in; versionsnumren steg med åtta steg för samtliga, så workflowen kördes flera gånger innan den lyckades. Därmed är `robo-bp-chat` (ägarskapskontroll på `conversation_id`, repo-commit 92420a4, odeployad sedan 2026-07-26) driftsatt — verifierat mot den driftsatta källkoden 2026-09-09. `konsol` driftsattes som version 21 samma kväll (19:24 UTC) från `bokpilot-admin`; koden är oförändrad sedan v19 (exakt e-postjämförelse i stället för `.ilike`). Dumpens `supabase/functions/` speglar det driftsatta läget: fyra filer uppdaterades 2026-09-09 från kundappens repo (`robo-bp-chat/index.ts` med ägarskapskontrollen, `_shared/serviceState.ts` med kommentaren om att IMAP-importern togs bort 2026-09-07, `_shared/ocr.ts` med Unicode-escaper i stället för literala tecken samt `_shared/deadlines.js`, där dumpens tidigare transkription hade tappat tecken i två kommentarslinjer); övriga 27 var redan identiska med repot (radslut bortsett). Sedan pushen deployar workflowen är repot källan för det som körs; dumpen synkas därför från repot (LF-normaliserat) och en manuell deploy via Supabase-kopplingen är reservväg.

| Slug | verify_jwt | Version (driftsatt 2026-09-07) |
|---|---|---|
| admin | ja | v16 |
| annual-report-ai | ja | v17 |
| annual-report-pdf | ja | v15 |
| ansokan-notis | nej | v15 |
| assistent-ai | ja | v16 |
| bokfor-ai | ja | v17 |
| bokforingsassistent | ja | v17 |
| bokslut-ai | ja | v20 |
| byra-inbjudan | ja | v13 |
| byra-medarbetare | ja | v10 |
| byrastod-jobb | nej | v9 |
| ekonomichef-ai | ja | v16 |
| granska-ai | ja | v16 |
| hamta-foretag | ja | v15 |
| inbound-email | nej | v18 |
| kivra-skicka | ja | v15 |
| kivra-sync | ja | v15 |
| konsol | nej | v21 (från bokpilot-admin) |
| losenord-notis | nej | v9 |
| manadskontroll-ai | ja | v17 |
| mcp-server | ja | v26 |
| notif-unsubscribe | nej | v16 |
| ocr-folio | ja | v15 |
| report-error | nej | v16 |
| robo-bp-chat | ja | v16 |
| skattekonto-sync | ja | v15 |
| stadning-underlag | nej | v10 |
| stripe-checkout | ja | v15 |
| stripe-portal | ja | v15 |
| stripe-webhook | nej | v16 |
| support-ai | ja | v17 |
| tolka-underlag | ja | v16 |

## Storage-buckets

| Bucket | Publik | Storleksgräns | MIME-begränsning |
|---|---|---|---|
| annual-report-exports | nej | – | – |
| arkiv | nej | 50 MB | pdf, bilder, xml, text/csv, zip, office-format |
| kyc | nej | 20 MB | pdf, png, jpeg, jpg, webp |
| shimo-audio | **ja** | – | – |
| support | nej | 10 MB | – |
| underlag | nej | 50 MB | – |

Bucketen `kyc` tillkom i etapp 13b. Policyerna på `storage.objects` (12 stycken, däribland `kyc_obj_select` och `kyc_obj_insert`) speglas inte i `schema/` — dumpen omfattar bara `public` — utan finns i migrationsfilerna (13b och 16).

## pg_cron-jobb

Se `schema/cron_jobs.sql`. Sammanfattning: dagliga notifierings-/abonnemangsjobb (06:00, 06:15), extern säkerhetskopia av Storage (02:30, jobid 11 sedan 2026-09-09), månadskontroller (03:15), kivra-sync var 10:e minut, byråstöd nattjobb (04:10), lagringsintegritet (03:25), KYC-bevakning (03:30), GDPR-gallring (03:40), driftkontroll (03:50). Jobid 9 saknas: det var KYC-bevakningens första schemaläggning (04:35), som avregistrerades i etapp 14b.

## Tabeller (128, samtliga med RLS)

account_import_batches, accounts, agi_deklarationer, ai_bokforing_logg, ai_call_log, ai_checklista_korningar, ai_cooldowns, ai_error_log, ai_usage_log, aml_flags, aml_installningar, annual_report_draft_sections, annual_report_drafts, annual_report_exports, annual_report_validation_items, arkiv_filer, arkiv_mappar, article_templates, assistent_logg, audit_log, backup_objekt, bank_accounts, bank_transactions, bas_accounts, beta_ansokningar, bokslut_ai_suggestions, bokslut_attachments, bokslut_audit_log, bokslut_checks, bokslut_denied_log, bokslut_engagements, bokslut_sync_operations, bookkeeping_templates, byra_installningar, byra_klient, byra_medlemmar, byra_medlemskap, companies, company_ai_features, company_invites, company_lookup_cache, company_lookup_rate, company_subscriptions, customers, deadline_regel, documents, download_audit_log, driftkomponenter, employees, extraction_corrections, fiscal_years, help_feedback, inbound_email_log, inbox_addresses, ink2_deklarationstidpunkt, inkommande_gods, inkopsorder_rader, inkopsordrar, interna_nycklar, invoice_rows, invoices, kivra_utskick, konsol_abonnemangsfakturor, konsol_arenden, konsol_audit_logg, konsol_kundanteckningar, konsol_kundprofiler, konsol_livscykel_steg, konsol_support_samtycken, kyc_arkiv, kyc_assessments, kyc_bilagor, kyc_huvudman, lager_handelser, lager_inventering_rader, lager_inventeringar, lager_leveranser, lonebesked, lonekorningar, mcp_audit_log, mcp_confirm_tokens, monthly_control_comments, monthly_control_events, monthly_control_items, monthly_controls, notification_deliveries, notification_events, notification_preferences, notification_provider_logs, notification_queue, notification_subscriptions, notification_templates, ocr_provider_config, platform_admins, platform_audit_log, platform_user_roles, products, robo_bp_audit_log, robo_bp_checks, robo_bp_control_runs, robo_bp_conversations, robo_bp_messages, robo_bp_rules, robo_bp_settings, salaries, sie_imports, skattekonto_regler, stripe_event_log, subscription_plans, supplier_accounting_rules, supplier_invoices, suppliers, support_ai_events, support_attachments, support_internal_notes, support_messages, support_reads, support_tickets, swish_regler, system_error_log, uppdrag, uppdragsuppgift, user_companies, vat_reports, verifikation_andringar, verifikation_rows, verifikationer, worker_health

Största (total relationsstorlek, 2026-08-20): audit_log ~17 MB, accounts ~5,5 MB, documents ~232 kB, notification_queue ~200 kB, bas_accounts ~200 kB, mcp_audit_log ~184 kB.

## Migrationer (99)

Från `20260710135627_bfl_skydd_v3_rpc_created_by` till `20260909160350_beta_ansokan_orgnr_v1`. Fullständig lista med en fil per migration i `supabase/migrations/`. Grupperna i historiken: BFL-skydd v3–v6 (2026-07-10), lager v1 (07-10), konsol/beta/byråstöd (07-11–07-14), räkenskapsårsregler + bokföringsassistent + lager etapp 2–3 (07-21), arkiv v1 + åtkomst/KYC/AML-scoping + SIE-import + BFL-skydd lön/levfaktura (07-25), etapp 1a/1b audit-triggrar + makuleringsfix (08-14), GDPR-gallring + bank_accounts-unikhet (08-17), etapp 2 spärr av bokföringsdata (08-24), etapp 3 åtkomst/rättelsejournal + audit-cascade-fixar (08-25), etapp 4 rättighetshärdning (08-25), etapp 5 prestanda: FK-index + RLS-InitPlan (08-25), etapp 6 behörighetskoll utan uid-beroende (08-25), etapp 7 anon utan tabellrättigheter (08-25), etapp 8 BFL-skydd vid bolagsradering (08-25), etapp 9 lagringsintegritet (08-25), etapp 10 backupunderlag (08-26), etapp 11 driftövervakning (08-26), etapp 12 rollstyrning på lönetabellerna (09-02), etapp 13a/13b KYC-datamodell + bucket (09-02), etapp 14/14b KYC-bevakning (09-02), etapp 15 append-only operatörslogg (09-02), etapp 16 KYC-arkiv vid avveckling (09-02), etapp 11b/11c driftvakten bedömer bara avslutade körningar + `imap-import` avregistrerad (09-09), kundappens säkerhetsåtgärder byrastod_scope_v1 + ai_kvot_v1 + inbound_avsandare_v1 + ai_kvot_v2 (09-09), extern säkerhetskopia av Storage backup_underlag_v1 + v2 (09-09), Elias beslut 09-09: gdpr_gallring_ai_call_log_v1 + notis_inkommande_kalla_v1, tvåfaktor för plattformsadmin mfa_aal2_plattformsadmin_v1 (09-09), org.nr-krav vid registrering beta_ansokan_orgnr_v1 (09-09).

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

**Den sanktionerade vägen.** `avveckla_bolag(bolags_id uuid, orsak text)` kräver plattformsadministratör och en ifylld orsak, sammanställer omfattningen av det som ska försvinna, skriver en permanent post i `platform_audit_log` och genomför sedan raderingen med spärrarna tillfälligt undantagna. Funktionen har EXECUTE för `authenticated` (behörigheten kontrolleras inuti funktionen); triggerfunktionen är oanropbar för samtliga API-roller. (Sedan etapp 16 fryser funktionen dessutom kundkännedomen i `kyc_arkiv` innan KYC-raderna raderas, se nedan.)

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

## Etapp 10 – backupunderlag (2026-08-26)

Supabases Storage-API listar inte rekursivt: `list()` returnerar en mapp i taget, så ett externt backupskript måste traversera hela mappträdet självt — bräckligt och långsamt. `lista_lagringsobjekt()` läser i stället `storage.objects` direkt och returnerar hela beståndet i ett svep (bucket, sökväg, storlek, MIME-typ, etag och ändringstid) för bucketarna `underlag`, `arkiv`, `annual-report-exports` och `support`. `shimo-audio` utesluts uttryckligen: den tillhör ett annat projekt, är publik och står för 40 av 46 MB — backupen ska omfatta räkenskapsinformation och klientdata, inget annat.

Funktionen är SECURITY DEFINER och anropbar enbart av `postgres`/`service_role` (EXECUTE återkallad från `public`, `anon` och `authenticated`): den listar filer tvärs alla bolag och hör hemma i backupskriptet, inte i API:t.

- `20260826065706_etapp_10_lista_lagringsobjekt_for_backup_v1` – funktionen och rättigheterna.

## Etapp 11 – driftövervakning (2026-08-26)

`worker_health` hade registrerat komponenternas hjärtslag sedan i somras och `cron.job_run_details` varje körning — men ingenting läste signalerna. Följden upptäcktes av en slump: `folio-ocr` hade elva raka misslyckanden sedan 2026-07-14, `stripe-webhook` hade aldrig lyckats (föll 2026-06-08 på okänt Stripe-pris-ID) och e-postimporten hade varit tyst i 78 dagar.

**Registret.** `driftkomponenter` (namn som primärnyckel, `typ`, `max_tyst_timmar`, `max_fel_i_rad`, `aktiv`, `senast_rapporterad_status`) skiljer på två sorters komponenter, eftersom de kräver två sorters larm: för `cron` är tystnad felet (jobbet ska köra på schema), för `handelsestyrd` kan tystnad vara normalt (inga fakturor kom in) medan upprepade fel alltid är fel. Tabellen har RLS utan policies och alla rättigheter återkallade för `anon`/`authenticated` — bara `service_role`/`postgres` når den. Innehållet är data (2026-09-09: 17 komponenter, varav 15 aktiva; `folio-ocr` är avstängd i registret sedan 2026-08-26 eftersom ingen OCR-tjänst är driftsatt, `imap-import` sedan etapp 11c eftersom IMAP-importen togs bort 2026-09-07; `backup-underlag-natt` och `backup-underlag` tillkom med `backup_underlag_v1`) och speglas inte i schemafilerna.

**Ögonblicksbilden.** `driftstatus()` (SECURITY DEFINER, EXECUTE för `authenticated`) bedömer cronjobben mot `cron.job_run_details` (SAKNAS, AVSTANGD, ALDRIG_LYCKATS, FEL, TYST eller OK) och de händelsestyrda mot `worker_health` (OKAND, FEL, ALDRIG_LYCKATS eller OK), med en läsbar detalj per komponent.

**Vakten.** `cron_driftkontroll()` (låst till `postgres`/`service_role`) körs av jobbet `driftkontroll-natt` (`50 3 * * *`) och larmar via `report_system_error` med koden `DRIFT_STATUS_ANDRAD` **enbart när en komponents status har ändrats** sedan senaste larm (jämförs mot `senast_rapporterad_status`) — ett dagligt larm om ett konstant tillstånd tränar bort uppmärksamheten, vilket är precis hur `folio-ocr` kunde ligga nere i sex veckor. Allvarlighet `error` om någon komponent inte är OK, annars `info`; hela statusbilden bifogas. Vakten registrerar eget hjärtslag (`driftkontroll`) i `worker_health`; sedan etapp 14 finns den även i sitt eget register, så `driftstatus()` visar TYST vid manuell kontroll om den skulle sluta köra.

- `20260826091028_etapp_11_driftovervakning_v1` – tabellen, båda funktionerna, rättigheterna, de första tretton registerraderna och cron-jobbet.

## Etapp 11b/11c – vakten larmade falskt (2026-09-09)

Sedan `driftkontroll-natt` registrerades i sitt eget register (etapp 14b) dömde `driftstatus()` varje natt vakten själv som FEL med detaljen "Senaste körning: running", och `kivra-sync-10min` växlade OK → FEL → OK sex gånger på tolv dygn (29/8, 31/8, 1/9, 5/9, 6/9 och 9/9) — sju larm med koden `DRIFT_STATUS_ANDRAD`, vart och ett en urgent-notis till plattformsadministratörerna, utan att något varit fel. Orsaken var lateral-frågan som väljer senaste status med `array_agg(... order by end_time desc)`: en pågående körning har `end_time = null`, och null sorteras först vid fallande sortering, så när vakten körde 03:50 såg den sin egen rad (running) och kivra-syncens rad som startar samma sekund (running/sending) som "senaste körning". Bekräftat mot `cron.job_run_details` (samtliga 9 044 körningar avslutade; ingen rad saknar `end_time` utom under själva körningen) och med en syntetisk sortering.

Rättningen räknar bara körningar med `end_time` satt; ett jobb som hänger fångas i stället av `max_tyst_timmar` (TYST) när dess senaste lyckade körning blir för gammal. Baslinjen för `driftkontroll-natt` sattes åter till OK (den var FEL enbart på grund av felet, och vakten ska larma om förändringar, inte om nuläget). `imap-import` avaktiverades i registret eftersom IMAP-importen togs bort 2026-09-07 (kundappens commit 85a56cc, Google ur driftkedjan); raden lämnas kvar avstängd som `folio-ocr`, så historiken i `worker_health` går att tolka. Efter rättningen: 13 aktiva komponenter, alla OK utom `stripe-webhook`, som är FEL på riktigt (planerna saknar Stripe-pris-ID — beslutet om abonnemangsplaner). Kontrollkörning av `cron_driftkontroll()` kl. 06:48 UTC direkt efter appliceringen gav inget larm; hjärtslaget `driftkontroll` uppdaterades och baslinjerna stod kvar.

- `20260909064557_etapp_11b_driftstatus_avslutade_korningar_v1` – `driftstatus()` filtrerar på `end_time is not null`, rättigheterna upprepade (EXECUTE för `authenticated`), baslinjen för `driftkontroll-natt` åter OK.
- `20260909064701_etapp_11c_imap_import_avregistrerad_v1` – `imap-import` avaktiverad i `driftkomponenter` med beskrivning om borttagningen.

## Etapp 12 – rollstyrning på lönetabellerna (2026-09-02)

`employees`, `lonebesked`, `lonekorningar`, `salaries` och `agi_deklarationer` hade alla policyn `company_id in (select user_company_ids())` FOR ALL (till `public`). RLS skilde alltså bara på bolag, inte på roll: en praktikant eller en klientanvändare inlagd för att attestera fakturor kunde läsa och ändra personnummer, clearing- och kontonummer och löneuppgifter. Art. 25.2 GDPR kräver att uppgifter inte som standard görs tillgängliga för fler än nödvändigt.

`user_companies.role` (admin|member) fanns men användes inte i någon policy, och `user_companies.moduler` (text[]) var påbörjad men oimplementerad. Båda tas i bruk: `mina_lonebolag()` (STABLE, SECURITY DEFINER, EXECUTE för `authenticated`) returnerar de bolag där användaren är administratör eller uttryckligen fått modulen `lon`. De fem breda policyerna ersätts av `<tabell>_lon_policy` (till `authenticated`, samma villkor i `using` och `with check`). Alla nuvarande medlemmar är administratörer och lönetabellerna är tomma — det här är en förutsättning inför första lönekörningen, inte en rättelse av något som redan läckt.

**Audit utan värden.** Triggerfunktionen `audit_personuppgifter()` (oanropbar för API-rollerna) loggar via `log_accounting_audit` vilken rad, vilken åtgärd och vilka kolumner som ändrades — aldrig värden. `audit_log` är läsbar för bolagets medlemmar, så fulla rader hade läckt personnummer bakvägen till just dem som inte får se lönetabellerna. Triggern `trg_audit_personuppgifter` ligger på `employees` och `lonebesked` (och sedan etapp 13a på `kyc_assessments`, `kyc_huvudman` och `kyc_bilagor`).

- `20260902120525_etapp_12_lonetabeller_rollstyrning_v1` – funktionen, audit-triggern och policybytet.

## Etapp 13 – KYC-datamodell och bucket (2026-09-02)

`kyc_assessments` registrerade *att* en kontroll skett (tidsstämplar och booleaner), inte *vad* den bestod av; ordet huvudman förekom i schemat bara som en tidsstämpelkolumn. Vid tillsyn kan byrån då inte visa upp de handlingar 5 kap. 3 § penningtvättslagen kräver att den bevarar i fem år — de hade aldrig samlats in. 3 kap. 8 § kräver att verklig huvudmans identitet kontrolleras, vilket förutsätter att man vet vem det är.

**13a – fältmodellen.** `kyc_assessments` får åtta kolumner (`identitetshandling_typ` med check-villkor, `identitetshandling_referens`, `identitetshandling_utfardare`, `identitetshandling_giltig_till`, `sanktionslista_kalla`, `sanktionslista_datum`, `pep_kalla`, `pep_datum`) och en unik nyckel `(id, company_id)` som gör sammansatta främmande nycklar möjliga. Två nya tabeller: `kyc_huvudman` (en rad per verklig huvudman; personnummer *eller* födelsedatum krävs, `agarandel` 0–100, `kontrollsatt` ur fast lista) och `kyc_bilagor` (registerutdrag, kopia av identitetshandling, utskrift av sanktionskontroll; `storage_path` unik). Båda har FK `(kyc_id, company_id)` mot `kyc_assessments` med ON DELETE CASCADE, RLS med samma scope som `kyc_assessments` (byråns klientbolag via `mina_klientbolag()`) för select/insert (samt update på huvudmän) och **ingen delete-policy** — underlaget ska bevaras i fem år. Alla tre tabellerna får audit-triggern från etapp 12; `kyc_assessments` var dessförinnan fritt redigerbar utan spår.

Observation ur databasen: migrationen återkallar rättigheterna på de nya tabellerna från `public` och `anon` men inte från `authenticated`, och Supabases standardrättigheter hade redan gett den rollen full DML när tabellerna skapades. De uttryckliga `grant select, insert(, update)` är additiva, så `authenticated` har i praktiken samtliga tabellrättigheter på `kyc_huvudman` och `kyc_bilagor` (så redovisas de i `schema/grants.sql`); det är RLS-policyerna, utan delete, som hindrar radering. `kyc_arkiv` (etapp 16) gjordes rätt: `revoke all` inklusive `authenticated` följt av `grant select`. **Rättat 2026-09-02 i `etapp_13c_kyc_tabellrattigheter_v1`: `authenticated` har nu INSERT, SELECT, UPDATE på `kyc_huvudman` och INSERT, SELECT på `kyc_bilagor` (verifierat i `role_table_grants`).*

**13b – bucketen.** Privat bucket `kyc` (20 MB; pdf, png, jpeg, jpg, webp) med sökvägsformatet `<company_id>/<kyc_id>/<uuid>.<ext>`; storage-policyerna `kyc_obj_select` och `kyc_obj_insert` (till `authenticated`) släpper igenom när första mappnivån är ett av byråns klientbolag. Ingen delete-policy. Bakgrund: `arkiv_v1c_regelefterlevnad` (07-25) tog bort arkivmappen "Uppdrag och kundkännedom" med motiveringen att materialet hör hemma i KYC-lagret — som saknade fillagring. Policyerna på `storage.objects` speglas inte i `schema/`; de finns i migrationsfilerna 13b och 16.

- `20260902120552_etapp_13a_kyc_faltmodell_v1` – kolumnerna, tabellerna, index, RLS, rättigheter och audit-triggrarna.
- `20260902120600_etapp_13b_kyc_bucket_v1` – bucketen och storage-policyerna.
- `20260902125353_etapp_13c_kyc_tabellrattigheter_v1` – tabellrättigheterna på `kyc_huvudman`/`kyc_bilagor` nedjusterade till avsikten (se observationen ovan).

## Etapp 14 – KYC-bevakning (2026-09-02)

Regelefterlevnadsgranskningen 2026-08-25 fann att `has_kyc_clearance()` prövar `giltig_till` men saknar verkställande anropare, och att `aml_run_checks()` bara körs från en knapp i gränssnittet. När en godkänd bedömning löpte ut hände ingenting — ingen notifiering, ingen flagga, ingen spärr — trots att gränssnittet kallar det "AUTO-grind".

`cron_kyc_bevakning()` (SECURITY DEFINER, låst till `postgres`/`service_role`) går igenom varje aktiv byråklient (`byra_klient.status = 'aktiv'`) och tittar på den senaste godkända bedömningen:

- **Saknas** godkänd bedömning: `aml_flags` av typ `kyc_saknas`, allvarlighet `hog`, dedup-nyckel `kyc_saknas:ÅÅÅÅ-MM` — en flagga per månad så länge bristen består (PTL 3 kap. 4 §).
- **Utgången** (`giltig_till` har passerats): `hog`, dedup-nyckel `kyc_utgangen:<datum>` (PTL 3 kap. 13 §).
- **Utgår inom 30 dagar**: `normal`, dedup-nyckel `kyc_utgar:<datum>`.

Dedup sker per omständighet via den unika nyckeln `(company_id, dedup_nyckel)` — samma omständighet flaggas en gång, inte varje natt — och flaggorna syns i byråns befintliga AML-vy. Jobbet anropar medvetet **inte** `aml_run_checks`: den funktionen skapar `aml_installningar` med standardtrösklar "on conflict do nothing", alltså utan att en människa fattat beslutet, och transaktionsövervakningens trösklar är verksamhetsutövarens ansvar enligt den allmänna riskbedömningen (2 kap. 1 §). Hjärtslag `kyc_bevakning` i `worker_health`.

Cron-jobbet `kyc-bevakning-natt` schemalades först 04:35 (jobid 9) och flyttades i 14b till `30 3 * * *` (jobid 10), före driftvakten 03:50 — annars hade vakten rapporterat "aldrig lyckats" första natten och "blev frisk" andra natten, två larm utan innehåll. Samtidigt registreras bevakningen och driftvakten själv i `driftkomponenter` med baslinjen OK (data, speglas inte i schemafilerna). Schemat i `schema/cron_jobs.sql` är kontrollerat mot `cron.job`, inte mot migrationstexten.

- `20260902121255_etapp_14_kyc_bevakning_v1` – funktionen, rättigheterna, cron-jobbet och registerraderna.
- `20260902121357_etapp_14b_kyc_bevakning_schema_v1` – omschemaläggningen till 03:30 och baslinjen.

## Etapp 15 – operatörsloggen append-only (2026-09-02)

`konsol/index.ts` påstår att `konsol_audit_logg` är append-only, men tabellen hade varken trigger eller RLS-policies — skyddet var enbart att bara `service_role` kommer åt den, och den nyckeln delas av alla 32 edge functions. Vem som helst med nyckeln kunde radera eller skriva om spåren av operatörens åtgärder. Jämför `verifikation_andringar`, som har en riktig append-only-trigger sedan etapp 3.

Triggerfunktionen `konsol_audit_appendonly()` (oanropbar för `anon`/`authenticated`) sitter som `trg_konsol_audit_appendonly` (BEFORE UPDATE OR DELETE, per rad) och `trg_konsol_audit_no_truncate` (BEFORE TRUNCATE, per statement). Enda tillåtna ändringen: FK:n mot `companies` är ON DELETE SET NULL, så vid en bolagsradering sätts `company_id` till null — den uppdateringen släpps igenom om och endast om inget annat fält ändras. Allt annat avbryts med `KONSOL_LOGG_APPENDONLY` (behandlingshistorik ska bevaras, BFL 5 kap. 11 §).

- `20260902121521_etapp_15_konsol_audit_appendonly_v1` – funktionen, rättigheterna och båda triggrarna.

## Etapp 16 – kundkännedom bevaras vid avveckling (2026-09-02)

`avveckla_bolag()` (etapp 8) skyddar räkenskapsinformationen enligt BFL men raderar `kyc_assessments` och `aml_flags` uttryckligen — de har RESTRICT-nycklar mot `companies` — och sedan etapp 13 kaskaderar även `kyc_huvudman` och `kyc_bilagor` med. Penningtvättslagen kräver att handlingar och uppgifter om kundkännedom bevaras i fem år efter att affärsförbindelsen upphörde (5 kap. 3 §), upp till tio år på begäran av myndighet (5 kap. 4 §).

**Arkivet.** `kyc_arkiv` tar en fryst kopia (jsonb) av bedömningarna, huvudmännen, bilagereferenserna och AML-flaggorna tillsammans med ursprungsbolagets id, namn och organisationsnummer, byråernas id:n (`byra_bolag_ids`), tidpunkten då affärsförbindelsen avslutades, `bevaras_till`, vem som avvecklade och orsaken. Index: GIN på `byra_bolag_ids`, B-tree på `bevaras_till`. RLS-policyn `kyc_arkiv_select` ger läsning till plattformsadministratörer och till byråer som haft bolaget som klient; `authenticated` har enbart `select` (allt annat återkallat), `service_role` full åtkomst.

**Append-only.** Triggerfunktionen `kyc_arkiv_skydd()` (`trg_kyc_arkiv_skydd` BEFORE UPDATE OR DELETE per rad, `trg_kyc_arkiv_no_truncate` BEFORE TRUNCATE) tillåter en enda ändring — att `bevaras_till` förlängs utan att något annat fält rörs — och radering först när bevarandetiden löpt ut. Allt annat avbryts med `KYC_ARKIV_SKYDD`.

**Avvecklingen.** `avveckla_bolag(uuid, text)` ersätts med en version som, innan KYC-raderna måste bort, fryser kundkännedomen i `kyc_arkiv` med `bevaras_till` = dagens datum + fem år, loggar `kyc_archived` i `platform_audit_log` och returnerar arkiv-id och bevarandedatum; i övrigt identisk med etapp 8. Filerna i bucketen `kyc` rörs inte av avvecklingen (`stadning-underlag` tömmer bara `underlag`), så storage-policyn `kyc_obj_select` utökas: byrån når bilagorna under `<bolags-id>/` även för avvecklade klienter som finns i arkivet. Personuppgifter (personnummer på verkliga huvudmän) hamnar i arkivet med den lagstadgade bevarandeskyldigheten som rättslig grund (GDPR art. 6.1 c).

- `20260902122644_etapp_16_kyc_arkiv_vid_avveckling_v1` – tabellen, index, RLS, rättigheter, triggerfunktionen, policyändringen i Storage och den nya `avveckla_bolag()`.

## Kundappens säkerhetsåtgärder 2026-09-09 – byrastod_scope_v1, ai_kvot_v1, inbound_avsandare_v1, ai_kvot_v2

Fyra migrationer från arbetet i kundappens repo (`EliasMakdessielias/bokpilot`; go-live-listans punkt 7 — de öppna fynden från edge-funktionsgranskningen 2026-08-25). Spegelfilerna finns även i kundappens `supabase/*.sql` med identiskt innehåll; edge-koden som använder dem deployas av GitHub Actions vid nästa push.

**Tenantavgränsning i byråstödet.** `byrastod_markera_forsenade()` markerade försenade uppgifter för ALLA byråer, och edge-funktionen `byrastod-jobb` lät en inloggad byråmedlem köra hela jobbet (uppdragsgenerering + markering) över samtliga byråer och få andra byråers uppdrags-id:n i svaret. Funktionen har nu signaturen `byrastod_markera_forsenade(p_byra_bolag_ids uuid[] default null)`: null (cron via service_role) = alla byråer; en lista begränsar; en inloggad byråmedlem begränsas alltid till `mina_byraer()` oavsett parameter. Den gamla nollargumentsversionen är droppad (annars tvetydigt PostgREST-anrop); anrop utan argument matchar defaultparametern, så den ännu odeployade edge-funktionen fortsätter fungera. Rättigheter: endast `service_role` (som efter etapp 4). Edge-funktionen hämtar anroparens byråer via `mina_byraer` (`_shared/byra.ts` normaliserar PostgREST-svaret) och filtrerar både `uppdrag`-urvalet och markeringen.

**AI-kostnadstak.** Sex AI-chattfunktioner (assistent-ai, bokfor-ai, ekonomichef-ai, granska-ai, manadskontroll-ai, support-ai) saknade helt kvot- och rate limit-kontroll; en licensgrind gick inte att använda eftersom planernas `features` saknar nycklarna. `ai_call_log` får kolumnen `funktion` och indexet `ai_call_log_user_recent_idx (user_id, created_at desc)`. `ai_kvot_klaim(p_user_id, p_funktion, p_company_id default null)` (SECURITY DEFINER, endast `service_role`) räknar anrop i glidande fönster och loggar anropet: 60 per användare och timme, 400 per användare och dygn, 1 500 per timme för hela plattformen (kretsbrytare); vid spärr returneras `allowed=false`, `reason` (timme/dygn/plattform) och `retry_after_seconds`. Raderna räknas även av `ai_claim_job` (tolka-underlag, 8 anrop/användare/minut) — en gemensam AI-budget per användare. Testat i produktion med en fingerad användare (räknade 1 → 2; raderna städade). Gallring saknas fortfarande för `ai_call_log` (beslutsunderlaget 2026-09-02 föreslår 12 månader). **`ai_kvot_v2` (samma dag, granskningsfynd):** användartaken räknar bara chattanrop (`funktion is not null`) och `ai_claim_job` bara tolkningar (`document_id is not null`), så att bulk-tolkning inte spärrar chatten och åtta chattfrågor på en minut inte ger tolkningen cooldown; plattformstaket räknar fortfarande alla AI-anrop. Testat: en tolkningsrad för användaren påverkar inte chattens räkning.

**Avsändarkontroll för inmejlade underlag.** `documents` får `avsandare_verifierad boolean` (true/false/null) och `avsandare_kontroll jsonb` (metod, orsak, avsändar-/kuvertdomän, SPF/DKIM/DMARC-resultat, tidpunkt — aldrig rubriktext). Edge-funktionen `inbound-email` bedömer alignment mellan autentiserad domän (DKIM `header.d` respektive SPF-kuvertet ur Cloudflares `ARC-Authentication-Results`, som workern skickar i `auth`) och synlig From-domän; false ⇒ underlaget tas ändå emot men får `status = needs_review`, AI-tolkas inte automatiskt och märks "Avsändare ej verifierad" i Inkorgen. Kräver att Cloudflare-workern deployas på nytt för att resultaten ska skickas — tills dess bedöms bara kuvertet (alignat kuvert ⇒ okänt, avvikande ⇒ false).

- `20260909072459_byrastod_scope_v1` – drop av `byrastod_markera_forsenade()`, ny version med `uuid[]`-parameter, rättigheter.
- `20260909072526_ai_kvot_v1` – kolumnen, indexet, `ai_kvot_klaim()` och rättigheterna.
- `20260909072604_inbound_avsandare_v1` – de två kolumnerna på `documents` med kolumnkommentarer.
- `20260909074216_ai_kvot_v2` – `ai_kvot_klaim()` och `ai_claim_job()` med separata räknefönster (chatt respektive tolkning).

## Extern säkerhetskopia av Storage – backup_underlag_v1 (2026-09-09)

Etapp 9 konstaterade att Supabases databasbackuper inte omfattar Storage: filerna i bucketarna `underlag`, `arkiv`, `annual-report-exports` och `support` — räkenskapsinformation enligt BFL 7 kap. — hade ingen kopia alls (27 objekt 2026-09-09). Etapp 10 gav backupunderlaget `lista_lagringsobjekt()`; beslutsunderlaget `docs/arkivlagring-azure-verifiering.md` (2026-08-26) verifierade Azure Blob Storage i Sweden Central (Cold + ZRS + oföränderlig container) som mål. Kundappens edge-funktion `backup-underlag` (byggd och deployad 2026-09-09) kopierar nya och ändrade objekt dit varje natt; data lämnar aldrig Sverige (edge i Stockholm → Sweden Central, ingen mellanhand). Aktiveringen kräver edge-secreten `AZURE_BLOB_SAS_URL` (container-SAS med skapa/skriv men aldrig radera; funktionen vägrar en SAS med `d` eller som gått ut) — se `docs/BACKUP-UNDERLAG.md` i kundappen.

**Driftsatt och provkört 2026-09-09.** Azure sattes upp samma dag (Entra-katalogen AcountX Redovisningsbyrå AB, prenumeration `e78aabcf-…` med BokPilot AB som momsregistrerad kund, resursgrupp `rg-bokpilot-arkiv`, lagringskonto `bokpilotarkiv` i Sweden Central med ZRS, container `underlag-2026` med olåst tidsbaserad oföränderlighet 3 000 dagar), secreten lades in och edge-funktionen deployades av workflowen kl. 09:46 UTC. Manuell körning kl. 09:48 UTC: 29 objekt kopierade (underlag 24, arkiv 2, support 2, annual-report-exports 1; 6,27 MB), 0 fel, 18,5 s; `backup_status()` visar `saknar_kopia = 0`. Kvar: låsning av policyn efter första nattkörningen.

**Databasens del.** Manifestet `backup_objekt` (bucket, sökväg, etag, storlek, blobnamn, tidpunkt; primärnyckel bucket+sökväg+etag; RLS utan policies, endast `service_role`) bokför varje kopierad objektversion. `backup_att_kopiera(p_max)` (SECURITY DEFINER, endast `service_role`) listar objekt vars aktuella etag saknar kopia, äldst först, med antalet tidigare kopior av samma sökväg — en ändrad fil får ett nytt blobnamn med etag-suffix eftersom arkivet aldrig skriver över. `backup_status()` (EXECUTE för `authenticated`) ger bara antal och tidpunkter. Cron-nyckeln `backup_cron` skapades slumpmässigt i `interna_nycklar` och lämnar databasen enbart i cron-headern; jobbet `backup-underlag-natt` (jobid 11, 02:30) anropar funktionen via `net.http_post`. Driftvakten fick två komponenter: `backup-underlag-natt` (cron — tystnad är fel) och `backup-underlag` (händelsestyrd — fel när en kopia misslyckas eller när SAS-URL:en saknas eller inte duger). Baslinjen lämnades tom, så första nattens verkliga status larmas en gång: tills Azure finns visar vakten FEL med orsaken "AZURE_BLOB_SAS_URL saknas".

- `20260909082723_backup_underlag_v1` – tabellen med index och rättigheter, `backup_att_kopiera()`, `backup_status()`, cron-nyckeln, cron-jobbet och registerraderna.
- `20260909095103_backup_underlag_v2` – `cron.alter_job` på jobb 11 med `timeout_milliseconds := 150000`: pg_net väntar annars bara 5 s på svar, och provkörningen tog 18,5 s.

## Två beslut 2026-09-09 – gdpr_gallring_ai_call_log_v1 och notis_inkommande_kalla_v1

Granskningsagenterna 2026-09-09 lämnade två punkter som krävde Elias beslut; han gav sitt ja samma dag och båda applicerades med transaktionsåterrullade tester.

- `20260909110657_gdpr_gallring_ai_call_log_v1` – `gallra_gdpr_loggar()` får en sjätte tabell: `ai_call_log` (kvoträknaren bakom AI-kvoterna, pseudonyma rader utan innehåll) gallras efter tolv månader av `gdpr-gallring-natt` (03:40). Bevarandetiden är nu fastställd i art. 30-registret (A6, B4) och PUB-utkastet (§9) i stället för klamrad. Test: funktionen returnerar sex rader, `ai_call_log = 0` (inga rader äldre än tolv månader ännu).
- `20260909110703_notis_inkommande_kalla_v1` – `notify_on_inbound_document()` (AFTER INSERT på `documents`) avbröt när `source` inte var exakt `'email'`, men Cloudflare-workern skriver `'cloudflare-email'` — inga notiser gick alltså för inmejlade underlag. Nu räknas båda e-postkällorna (`coalesce(source, '') not in ('email', 'cloudflare-email')`); uppladdningar i appen notifieras som förut inte. Test i rullad transaktion: en `needs_review`-rad med `source = 'cloudflare-email'` gav en `notification_events`-rad av typen `invoice_needs_review` och fyra köposter i `notification_queue`.

## Tvåfaktor för plattformsadmin – mfa_aal2_plattformsadmin_v1 (2026-09-09)

Kundappen fick tvåfaktorsautentisering (Supabase Auth MFA, TOTP) 2026-09-09; granskningen samma dag konstaterade att spärren bara låg i appen. `20260909145608_mfa_aal2_plattformsadmin_v1` ersätter `is_platform_admin()`: funktionen är sann bara om JWT-claimen `aal` är `aal2` så snart kontot har en verifierad faktor i `auth.mfa_factors` (konton utan faktor är opåverkade — ingen låses ute innan de aktiverat skyddet). Eftersom `is_superadmin`, `has_platform_role`, `my_platform_access`, `can_*` och 18 RLS-policies bygger på funktionen gäller kravet hela plattformsadmin-rollen. Testat med simulerade `request.jwt.claims`: admin utan faktor → sann på aal1 och aal2, annan adress → falsk, utan JWT → falsk. Faktorerna själva ligger i `auth`-schemat och speglas inte i dumpen. Edge-funktionerna `admin` (kundappen) och `konsol` (bokpilot-admin) gör samma bedömning i kod.

## Organisationsnummer vid registrering – beta_ansokan_orgnr_v1 (2026-09-09)

Registreringsformuläret kräver sedan 2026-09-09 organisationsnummer (BokPilot tillhandahålls näringsidkare; enskild firma anger personnummer), men kravet låg bara i webbläsaren. `20260909160350_beta_ansokan_orgnr_v1` inför `orgnr_normaliserat(text)` (IMMUTABLE, EXECUTE för `authenticated` och `service_role`): siffrorna plockas ut, tolv siffror med sekelprefix 16/19/20 kortas till tio, kontrollsiffran räknas med Luhn och resultatet formateras `NNNNNN-NNNN` — eller `null` vid ogiltigt nummer. `skapa_beta_ansokan()` vägrar nu ogiltigt eller saknat nummer och lagrar det normaliserade värdet i både `companies.org_nr` och `beta_ansokningar.org_nr`. Kontrollerat: `559208-1219`, `165592081219` och `5592081219` ger alla `559208-1219`; fel kontrollsiffra, skräp och `null` ger `null`. Samma regler som kundappens `src/lib/orgnr.js`.
