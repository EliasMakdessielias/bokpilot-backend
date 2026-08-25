create policy "aib_insert" on public.account_import_batches for insert to public with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "aib_select" on public.account_import_batches for select to public using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "accounts_policy" on public.accounts for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "agi_deklarationer_policy" on public.agi_deklarationer for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ai_bokforing_logg_policy" on public.ai_bokforing_logg for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ai_checklista_korningar_policy" on public.ai_checklista_korningar for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ai_error_log_select" on public.ai_error_log for select to public using ((company_id IN ( SELECT user_companies.company_id
   FROM user_companies
  WHERE (user_companies.user_id = ( SELECT auth.uid() AS uid)))));
create policy "aiu_select" on public.ai_usage_log for select to authenticated using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR can_manage_billing()));
create policy "aml_insert_byra" on public.aml_flags for insert to authenticated with check ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag)));
create policy "aml_select_byra" on public.aml_flags for select to authenticated using ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag)));
create policy "aml_update_byra" on public.aml_flags for update to authenticated using ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag))) with check ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag)));
create policy "aml_install_insert_byra" on public.aml_installningar for insert to authenticated with check ((byra_bolag_id IN ( SELECT mina_byraer() AS mina_byraer)));
create policy "aml_install_select_byra" on public.aml_installningar for select to authenticated using ((byra_bolag_id IN ( SELECT mina_byraer() AS mina_byraer)));
create policy "aml_install_update_byra" on public.aml_installningar for update to authenticated using ((byra_bolag_id IN ( SELECT mina_byraer() AS mina_byraer))) with check ((byra_bolag_id IN ( SELECT mina_byraer() AS mina_byraer)));
create policy "annual_report_sections_select" on public.annual_report_draft_sections for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "annual_report_drafts_select" on public.annual_report_drafts for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ar_exports_select" on public.annual_report_exports for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ar_validation_select" on public.annual_report_validation_items for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "arkiv_filer_delete" on public.arkiv_filer for delete to authenticated using ((EXISTS ( SELECT 1
   FROM arkiv_mappar m
  WHERE ((m.id = arkiv_filer.mapp_id) AND (m.company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ((m.synlighet <> 'byra'::text) OR ar_arkiv_forvaltare(m.company_id)) AND (ar_arkiv_forvaltare(m.company_id) OR (arkiv_filer.uppladdad_av = ( SELECT auth.uid() AS uid)))))));
create policy "arkiv_filer_insert" on public.arkiv_filer for insert to authenticated with check (((EXISTS ( SELECT 1
   FROM arkiv_mappar m
  WHERE ((m.id = arkiv_filer.mapp_id) AND (m.company_id = arkiv_filer.company_id) AND (m.company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND (ar_arkiv_forvaltare(m.company_id) OR (m.synlighet = 'kund_skriv'::text))))) AND ((document_id IS NULL) OR (EXISTS ( SELECT 1
   FROM documents d
  WHERE ((d.id = arkiv_filer.document_id) AND (d.company_id = arkiv_filer.company_id)))))));
create policy "arkiv_filer_select" on public.arkiv_filer for select to authenticated using ((EXISTS ( SELECT 1
   FROM arkiv_mappar m
  WHERE ((m.id = arkiv_filer.mapp_id) AND (m.company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ((m.synlighet <> 'byra'::text) OR ar_arkiv_forvaltare(m.company_id))))));
create policy "arkiv_filer_update" on public.arkiv_filer for update to authenticated using ((EXISTS ( SELECT 1
   FROM arkiv_mappar m
  WHERE ((m.id = arkiv_filer.mapp_id) AND (m.company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ((m.synlighet <> 'byra'::text) OR ar_arkiv_forvaltare(m.company_id)) AND (ar_arkiv_forvaltare(m.company_id) OR (arkiv_filer.uppladdad_av = ( SELECT auth.uid() AS uid))))))) with check (((EXISTS ( SELECT 1
   FROM arkiv_mappar m
  WHERE ((m.id = arkiv_filer.mapp_id) AND (m.company_id = arkiv_filer.company_id) AND (m.company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND (ar_arkiv_forvaltare(m.company_id) OR (m.synlighet = 'kund_skriv'::text))))) AND ((document_id IS NULL) OR (EXISTS ( SELECT 1
   FROM documents d
  WHERE ((d.id = arkiv_filer.document_id) AND (d.company_id = arkiv_filer.company_id)))))));
create policy "arkiv_mappar_delete" on public.arkiv_mappar for delete to authenticated using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ar_arkiv_forvaltare(company_id)));
create policy "arkiv_mappar_insert" on public.arkiv_mappar for insert to authenticated with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ar_arkiv_forvaltare(company_id)));
create policy "arkiv_mappar_select" on public.arkiv_mappar for select to authenticated using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ((synlighet <> 'byra'::text) OR ar_arkiv_forvaltare(company_id))));
create policy "arkiv_mappar_update" on public.arkiv_mappar for update to authenticated using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ar_arkiv_forvaltare(company_id))) with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND ar_arkiv_forvaltare(company_id)));
create policy "at_all" on public.article_templates for all to public using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin())) with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "assistent_logg_select" on public.assistent_logg for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "audit_insert" on public.audit_log for insert to public with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "audit_select" on public.audit_log for select to public using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "bank_accounts_policy" on public.bank_accounts for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "bank_transactions_policy" on public.bank_transactions for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "Egen ansökan kan läsas" on public.beta_ansokningar for select to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "Egen ansökan kan skapas" on public.beta_ansokningar for insert to authenticated with check (((user_id = ( SELECT auth.uid() AS uid)) AND (epost = COALESCE((( SELECT auth.jwt() AS jwt) ->> 'email'::text), ''::text)) AND (status = 'vantar'::text)));
create policy "bokslut_ai_suggestions_select" on public.bokslut_ai_suggestions for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "bokslut_attachments_select" on public.bokslut_attachments for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "bokslut_audit_select" on public.bokslut_audit_log for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "bokslut_checks_select" on public.bokslut_checks for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "bokslut_denied_log_select" on public.bokslut_denied_log for select to public using (is_platform_admin());
create policy "bokslut_eng_select" on public.bokslut_engagements for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "bt_all" on public.bookkeeping_templates for all to public using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin())) with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "byra_installningar_insert" on public.byra_installningar for insert to public with check (ar_byra_admin(byra_bolag_id));
create policy "byra_installningar_select" on public.byra_installningar for select to public using ((byra_bolag_id IN ( SELECT min_byra_ids() AS min_byra_ids)));
create policy "byra_installningar_update" on public.byra_installningar for update to public using (ar_byra_admin(byra_bolag_id));
create policy "byra_klient_insert" on public.byra_klient for insert to authenticated with check (ar_byra_admin(byra_bolag_id));
create policy "byra_klient_select" on public.byra_klient for select to authenticated using (((byra_bolag_id IN ( SELECT min_byra_ids() AS min_byra_ids)) AND (ar_byra_admin(byra_bolag_id) OR (kundansvarig_anvandare_id = ( SELECT auth.uid() AS uid)))));
create policy "byra_klient_update" on public.byra_klient for update to authenticated using (ar_byra_admin(byra_bolag_id));
create policy "byra_medlemmar_select" on public.byra_medlemmar for select to authenticated using (ar_byra_medlem());
create policy "byra_medlemskap_insert" on public.byra_medlemskap for insert to authenticated with check (ar_byra_admin(byra_bolag_id));
create policy "byra_medlemskap_select" on public.byra_medlemskap for select to authenticated using ((byra_bolag_id IN ( SELECT min_byra_ids() AS min_byra_ids)));
create policy "byra_medlemskap_update" on public.byra_medlemskap for update to authenticated using (ar_byra_admin(byra_bolag_id));
create policy "companies_admin_all" on public.companies for all to public using (is_platform_admin()) with check (is_platform_admin());
create policy "companies_byra_select" on public.companies for select to public using ((id IN ( SELECT byra_synliga_bolag_ids() AS byra_synliga_bolag_ids)));
create policy "companies_insert" on public.companies for insert to public with check (((( SELECT auth.uid() AS uid) IS NOT NULL) AND ((COALESCE(suspended, true) = true) OR is_platform_admin() OR COALESCE((((( SELECT auth.jwt() AS jwt) -> 'app_metadata'::text) ->> 'approved'::text))::boolean, false))));
create policy "users_own_companies" on public.companies for all to public using ((id IN ( SELECT user_companies.company_id
   FROM user_companies
  WHERE (user_companies.user_id = ( SELECT auth.uid() AS uid)))));
