# Inventering – bokpilot-sverige (2026-08-20)

Projekt: `bokpilot-sverige`, ref `vzeqvapebkbapwflozbi`, eu-north-1.

Totalsiffror (public-schemat): **123 tabeller** (samtliga med RLS aktivt), **0 vyer**, **249 egna funktioner** (exkl. extension-ägda), **75 triggrar**, **160 RLS-policies**, **191 index** (som inte backar constraints), **70 migrationer**, **32 edge functions**, **6 pg_cron-jobb**, **5 storage-buckets**. (Uppdaterat 2026-08-25 efter etapp 4–7: search_path-låsning och anon-indragning, täckande FK-index, RLS-InitPlan-omskrivning, behörighetskoll utan uid-beroende samt indragna tabellrättigheter för anon.) Inga egna enum-typer. Enda schema med egna objekt är `public`.

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

Se `schema/cron_jobs.sql`. Sammanfattning: dagliga notifierings-/abonnemangsjobb (06:00, 06:15), månadskontroller (03:15), kivra-sync var 10:e minut, byråstöd nattjobb (04:10), GDPR-gallring (03:40).

## Tabeller (123, samtliga med RLS)

account_import_batches, accounts, agi_deklarationer, ai_bokforing_logg, ai_call_log, ai_checklista_korningar, ai_cooldowns, ai_error_log, ai_usage_log, aml_flags, aml_installningar, annual_report_draft_sections, annual_report_drafts, annual_report_exports, annual_report_validation_items, arkiv_filer, arkiv_mappar, article_templates, assistent_logg, audit_log, bank_accounts, bank_transactions, bas_accounts, beta_ansokningar, bokslut_ai_suggestions, bokslut_attachments, bokslut_audit_log, bokslut_checks, bokslut_denied_log, bokslut_engagements, bokslut_sync_operations, bookkeeping_templates, byra_installningar, byra_klient, byra_medlemmar, byra_medlemskap, companies, company_ai_features, company_invites, company_lookup_cache, company_lookup_rate, company_subscriptions, customers, deadline_regel, documents, download_audit_log, employees, extraction_corrections, fiscal_years, help_feedback, inbound_email_log, inbox_addresses, ink2_deklarationstidpunkt, inkommande_gods, inkopsorder_rader, inkopsordrar, interna_nycklar, invoice_rows, invoices, kivra_utskick, konsol_abonnemangsfakturor, konsol_arenden, konsol_audit_logg, konsol_kundanteckningar, konsol_kundprofiler, konsol_livscykel_steg, konsol_support_samtycken, kyc_assessments, lager_handelser, lager_inventering_rader, lager_inventeringar, lager_leveranser, lonebesked, lonekorningar, mcp_audit_log, mcp_confirm_tokens, monthly_control_comments, monthly_control_events, monthly_control_items, monthly_controls, notification_deliveries, notification_events, notification_preferences, notification_provider_logs, notification_queue, notification_subscriptions, notification_templates, ocr_provider_config, platform_admins, platform_audit_log, platform_user_roles, products, robo_bp_audit_log, robo_bp_checks, robo_bp_control_runs, robo_bp_conversations, robo_bp_messages, robo_bp_rules, robo_bp_settings, salaries, sie_imports, skattekonto_regler, stripe_event_log, subscription_plans, supplier_accounting_rules, supplier_invoices, suppliers, support_ai_events, support_attachments, support_internal_notes, support_messages, support_reads, support_tickets, swish_regler, system_error_log, uppdrag, uppdragsuppgift, user_companies, vat_reports, verifikation_andringar, verifikation_rows, verifikationer, worker_health

Största (total relationsstorlek): audit_log ~17 MB, accounts ~5,5 MB, documents ~232 kB, notification_queue ~200 kB, bas_accounts ~200 kB, mcp_audit_log ~184 kB.

## Migrationer (70)

Från `20260710135627_bfl_skydd_v3_rpc_created_by` till `20260825142721_etapp_7_anon_utan_tabellrattigheter_v1`. Fullständig lista med en fil per migration i `supabase/migrations/`. Grupperna i historiken: BFL-skydd v3–v6 (2026-07-10), lager v1 (07-10), konsol/beta/byråstöd (07-11–07-14), räkenskapsårsregler + bokföringsassistent + lager etapp 2–3 (07-21), arkiv v1 + åtkomst/KYC/AML-scoping + SIE-import + BFL-skydd lön/levfaktura (07-25), etapp 1a/1b audit-triggrar + makuleringsfix (08-14), GDPR-gallring + bank_accounts-unikhet (08-17), etapp 2 spärr av bokföringsdata (08-24), etapp 3 åtkomst/rättelsejournal + audit-cascade-fixar (08-25), etapp 4 rättighetshärdning (08-25), etapp 5 prestanda: FK-index + RLS-InitPlan (08-25), etapp 6 behörighetskoll utan uid-beroende (08-25), etapp 7 anon utan tabellrättigheter (08-25).

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
