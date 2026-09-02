create table public.account_import_batches (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  filename text,
  mode text not null,
  total_rows integer default 0,
  inserted integer default 0,
  updated integer default 0,
  skipped integer default 0,
  deactivated integer default 0,
  deleted integer default 0,
  status text default 'completed'::text,
  error text,
  imported_by uuid,
  imported_by_email text,
  created_at timestamp with time zone default now()
);

alter table public.account_import_batches enable row level security;

create table public.accounts (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  account_nr text not null,
  name text not null,
  vat_code text default ''::text,
  sru text default ''::text,
  is_active boolean default true,
  opening_balance numeric(15,2) default 0,
  budget numeric(15,2) default 0,
  auto_kontering text default ''::text,
  suggest_debit_credit text default 'debet'::text,
  transaction_info text default 'allowed'::text,
  created_at timestamp with time zone default now(),
  account_class smallint,
  account_type text,
  updated_at timestamp with time zone default now(),
  imported_from text,
  import_batch_id uuid,
  is_blocked_for_manual_booking boolean default false,
  is_locked boolean default false,
  locked_reason text,
  locked_source text
);

alter table public.accounts enable row level security;

create table public.agi_deklarationer (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  period text not null,
  status text default 'skapad'::text not null,
  summa_underlag numeric default 0 not null,
  ag_avgift numeric default 0 not null,
  avdragen_skatt numeric default 0 not null,
  att_betala numeric default 0 not null,
  antal_individer integer default 0 not null,
  individuppgifter jsonb default '[]'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid default auth.uid()
);

alter table public.agi_deklarationer enable row level security;

create table public.ai_bokforing_logg (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  document_id uuid,
  kind text,
  fraga text,
  svar text,
  konteringsforslag jsonb,
  konfidens numeric,
  kraver_manuell_granskning boolean,
  regelverk_version text,
  model text,
  applied boolean default false not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  verifikation_id uuid
);

alter table public.ai_bokforing_logg enable row level security;

create table public.ai_call_log (
  id uuid default gen_random_uuid() not null,
  created_at timestamp with time zone default now() not null,
  user_id uuid,
  company_id uuid,
  document_id uuid
);

alter table public.ai_call_log enable row level security;