create policy "company_ai_features_select" on public.company_ai_features for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ci_company" on public.company_invites for all to public using (ar_bolagsadmin(company_id)) with check (ar_bolagsadmin(company_id));
create policy "ci_invitee_select" on public.company_invites for select to public using ((lower(email) = lower((( SELECT auth.jwt() AS jwt) ->> 'email'::text))));
create policy "ci_invitee_update" on public.company_invites for update to public using ((lower(email) = lower((( SELECT auth.jwt() AS jwt) ->> 'email'::text)))) with check ((lower(email) = lower((( SELECT auth.jwt() AS jwt) ->> 'email'::text))));
create policy "cs_select" on public.company_subscriptions for select to authenticated using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR can_manage_billing()));
create policy "customers_policy" on public.customers for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "deadline_regel_select" on public.deadline_regel for select to authenticated using (ar_byra_medlem());
create policy "documents_policy" on public.documents for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "dal_select" on public.download_audit_log for select to public using ((company_id IN ( SELECT user_companies.company_id
   FROM user_companies
  WHERE (user_companies.user_id = ( SELECT auth.uid() AS uid)))));
create policy "employees_policy" on public.employees for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "extraction_corrections_policy" on public.extraction_corrections for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "fiscal_years_policy" on public.fiscal_years for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "help_feedback_insert" on public.help_feedback for insert to public with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "help_feedback_select" on public.help_feedback for select to public using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "iel_select" on public.inbound_email_log for select to public using ((((company_id IS NOT NULL) AND (company_id IN ( SELECT user_company_ids() AS user_company_ids))) OR is_platform_admin()));
create policy "ia_delete" on public.inbox_addresses for delete to public using (is_platform_admin());
create policy "ia_insert" on public.inbox_addresses for insert to public with check (is_platform_admin());
create policy "ia_select" on public.inbox_addresses for select to public using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "ia_update" on public.inbox_addresses for update to public using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin())) with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR is_platform_admin()));
create policy "ink2_tidpunkt_select" on public.ink2_deklarationstidpunkt for select to authenticated using (ar_byra_medlem());
create policy "inkommande_gods_policy" on public.inkommande_gods for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "inkopsorder_rader_policy" on public.inkopsorder_rader for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "inkopsordrar_policy" on public.inkopsordrar for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "invoice_rows_policy" on public.invoice_rows for all to public using ((invoice_id IN ( SELECT invoices.id
   FROM invoices
  WHERE (invoices.company_id IN ( SELECT user_company_ids() AS user_company_ids)))));
