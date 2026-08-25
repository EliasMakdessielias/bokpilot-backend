-- tabell: account_import_batches
CREATE TRIGGER trg_notify_import_failed AFTER INSERT OR UPDATE ON public.account_import_batches FOR EACH ROW EXECUTE FUNCTION notify_on_import_failed();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.account_import_batches FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: accounts
CREATE TRIGGER trg_accounts_audit AFTER INSERT OR DELETE OR UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION accounts_audit();
CREATE TRIGGER trg_accounts_updated BEFORE UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_protect_locked BEFORE DELETE OR UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION protect_locked_account();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.accounts FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: arkiv_filer
CREATE TRIGGER arkiv_fil_fore_insert_trg BEFORE INSERT ON public.arkiv_filer FOR EACH ROW EXECUTE FUNCTION arkiv_fil_fore_insert();
CREATE TRIGGER arkiv_fil_logga_mjukradering_trg BEFORE UPDATE ON public.arkiv_filer FOR EACH ROW EXECUTE FUNCTION arkiv_fil_logga_radering();
CREATE TRIGGER arkiv_fil_logga_radering_trg AFTER DELETE ON public.arkiv_filer FOR EACH ROW EXECUTE FUNCTION arkiv_fil_logga_radering();
CREATE TRIGGER arkiv_skydda_rakenskapsinfo_del BEFORE DELETE ON public.arkiv_filer FOR EACH ROW EXECUTE FUNCTION arkiv_skydda_rakenskapsinfo();
CREATE TRIGGER arkiv_skydda_rakenskapsinfo_upd BEFORE UPDATE ON public.arkiv_filer FOR EACH ROW EXECUTE FUNCTION arkiv_skydda_rakenskapsinfo();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.arkiv_filer FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: arkiv_mappar
CREATE TRIGGER arkiv_mapp_fore_radering_trg BEFORE DELETE ON public.arkiv_mappar FOR EACH ROW EXECUTE FUNCTION arkiv_mapp_fore_radering();
CREATE TRIGGER arkiv_mapp_logga_synlighet_trg AFTER UPDATE ON public.arkiv_mappar FOR EACH ROW EXECUTE FUNCTION arkiv_mapp_logga_synlighet();
CREATE TRIGGER arkiv_mapp_skydda_systemmapp_trg BEFORE UPDATE ON public.arkiv_mappar FOR EACH ROW EXECUTE FUNCTION arkiv_mapp_skydda_systemmapp();
CREATE TRIGGER arkiv_mapp_validera_trg BEFORE INSERT OR UPDATE ON public.arkiv_mappar FOR EACH ROW EXECUTE FUNCTION arkiv_mapp_validera();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.arkiv_mappar FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: article_templates
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.article_templates FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: bank_accounts
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.bank_accounts FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: bank_transactions
CREATE TRIGGER trg_forbjud_banktx_delete BEFORE DELETE ON public.bank_transactions FOR EACH ROW EXECUTE FUNCTION forbjud_bokford_banktx_radering();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.bank_transactions FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: bokslut_checks
CREATE TRIGGER trg_bokslut_checks_comment_revision BEFORE UPDATE ON public.bokslut_checks FOR EACH ROW EXECUTE FUNCTION _bokslut_checks_comment_revision();
-- tabell: bookkeeping_templates
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.bookkeeping_templates FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: byra_medlemskap
CREATE TRIGGER byra_medlemskap_sista_admin BEFORE DELETE OR UPDATE ON public.byra_medlemskap FOR EACH ROW EXECUTE FUNCTION skydda_sista_byra_admin();
-- tabell: companies
CREATE TRIGGER trg_assign_archive_number BEFORE INSERT ON public.companies FOR EACH ROW EXECUTE FUNCTION assign_archive_number();
CREATE TRIGGER trg_forbjud_radera_bolag_med_rakenskapsinfo BEFORE DELETE ON public.companies FOR EACH ROW EXECUTE FUNCTION forbjud_radera_bolag_med_rakenskapsinfo();
CREATE TRIGGER trg_protect_archive_number BEFORE UPDATE ON public.companies FOR EACH ROW EXECUTE FUNCTION protect_archive_number();
CREATE TRIGGER trg_provision_inboxes AFTER INSERT ON public.companies FOR EACH ROW EXECUTE FUNCTION provision_company_inboxes();
CREATE TRIGGER trg_seed_new_company AFTER INSERT ON public.companies FOR EACH ROW EXECUTE FUNCTION seed_new_company();
-- tabell: customers
CREATE TRIGGER trg_customers_orgnr_norm BEFORE INSERT OR UPDATE OF org_nr ON public.customers FOR EACH ROW EXECUTE FUNCTION set_org_nr_normalized();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: documents
CREATE TRIGGER trg_notify_bookkeeping_suggestion AFTER UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION notify_on_bookkeeping_suggestion();
CREATE TRIGGER trg_notify_inbound_document AFTER INSERT ON public.documents FOR EACH ROW EXECUTE FUNCTION notify_on_inbound_document();
CREATE TRIGGER trg_skydda_underlag BEFORE DELETE OR UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION skydda_bokfort_underlag();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.documents FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: fiscal_years
CREATE TRIGGER trg_skydda_rakenskapsar BEFORE DELETE OR UPDATE ON public.fiscal_years FOR EACH ROW EXECUTE FUNCTION skydda_rakenskapsar();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.fiscal_years FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: inbox_addresses
CREATE TRIGGER trg_inbox_addr_guard BEFORE UPDATE ON public.inbox_addresses FOR EACH ROW EXECUTE FUNCTION inbox_addr_guard();
-- tabell: invoice_rows
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.invoice_rows FOR EACH ROW EXECUTE FUNCTION enforce_write_lock_invoice_rows();
-- tabell: invoices
CREATE TRIGGER trg_audit_customer_invoice_booked AFTER INSERT OR UPDATE OF verifikation_id ON public.invoices FOR EACH ROW EXECUTE FUNCTION audit_customer_invoice_booked();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: lager_handelser
CREATE TRIGGER trg_lager_handelser_appendonly BEFORE DELETE OR UPDATE ON public.lager_handelser FOR EACH ROW EXECUTE FUNCTION lager_handelser_appendonly();
-- tabell: lager_inventering_rader
CREATE TRIGGER trg_lager_inventering_rader_last BEFORE DELETE OR UPDATE ON public.lager_inventering_rader FOR EACH ROW EXECUTE FUNCTION lager_inventering_last();
-- tabell: lager_inventeringar
CREATE TRIGGER trg_lager_inventering_last BEFORE DELETE OR UPDATE ON public.lager_inventeringar FOR EACH ROW EXECUTE FUNCTION lager_inventering_last();
-- tabell: lonekorningar
CREATE TRIGGER trg_forbjud_bokford_lonekorning_radering BEFORE DELETE ON public.lonekorningar FOR EACH ROW EXECUTE FUNCTION forbjud_bokford_lonekorning_radering();
-- tabell: products
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: salaries
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.salaries FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: supplier_invoices
CREATE TRIGGER trg_audit_supplier_invoice_booked AFTER INSERT OR UPDATE OF bokford ON public.supplier_invoices FOR EACH ROW EXECUTE FUNCTION audit_supplier_invoice_booked();
CREATE TRIGGER trg_forbjud_andring_bokford_levfaktura BEFORE UPDATE ON public.supplier_invoices FOR EACH ROW EXECUTE FUNCTION forbjud_andring_bokford_levfaktura();
CREATE TRIGGER trg_forbjud_bokford_faktura_radering BEFORE DELETE ON public.supplier_invoices FOR EACH ROW EXECUTE FUNCTION forbjud_bokford_faktura_radering();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.supplier_invoices FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: suppliers
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.suppliers FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
-- tabell: uppdrag
CREATE TRIGGER trg_validera_uppdrag BEFORE INSERT OR UPDATE ON public.uppdrag FOR EACH ROW EXECUTE FUNCTION byrastod_validera_uppdrag();
-- tabell: uppdragsuppgift
CREATE TRIGGER trg_uppgift_fore_update BEFORE UPDATE ON public.uppdragsuppgift FOR EACH ROW EXECUTE FUNCTION byrastod_uppgift_fore_update();
-- tabell: user_companies
CREATE TRIGGER trg_forbjud_sista_admin_bort BEFORE DELETE ON public.user_companies FOR EACH ROW EXECUTE FUNCTION forbjud_sista_admin_bort();
-- tabell: verifikation_andringar
CREATE TRIGGER trg_andringar_appendonly BEFORE DELETE OR UPDATE ON public.verifikation_andringar FOR EACH ROW EXECUTE FUNCTION verifikation_andringar_appendonly();
-- tabell: verifikation_rows
CREATE TRIGGER trg_audit_ver_rows AFTER INSERT OR DELETE OR UPDATE ON public.verifikation_rows FOR EACH ROW EXECUTE FUNCTION audit_verifikation_rows();
CREATE TRIGGER trg_forbjud_ver_rows_delete BEFORE DELETE ON public.verifikation_rows FOR EACH ROW EXECUTE FUNCTION forbjud_bokford_radering();
CREATE TRIGGER trg_immutabel_ver_rows BEFORE INSERT OR UPDATE ON public.verifikation_rows FOR EACH ROW EXECUTE FUNCTION enforce_immutabel_ver_rows();
CREATE TRIGGER trg_makulerad_skydd_rows BEFORE INSERT OR DELETE OR UPDATE ON public.verifikation_rows FOR EACH ROW EXECUTE FUNCTION protect_makulerad_ver_rows();
CREATE TRIGGER trg_periodlas_ver_rows BEFORE INSERT OR DELETE OR UPDATE ON public.verifikation_rows FOR EACH ROW EXECUTE FUNCTION enforce_periodlas_ver_rows();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.verifikation_rows FOR EACH ROW EXECUTE FUNCTION enforce_write_lock_verifikation_rows();
-- tabell: verifikationer
CREATE TRIGGER trg_audit_verifikation_del BEFORE DELETE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION audit_verifikation();
CREATE TRIGGER trg_audit_verifikation_ins AFTER INSERT ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION audit_verifikation();
CREATE TRIGGER trg_audit_verifikation_upd AFTER UPDATE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION audit_verifikation();
CREATE TRIGGER trg_forbjud_ver_delete BEFORE DELETE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION forbjud_bokford_radering();
CREATE TRIGGER trg_immutabel_verifikation BEFORE UPDATE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION enforce_immutabel_verifikation();
CREATE TRIGGER trg_journalfor_andring AFTER UPDATE OF status ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION journalfor_verifikationsandring();
CREATE TRIGGER trg_makulerad_skydd BEFORE DELETE OR UPDATE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION protect_makulerad_verifikation();
CREATE TRIGGER trg_notify_verifikation_created AFTER INSERT ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION notify_on_verifikation_created();
CREATE TRIGGER trg_observe_ver_mutation AFTER UPDATE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION observe_verifikation_mutation();
CREATE TRIGGER trg_periodlas_verifikation BEFORE INSERT OR DELETE OR UPDATE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION enforce_periodlas_verifikation();
CREATE TRIGGER trg_reset_lonekorning_on_makulering AFTER UPDATE OF status ON public.verifikationer FOR EACH ROW WHEN ((new.status = 'makulerad'::text)) EXECUTE FUNCTION reset_lonekorning_on_makulering();
CREATE TRIGGER trg_validate_ver_links BEFORE INSERT ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION validate_verifikation_links();
CREATE TRIGGER trg_verifikation_delete BEFORE DELETE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION on_verifikation_delete();
CREATE TRIGGER trg_write_lock BEFORE INSERT OR DELETE OR UPDATE ON public.verifikationer FOR EACH ROW EXECUTE FUNCTION enforce_company_write_lock();