create table public.ai_checklista_korningar (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  created_by uuid,
  resultat jsonb default '{}'::jsonb not null,
  antal_ai_anrop integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

alter table public.ai_checklista_korningar enable row level security;

create table public.ai_cooldowns (
  scope text not null,
  scope_key text not null,
  cooldown_until timestamp with time zone not null,
  reason text,
  updated_at timestamp with time zone default now() not null
);

alter table public.ai_cooldowns enable row level security;

create table public.ai_error_log (
  id uuid default gen_random_uuid() not null,
  created_at timestamp with time zone default now() not null,
  provider text,
  model text,
  status_code integer,
  error_code text,
  error_body text,
  request_id text,
  attempts integer,
  kind text,
  user_id uuid,
  company_id uuid,
  document_id uuid
);

alter table public.ai_error_log enable row level security;

create table public.ai_usage_log (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  kind text default 'ocr'::text,
  created_at timestamp with time zone default now() not null
);

alter table public.ai_usage_log enable row level security;

create table public.aml_flags (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  typ text not null,
  allvarlighet text default 'normal'::text not null,
  verifikation_id uuid,
  document_id uuid,
  beskrivning text not null,
  dedup_nyckel text not null,
  status text default 'oppen'::text not null,
  beslutsanteckning text,
  granskad_av uuid,
  granskad_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

alter table public.aml_flags enable row level security;

create table public.aml_installningar (
  id boolean default true,
  kontantgrans_kr numeric default 15000 not null,
  strukturering_fonster_dagar integer default 30 not null,
  strukturering_min_antal integer default 3 not null,
  strukturering_andel_av_grans numeric default 0.7 not null,
  updated_at timestamp with time zone default now() not null,
  byra_bolag_id uuid not null
);

alter table public.aml_installningar enable row level security;

create table public.annual_report_draft_sections (
  id uuid default gen_random_uuid() not null,
  draft_id uuid not null,
  company_id uuid not null,
  section_key text not null,
  title text not null,
  content text,
  structured_data jsonb default '{}'::jsonb not null,
  source_references jsonb default '{}'::jsonb not null,
  ai_generated boolean default false not null,
  requires_review boolean default true not null,
  review_status text default 'needs_review'::text not null,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  review_comment text,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  ai_model text,
  ai_prompt_version text,
  ai_generated_at timestamp with time zone,
  ai_source_summary jsonb default '{}'::jsonb not null
);

alter table public.annual_report_draft_sections enable row level security;

create table public.annual_report_drafts (
  id uuid default gen_random_uuid() not null,
  engagement_id uuid not null,
  company_id uuid not null,
  fiscal_year_id uuid,
  regelverk text default 'K2'::text not null,
  status text default 'draft'::text not null,
  title text,
  period_start date,
  period_end date,
  generated_by uuid,
  generated_at timestamp with time zone,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  approved_by uuid,
  approved_at timestamp with time zone,
  source_data jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.annual_report_drafts enable row level security;

create table public.annual_report_exports (
  id uuid default gen_random_uuid() not null,
  draft_id uuid not null,
  engagement_id uuid not null,
  company_id uuid not null,
  export_type text not null,
  status text default 'generating'::text not null,
  file_path text,
  file_name text,
  file_size bigint,
  validation_summary jsonb default '{}'::jsonb not null,
  error text,
  generated_by uuid,
  generated_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  storage_bucket text,
  storage_path text,
  checksum text,
  render_engine text,
  quality_status text default 'not_checked'::text not null,
  quality_report jsonb default '{}'::jsonb not null
);

alter table public.annual_report_exports enable row level security;

create table public.annual_report_validation_items (
  id uuid default gen_random_uuid() not null,
  draft_id uuid not null,
  engagement_id uuid not null,
  company_id uuid not null,
  section_id uuid,
  validation_key text not null,
  title text not null,
  description text,
  severity text default 'warning'::text not null,
  status text default 'open'::text not null,
  source text default 'rule'::text not null,
  source_data jsonb default '{}'::jsonb not null,
  suggested_action text,
  resolved_by uuid,
  resolved_at timestamp with time zone,
  ignored_by uuid,
  ignored_at timestamp with time zone,
  ignored_reason text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.annual_report_validation_items enable row level security;

create table public.arkiv_filer (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  mapp_id uuid not null,
  document_id uuid,
  storage_path text,
  file_name text not null,
  mime_type text,
  file_size bigint,
  beskrivning text,
  kalla text default 'uppladdad'::text not null,
  uppladdad_av uuid default auth.uid(),
  raderad_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  raderad_av uuid
);

alter table public.arkiv_filer enable row level security;

create table public.arkiv_mappar (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  parent_id uuid,
  namn text not null,
  synlighet text default 'kund_skriv'::text not null,
  gallringsregel text default 'ingen'::text not null,
  systemnyckel text,
  sortering integer default 100 not null,
  skapad_av uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

alter table public.arkiv_mappar enable row level security;

create table public.article_templates (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  name text not null,
  name_en text,
  vat_rate smallint default 25,
  category text default 'Varor'::text,
  description text,
  is_active boolean default true,
  is_standard boolean default false,
  locked boolean default false,
  sales_accounts jsonb default '{}'::jsonb,
  created_at timestamp with time zone default now()
);

alter table public.article_templates enable row level security;

create table public.assistent_logg (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  user_id uuid not null,
  in_tokens integer default 0 not null,
  out_tokens integer default 0 not null,
  cache_read_tokens integer default 0 not null,
  verktygsanrop integer default 0 not null,
  bokford boolean default false not null,
  created_at timestamp with time zone default now() not null,
  mall_key text,
  prompt text,
  svar text,
  status text default 'klar'::text not null
);

alter table public.assistent_logg enable row level security;

create table public.audit_log (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  entity text not null,
  entity_ref text,
  action text not null,
  old_data jsonb,
  new_data jsonb,
  batch_id uuid,
  changed_by uuid,
  changed_by_email text,
  created_at timestamp with time zone default now(),
  source text,
  metadata jsonb
);

alter table public.audit_log enable row level security;

create table public.bank_accounts (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  namn text not null,
  typ text default 'Företagskonto'::text not null,
  valuta text default 'SEK'::text not null,
  account_nr text,
  bankgiro text,
  iban text,
  aktiv boolean default true not null,
  created_at timestamp with time zone default now(),
  is_standard boolean default false,
  locked boolean default false,
  bankkontonr text
);

alter table public.bank_accounts enable row level security;

create table public.bank_transactions (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  account_nr text not null,
  datum date,
  text text,
  amount numeric(15,2),
  status text default 'unmatched'::text,
  verifikation_id uuid,
  imported_at timestamp with time zone default now(),
  avstamd boolean default false,
  import_batch uuid
);

alter table public.bank_transactions enable row level security;

create table public.bas_accounts (
  account_nr text not null,
  name text not null,
  vat_code text default ''::text,
  is_active boolean default true
);

alter table public.bas_accounts enable row level security;

create table public.beta_ansokningar (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  company_id uuid,
  epost text not null,
  bolagsnamn text not null,
  org_nr text,
  meddelande text,
  status text default 'vantar'::text not null,
  hanterad_av_email text,
  hanterad_at timestamp with time zone,
  avvisad_orsak text,
  created_at timestamp with time zone default now() not null
);

alter table public.beta_ansokningar enable row level security;

create table public.bokslut_ai_suggestions (
  id uuid default gen_random_uuid() not null,
  engagement_id uuid not null,
  company_id uuid not null,
  suggestion_type text not null,
  title text not null,
  summary text,
  reasoning text,
  risk_level text default 'medium'::text not null,
  confidence numeric,
  related_check_id uuid,
  related_attachment_id uuid,
  source_data jsonb default '{}'::jsonb not null,
  suggested_next_action text,
  status text default 'needs_review'::text not null,
  model text,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  review_comment text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.bokslut_ai_suggestions enable row level security;

create table public.bokslut_attachments (
  id uuid default gen_random_uuid() not null,
  engagement_id uuid not null,
  company_id uuid not null,
  type text not null,
  title text not null,
  account_nr text,
  saldo_huvudbok numeric,
  avstamt_belopp numeric,
  differens numeric,
  source text,
  source_data jsonb default '{}'::jsonb not null,
  status text default 'draft'::text not null,
  comment text,
  check_id uuid,
  rule_key text,
  reviewed_by uuid,
  reviewed_at timestamp with time zone,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.bokslut_attachments enable row level security;

create table public.bokslut_audit_log (
  id uuid default gen_random_uuid() not null,
  engagement_id uuid,
  company_id uuid not null,
  user_id uuid,
  action text not null,
  model text,
  prompt_version text,
  detail jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.bokslut_audit_log enable row level security;

create table public.bokslut_checks (
  id uuid default gen_random_uuid() not null,
  engagement_id uuid not null,
  company_id uuid not null,
  category text not null,
  title text not null,
  description text,
  account_nr text,
  saldo numeric,
  risk_level text default 'low'::text not null,
  status text default 'open'::text not null,
  suggested_action text,
  source text,
  action_url text,
  rule_key text not null,
  assigned_to uuid,
  comment text,
  source_data jsonb default '{}'::jsonb not null,
  resolved_by uuid,
  resolved_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  comment_revision bigint default 1 not null,
  comment_updated_at timestamp with time zone,
  comment_updated_by uuid
);

alter table public.bokslut_checks enable row level security;

create table public.bokslut_denied_log (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  company_id uuid,
  engagement_id uuid,
  role text,
  action text not null,
  reason text,
  context jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.bokslut_denied_log enable row level security;

create table public.bokslut_engagements (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  fiscal_year_id uuid not null,
  regelverk text default 'K2'::text not null,
  status text default 'ej_paborjad'::text not null,
  ansvarig_user_id uuid,
  last_analysis_at timestamp with time zone,
  open_count integer default 0 not null,
  critical_count integer default 0 not null,
  high_count integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.bokslut_engagements enable row level security;

create table public.bokslut_sync_operations (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  company_id uuid not null,
  entity_type text not null,
  entity_id uuid not null,
  operation_type text not null,
  idempotency_key uuid not null,
  request_hash text not null,
  base_revision bigint not null,
  status text not null,
  result_payload jsonb,
  created_at timestamp with time zone default now() not null,
  completed_at timestamp with time zone,
  expires_at timestamp with time zone default (now() + '90 days'::interval) not null
);

alter table public.bokslut_sync_operations enable row level security;

create table public.bookkeeping_templates (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  name text not null,
  name_en text,
  usage_area text default 'Manuell verifikation'::text,
  ver_series text,
  description text,
  is_active boolean default true,
  is_standard boolean default false,
  locked boolean default false,
  rows jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now()
);

alter table public.bookkeeping_templates enable row level security;

create table public.byra_installningar (
  byra_bolag_id uuid not null,
  standard_moduler text[],
  standard_uppdragstyper text[] default '{}'::text[] not null,
  updated_at timestamp with time zone default now() not null,
  updated_av uuid
);

alter table public.byra_installningar enable row level security;

create table public.byra_klient (
  id uuid default gen_random_uuid() not null,
  byra_bolag_id uuid not null,
  klient_bolag_id uuid not null,
  status text default 'aktiv'::text not null,
  kundansvarig_anvandare_id uuid,
  tillagd_av uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  avslutad_at timestamp with time zone
);

alter table public.byra_klient enable row level security;

create table public.byra_medlemmar (
  user_id uuid not null,
  namn text,
  tillagd_av uuid,
  created_at timestamp with time zone default now() not null
);

alter table public.byra_medlemmar enable row level security;

create table public.byra_medlemskap (
  id uuid default gen_random_uuid() not null,
  byra_bolag_id uuid not null,
  anvandare_id uuid not null,
  roll text default 'konsult'::text not null,
  namn text,
  epost text,
  aktiv boolean default true not null,
  tillagd_av uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.byra_medlemskap enable row level security;

create table public.companies (
  id uuid default gen_random_uuid() not null,
  name text not null,
  org_nr text,
  vat_nr text,
  address text,
  phone text,
  email text,
  website text,
  bankgiro text,
  plusgiro text,
  iban text,
  bic_swift text,
  payment_terms integer default 30,
  late_interest numeric(5,2) default 8.00,
  created_at timestamp with time zone default now(),
  bokforingsmetod text default 'faktura'::text,
  postnr text,
  postort text,
  sate text,
  mobil text,
  valuta text default 'SEK'::text,
  swish text,
  foretagsform text,
  momsperiod text,
  bokforing_last_tom text,
  nasta_fakturanr integer,
  faktura_text text,
  faktura_epost_text text,
  suspended boolean default true,
  settings jsonb default '{}'::jsonb not null,
  onboarded boolean default false,
  company_number bigint default nextval('company_number_seq'::regclass),
  archive_number bigint not null,
  service_state text default 'active'::text not null,
  service_reason text,
  service_note text,
  service_changed_at timestamp with time zone,
  service_changed_by uuid,
  service_state_manual boolean default false not null,
  abonnemang_status text default 'testperiod'::text not null
);

alter table public.companies enable row level security;

create table public.company_ai_features (
  company_id uuid not null,
  feature_key text not null,
  enabled boolean default true not null,
  note text,
  created_at timestamp with time zone default now() not null
);

alter table public.company_ai_features enable row level security;

create table public.company_invites (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  email text not null,
  role text default 'member'::text,
  status text default 'pending'::text,
  invited_by uuid,
  created_at timestamp with time zone default now()
);

alter table public.company_invites enable row level security;

create table public.company_lookup_cache (
  org_nr text not null,
  payload jsonb not null,
  api_version text,
  source text,
  fetched_at timestamp with time zone default now() not null
);

alter table public.company_lookup_cache enable row level security;

create table public.company_lookup_rate (
  user_id uuid not null,
  window_start timestamp with time zone default now() not null,
  count integer default 0 not null
);

alter table public.company_lookup_rate enable row level security;

create table public.company_subscriptions (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  plan_id uuid,
  status text default 'trial'::text not null,
  billing_period text default 'trial'::text not null,
  current_period_start timestamp with time zone,
  current_period_end timestamp with time zone,
  trial_ends_at timestamp with time zone,
  cancelled_at timestamp with time zone,
  suspended_at timestamp with time zone,
  payment_provider text,
  payment_customer_id text,
  payment_subscription_id text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  payment_price_id text,
  payment_checkout_session_id text,
  payment_status text,
  last_payment_at timestamp with time zone,
  next_billing_at timestamp with time zone,
  grace_until timestamp with time zone,
  cancel_at timestamp with time zone,
  last_payment_failed_at timestamp with time zone,
  next_payment_attempt_at timestamp with time zone,
  stripe_latest_invoice_id text,
  discount_percent numeric
);

alter table public.company_subscriptions enable row level security;

create table public.customers (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  name text not null,
  org_nr text,
  contact_person text,
  email text,
  phone text,
  address text,
  payment_terms integer default 30,
  is_active boolean default true,
  created_at timestamp with time zone default now(),
  kund_nr integer,
  kundtyp text default 'foretag'::text not null,
  address2 text,
  postnr text,
  ort text,
  land text,
  telefon2 text,
  webb text,
  lev_namn text,
  lev_adress text,
  lev_adress2 text,
  lev_postnr text,
  lev_ort text,
  lev_land text,
  anteckningar text,
  leveransvillkor text,
  leveranssatt text,
  valuta text default 'SEK'::text,
  var_referens text,
  er_referens text,
  vat_nummer text,
  forsaljningskonto text,
  org_nr_normalized text,
  data_source text,
  source_retrieved_at timestamp with time zone,
  source_api_version text,
  manual_fields jsonb,
  last_manual_edit_at timestamp with time zone,
  last_manual_edit_by uuid,
  faktura_installningar jsonb default '{}'::jsonb not null,
  landskod text,
  fax text,
  lev_telefon text,
  lev_telefon2 text,
  lev_fax text,
  lev_landskod text,
  sni text,
  cfar text,
  butiks_id text
);

alter table public.customers enable row level security;

create table public.deadline_regel (
  id uuid default gen_random_uuid() not null,
  uppgiftstyp text not null,
  bolagsform text,
  variant text,
  parametrar jsonb not null,
  kalla text,
  giltig_fran date default CURRENT_DATE not null,
  giltig_till date,
  uppdaterad_at timestamp with time zone default now() not null
);

alter table public.deadline_regel enable row level security;

create table public.documents (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  verifikation_id uuid,
  storage_path text,
  file_name text not null,
  mime_type text,
  file_size bigint,
  created_at timestamp with time zone default now(),
  kategori text default 'dokument'::text,
  tolkning jsonb,
  tolkad boolean default false,
  source text default 'upload'::text,
  status text default 'new'::text,
  email_from text,
  email_to text,
  email_subject text,
  email_body text,
  received_at timestamp with time zone,
  confidence numeric,
  inbound_message_id text,
  ai_status text,
  ai_attempts integer default 0 not null,
  ai_cooldown_until timestamp with time zone,
  ai_job_id uuid,
  ai_job_started_at timestamp with time zone,
  ai_last_error text,
  original_storage_path text,
  import_batch uuid,
  raderad_at timestamp with time zone
);

alter table public.documents enable row level security;

create table public.download_audit_log (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  company_id uuid,
  section text,
  kind text,
  file_count integer,
  created_at timestamp with time zone default now()
);

alter table public.download_audit_log enable row level security;

create table public.driftkomponenter (
  namn text not null,
  typ text not null,
  max_tyst_timmar integer,
  max_fel_i_rad integer default 3 not null,
  beskrivning text,
  aktiv boolean default true not null,
  senast_rapporterad_status text,
  created_at timestamp with time zone default now() not null
);

alter table public.driftkomponenter enable row level security;

create table public.employees (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  fornamn text,
  efternamn text,
  personnummer text,
  epost text,
  telefon text,
  befattning text,
  anstallningsform text default 'tillsvidare'::text not null,
  lonetyp text default 'manad'::text not null,
  manadslon numeric,
  timlon numeric,
  skattetabell integer,
  skattekolumn integer default 1,
  arbetsgivaravgift_procent numeric default 31.42 not null,
  clearingnr text,
  kontonr text,
  anstallningsdatum date,
  slutdatum date,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  created_by uuid default auth.uid(),
  namn text,
  sidoinkomst boolean default false not null,
  undanta_arbetsgivaravgift boolean default false not null,
  kommun text,
  bankkontonummer text,
  ack_bruttolon numeric default 0 not null,
  ack_prelskatt numeric default 0 not null,
  personaltyp text default 'tjansteman'::text not null
);

alter table public.employees enable row level security;

create table public.extraction_corrections (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  supplier_id uuid,
  document_id uuid,
  field text not null,
  original_value text,
  final_value text,
  confidence_before numeric,
  doc_type text,
  model text,
  prompt_version text,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

alter table public.extraction_corrections enable row level security;

create table public.fiscal_years (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  year integer not null,
  start_date date not null,
  end_date date not null,
  status text default 'active'::text,
  created_at timestamp with time zone default now()
);

alter table public.fiscal_years enable row level security;

create table public.help_feedback (
  id uuid default gen_random_uuid() not null,
  created_at timestamp with time zone default now() not null,
  article_id text,
  article_slug text,
  user_id uuid default auth.uid(),
  company_id uuid,
  answer text,
  comment text
);

alter table public.help_feedback enable row level security;

create table public.inbound_email_log (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  recipient text,
  sender text,
  subject text,
  status text not null,
  detail text,
  attachment_count integer default 0,
  created_at timestamp with time zone default now(),
  message_id text
);

alter table public.inbound_email_log enable row level security;

create table public.inbox_addresses (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  inbox_type text not null,
  email_address text not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.inbox_addresses enable row level security;

create table public.ink2_deklarationstidpunkt (
  id uuid default gen_random_uuid() not null,
  bokslutsar integer not null,
  bokslutsmanad_fran integer not null,
  bokslutsmanad_till integer not null,
  deadline date not null,
  kalla text
);

alter table public.ink2_deklarationstidpunkt enable row level security;

create table public.inkommande_gods (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  godsnr integer not null,
  order_id uuid,
  foljesedel text,
  datum date default CURRENT_DATE not null,
  anteckning text,
  status text default 'slutford'::text not null,
  leverans_id uuid,
  created_by uuid,
  created_at timestamp with time zone default now()
);

alter table public.inkommande_gods enable row level security;

create table public.inkopsorder_rader (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  order_id uuid not null,
  product_id uuid not null,
  antal numeric not null,
  a_pris numeric,
  mottaget numeric default 0 not null
);

alter table public.inkopsorder_rader enable row level security;

create table public.inkopsordrar (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  ordernr integer not null,
  supplier_id uuid,
  intern_referens text,
  best_datum date default CURRENT_DATE not null,
  lev_datum date,
  anteckning text,
  status text default 'ej_skickad'::text not null,
  skickad_at timestamp with time zone,
  created_by uuid,
  created_at timestamp with time zone default now()
);

alter table public.inkopsordrar enable row level security;

create table public.interna_nycklar (
  namn text not null,
  varde text not null,
  created_at timestamp with time zone default now() not null
);

alter table public.interna_nycklar enable row level security;

create table public.invoice_rows (
  id uuid default gen_random_uuid() not null,
  invoice_id uuid,
  description text not null,
  quantity numeric(10,2) default 1,
  unit_price numeric(15,2) default 0,
  vat_rate numeric(5,2) default 25,
  total numeric(15,2) default 0,
  sort_order integer default 0,
  product_id uuid
);

alter table public.invoice_rows enable row level security;

create table public.invoices (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  customer_id uuid,
  invoice_nr text not null,
  invoice_date date not null,
  due_date date not null,
  amount_excl_vat numeric(15,2) default 0,
  vat_amount numeric(15,2) default 0,
  total_amount numeric(15,2) default 0,
  status text default 'draft'::text,
  message text default ''::text,
  created_at timestamp with time zone default now(),
  verifikation_id uuid,
  leverans_datum date,
  typ text default 'faktura'::text not null,
  krediterar_id uuid,
  omvand_moms boolean default false not null,
  betalning_ver_id uuid
);

alter table public.invoices enable row level security;

create table public.kivra_utskick (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  typ text not null,
  referens_id uuid not null,
  mottagare text,
  amne text,
  lage text not null,
  kivra_content_key text,
  status text default 'skickad'::text not null,
  fel text,
  skickad_av uuid,
  skickad_at timestamp with time zone default now() not null
);

alter table public.kivra_utskick enable row level security;

create table public.konsol_abonnemangsfakturor (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  fakturadatum date not null,
  forfallodatum date not null,
  belopp_ore integer not null,
  status text default 'fakturerad'::text not null,
  betald_datum date,
  skapad_av_email text not null,
  created_at timestamp with time zone default now() not null
);

alter table public.konsol_abonnemangsfakturor enable row level security;

create table public.konsol_arenden (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  rubrik text not null,
  beskrivning text,
  status text default 'oppen'::text not null,
  prioritet text default 'normal'::text not null,
  skapad_av_email text not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.konsol_arenden enable row level security;

create table public.konsol_audit_logg (
  id uuid default gen_random_uuid() not null,
  admin_user_id uuid not null,
  admin_email text not null,
  action text not null,
  company_id uuid,
  params jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.konsol_audit_logg enable row level security;

create table public.konsol_kundanteckningar (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  typ text default 'allmant'::text not null,
  innehall text not null,
  skapad_av_user_id uuid not null,
  skapad_av_email text not null,
  created_at timestamp with time zone default now() not null
);

alter table public.konsol_kundanteckningar enable row level security;

create table public.konsol_kundprofiler (
  company_id uuid not null,
  kundtyp text default 'foretag'::text not null,
  prisplan text default 'start'::text not null,
  manadspris_ore integer default 4900 not null,
  ansvarig text,
  uppfoljning_datum date,
  updated_at timestamp with time zone default now() not null,
  updated_by_email text not null,
  testperiod_manader integer default 1 not null,
  rabatt_procent integer default 0 not null,
  rabatt_tom date
);

alter table public.konsol_kundprofiler enable row level security;

create table public.konsol_livscykel_steg (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  steg_key text not null,
  status text default 'ej_paborjad'::text not null,
  notering text,
  uppdaterad_av_email text not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.konsol_livscykel_steg enable row level security;

create table public.konsol_support_samtycken (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  beviljad_av_user_id uuid not null,
  beviljad_av_email text not null,
  giltig_till timestamp with time zone not null,
  aterkallad_at timestamp with time zone,
  created_at timestamp with time zone default now() not null
);

alter table public.konsol_support_samtycken enable row level security;

create table public.kyc_arkiv (
  id uuid default gen_random_uuid() not null,
  bolag_id_ursprung uuid not null,
  bolag_namn text not null,
  org_nr text,
  byra_bolag_ids uuid[] default '{}'::uuid[] not null,
  affarsforbindelse_avslutad_at timestamp with time zone default now() not null,
  bevaras_till date not null,
  avvecklad_av uuid,
  orsak text,
  kyc_assessments jsonb not null,
  kyc_huvudman jsonb default '[]'::jsonb not null,
  kyc_bilagor jsonb default '[]'::jsonb not null,
  aml_flags jsonb default '[]'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.kyc_arkiv enable row level security;

create table public.kyc_assessments (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  status text default 'ej_paborjad'::text not null,
  riskklass text,
  identitet_kontrollerad_at timestamp with time zone,
  verklig_huvudman_kontrollerad_at timestamp with time zone,
  pep_kontrollerad_at timestamp with time zone,
  pep_traff boolean,
  sanktion_kontrollerad_at timestamp with time zone,
  sanktion_traff boolean,
  syfte_och_art text,
  anteckningar text,
  giltig_till date,
  granskad_av uuid,
  beslutad_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  identitetshandling_typ text,
  identitetshandling_referens text,
  identitetshandling_utfardare text,
  identitetshandling_giltig_till date,
  sanktionslista_kalla text,
  sanktionslista_datum date,
  pep_kalla text,
  pep_datum date
);

alter table public.kyc_assessments enable row level security;

create table public.kyc_bilagor (
  id uuid default gen_random_uuid() not null,
  kyc_id uuid not null,
  company_id uuid not null,
  typ text not null,
  storage_path text not null,
  file_name text not null,
  mime_type text,
  file_size bigint,
  beskrivning text,
  uppladdad_av uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

alter table public.kyc_bilagor enable row level security;

create table public.kyc_huvudman (
  id uuid default gen_random_uuid() not null,
  kyc_id uuid not null,
  company_id uuid not null,
  namn text not null,
  personnummer text,
  fodelsedatum date,
  agarandel numeric(5,2),
  kontrollsatt text not null,
  kalla text,
  kontrollerad_at timestamp with time zone default now() not null,
  kontrollerad_av uuid default auth.uid(),
  created_at timestamp with time zone default now() not null
);

alter table public.kyc_huvudman enable row level security;

create table public.lager_handelser (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  product_id uuid not null,
  typ text not null,
  antal numeric not null,
  a_pris numeric,
  datum date default CURRENT_DATE not null,
  kommentar text,
  invoice_id uuid,
  supplier_invoice_id uuid,
  created_by uuid,
  created_at timestamp with time zone default now(),
  leverans_id uuid,
  inventering_id uuid,
  batchnr text
);

alter table public.lager_handelser enable row level security;

create table public.lager_inventering_rader (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  inventering_id uuid not null,
  product_id uuid not null,
  raknat numeric,
  saldo_vid_rakning numeric,
  a_pris numeric,
  varde numeric
);

alter table public.lager_inventering_rader enable row level security;

create table public.lager_inventeringar (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  nr integer not null,
  datum date default CURRENT_DATE not null,
  benamning text not null,
  ansvarig text,
  status text default 'under_planering'::text not null,
  created_by uuid,
  created_at timestamp with time zone default now(),
  forsakran_namn text,
  forsakran_user_id uuid,
  forsakran_at timestamp with time zone,
  totalt_varde numeric
);

alter table public.lager_inventeringar enable row level security;

create table public.lager_leveranser (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  typ text not null,
  leveransnr integer not null,
  datum date default CURRENT_DATE not null,
  anteckning text,
  status text default 'klar'::text not null,
  created_by uuid,
  created_at timestamp with time zone default now()
);

alter table public.lager_leveranser enable row level security;

create table public.lonebesked (
  id uuid default gen_random_uuid() not null,
  run_id uuid not null,
  company_id uuid not null,
  employee_id uuid,
  namn text not null,
  personnummer text,
  bruttolon numeric default 0 not null,
  tillagg jsonb default '[]'::jsonb not null,
  skatteavdrag numeric default 0 not null,
  ag_avgift numeric default 0 not null,
  ag_procent numeric,
  nettolon numeric default 0 not null,
  skattetabell integer,
  skattekolumn integer,
  sidoinkomst boolean default false not null,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null
);

alter table public.lonebesked enable row level security;

create table public.lonekorningar (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  period text not null,
  utbetalningsdag date not null,
  beskrivning text,
  status text default 'utkast'::text not null,
  bokford boolean default false not null,
  verifikation_id uuid,
  created_at timestamp with time zone default now() not null,
  created_by uuid default auth.uid()
);

alter table public.lonekorningar enable row level security;

create table public.mcp_audit_log (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  company_id uuid,
  tool text not null,
  params jsonb default '{}'::jsonb not null,
  status text not null,
  error text,
  created_at timestamp with time zone default now() not null
);

alter table public.mcp_audit_log enable row level security;

create table public.mcp_confirm_tokens (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  company_id uuid not null,
  tool text not null,
  payload jsonb not null,
  idempotency_key text,
  verifikation_id uuid,
  created_at timestamp with time zone default now() not null,
  expires_at timestamp with time zone not null,
  used_at timestamp with time zone
);

alter table public.mcp_confirm_tokens enable row level security;

create table public.monthly_control_comments (
  id uuid default gen_random_uuid() not null,
  item_id uuid not null,
  company_id uuid not null,
  user_id uuid,
  body text not null,
  created_at timestamp with time zone default now() not null
);

alter table public.monthly_control_comments enable row level security;

create table public.monthly_control_events (
  id uuid default gen_random_uuid() not null,
  monthly_control_id uuid,
  item_id uuid,
  company_id uuid not null,
  user_id uuid,
  event_type text not null,
  detail jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.monthly_control_events enable row level security;

create table public.monthly_control_items (
  id uuid default gen_random_uuid() not null,
  monthly_control_id uuid not null,
  company_id uuid not null,
  module text not null,
  related_type text,
  related_id uuid,
  title text not null,
  description text,
  priority text default 'normal'::text not null,
  status text default 'open'::text not null,
  assigned_to uuid,
  due_date date,
  suggested_action text,
  action_url text,
  rule_key text not null,
  source_data jsonb default '{}'::jsonb not null,
  ignored_reason text,
  resolved_by uuid,
  resolved_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.monthly_control_items enable row level security;

create table public.monthly_controls (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  year integer not null,
  month integer not null,
  status text default 'not_started'::text not null,
  progress_percent integer default 0 not null,
  critical_count integer default 0 not null,
  high_count integer default 0 not null,
  normal_count integer default 0 not null,
  low_count integer default 0 not null,
  resolved_count integer default 0 not null,
  last_run_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  closed_at timestamp with time zone
);

alter table public.monthly_controls enable row level security;

create table public.notification_deliveries (
  id uuid default gen_random_uuid() not null,
  queue_id uuid,
  channel text,
  provider text,
  provider_message_id text,
  status text,
  delivered_at timestamp with time zone,
  opened_at timestamp with time zone,
  clicked_at timestamp with time zone,
  failed_at timestamp with time zone,
  failure_reason text,
  last_attempt_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

alter table public.notification_deliveries enable row level security;

create table public.notification_events (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  event_type text not null,
  payload jsonb default '{}'::jsonb not null,
  actor_user_id uuid,
  object_type text,
  object_id uuid,
  created_at timestamp with time zone default now(),
  dedupe_key text,
  acknowledged_at timestamp with time zone,
  acknowledged_by uuid
);

alter table public.notification_events enable row level security;

create table public.notification_preferences (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  company_id uuid,
  event_type text not null,
  channel text not null,
  enabled boolean default true not null,
  updated_at timestamp with time zone default now()
);

alter table public.notification_preferences enable row level security;

create table public.notification_provider_logs (
  id uuid default gen_random_uuid() not null,
  queue_id uuid,
  provider text,
  channel text,
  status text,
  meta jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now()
);

alter table public.notification_provider_logs enable row level security;

create table public.notification_queue (
  id uuid default gen_random_uuid() not null,
  event_id uuid,
  company_id uuid,
  user_id uuid,
  channel text not null,
  priority text default 'normal'::text not null,
  status text default 'pending'::text not null,
  subject text,
  body text,
  link_url text,
  object_type text,
  object_id uuid,
  scheduled_at timestamp with time zone default now(),
  attempt_count integer default 0 not null,
  max_attempts integer default 5 not null,
  next_retry_at timestamp with time zone,
  idempotency_key text,
  read_at timestamp with time zone,
  error_message text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.notification_queue enable row level security;

create table public.notification_subscriptions (
  id uuid default gen_random_uuid() not null,
  user_id uuid not null,
  channel text not null,
  endpoint text,
  p256dh text,
  auth text,
  phone text,
  opt_in boolean default false not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now()
);

alter table public.notification_subscriptions enable row level security;

create table public.notification_templates (
  id uuid default gen_random_uuid() not null,
  event_type text not null,
  channel text not null,
  lang text default 'sv-SE'::text not null,
  subject text,
  body text not null,
  required_vars text[] default '{}'::text[] not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now()
);

alter table public.notification_templates enable row level security;

create table public.ocr_provider_config (
  id boolean default true not null,
  folio_enabled boolean default false not null,
  folio_base_url text,
  updated_at timestamp with time zone default now(),
  updated_by uuid
);

alter table public.ocr_provider_config enable row level security;

create table public.platform_admins (
  email text not null,
  created_at timestamp with time zone default now()
);

alter table public.platform_admins enable row level security;

create table public.platform_audit_log (
  id uuid default gen_random_uuid() not null,
  actor_email text,
  actor_id uuid,
  action text not null,
  target text,
  detail jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.platform_audit_log enable row level security;

create table public.platform_user_roles (
  id uuid default gen_random_uuid() not null,
  email text not null,
  role text not null,
  granted_by uuid,
  granted_at timestamp with time zone default now() not null
);

alter table public.platform_user_roles enable row level security;

create table public.products (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  article_nr text,
  name text not null,
  type text default 'service'::text,
  unit text default 'st'::text,
  unit_price numeric(15,2) default 0,
  vat_rate numeric(5,2) default 25,
  account_nr text default '3010'::text,
  is_active boolean default true,
  created_at timestamp with time zone default now(),
  lagervara boolean default false not null,
  inkopspris numeric,
  bestallningspunkt numeric,
  lagerplats text
);

alter table public.products enable row level security;

create table public.robo_bp_audit_log (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  user_id uuid default auth.uid(),
  action text not null,
  detail jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now() not null
);

alter table public.robo_bp_audit_log enable row level security;

create table public.robo_bp_checks (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  source text default 'robo_bp'::text not null,
  view text,
  fiscal_year_id uuid,
  title text not null,
  description text,
  risk_level text default 'medium'::text not null,
  affected_objects jsonb default '[]'::jsonb not null,
  status text default 'open'::text not null,
  conversation_id uuid,
  created_by uuid default auth.uid(),
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  decision_basis text,
  confidence_label text
);

alter table public.robo_bp_checks enable row level security;

create table public.robo_bp_control_runs (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  fiscal_year_id uuid,
  started_by uuid default auth.uid(),
  started_at timestamp with time zone default now() not null,
  status text default 'done'::text not null,
  summary jsonb default '{}'::jsonb not null
);

alter table public.robo_bp_control_runs enable row level security;

create table public.robo_bp_conversations (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  fiscal_year_id uuid,
  user_id uuid default auth.uid() not null,
  title text,
  context_view text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.robo_bp_conversations enable row level security;

create table public.robo_bp_messages (
  id uuid default gen_random_uuid() not null,
  conversation_id uuid not null,
  company_id uuid not null,
  user_id uuid,
  role text not null,
  content text default ''::text not null,
  structured jsonb,
  basis text[],
  risk_level text,
  created_at timestamp with time zone default now() not null
);

alter table public.robo_bp_messages enable row level security;

create table public.robo_bp_rules (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  counterparty text not null,
  org_nr text,
  suggested_account text,
  vat_handling text,
  confidence numeric default 0 not null,
  source text default 'historik'::text not null,
  created_by uuid,
  approved_by uuid,
  created_at timestamp with time zone default now() not null,
  last_used_at timestamp with time zone,
  success_count integer default 0 not null,
  active boolean default true not null
);

alter table public.robo_bp_rules enable row level security;

create table public.robo_bp_settings (
  company_id uuid not null,
  sensitivity text default 'standard'::text not null,
  categories jsonb default '["saknade_underlag", "balansrakning", "skulder", "fordringar"]'::jsonb not null,
  moms_period text,
  updated_by uuid,
  updated_at timestamp with time zone default now() not null
);

alter table public.robo_bp_settings enable row level security;

create table public.salaries (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  employee_name text not null,
  personal_nr text,
  period text not null,
  gross_salary numeric(15,2) default 0,
  tax_deduction numeric(15,2) default 0,
  net_salary numeric(15,2) default 0,
  employer_fee numeric(15,2) default 0,
  status text default 'draft'::text,
  created_at timestamp with time zone default now()
);

alter table public.salaries enable row level security;

create table public.sie_imports (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  file_name text default ''::text not null,
  encoding text,
  accounts_created integer default 0 not null,
  ver_count integer default 0 not null,
  status text default 'imported'::text not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  reverted_at timestamp with time zone,
  reverted_by uuid
);

alter table public.sie_imports enable row level security;

create table public.skattekonto_regler (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  matchtext text not null,
  motkonto text not null,
  aktiv boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

alter table public.skattekonto_regler enable row level security;

create table public.stripe_event_log (
  event_id text not null,
  type text,
  created_at timestamp with time zone default now() not null
);

alter table public.stripe_event_log enable row level security;

create table public.subscription_plans (
  id uuid default gen_random_uuid() not null,
  name text not null,
  description text,
  monthly_price numeric(12,2) default 0 not null,
  yearly_price numeric(12,2) default 0 not null,
  currency text default 'SEK'::text not null,
  max_users integer,
  max_companies integer,
  max_invoices_per_month integer,
  max_documents_per_month integer,
  max_storage_mb integer,
  max_ai_operations_per_month integer,
  support_level text,
  features jsonb default '[]'::jsonb not null,
  is_active boolean default true not null,
  sort_order integer default 0 not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  stripe_price_monthly text,
  stripe_price_yearly text,
  stripe_product_id text
);

alter table public.subscription_plans enable row level security;

create table public.supplier_accounting_rules (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  supplier_id uuid,
  supplier_name text,
  supplier_org_number text,
  document_type text,
  invoice_category text,
  line_keyword text,
  account_number text not null,
  account_name text,
  vat_account text,
  vat_rate numeric,
  allocation_pattern jsonb,
  belopp_type text default 'kostnad'::text,
  confirmation_count integer default 1 not null,
  correction_count integer default 0 not null,
  confidence_score numeric default 0.2 not null,
  status text default 'active'::text not null,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  merchant_name text
);

alter table public.supplier_accounting_rules enable row level security;

create table public.supplier_invoices (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  supplier_id uuid,
  invoice_nr text,
  invoice_date date,
  due_date date,
  amount_excl_vat numeric(15,2) default 0,
  vat_amount numeric(15,2) default 0,
  total_amount numeric(15,2) default 0,
  status text default 'unpaid'::text,
  created_at timestamp with time zone default now(),
  lopnr integer,
  ocr text,
  currency text default 'SEK'::text,
  paid_amount numeric default 0 not null,
  paid_date date,
  bokford boolean default false not null,
  makulerad boolean default false not null,
  kostnadskonto text default '4000'::text,
  verifikation_id uuid,
  betalning_ver_id uuid,
  kreditfaktura boolean default false,
  created_by uuid,
  document_id uuid,
  momstyp text default 'normal'::text not null
);

alter table public.supplier_invoices enable row level security;

create table public.suppliers (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  name text not null,
  org_nr text,
  category text,
  bankgiro text,
  email text,
  phone text,
  address text,
  is_active boolean default true,
  created_at timestamp with time zone default now(),
  leverantorsnr text,
  aktiv boolean default true,
  telefon2 text,
  fax text,
  webb text,
  faktura_adress text,
  faktura_adress2 text,
  postnr text,
  ort text,
  land text,
  landskod text,
  plusgiro text,
  bic text,
  iban text,
  kontotyp text,
  bank text,
  clearingnr text,
  kontonr text,
  avgiftskod text,
  betalkod text,
  inaktivera_betalfil boolean default false,
  default_motkonto text,
  konteringsmall text,
  artikelregistrering boolean default false,
  oresavrundning boolean default true,
  momstyp text,
  vat_nummer text,
  valuta text default 'SEK'::text,
  betalningsvillkor text,
  kundnummer text,
  cfar text,
  sni text,
  referens text,
  anteckning text
);

alter table public.suppliers enable row level security;

create table public.support_ai_events (
  id uuid default gen_random_uuid() not null,
  created_at timestamp with time zone default now() not null,
  company_id uuid,
  user_id uuid,
  question text,
  answer text,
  in_scope boolean,
  escalated boolean default false not null,
  route text,
  model text
);

alter table public.support_ai_events enable row level security;

create table public.support_attachments (
  id uuid default gen_random_uuid() not null,
  ticket_id uuid not null,
  message_id uuid,
  storage_path text,
  file_name text,
  mime_type text,
  file_size bigint,
  created_at timestamp with time zone default now() not null,
  company_id uuid,
  uploaded_by_user_id uuid,
  visibility text default 'customer_visible'::text not null,
  note_id uuid
);

alter table public.support_attachments enable row level security;

create table public.support_internal_notes (
  id uuid default gen_random_uuid() not null,
  ticket_id uuid not null,
  author_admin_id uuid,
  body text not null,
  created_at timestamp with time zone default now() not null
);

alter table public.support_internal_notes enable row level security;

create table public.support_messages (
  id uuid default gen_random_uuid() not null,
  ticket_id uuid not null,
  sender_user_id uuid,
  is_admin boolean default false not null,
  body text not null,
  created_at timestamp with time zone default now() not null
);

alter table public.support_messages enable row level security;

create table public.support_reads (
  ticket_id uuid not null,
  user_id uuid not null,
  last_read_at timestamp with time zone default now() not null
);

alter table public.support_reads enable row level security;

create table public.support_tickets (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  created_by_user_id uuid,
  assigned_admin_id uuid,
  subject text not null,
  category text default 'other'::text not null,
  priority text default 'normal'::text not null,
  status text default 'new'::text not null,
  last_message_at timestamp with time zone default now(),
  closed_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.support_tickets enable row level security;

create table public.swish_regler (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  customer_id uuid not null,
  min_belopp numeric not null,
  max_belopp numeric not null,
  motkonto text not null,
  momssats numeric default 0 not null,
  aktiv boolean default true not null,
  created_by uuid,
  created_at timestamp with time zone default now() not null
);

alter table public.swish_regler enable row level security;

create table public.system_error_log (
  id uuid default gen_random_uuid() not null,
  occurred_at timestamp with time zone default now() not null,
  component text,
  message text,
  severity text,
  error_code text,
  metadata jsonb,
  company_id uuid
);

alter table public.system_error_log enable row level security;

create table public.uppdrag (
  id uuid default gen_random_uuid() not null,
  byra_klient_id uuid not null,
  byra_bolag_id uuid not null,
  klient_bolag_id uuid not null,
  uppdragstyp text not null,
  uppdragsansvarig_anvandare_id uuid,
  bokforingstakt text,
  byraanstand_aktiv boolean default false not null,
  revisionsplikt boolean default false not null,
  startdatum date default CURRENT_DATE not null,
  status text default 'aktiv'::text not null,
  skapad_av uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.uppdrag enable row level security;

create table public.uppdragsuppgift (
  id uuid default gen_random_uuid() not null,
  uppdrag_id uuid not null,
  byra_bolag_id uuid not null,
  klient_bolag_id uuid not null,
  uppdragsansvarig_anvandare_id uuid,
  period_start date not null,
  period_slut date not null,
  etikett text not null,
  ordinarie_forfallodatum date,
  revisionsstart_datum date,
  justerat_forfallodatum date,
  justering_anledning text,
  justerad_av uuid,
  justerad_at timestamp with time zone,
  status text default 'ej_paborjad'::text not null,
  klarmarkerad_av uuid,
  klarmarkerad_at timestamp with time zone,
  kommentar text,
  kopplat_underlag_id uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.uppdragsuppgift enable row level security;

create table public.user_companies (
  id uuid default gen_random_uuid() not null,
  user_id uuid,
  company_id uuid,
  role text default 'member'::text,
  created_at timestamp with time zone default now(),
  email text,
  moduler text[]
);

alter table public.user_companies enable row level security;

create table public.vat_reports (
  id uuid default gen_random_uuid() not null,
  company_id uuid not null,
  year integer not null,
  month integer not null,
  period_start date,
  period_end date,
  status text default 'submitted'::text not null,
  utgaende_moms numeric default 0 not null,
  ingaende_moms numeric default 0 not null,
  moms_att_betala numeric default 0 not null,
  difference numeric default 0 not null,
  verifikation_id uuid,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

alter table public.vat_reports enable row level security;

create table public.verifikation_andringar (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  original_id uuid,
  rattelse_id uuid,
  orsak text not null,
  utford_av_epost text,
  skapad timestamp with time zone default now()
);

alter table public.verifikation_andringar enable row level security;

create table public.verifikation_rows (
  id uuid default gen_random_uuid() not null,
  verifikation_id uuid,
  account_nr text not null,
  account_name text default ''::text,
  debet numeric(15,2) default 0,
  kredit numeric(15,2) default 0,
  transaction_info text default ''::text,
  sort_order integer default 0,
  avstamd boolean default false
);

alter table public.verifikation_rows enable row level security;

create table public.verifikationer (
  id uuid default gen_random_uuid() not null,
  company_id uuid,
  ver_nr text not null,
  ver_serie text default 'A'::text,
  datum date not null,
  beskrivning text not null,
  total_debet numeric(15,2) not null,
  total_kredit numeric(15,2) not null,
  is_locked boolean default true,
  created_by uuid,
  created_at timestamp with time zone default now(),
  kommentar text,
  status text default 'aktiv'::text not null,
  makulerad_av uuid,
  motverkar uuid,
  rattad_av uuid,
  rattar uuid,
  ersatter uuid,
  sie_import_id uuid,
  motpart text
);

alter table public.verifikationer enable row level security;

create table public.worker_health (
  component text not null,
  last_success_at timestamp with time zone,
  last_failure_at timestamp with time zone,
  consecutive_failures integer default 0 not null,
  last_error text,
  updated_at timestamp with time zone default now() not null
);

alter table public.worker_health enable row level security;