create policy "invoices_policy" on public.invoices for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "kivra_utskick_select" on public.kivra_utskick for select to authenticated using ((company_id IN ( SELECT user_companies.company_id
   FROM user_companies
  WHERE (user_companies.user_id = ( SELECT auth.uid() AS uid)))));
create policy "Kund kan bevilja supportsamtycke" on public.konsol_support_samtycken for insert to authenticated with check (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) AND (beviljad_av_user_id = ( SELECT auth.uid() AS uid)) AND (beviljad_av_email = COALESCE((( SELECT auth.jwt() AS jwt) ->> 'email'::text), ''::text)) AND (giltig_till > now()) AND (giltig_till <= (now() + '30 days'::interval))));
create policy "Kund kan läsa egna supportsamtycken" on public.konsol_support_samtycken for select to authenticated using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "Kund kan återkalla supportsamtycke" on public.konsol_support_samtycken for update to authenticated using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "kyc_insert_byra" on public.kyc_assessments for insert to authenticated with check ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag)));
create policy "kyc_select_byra" on public.kyc_assessments for select to authenticated using ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag)));
create policy "kyc_update_byra" on public.kyc_assessments for update to authenticated using ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag))) with check ((company_id IN ( SELECT mina_klientbolag() AS mina_klientbolag)));
create policy "lager_handelser_policy" on public.lager_handelser for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "lager_inventering_rader_policy" on public.lager_inventering_rader for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "lager_inventeringar_policy" on public.lager_inventeringar for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "lager_leveranser_policy" on public.lager_leveranser for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "lonebesked_policy" on public.lonebesked for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "lonekorningar_policy" on public.lonekorningar for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "mcp_audit_insert_own" on public.mcp_audit_log for insert to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "mcp_audit_select" on public.mcp_audit_log for select to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) OR (company_id IN ( SELECT user_company_ids() AS user_company_ids))));
create policy "mcp_tokens_insert_own" on public.mcp_confirm_tokens for insert to authenticated with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "mcp_tokens_select_own" on public.mcp_confirm_tokens for select to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "mcp_tokens_update_own" on public.mcp_confirm_tokens for update to authenticated using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "mcc_select" on public.monthly_control_comments for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "mce_select" on public.monthly_control_events for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "mci_select" on public.monthly_control_items for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "mc_select" on public.monthly_controls for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "ndel_read" on public.notification_deliveries for select to authenticated using (can_view_operations());
create policy "nev_read" on public.notification_events for select to authenticated using (((company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR can_view_operations()));
create policy "npref_all" on public.notification_preferences for all to public using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "nplog_read" on public.notification_provider_logs for select to authenticated using (can_view_operations());
create policy "nq_select" on public.notification_queue for select to authenticated using (((user_id = ( SELECT auth.uid() AS uid)) OR can_view_operations()));
create policy "nq_update" on public.notification_queue for update to public using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "nsub_all" on public.notification_subscriptions for all to public using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "ntmpl_admin" on public.notification_templates for all to public using (is_platform_admin()) with check (is_platform_admin());
create policy "ntmpl_read" on public.notification_templates for select to public using ((( SELECT auth.role() AS role) = 'authenticated'::text));
create policy "pa_self" on public.platform_admins for select to public using ((lower(email) = lower((( SELECT auth.jwt() AS jwt) ->> 'email'::text))));
create policy "pal_read" on public.platform_audit_log for select to authenticated using (can_view_operations());
create policy "pur_read" on public.platform_user_roles for select to authenticated using (is_superadmin());
create policy "products_policy" on public.products for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_audit_select" on public.robo_bp_audit_log for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_checks_select" on public.robo_bp_checks for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_bp_control_runs_sel" on public.robo_bp_control_runs for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_conv_select" on public.robo_bp_conversations for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_msg_select" on public.robo_bp_messages for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_rules_select" on public.robo_bp_rules for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "robo_bp_settings_sel" on public.robo_bp_settings for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "salaries_policy" on public.salaries for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "sie_imports_insert" on public.sie_imports for insert to public with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "sie_imports_select" on public.sie_imports for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "sie_imports_update" on public.sie_imports for update to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "skattekonto_regler_delete" on public.skattekonto_regler for delete to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "skattekonto_regler_insert" on public.skattekonto_regler for insert to public with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "skattekonto_regler_select" on public.skattekonto_regler for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "skattekonto_regler_update" on public.skattekonto_regler for update to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "sp_select" on public.subscription_plans for select to authenticated using (true);
create policy "supplier_accounting_rules_policy" on public.supplier_accounting_rules for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "supplier_invoices_policy" on public.supplier_invoices for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "suppliers_policy" on public.suppliers for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "support_ai_events_select" on public.support_ai_events for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "sa_select" on public.support_attachments for select to authenticated using ((can_view_support() OR ((visibility = 'customer_visible'::text) AND (EXISTS ( SELECT 1
   FROM support_tickets t
  WHERE ((t.id = support_attachments.ticket_id) AND ((t.created_by_user_id = ( SELECT auth.uid() AS uid)) OR (t.company_id IN ( SELECT user_company_ids() AS user_company_ids)))))))));
create policy "sin_select" on public.support_internal_notes for select to authenticated using (can_view_support());
create policy "sm_select" on public.support_messages for select to authenticated using ((EXISTS ( SELECT 1
   FROM support_tickets t
  WHERE ((t.id = support_messages.ticket_id) AND ((t.created_by_user_id = ( SELECT auth.uid() AS uid)) OR (t.company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR can_view_support())))));
create policy "support_reads_insert_own" on public.support_reads for insert to public with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "support_reads_select_own" on public.support_reads for select to public using ((user_id = ( SELECT auth.uid() AS uid)));
create policy "support_reads_update_own" on public.support_reads for update to public using ((user_id = ( SELECT auth.uid() AS uid))) with check ((user_id = ( SELECT auth.uid() AS uid)));
create policy "st_select" on public.support_tickets for select to authenticated using (((created_by_user_id = ( SELECT auth.uid() AS uid)) OR (company_id IN ( SELECT user_company_ids() AS user_company_ids)) OR can_view_support()));
create policy "swish_regler_delete" on public.swish_regler for delete to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "swish_regler_insert" on public.swish_regler for insert to public with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "swish_regler_select" on public.swish_regler for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "swish_regler_update" on public.swish_regler for update to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "uppdrag_insert" on public.uppdrag for insert to authenticated with check (ar_byra_admin(byra_bolag_id));
create policy "uppdrag_select" on public.uppdrag for select to authenticated using (((byra_bolag_id IN ( SELECT min_byra_ids() AS min_byra_ids)) AND (ar_byra_admin(byra_bolag_id) OR (uppdragsansvarig_anvandare_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM byra_klient bk
  WHERE ((bk.id = uppdrag.byra_klient_id) AND (bk.kundansvarig_anvandare_id = ( SELECT auth.uid() AS uid))))))));
create policy "uppdrag_update" on public.uppdrag for update to authenticated using (ar_byra_admin(byra_bolag_id));
create policy "uppgift_select" on public.uppdragsuppgift for select to authenticated using (((byra_bolag_id IN ( SELECT min_byra_ids() AS min_byra_ids)) AND (ar_byra_admin(byra_bolag_id) OR (uppdragsansvarig_anvandare_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM (uppdrag u
     JOIN byra_klient bk ON ((bk.id = u.byra_klient_id)))
  WHERE ((u.id = uppdragsuppgift.uppdrag_id) AND (bk.kundansvarig_anvandare_id = ( SELECT auth.uid() AS uid))))))));
create policy "uppgift_update" on public.uppdragsuppgift for update to authenticated using (((byra_bolag_id IN ( SELECT min_byra_ids() AS min_byra_ids)) AND (ar_byra_admin(byra_bolag_id) OR (uppdragsansvarig_anvandare_id = ( SELECT auth.uid() AS uid)) OR (EXISTS ( SELECT 1
   FROM (uppdrag u
     JOIN byra_klient bk ON ((bk.id = u.byra_klient_id)))
  WHERE ((u.id = uppdragsuppgift.uppdrag_id) AND (bk.kundansvarig_anvandare_id = ( SELECT auth.uid() AS uid))))))));
create policy "uc_admin_read" on public.user_companies for select to public using (is_platform_admin());
create policy "uc_delete" on public.user_companies for delete to public using (((user_id = ( SELECT auth.uid() AS uid)) OR ar_bolagsadmin(company_id)));
create policy "uc_select" on public.user_companies for select to public using (((user_id = ( SELECT auth.uid() AS uid)) OR (company_id IN ( SELECT user_company_ids() AS user_company_ids))));
create policy "vat_reports_select" on public.vat_reports for select to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "andringar_policy" on public.verifikation_andringar for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids))) with check ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "verifikation_rows_policy" on public.verifikation_rows for all to public using ((verifikation_id IN ( SELECT verifikationer.id
   FROM verifikationer
  WHERE (verifikationer.company_id IN ( SELECT user_company_ids() AS user_company_ids)))));
create policy "ver_admin_read" on public.verifikationer for select to public using (is_platform_admin());
create policy "verifikationer_policy" on public.verifikationer for all to public using ((company_id IN ( SELECT user_company_ids() AS user_company_ids)));
create policy "wh_admin_read" on public.worker_health for select to authenticated using (can_view_operations());
