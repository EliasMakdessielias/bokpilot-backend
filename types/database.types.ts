export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      account_import_batches: {
        Row: {
          company_id: string | null
          created_at: string | null
          deactivated: number | null
          deleted: number | null
          error: string | null
          filename: string | null
          id: string
          imported_by: string | null
          imported_by_email: string | null
          inserted: number | null
          mode: string
          skipped: number | null
          status: string | null
          total_rows: number | null
          updated: number | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          deactivated?: number | null
          deleted?: number | null
          error?: string | null
          filename?: string | null
          id?: string
          imported_by?: string | null
          imported_by_email?: string | null
          inserted?: number | null
          mode: string
          skipped?: number | null
          status?: string | null
          total_rows?: number | null
          updated?: number | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          deactivated?: number | null
          deleted?: number | null
          error?: string | null
          filename?: string | null
          id?: string
          imported_by?: string | null
          imported_by_email?: string | null
          inserted?: number | null
          mode?: string
          skipped?: number | null
          status?: string | null
          total_rows?: number | null
          updated?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "account_import_batches_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      accounts: {
        Row: {
          account_class: number | null
          account_nr: string
          account_type: string | null
          auto_kontering: string | null
          budget: number | null
          company_id: string | null
          created_at: string | null
          id: string
          import_batch_id: string | null
          imported_from: string | null
          is_active: boolean | null
          is_blocked_for_manual_booking: boolean | null
          is_locked: boolean | null
          locked_reason: string | null
          locked_source: string | null
          name: string
          opening_balance: number | null
          sru: string | null
          suggest_debit_credit: string | null
          transaction_info: string | null
          updated_at: string | null
          vat_code: string | null
        }
        Insert: {
          account_class?: number | null
          account_nr: string
          account_type?: string | null
          auto_kontering?: string | null
          budget?: number | null
          company_id?: string | null
          created_at?: string | null
          id?: string
          import_batch_id?: string | null
          imported_from?: string | null
          is_active?: boolean | null
          is_blocked_for_manual_booking?: boolean | null
          is_locked?: boolean | null
          locked_reason?: string | null
          locked_source?: string | null
          name: string
          opening_balance?: number | null
          sru?: string | null
          suggest_debit_credit?: string | null
          transaction_info?: string | null
          updated_at?: string | null
          vat_code?: string | null
        }
        Update: {
          account_class?: number | null
          account_nr?: string
          account_type?: string | null
          auto_kontering?: string | null
          budget?: number | null
          company_id?: string | null
          created_at?: string | null
          id?: string
          import_batch_id?: string | null
          imported_from?: string | null
          is_active?: boolean | null
          is_blocked_for_manual_booking?: boolean | null
          is_locked?: boolean | null
          locked_reason?: string | null
          locked_source?: string | null
          name?: string
          opening_balance?: number | null
          sru?: string | null
          suggest_debit_credit?: string | null
          transaction_info?: string | null
          updated_at?: string | null
          vat_code?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "accounts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      agi_deklarationer: {
        Row: {
          ag_avgift: number
          antal_individer: number
          att_betala: number
          avdragen_skatt: number
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          individuppgifter: Json
          period: string
          status: string
          summa_underlag: number
        }
        Insert: {
          ag_avgift?: number
          antal_individer?: number
          att_betala?: number
          avdragen_skatt?: number
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          individuppgifter?: Json
          period: string
          status?: string
          summa_underlag?: number
        }
        Update: {
          ag_avgift?: number
          antal_individer?: number
          att_betala?: number
          avdragen_skatt?: number
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          individuppgifter?: Json
          period?: string
          status?: string
          summa_underlag?: number
        }
        Relationships: []
      }
      ai_bokforing_logg: {
        Row: {
          applied: boolean
          company_id: string
          created_at: string
          created_by: string | null
          document_id: string | null
          fraga: string | null
          id: string
          kind: string | null
          konfidens: number | null
          konteringsforslag: Json | null
          kraver_manuell_granskning: boolean | null
          model: string | null
          regelverk_version: string | null
          svar: string | null
          verifikation_id: string | null
        }
        Insert: {
          applied?: boolean
          company_id: string
          created_at?: string
          created_by?: string | null
          document_id?: string | null
          fraga?: string | null
          id?: string
          kind?: string | null
          konfidens?: number | null
          konteringsforslag?: Json | null
          kraver_manuell_granskning?: boolean | null
          model?: string | null
          regelverk_version?: string | null
          svar?: string | null
          verifikation_id?: string | null
        }
        Update: {
          applied?: boolean
          company_id?: string
          created_at?: string
          created_by?: string | null
          document_id?: string | null
          fraga?: string | null
          id?: string
          kind?: string | null
          konfidens?: number | null
          konteringsforslag?: Json | null
          kraver_manuell_granskning?: boolean | null
          model?: string | null
          regelverk_version?: string | null
          svar?: string | null
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_bokforing_logg_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_bokforing_logg_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ai_bokforing_logg_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_call_log: {
        Row: {
          company_id: string | null
          created_at: string
          document_id: string | null
          id: string
          user_id: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string
          document_id?: string | null
          id?: string
          user_id?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string
          document_id?: string | null
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      ai_checklista_korningar: {
        Row: {
          antal_ai_anrop: number
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          resultat: Json
        }
        Insert: {
          antal_ai_anrop?: number
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          resultat?: Json
        }
        Update: {
          antal_ai_anrop?: number
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          resultat?: Json
        }
        Relationships: [
          {
            foreignKeyName: "ai_checklista_korningar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      ai_cooldowns: {
        Row: {
          cooldown_until: string
          reason: string | null
          scope: string
          scope_key: string
          updated_at: string
        }
        Insert: {
          cooldown_until: string
          reason?: string | null
          scope: string
          scope_key: string
          updated_at?: string
        }
        Update: {
          cooldown_until?: string
          reason?: string | null
          scope?: string
          scope_key?: string
          updated_at?: string
        }
        Relationships: []
      }
      ai_error_log: {
        Row: {
          attempts: number | null
          company_id: string | null
          created_at: string
          document_id: string | null
          error_body: string | null
          error_code: string | null
          id: string
          kind: string | null
          model: string | null
          provider: string | null
          request_id: string | null
          status_code: number | null
          user_id: string | null
        }
        Insert: {
          attempts?: number | null
          company_id?: string | null
          created_at?: string
          document_id?: string | null
          error_body?: string | null
          error_code?: string | null
          id?: string
          kind?: string | null
          model?: string | null
          provider?: string | null
          request_id?: string | null
          status_code?: number | null
          user_id?: string | null
        }
        Update: {
          attempts?: number | null
          company_id?: string | null
          created_at?: string
          document_id?: string | null
          error_body?: string | null
          error_code?: string | null
          id?: string
          kind?: string | null
          model?: string | null
          provider?: string | null
          request_id?: string | null
          status_code?: number | null
          user_id?: string | null
        }
        Relationships: []
      }
      ai_usage_log: {
        Row: {
          company_id: string | null
          created_at: string
          id: string
          kind: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string
          id?: string
          kind?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string
          id?: string
          kind?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ai_usage_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      aml_flags: {
        Row: {
          allvarlighet: string
          beskrivning: string
          beslutsanteckning: string | null
          company_id: string
          created_at: string
          dedup_nyckel: string
          document_id: string | null
          granskad_at: string | null
          granskad_av: string | null
          id: string
          status: string
          typ: string
          verifikation_id: string | null
        }
        Insert: {
          allvarlighet?: string
          beskrivning: string
          beslutsanteckning?: string | null
          company_id: string
          created_at?: string
          dedup_nyckel: string
          document_id?: string | null
          granskad_at?: string | null
          granskad_av?: string | null
          id?: string
          status?: string
          typ: string
          verifikation_id?: string | null
        }
        Update: {
          allvarlighet?: string
          beskrivning?: string
          beslutsanteckning?: string | null
          company_id?: string
          created_at?: string
          dedup_nyckel?: string
          document_id?: string | null
          granskad_at?: string | null
          granskad_av?: string | null
          id?: string
          status?: string
          typ?: string
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "aml_flags_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      aml_installningar: {
        Row: {
          byra_bolag_id: string
          id: boolean | null
          kontantgrans_kr: number
          strukturering_andel_av_grans: number
          strukturering_fonster_dagar: number
          strukturering_min_antal: number
          updated_at: string
        }
        Insert: {
          byra_bolag_id: string
          id?: boolean | null
          kontantgrans_kr?: number
          strukturering_andel_av_grans?: number
          strukturering_fonster_dagar?: number
          strukturering_min_antal?: number
          updated_at?: string
        }
        Update: {
          byra_bolag_id?: string
          id?: boolean | null
          kontantgrans_kr?: number
          strukturering_andel_av_grans?: number
          strukturering_fonster_dagar?: number
          strukturering_min_antal?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "aml_installningar_byra_bolag_id_fkey"
            columns: ["byra_bolag_id"]
            isOneToOne: true
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      annual_report_draft_sections: {
        Row: {
          ai_generated: boolean
          ai_generated_at: string | null
          ai_model: string | null
          ai_prompt_version: string | null
          ai_source_summary: Json
          company_id: string
          content: string | null
          created_at: string
          draft_id: string
          id: string
          requires_review: boolean
          review_comment: string | null
          review_status: string
          reviewed_at: string | null
          reviewed_by: string | null
          section_key: string
          sort_order: number
          source_references: Json
          structured_data: Json
          title: string
          updated_at: string
        }
        Insert: {
          ai_generated?: boolean
          ai_generated_at?: string | null
          ai_model?: string | null
          ai_prompt_version?: string | null
          ai_source_summary?: Json
          company_id: string
          content?: string | null
          created_at?: string
          draft_id: string
          id?: string
          requires_review?: boolean
          review_comment?: string | null
          review_status?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          section_key: string
          sort_order?: number
          source_references?: Json
          structured_data?: Json
          title: string
          updated_at?: string
        }
        Update: {
          ai_generated?: boolean
          ai_generated_at?: string | null
          ai_model?: string | null
          ai_prompt_version?: string | null
          ai_source_summary?: Json
          company_id?: string
          content?: string | null
          created_at?: string
          draft_id?: string
          id?: string
          requires_review?: boolean
          review_comment?: string | null
          review_status?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          section_key?: string
          sort_order?: number
          source_references?: Json
          structured_data?: Json
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "annual_report_draft_sections_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_draft_sections_draft_id_fkey"
            columns: ["draft_id"]
            isOneToOne: false
            referencedRelation: "annual_report_drafts"
            referencedColumns: ["id"]
          },
        ]
      }
      annual_report_drafts: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          company_id: string
          created_at: string
          engagement_id: string
          fiscal_year_id: string | null
          generated_at: string | null
          generated_by: string | null
          id: string
          period_end: string | null
          period_start: string | null
          regelverk: string
          reviewed_at: string | null
          reviewed_by: string | null
          source_data: Json
          status: string
          title: string | null
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          company_id: string
          created_at?: string
          engagement_id: string
          fiscal_year_id?: string | null
          generated_at?: string | null
          generated_by?: string | null
          id?: string
          period_end?: string | null
          period_start?: string | null
          regelverk?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_data?: Json
          status?: string
          title?: string | null
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          company_id?: string
          created_at?: string
          engagement_id?: string
          fiscal_year_id?: string | null
          generated_at?: string | null
          generated_by?: string | null
          id?: string
          period_end?: string | null
          period_start?: string | null
          regelverk?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          source_data?: Json
          status?: string
          title?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "annual_report_drafts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_drafts_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: true
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_drafts_fiscal_year_id_fkey"
            columns: ["fiscal_year_id"]
            isOneToOne: false
            referencedRelation: "fiscal_years"
            referencedColumns: ["id"]
          },
        ]
      }
      annual_report_exports: {
        Row: {
          checksum: string | null
          company_id: string
          created_at: string
          draft_id: string
          engagement_id: string
          error: string | null
          export_type: string
          file_name: string | null
          file_path: string | null
          file_size: number | null
          generated_at: string | null
          generated_by: string | null
          id: string
          quality_report: Json
          quality_status: string
          render_engine: string | null
          status: string
          storage_bucket: string | null
          storage_path: string | null
          validation_summary: Json
        }
        Insert: {
          checksum?: string | null
          company_id: string
          created_at?: string
          draft_id: string
          engagement_id: string
          error?: string | null
          export_type: string
          file_name?: string | null
          file_path?: string | null
          file_size?: number | null
          generated_at?: string | null
          generated_by?: string | null
          id?: string
          quality_report?: Json
          quality_status?: string
          render_engine?: string | null
          status?: string
          storage_bucket?: string | null
          storage_path?: string | null
          validation_summary?: Json
        }
        Update: {
          checksum?: string | null
          company_id?: string
          created_at?: string
          draft_id?: string
          engagement_id?: string
          error?: string | null
          export_type?: string
          file_name?: string | null
          file_path?: string | null
          file_size?: number | null
          generated_at?: string | null
          generated_by?: string | null
          id?: string
          quality_report?: Json
          quality_status?: string
          render_engine?: string | null
          status?: string
          storage_bucket?: string | null
          storage_path?: string | null
          validation_summary?: Json
        }
        Relationships: [
          {
            foreignKeyName: "annual_report_exports_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_exports_draft_id_fkey"
            columns: ["draft_id"]
            isOneToOne: false
            referencedRelation: "annual_report_drafts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_exports_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: false
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
        ]
      }
      annual_report_validation_items: {
        Row: {
          company_id: string
          created_at: string
          description: string | null
          draft_id: string
          engagement_id: string
          id: string
          ignored_at: string | null
          ignored_by: string | null
          ignored_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          section_id: string | null
          severity: string
          source: string
          source_data: Json
          status: string
          suggested_action: string | null
          title: string
          updated_at: string
          validation_key: string
        }
        Insert: {
          company_id: string
          created_at?: string
          description?: string | null
          draft_id: string
          engagement_id: string
          id?: string
          ignored_at?: string | null
          ignored_by?: string | null
          ignored_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          section_id?: string | null
          severity?: string
          source?: string
          source_data?: Json
          status?: string
          suggested_action?: string | null
          title: string
          updated_at?: string
          validation_key: string
        }
        Update: {
          company_id?: string
          created_at?: string
          description?: string | null
          draft_id?: string
          engagement_id?: string
          id?: string
          ignored_at?: string | null
          ignored_by?: string | null
          ignored_reason?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          section_id?: string | null
          severity?: string
          source?: string
          source_data?: Json
          status?: string
          suggested_action?: string | null
          title?: string
          updated_at?: string
          validation_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "annual_report_validation_items_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_validation_items_draft_id_fkey"
            columns: ["draft_id"]
            isOneToOne: false
            referencedRelation: "annual_report_drafts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_validation_items_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: false
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "annual_report_validation_items_section_id_fkey"
            columns: ["section_id"]
            isOneToOne: false
            referencedRelation: "annual_report_draft_sections"
            referencedColumns: ["id"]
          },
        ]
      }
      arkiv_filer: {
        Row: {
          beskrivning: string | null
          company_id: string
          created_at: string
          document_id: string | null
          file_name: string
          file_size: number | null
          id: string
          kalla: string
          mapp_id: string
          mime_type: string | null
          raderad_at: string | null
          raderad_av: string | null
          storage_path: string | null
          uppladdad_av: string | null
        }
        Insert: {
          beskrivning?: string | null
          company_id: string
          created_at?: string
          document_id?: string | null
          file_name: string
          file_size?: number | null
          id?: string
          kalla?: string
          mapp_id: string
          mime_type?: string | null
          raderad_at?: string | null
          raderad_av?: string | null
          storage_path?: string | null
          uppladdad_av?: string | null
        }
        Update: {
          beskrivning?: string | null
          company_id?: string
          created_at?: string
          document_id?: string | null
          file_name?: string
          file_size?: number | null
          id?: string
          kalla?: string
          mapp_id?: string
          mime_type?: string | null
          raderad_at?: string | null
          raderad_av?: string | null
          storage_path?: string | null
          uppladdad_av?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "arkiv_filer_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "arkiv_filer_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "arkiv_filer_mapp_id_fkey"
            columns: ["mapp_id"]
            isOneToOne: false
            referencedRelation: "arkiv_mappar"
            referencedColumns: ["id"]
          },
        ]
      }
      arkiv_mappar: {
        Row: {
          company_id: string
          created_at: string
          gallringsregel: string
          id: string
          namn: string
          parent_id: string | null
          skapad_av: string | null
          sortering: number
          synlighet: string
          systemnyckel: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          gallringsregel?: string
          id?: string
          namn: string
          parent_id?: string | null
          skapad_av?: string | null
          sortering?: number
          synlighet?: string
          systemnyckel?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          gallringsregel?: string
          id?: string
          namn?: string
          parent_id?: string | null
          skapad_av?: string | null
          sortering?: number
          synlighet?: string
          systemnyckel?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "arkiv_mappar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "arkiv_mappar_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "arkiv_mappar"
            referencedColumns: ["id"]
          },
        ]
      }
      article_templates: {
        Row: {
          category: string | null
          company_id: string | null
          created_at: string | null
          description: string | null
          id: string
          is_active: boolean | null
          is_standard: boolean | null
          locked: boolean | null
          name: string
          name_en: string | null
          sales_accounts: Json | null
          vat_rate: number | null
        }
        Insert: {
          category?: string | null
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_active?: boolean | null
          is_standard?: boolean | null
          locked?: boolean | null
          name: string
          name_en?: string | null
          sales_accounts?: Json | null
          vat_rate?: number | null
        }
        Update: {
          category?: string | null
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_active?: boolean | null
          is_standard?: boolean | null
          locked?: boolean | null
          name?: string
          name_en?: string | null
          sales_accounts?: Json | null
          vat_rate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "article_templates_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      assistent_logg: {
        Row: {
          bokford: boolean
          cache_read_tokens: number
          company_id: string
          created_at: string
          id: string
          in_tokens: number
          mall_key: string | null
          out_tokens: number
          prompt: string | null
          status: string
          svar: string | null
          user_id: string
          verktygsanrop: number
        }
        Insert: {
          bokford?: boolean
          cache_read_tokens?: number
          company_id: string
          created_at?: string
          id?: string
          in_tokens?: number
          mall_key?: string | null
          out_tokens?: number
          prompt?: string | null
          status?: string
          svar?: string | null
          user_id: string
          verktygsanrop?: number
        }
        Update: {
          bokford?: boolean
          cache_read_tokens?: number
          company_id?: string
          created_at?: string
          id?: string
          in_tokens?: number
          mall_key?: string | null
          out_tokens?: number
          prompt?: string | null
          status?: string
          svar?: string | null
          user_id?: string
          verktygsanrop?: number
        }
        Relationships: [
          {
            foreignKeyName: "assistent_logg_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          batch_id: string | null
          changed_by: string | null
          changed_by_email: string | null
          company_id: string | null
          created_at: string | null
          entity: string
          entity_ref: string | null
          id: string
          metadata: Json | null
          new_data: Json | null
          old_data: Json | null
          source: string | null
        }
        Insert: {
          action: string
          batch_id?: string | null
          changed_by?: string | null
          changed_by_email?: string | null
          company_id?: string | null
          created_at?: string | null
          entity: string
          entity_ref?: string | null
          id?: string
          metadata?: Json | null
          new_data?: Json | null
          old_data?: Json | null
          source?: string | null
        }
        Update: {
          action?: string
          batch_id?: string | null
          changed_by?: string | null
          changed_by_email?: string | null
          company_id?: string | null
          created_at?: string | null
          entity?: string
          entity_ref?: string | null
          id?: string
          metadata?: Json | null
          new_data?: Json | null
          old_data?: Json | null
          source?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      bank_accounts: {
        Row: {
          account_nr: string | null
          aktiv: boolean
          bankgiro: string | null
          bankkontonr: string | null
          company_id: string
          created_at: string | null
          iban: string | null
          id: string
          is_standard: boolean | null
          locked: boolean | null
          namn: string
          typ: string
          valuta: string
        }
        Insert: {
          account_nr?: string | null
          aktiv?: boolean
          bankgiro?: string | null
          bankkontonr?: string | null
          company_id: string
          created_at?: string | null
          iban?: string | null
          id?: string
          is_standard?: boolean | null
          locked?: boolean | null
          namn: string
          typ?: string
          valuta?: string
        }
        Update: {
          account_nr?: string | null
          aktiv?: boolean
          bankgiro?: string | null
          bankkontonr?: string | null
          company_id?: string
          created_at?: string | null
          iban?: string | null
          id?: string
          is_standard?: boolean | null
          locked?: boolean | null
          namn?: string
          typ?: string
          valuta?: string
        }
        Relationships: [
          {
            foreignKeyName: "bank_accounts_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      bank_transactions: {
        Row: {
          account_nr: string
          amount: number | null
          avstamd: boolean | null
          company_id: string | null
          datum: string | null
          id: string
          import_batch: string | null
          imported_at: string | null
          status: string | null
          text: string | null
          verifikation_id: string | null
        }
        Insert: {
          account_nr: string
          amount?: number | null
          avstamd?: boolean | null
          company_id?: string | null
          datum?: string | null
          id?: string
          import_batch?: string | null
          imported_at?: string | null
          status?: string | null
          text?: string | null
          verifikation_id?: string | null
        }
        Update: {
          account_nr?: string
          amount?: number | null
          avstamd?: boolean | null
          company_id?: string | null
          datum?: string | null
          id?: string
          import_batch?: string | null
          imported_at?: string | null
          status?: string | null
          text?: string | null
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bank_transactions_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bank_transactions_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      bas_accounts: {
        Row: {
          account_nr: string
          is_active: boolean | null
          name: string
          vat_code: string | null
        }
        Insert: {
          account_nr: string
          is_active?: boolean | null
          name: string
          vat_code?: string | null
        }
        Update: {
          account_nr?: string
          is_active?: boolean | null
          name?: string
          vat_code?: string | null
        }
        Relationships: []
      }
      beta_ansokningar: {
        Row: {
          avvisad_orsak: string | null
          bolagsnamn: string
          company_id: string | null
          created_at: string
          epost: string
          hanterad_at: string | null
          hanterad_av_email: string | null
          id: string
          meddelande: string | null
          org_nr: string | null
          status: string
          user_id: string
        }
        Insert: {
          avvisad_orsak?: string | null
          bolagsnamn: string
          company_id?: string | null
          created_at?: string
          epost: string
          hanterad_at?: string | null
          hanterad_av_email?: string | null
          id?: string
          meddelande?: string | null
          org_nr?: string | null
          status?: string
          user_id: string
        }
        Update: {
          avvisad_orsak?: string | null
          bolagsnamn?: string
          company_id?: string | null
          created_at?: string
          epost?: string
          hanterad_at?: string | null
          hanterad_av_email?: string | null
          id?: string
          meddelande?: string | null
          org_nr?: string | null
          status?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "beta_ansokningar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      bokslut_ai_suggestions: {
        Row: {
          company_id: string
          confidence: number | null
          created_at: string
          engagement_id: string
          id: string
          model: string | null
          reasoning: string | null
          related_attachment_id: string | null
          related_check_id: string | null
          review_comment: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          risk_level: string
          source_data: Json
          status: string
          suggested_next_action: string | null
          suggestion_type: string
          summary: string | null
          title: string
          updated_at: string
        }
        Insert: {
          company_id: string
          confidence?: number | null
          created_at?: string
          engagement_id: string
          id?: string
          model?: string | null
          reasoning?: string | null
          related_attachment_id?: string | null
          related_check_id?: string | null
          review_comment?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          risk_level?: string
          source_data?: Json
          status?: string
          suggested_next_action?: string | null
          suggestion_type: string
          summary?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          company_id?: string
          confidence?: number | null
          created_at?: string
          engagement_id?: string
          id?: string
          model?: string | null
          reasoning?: string | null
          related_attachment_id?: string | null
          related_check_id?: string | null
          review_comment?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          risk_level?: string
          source_data?: Json
          status?: string
          suggested_next_action?: string | null
          suggestion_type?: string
          summary?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bokslut_ai_suggestions_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_ai_suggestions_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: false
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_ai_suggestions_related_attachment_id_fkey"
            columns: ["related_attachment_id"]
            isOneToOne: false
            referencedRelation: "bokslut_attachments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_ai_suggestions_related_check_id_fkey"
            columns: ["related_check_id"]
            isOneToOne: false
            referencedRelation: "bokslut_checks"
            referencedColumns: ["id"]
          },
        ]
      }
      bokslut_attachments: {
        Row: {
          account_nr: string | null
          avstamt_belopp: number | null
          check_id: string | null
          comment: string | null
          company_id: string
          created_at: string
          created_by: string | null
          differens: number | null
          engagement_id: string
          id: string
          reviewed_at: string | null
          reviewed_by: string | null
          rule_key: string | null
          saldo_huvudbok: number | null
          source: string | null
          source_data: Json
          status: string
          title: string
          type: string
          updated_at: string
        }
        Insert: {
          account_nr?: string | null
          avstamt_belopp?: number | null
          check_id?: string | null
          comment?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          differens?: number | null
          engagement_id: string
          id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          rule_key?: string | null
          saldo_huvudbok?: number | null
          source?: string | null
          source_data?: Json
          status?: string
          title: string
          type: string
          updated_at?: string
        }
        Update: {
          account_nr?: string | null
          avstamt_belopp?: number | null
          check_id?: string | null
          comment?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          differens?: number | null
          engagement_id?: string
          id?: string
          reviewed_at?: string | null
          reviewed_by?: string | null
          rule_key?: string | null
          saldo_huvudbok?: number | null
          source?: string | null
          source_data?: Json
          status?: string
          title?: string
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bokslut_attachments_check_id_fkey"
            columns: ["check_id"]
            isOneToOne: false
            referencedRelation: "bokslut_checks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_attachments_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_attachments_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: false
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
        ]
      }
      bokslut_audit_log: {
        Row: {
          action: string
          company_id: string
          created_at: string
          detail: Json
          engagement_id: string | null
          id: string
          model: string | null
          prompt_version: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          company_id: string
          created_at?: string
          detail?: Json
          engagement_id?: string | null
          id?: string
          model?: string | null
          prompt_version?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          company_id?: string
          created_at?: string
          detail?: Json
          engagement_id?: string | null
          id?: string
          model?: string | null
          prompt_version?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bokslut_audit_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_audit_log_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: false
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
        ]
      }
      bokslut_checks: {
        Row: {
          account_nr: string | null
          action_url: string | null
          assigned_to: string | null
          category: string
          comment: string | null
          comment_revision: number
          comment_updated_at: string | null
          comment_updated_by: string | null
          company_id: string
          created_at: string
          description: string | null
          engagement_id: string
          id: string
          resolved_at: string | null
          resolved_by: string | null
          risk_level: string
          rule_key: string
          saldo: number | null
          source: string | null
          source_data: Json
          status: string
          suggested_action: string | null
          title: string
          updated_at: string
        }
        Insert: {
          account_nr?: string | null
          action_url?: string | null
          assigned_to?: string | null
          category: string
          comment?: string | null
          comment_revision?: number
          comment_updated_at?: string | null
          comment_updated_by?: string | null
          company_id: string
          created_at?: string
          description?: string | null
          engagement_id: string
          id?: string
          resolved_at?: string | null
          resolved_by?: string | null
          risk_level?: string
          rule_key: string
          saldo?: number | null
          source?: string | null
          source_data?: Json
          status?: string
          suggested_action?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          account_nr?: string | null
          action_url?: string | null
          assigned_to?: string | null
          category?: string
          comment?: string | null
          comment_revision?: number
          comment_updated_at?: string | null
          comment_updated_by?: string | null
          company_id?: string
          created_at?: string
          description?: string | null
          engagement_id?: string
          id?: string
          resolved_at?: string | null
          resolved_by?: string | null
          risk_level?: string
          rule_key?: string
          saldo?: number | null
          source?: string | null
          source_data?: Json
          status?: string
          suggested_action?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bokslut_checks_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_checks_engagement_id_fkey"
            columns: ["engagement_id"]
            isOneToOne: false
            referencedRelation: "bokslut_engagements"
            referencedColumns: ["id"]
          },
        ]
      }
      bokslut_denied_log: {
        Row: {
          action: string
          company_id: string | null
          context: Json
          created_at: string
          engagement_id: string | null
          id: string
          reason: string | null
          role: string | null
          user_id: string | null
        }
        Insert: {
          action: string
          company_id?: string | null
          context?: Json
          created_at?: string
          engagement_id?: string | null
          id?: string
          reason?: string | null
          role?: string | null
          user_id?: string | null
        }
        Update: {
          action?: string
          company_id?: string | null
          context?: Json
          created_at?: string
          engagement_id?: string | null
          id?: string
          reason?: string | null
          role?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      bokslut_engagements: {
        Row: {
          ansvarig_user_id: string | null
          company_id: string
          created_at: string
          critical_count: number
          fiscal_year_id: string
          high_count: number
          id: string
          last_analysis_at: string | null
          open_count: number
          regelverk: string
          status: string
          updated_at: string
        }
        Insert: {
          ansvarig_user_id?: string | null
          company_id: string
          created_at?: string
          critical_count?: number
          fiscal_year_id: string
          high_count?: number
          id?: string
          last_analysis_at?: string | null
          open_count?: number
          regelverk?: string
          status?: string
          updated_at?: string
        }
        Update: {
          ansvarig_user_id?: string | null
          company_id?: string
          created_at?: string
          critical_count?: number
          fiscal_year_id?: string
          high_count?: number
          id?: string
          last_analysis_at?: string | null
          open_count?: number
          regelverk?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bokslut_engagements_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bokslut_engagements_fiscal_year_id_fkey"
            columns: ["fiscal_year_id"]
            isOneToOne: false
            referencedRelation: "fiscal_years"
            referencedColumns: ["id"]
          },
        ]
      }
      bokslut_sync_operations: {
        Row: {
          base_revision: number
          company_id: string
          completed_at: string | null
          created_at: string
          entity_id: string
          entity_type: string
          expires_at: string
          id: string
          idempotency_key: string
          operation_type: string
          request_hash: string
          result_payload: Json | null
          status: string
          user_id: string
        }
        Insert: {
          base_revision: number
          company_id: string
          completed_at?: string | null
          created_at?: string
          entity_id: string
          entity_type: string
          expires_at?: string
          id?: string
          idempotency_key: string
          operation_type: string
          request_hash: string
          result_payload?: Json | null
          status: string
          user_id: string
        }
        Update: {
          base_revision?: number
          company_id?: string
          completed_at?: string | null
          created_at?: string
          entity_id?: string
          entity_type?: string
          expires_at?: string
          id?: string
          idempotency_key?: string
          operation_type?: string
          request_hash?: string
          result_payload?: Json | null
          status?: string
          user_id?: string
        }
        Relationships: []
      }
      bookkeeping_templates: {
        Row: {
          company_id: string | null
          created_at: string | null
          description: string | null
          id: string
          is_active: boolean | null
          is_standard: boolean | null
          locked: boolean | null
          name: string
          name_en: string | null
          rows: Json | null
          usage_area: string | null
          ver_series: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_active?: boolean | null
          is_standard?: boolean | null
          locked?: boolean | null
          name: string
          name_en?: string | null
          rows?: Json | null
          usage_area?: string | null
          ver_series?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          description?: string | null
          id?: string
          is_active?: boolean | null
          is_standard?: boolean | null
          locked?: boolean | null
          name?: string
          name_en?: string | null
          rows?: Json | null
          usage_area?: string | null
          ver_series?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "bookkeeping_templates_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      byra_installningar: {
        Row: {
          byra_bolag_id: string
          standard_moduler: string[] | null
          standard_uppdragstyper: string[]
          updated_at: string
          updated_av: string | null
        }
        Insert: {
          byra_bolag_id: string
          standard_moduler?: string[] | null
          standard_uppdragstyper?: string[]
          updated_at?: string
          updated_av?: string | null
        }
        Update: {
          byra_bolag_id?: string
          standard_moduler?: string[] | null
          standard_uppdragstyper?: string[]
          updated_at?: string
          updated_av?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "byra_installningar_byra_bolag_id_fkey"
            columns: ["byra_bolag_id"]
            isOneToOne: true
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      byra_klient: {
        Row: {
          avslutad_at: string | null
          byra_bolag_id: string
          created_at: string
          id: string
          klient_bolag_id: string
          kundansvarig_anvandare_id: string | null
          status: string
          tillagd_av: string | null
          updated_at: string
        }
        Insert: {
          avslutad_at?: string | null
          byra_bolag_id: string
          created_at?: string
          id?: string
          klient_bolag_id: string
          kundansvarig_anvandare_id?: string | null
          status?: string
          tillagd_av?: string | null
          updated_at?: string
        }
        Update: {
          avslutad_at?: string | null
          byra_bolag_id?: string
          created_at?: string
          id?: string
          klient_bolag_id?: string
          kundansvarig_anvandare_id?: string | null
          status?: string
          tillagd_av?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "byra_klient_byra_bolag_id_fkey"
            columns: ["byra_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "byra_klient_klient_bolag_id_fkey"
            columns: ["klient_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      byra_medlemmar: {
        Row: {
          created_at: string
          namn: string | null
          tillagd_av: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          namn?: string | null
          tillagd_av?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          namn?: string | null
          tillagd_av?: string | null
          user_id?: string
        }
        Relationships: []
      }
      byra_medlemskap: {
        Row: {
          aktiv: boolean
          anvandare_id: string
          byra_bolag_id: string
          created_at: string
          epost: string | null
          id: string
          namn: string | null
          roll: string
          tillagd_av: string | null
          updated_at: string
        }
        Insert: {
          aktiv?: boolean
          anvandare_id: string
          byra_bolag_id: string
          created_at?: string
          epost?: string | null
          id?: string
          namn?: string | null
          roll?: string
          tillagd_av?: string | null
          updated_at?: string
        }
        Update: {
          aktiv?: boolean
          anvandare_id?: string
          byra_bolag_id?: string
          created_at?: string
          epost?: string | null
          id?: string
          namn?: string | null
          roll?: string
          tillagd_av?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "byra_medlemskap_byra_bolag_id_fkey"
            columns: ["byra_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      companies: {
        Row: {
          abonnemang_status: string
          address: string | null
          archive_number: number
          bankgiro: string | null
          bic_swift: string | null
          bokforing_last_tom: string | null
          bokforingsmetod: string | null
          company_number: number | null
          created_at: string | null
          email: string | null
          faktura_epost_text: string | null
          faktura_text: string | null
          foretagsform: string | null
          iban: string | null
          id: string
          late_interest: number | null
          mobil: string | null
          momsperiod: string | null
          name: string
          nasta_fakturanr: number | null
          onboarded: boolean | null
          org_nr: string | null
          payment_terms: number | null
          phone: string | null
          plusgiro: string | null
          postnr: string | null
          postort: string | null
          sate: string | null
          service_changed_at: string | null
          service_changed_by: string | null
          service_note: string | null
          service_reason: string | null
          service_state: string
          service_state_manual: boolean
          settings: Json
          suspended: boolean | null
          swish: string | null
          valuta: string | null
          vat_nr: string | null
          website: string | null
        }
        Insert: {
          abonnemang_status?: string
          address?: string | null
          archive_number: number
          bankgiro?: string | null
          bic_swift?: string | null
          bokforing_last_tom?: string | null
          bokforingsmetod?: string | null
          company_number?: number | null
          created_at?: string | null
          email?: string | null
          faktura_epost_text?: string | null
          faktura_text?: string | null
          foretagsform?: string | null
          iban?: string | null
          id?: string
          late_interest?: number | null
          mobil?: string | null
          momsperiod?: string | null
          name: string
          nasta_fakturanr?: number | null
          onboarded?: boolean | null
          org_nr?: string | null
          payment_terms?: number | null
          phone?: string | null
          plusgiro?: string | null
          postnr?: string | null
          postort?: string | null
          sate?: string | null
          service_changed_at?: string | null
          service_changed_by?: string | null
          service_note?: string | null
          service_reason?: string | null
          service_state?: string
          service_state_manual?: boolean
          settings?: Json
          suspended?: boolean | null
          swish?: string | null
          valuta?: string | null
          vat_nr?: string | null
          website?: string | null
        }
        Update: {
          abonnemang_status?: string
          address?: string | null
          archive_number?: number
          bankgiro?: string | null
          bic_swift?: string | null
          bokforing_last_tom?: string | null
          bokforingsmetod?: string | null
          company_number?: number | null
          created_at?: string | null
          email?: string | null
          faktura_epost_text?: string | null
          faktura_text?: string | null
          foretagsform?: string | null
          iban?: string | null
          id?: string
          late_interest?: number | null
          mobil?: string | null
          momsperiod?: string | null
          name?: string
          nasta_fakturanr?: number | null
          onboarded?: boolean | null
          org_nr?: string | null
          payment_terms?: number | null
          phone?: string | null
          plusgiro?: string | null
          postnr?: string | null
          postort?: string | null
          sate?: string | null
          service_changed_at?: string | null
          service_changed_by?: string | null
          service_note?: string | null
          service_reason?: string | null
          service_state?: string
          service_state_manual?: boolean
          settings?: Json
          suspended?: boolean | null
          swish?: string | null
          valuta?: string | null
          vat_nr?: string | null
          website?: string | null
        }
        Relationships: []
      }
      company_ai_features: {
        Row: {
          company_id: string
          created_at: string
          enabled: boolean
          feature_key: string
          note: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          enabled?: boolean
          feature_key: string
          note?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          enabled?: boolean
          feature_key?: string
          note?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "company_ai_features_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      company_invites: {
        Row: {
          company_id: string | null
          created_at: string | null
          email: string
          id: string
          invited_by: string | null
          role: string | null
          status: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          email: string
          id?: string
          invited_by?: string | null
          role?: string | null
          status?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          email?: string
          id?: string
          invited_by?: string | null
          role?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "company_invites_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      company_lookup_cache: {
        Row: {
          api_version: string | null
          fetched_at: string
          org_nr: string
          payload: Json
          source: string | null
        }
        Insert: {
          api_version?: string | null
          fetched_at?: string
          org_nr: string
          payload: Json
          source?: string | null
        }
        Update: {
          api_version?: string | null
          fetched_at?: string
          org_nr?: string
          payload?: Json
          source?: string | null
        }
        Relationships: []
      }
      company_lookup_rate: {
        Row: {
          count: number
          user_id: string
          window_start: string
        }
        Insert: {
          count?: number
          user_id: string
          window_start?: string
        }
        Update: {
          count?: number
          user_id?: string
          window_start?: string
        }
        Relationships: []
      }
      company_subscriptions: {
        Row: {
          billing_period: string
          cancel_at: string | null
          cancelled_at: string | null
          company_id: string
          created_at: string
          current_period_end: string | null
          current_period_start: string | null
          discount_percent: number | null
          grace_until: string | null
          id: string
          last_payment_at: string | null
          last_payment_failed_at: string | null
          next_billing_at: string | null
          next_payment_attempt_at: string | null
          payment_checkout_session_id: string | null
          payment_customer_id: string | null
          payment_price_id: string | null
          payment_provider: string | null
          payment_status: string | null
          payment_subscription_id: string | null
          plan_id: string | null
          status: string
          stripe_latest_invoice_id: string | null
          suspended_at: string | null
          trial_ends_at: string | null
          updated_at: string
        }
        Insert: {
          billing_period?: string
          cancel_at?: string | null
          cancelled_at?: string | null
          company_id: string
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          discount_percent?: number | null
          grace_until?: string | null
          id?: string
          last_payment_at?: string | null
          last_payment_failed_at?: string | null
          next_billing_at?: string | null
          next_payment_attempt_at?: string | null
          payment_checkout_session_id?: string | null
          payment_customer_id?: string | null
          payment_price_id?: string | null
          payment_provider?: string | null
          payment_status?: string | null
          payment_subscription_id?: string | null
          plan_id?: string | null
          status?: string
          stripe_latest_invoice_id?: string | null
          suspended_at?: string | null
          trial_ends_at?: string | null
          updated_at?: string
        }
        Update: {
          billing_period?: string
          cancel_at?: string | null
          cancelled_at?: string | null
          company_id?: string
          created_at?: string
          current_period_end?: string | null
          current_period_start?: string | null
          discount_percent?: number | null
          grace_until?: string | null
          id?: string
          last_payment_at?: string | null
          last_payment_failed_at?: string | null
          next_billing_at?: string | null
          next_payment_attempt_at?: string | null
          payment_checkout_session_id?: string | null
          payment_customer_id?: string | null
          payment_price_id?: string | null
          payment_provider?: string | null
          payment_status?: string | null
          payment_subscription_id?: string | null
          plan_id?: string | null
          status?: string
          stripe_latest_invoice_id?: string | null
          suspended_at?: string | null
          trial_ends_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "company_subscriptions_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: true
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "company_subscriptions_plan_id_fkey"
            columns: ["plan_id"]
            isOneToOne: false
            referencedRelation: "subscription_plans"
            referencedColumns: ["id"]
          },
        ]
      }
      customers: {
        Row: {
          address: string | null
          address2: string | null
          anteckningar: string | null
          butiks_id: string | null
          cfar: string | null
          company_id: string | null
          contact_person: string | null
          created_at: string | null
          data_source: string | null
          email: string | null
          er_referens: string | null
          faktura_installningar: Json
          fax: string | null
          forsaljningskonto: string | null
          id: string
          is_active: boolean | null
          kund_nr: number | null
          kundtyp: string
          land: string | null
          landskod: string | null
          last_manual_edit_at: string | null
          last_manual_edit_by: string | null
          lev_adress: string | null
          lev_adress2: string | null
          lev_fax: string | null
          lev_land: string | null
          lev_landskod: string | null
          lev_namn: string | null
          lev_ort: string | null
          lev_postnr: string | null
          lev_telefon: string | null
          lev_telefon2: string | null
          leveranssatt: string | null
          leveransvillkor: string | null
          manual_fields: Json | null
          name: string
          org_nr: string | null
          org_nr_normalized: string | null
          ort: string | null
          payment_terms: number | null
          phone: string | null
          postnr: string | null
          sni: string | null
          source_api_version: string | null
          source_retrieved_at: string | null
          telefon2: string | null
          valuta: string | null
          var_referens: string | null
          vat_nummer: string | null
          webb: string | null
        }
        Insert: {
          address?: string | null
          address2?: string | null
          anteckningar?: string | null
          butiks_id?: string | null
          cfar?: string | null
          company_id?: string | null
          contact_person?: string | null
          created_at?: string | null
          data_source?: string | null
          email?: string | null
          er_referens?: string | null
          faktura_installningar?: Json
          fax?: string | null
          forsaljningskonto?: string | null
          id?: string
          is_active?: boolean | null
          kund_nr?: number | null
          kundtyp?: string
          land?: string | null
          landskod?: string | null
          last_manual_edit_at?: string | null
          last_manual_edit_by?: string | null
          lev_adress?: string | null
          lev_adress2?: string | null
          lev_fax?: string | null
          lev_land?: string | null
          lev_landskod?: string | null
          lev_namn?: string | null
          lev_ort?: string | null
          lev_postnr?: string | null
          lev_telefon?: string | null
          lev_telefon2?: string | null
          leveranssatt?: string | null
          leveransvillkor?: string | null
          manual_fields?: Json | null
          name: string
          org_nr?: string | null
          org_nr_normalized?: string | null
          ort?: string | null
          payment_terms?: number | null
          phone?: string | null
          postnr?: string | null
          sni?: string | null
          source_api_version?: string | null
          source_retrieved_at?: string | null
          telefon2?: string | null
          valuta?: string | null
          var_referens?: string | null
          vat_nummer?: string | null
          webb?: string | null
        }
        Update: {
          address?: string | null
          address2?: string | null
          anteckningar?: string | null
          butiks_id?: string | null
          cfar?: string | null
          company_id?: string | null
          contact_person?: string | null
          created_at?: string | null
          data_source?: string | null
          email?: string | null
          er_referens?: string | null
          faktura_installningar?: Json
          fax?: string | null
          forsaljningskonto?: string | null
          id?: string
          is_active?: boolean | null
          kund_nr?: number | null
          kundtyp?: string
          land?: string | null
          landskod?: string | null
          last_manual_edit_at?: string | null
          last_manual_edit_by?: string | null
          lev_adress?: string | null
          lev_adress2?: string | null
          lev_fax?: string | null
          lev_land?: string | null
          lev_landskod?: string | null
          lev_namn?: string | null
          lev_ort?: string | null
          lev_postnr?: string | null
          lev_telefon?: string | null
          lev_telefon2?: string | null
          leveranssatt?: string | null
          leveransvillkor?: string | null
          manual_fields?: Json | null
          name?: string
          org_nr?: string | null
          org_nr_normalized?: string | null
          ort?: string | null
          payment_terms?: number | null
          phone?: string | null
          postnr?: string | null
          sni?: string | null
          source_api_version?: string | null
          source_retrieved_at?: string | null
          telefon2?: string | null
          valuta?: string | null
          var_referens?: string | null
          vat_nummer?: string | null
          webb?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "customers_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      deadline_regel: {
        Row: {
          bolagsform: string | null
          giltig_fran: string
          giltig_till: string | null
          id: string
          kalla: string | null
          parametrar: Json
          uppdaterad_at: string
          uppgiftstyp: string
          variant: string | null
        }
        Insert: {
          bolagsform?: string | null
          giltig_fran?: string
          giltig_till?: string | null
          id?: string
          kalla?: string | null
          parametrar: Json
          uppdaterad_at?: string
          uppgiftstyp: string
          variant?: string | null
        }
        Update: {
          bolagsform?: string | null
          giltig_fran?: string
          giltig_till?: string | null
          id?: string
          kalla?: string | null
          parametrar?: Json
          uppdaterad_at?: string
          uppgiftstyp?: string
          variant?: string | null
        }
        Relationships: []
      }
      documents: {
        Row: {
          ai_attempts: number
          ai_cooldown_until: string | null
          ai_job_id: string | null
          ai_job_started_at: string | null
          ai_last_error: string | null
          ai_status: string | null
          company_id: string | null
          confidence: number | null
          created_at: string | null
          email_body: string | null
          email_from: string | null
          email_subject: string | null
          email_to: string | null
          file_name: string
          file_size: number | null
          id: string
          import_batch: string | null
          inbound_message_id: string | null
          kategori: string | null
          mime_type: string | null
          original_storage_path: string | null
          raderad_at: string | null
          received_at: string | null
          source: string | null
          status: string | null
          storage_path: string | null
          tolkad: boolean | null
          tolkning: Json | null
          verifikation_id: string | null
        }
        Insert: {
          ai_attempts?: number
          ai_cooldown_until?: string | null
          ai_job_id?: string | null
          ai_job_started_at?: string | null
          ai_last_error?: string | null
          ai_status?: string | null
          company_id?: string | null
          confidence?: number | null
          created_at?: string | null
          email_body?: string | null
          email_from?: string | null
          email_subject?: string | null
          email_to?: string | null
          file_name: string
          file_size?: number | null
          id?: string
          import_batch?: string | null
          inbound_message_id?: string | null
          kategori?: string | null
          mime_type?: string | null
          original_storage_path?: string | null
          raderad_at?: string | null
          received_at?: string | null
          source?: string | null
          status?: string | null
          storage_path?: string | null
          tolkad?: boolean | null
          tolkning?: Json | null
          verifikation_id?: string | null
        }
        Update: {
          ai_attempts?: number
          ai_cooldown_until?: string | null
          ai_job_id?: string | null
          ai_job_started_at?: string | null
          ai_last_error?: string | null
          ai_status?: string | null
          company_id?: string | null
          confidence?: number | null
          created_at?: string | null
          email_body?: string | null
          email_from?: string | null
          email_subject?: string | null
          email_to?: string | null
          file_name?: string
          file_size?: number | null
          id?: string
          import_batch?: string | null
          inbound_message_id?: string | null
          kategori?: string | null
          mime_type?: string | null
          original_storage_path?: string | null
          raderad_at?: string | null
          received_at?: string | null
          source?: string | null
          status?: string | null
          storage_path?: string | null
          tolkad?: boolean | null
          tolkning?: Json | null
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "documents_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "documents_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      download_audit_log: {
        Row: {
          company_id: string | null
          created_at: string | null
          file_count: number | null
          id: string
          kind: string | null
          section: string | null
          user_id: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          file_count?: number | null
          id?: string
          kind?: string | null
          section?: string | null
          user_id?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          file_count?: number | null
          id?: string
          kind?: string | null
          section?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      employees: {
        Row: {
          ack_bruttolon: number
          ack_prelskatt: number
          anstallningsdatum: string | null
          anstallningsform: string
          arbetsgivaravgift_procent: number
          bankkontonummer: string | null
          befattning: string | null
          clearingnr: string | null
          company_id: string
          created_at: string
          created_by: string | null
          efternamn: string | null
          epost: string | null
          fornamn: string | null
          id: string
          is_active: boolean
          kommun: string | null
          kontonr: string | null
          lonetyp: string
          manadslon: number | null
          namn: string | null
          personaltyp: string
          personnummer: string | null
          sidoinkomst: boolean
          skattekolumn: number | null
          skattetabell: number | null
          slutdatum: string | null
          telefon: string | null
          timlon: number | null
          undanta_arbetsgivaravgift: boolean
        }
        Insert: {
          ack_bruttolon?: number
          ack_prelskatt?: number
          anstallningsdatum?: string | null
          anstallningsform?: string
          arbetsgivaravgift_procent?: number
          bankkontonummer?: string | null
          befattning?: string | null
          clearingnr?: string | null
          company_id: string
          created_at?: string
          created_by?: string | null
          efternamn?: string | null
          epost?: string | null
          fornamn?: string | null
          id?: string
          is_active?: boolean
          kommun?: string | null
          kontonr?: string | null
          lonetyp?: string
          manadslon?: number | null
          namn?: string | null
          personaltyp?: string
          personnummer?: string | null
          sidoinkomst?: boolean
          skattekolumn?: number | null
          skattetabell?: number | null
          slutdatum?: string | null
          telefon?: string | null
          timlon?: number | null
          undanta_arbetsgivaravgift?: boolean
        }
        Update: {
          ack_bruttolon?: number
          ack_prelskatt?: number
          anstallningsdatum?: string | null
          anstallningsform?: string
          arbetsgivaravgift_procent?: number
          bankkontonummer?: string | null
          befattning?: string | null
          clearingnr?: string | null
          company_id?: string
          created_at?: string
          created_by?: string | null
          efternamn?: string | null
          epost?: string | null
          fornamn?: string | null
          id?: string
          is_active?: boolean
          kommun?: string | null
          kontonr?: string | null
          lonetyp?: string
          manadslon?: number | null
          namn?: string | null
          personaltyp?: string
          personnummer?: string | null
          sidoinkomst?: boolean
          skattekolumn?: number | null
          skattetabell?: number | null
          slutdatum?: string | null
          telefon?: string | null
          timlon?: number | null
          undanta_arbetsgivaravgift?: boolean
        }
        Relationships: []
      }
      extraction_corrections: {
        Row: {
          company_id: string
          confidence_before: number | null
          created_at: string
          created_by: string | null
          doc_type: string | null
          document_id: string | null
          field: string
          final_value: string | null
          id: string
          model: string | null
          original_value: string | null
          prompt_version: string | null
          supplier_id: string | null
        }
        Insert: {
          company_id: string
          confidence_before?: number | null
          created_at?: string
          created_by?: string | null
          doc_type?: string | null
          document_id?: string | null
          field: string
          final_value?: string | null
          id?: string
          model?: string | null
          original_value?: string | null
          prompt_version?: string | null
          supplier_id?: string | null
        }
        Update: {
          company_id?: string
          confidence_before?: number | null
          created_at?: string
          created_by?: string | null
          doc_type?: string | null
          document_id?: string | null
          field?: string
          final_value?: string | null
          id?: string
          model?: string | null
          original_value?: string | null
          prompt_version?: string | null
          supplier_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "extraction_corrections_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "extraction_corrections_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "extraction_corrections_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      fiscal_years: {
        Row: {
          company_id: string | null
          created_at: string | null
          end_date: string
          id: string
          start_date: string
          status: string | null
          year: number
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          end_date: string
          id?: string
          start_date: string
          status?: string | null
          year: number
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          end_date?: string
          id?: string
          start_date?: string
          status?: string | null
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "fiscal_years_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      help_feedback: {
        Row: {
          answer: string | null
          article_id: string | null
          article_slug: string | null
          comment: string | null
          company_id: string | null
          created_at: string
          id: string
          user_id: string | null
        }
        Insert: {
          answer?: string | null
          article_id?: string | null
          article_slug?: string | null
          comment?: string | null
          company_id?: string | null
          created_at?: string
          id?: string
          user_id?: string | null
        }
        Update: {
          answer?: string | null
          article_id?: string | null
          article_slug?: string | null
          comment?: string | null
          company_id?: string | null
          created_at?: string
          id?: string
          user_id?: string | null
        }
        Relationships: []
      }
      inbound_email_log: {
        Row: {
          attachment_count: number | null
          company_id: string | null
          created_at: string | null
          detail: string | null
          id: string
          message_id: string | null
          recipient: string | null
          sender: string | null
          status: string
          subject: string | null
        }
        Insert: {
          attachment_count?: number | null
          company_id?: string | null
          created_at?: string | null
          detail?: string | null
          id?: string
          message_id?: string | null
          recipient?: string | null
          sender?: string | null
          status: string
          subject?: string | null
        }
        Update: {
          attachment_count?: number | null
          company_id?: string | null
          created_at?: string | null
          detail?: string | null
          id?: string
          message_id?: string | null
          recipient?: string | null
          sender?: string | null
          status?: string
          subject?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inbound_email_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      inbox_addresses: {
        Row: {
          company_id: string
          created_at: string | null
          email_address: string
          id: string
          inbox_type: string
          is_active: boolean
          updated_at: string | null
        }
        Insert: {
          company_id: string
          created_at?: string | null
          email_address: string
          id?: string
          inbox_type: string
          is_active?: boolean
          updated_at?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string | null
          email_address?: string
          id?: string
          inbox_type?: string
          is_active?: boolean
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inbox_addresses_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      ink2_deklarationstidpunkt: {
        Row: {
          bokslutsar: number
          bokslutsmanad_fran: number
          bokslutsmanad_till: number
          deadline: string
          id: string
          kalla: string | null
        }
        Insert: {
          bokslutsar: number
          bokslutsmanad_fran: number
          bokslutsmanad_till: number
          deadline: string
          id?: string
          kalla?: string | null
        }
        Update: {
          bokslutsar?: number
          bokslutsmanad_fran?: number
          bokslutsmanad_till?: number
          deadline?: string
          id?: string
          kalla?: string | null
        }
        Relationships: []
      }
      inkommande_gods: {
        Row: {
          anteckning: string | null
          company_id: string
          created_at: string | null
          created_by: string | null
          datum: string
          foljesedel: string | null
          godsnr: number
          id: string
          leverans_id: string | null
          order_id: string | null
          status: string
        }
        Insert: {
          anteckning?: string | null
          company_id: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          foljesedel?: string | null
          godsnr: number
          id?: string
          leverans_id?: string | null
          order_id?: string | null
          status?: string
        }
        Update: {
          anteckning?: string | null
          company_id?: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          foljesedel?: string | null
          godsnr?: number
          id?: string
          leverans_id?: string | null
          order_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "inkommande_gods_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inkommande_gods_leverans_id_fkey"
            columns: ["leverans_id"]
            isOneToOne: false
            referencedRelation: "lager_leveranser"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inkommande_gods_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "inkopsordrar"
            referencedColumns: ["id"]
          },
        ]
      }
      inkopsorder_rader: {
        Row: {
          a_pris: number | null
          antal: number
          company_id: string
          id: string
          mottaget: number
          order_id: string
          product_id: string
        }
        Insert: {
          a_pris?: number | null
          antal: number
          company_id: string
          id?: string
          mottaget?: number
          order_id: string
          product_id: string
        }
        Update: {
          a_pris?: number | null
          antal?: number
          company_id?: string
          id?: string
          mottaget?: number
          order_id?: string
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "inkopsorder_rader_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inkopsorder_rader_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "inkopsordrar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inkopsorder_rader_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      inkopsordrar: {
        Row: {
          anteckning: string | null
          best_datum: string
          company_id: string
          created_at: string | null
          created_by: string | null
          id: string
          intern_referens: string | null
          lev_datum: string | null
          ordernr: number
          skickad_at: string | null
          status: string
          supplier_id: string | null
        }
        Insert: {
          anteckning?: string | null
          best_datum?: string
          company_id: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          intern_referens?: string | null
          lev_datum?: string | null
          ordernr: number
          skickad_at?: string | null
          status?: string
          supplier_id?: string | null
        }
        Update: {
          anteckning?: string | null
          best_datum?: string
          company_id?: string
          created_at?: string | null
          created_by?: string | null
          id?: string
          intern_referens?: string | null
          lev_datum?: string | null
          ordernr?: number
          skickad_at?: string | null
          status?: string
          supplier_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inkopsordrar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inkopsordrar_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      interna_nycklar: {
        Row: {
          created_at: string
          namn: string
          varde: string
        }
        Insert: {
          created_at?: string
          namn: string
          varde: string
        }
        Update: {
          created_at?: string
          namn?: string
          varde?: string
        }
        Relationships: []
      }
      invoice_rows: {
        Row: {
          description: string
          id: string
          invoice_id: string | null
          product_id: string | null
          quantity: number | null
          sort_order: number | null
          total: number | null
          unit_price: number | null
          vat_rate: number | null
        }
        Insert: {
          description: string
          id?: string
          invoice_id?: string | null
          product_id?: string | null
          quantity?: number | null
          sort_order?: number | null
          total?: number | null
          unit_price?: number | null
          vat_rate?: number | null
        }
        Update: {
          description?: string
          id?: string
          invoice_id?: string | null
          product_id?: string | null
          quantity?: number | null
          sort_order?: number | null
          total?: number | null
          unit_price?: number | null
          vat_rate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "invoice_rows_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoice_rows_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      invoices: {
        Row: {
          amount_excl_vat: number | null
          betalning_ver_id: string | null
          company_id: string | null
          created_at: string | null
          customer_id: string | null
          due_date: string
          id: string
          invoice_date: string
          invoice_nr: string
          krediterar_id: string | null
          leverans_datum: string | null
          message: string | null
          omvand_moms: boolean
          status: string | null
          total_amount: number | null
          typ: string
          vat_amount: number | null
          verifikation_id: string | null
        }
        Insert: {
          amount_excl_vat?: number | null
          betalning_ver_id?: string | null
          company_id?: string | null
          created_at?: string | null
          customer_id?: string | null
          due_date: string
          id?: string
          invoice_date: string
          invoice_nr: string
          krediterar_id?: string | null
          leverans_datum?: string | null
          message?: string | null
          omvand_moms?: boolean
          status?: string | null
          total_amount?: number | null
          typ?: string
          vat_amount?: number | null
          verifikation_id?: string | null
        }
        Update: {
          amount_excl_vat?: number | null
          betalning_ver_id?: string | null
          company_id?: string | null
          created_at?: string | null
          customer_id?: string | null
          due_date?: string
          id?: string
          invoice_date?: string
          invoice_nr?: string
          krediterar_id?: string | null
          leverans_datum?: string | null
          message?: string | null
          omvand_moms?: boolean
          status?: string | null
          total_amount?: number | null
          typ?: string
          vat_amount?: number | null
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "invoices_betalning_ver_id_fkey"
            columns: ["betalning_ver_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_krediterar_id_fkey"
            columns: ["krediterar_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "invoices_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      kivra_utskick: {
        Row: {
          amne: string | null
          company_id: string
          fel: string | null
          id: string
          kivra_content_key: string | null
          lage: string
          mottagare: string | null
          referens_id: string
          skickad_at: string
          skickad_av: string | null
          status: string
          typ: string
        }
        Insert: {
          amne?: string | null
          company_id: string
          fel?: string | null
          id?: string
          kivra_content_key?: string | null
          lage: string
          mottagare?: string | null
          referens_id: string
          skickad_at?: string
          skickad_av?: string | null
          status?: string
          typ: string
        }
        Update: {
          amne?: string | null
          company_id?: string
          fel?: string | null
          id?: string
          kivra_content_key?: string | null
          lage?: string
          mottagare?: string | null
          referens_id?: string
          skickad_at?: string
          skickad_av?: string | null
          status?: string
          typ?: string
        }
        Relationships: [
          {
            foreignKeyName: "kivra_utskick_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_abonnemangsfakturor: {
        Row: {
          belopp_ore: number
          betald_datum: string | null
          company_id: string
          created_at: string
          fakturadatum: string
          forfallodatum: string
          id: string
          skapad_av_email: string
          status: string
        }
        Insert: {
          belopp_ore: number
          betald_datum?: string | null
          company_id: string
          created_at?: string
          fakturadatum: string
          forfallodatum: string
          id?: string
          skapad_av_email: string
          status?: string
        }
        Update: {
          belopp_ore?: number
          betald_datum?: string | null
          company_id?: string
          created_at?: string
          fakturadatum?: string
          forfallodatum?: string
          id?: string
          skapad_av_email?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "konsol_abonnemangsfakturor_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_arenden: {
        Row: {
          beskrivning: string | null
          company_id: string
          created_at: string
          id: string
          prioritet: string
          rubrik: string
          skapad_av_email: string
          status: string
          updated_at: string
        }
        Insert: {
          beskrivning?: string | null
          company_id: string
          created_at?: string
          id?: string
          prioritet?: string
          rubrik: string
          skapad_av_email: string
          status?: string
          updated_at?: string
        }
        Update: {
          beskrivning?: string | null
          company_id?: string
          created_at?: string
          id?: string
          prioritet?: string
          rubrik?: string
          skapad_av_email?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "konsol_arenden_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_audit_logg: {
        Row: {
          action: string
          admin_email: string
          admin_user_id: string
          company_id: string | null
          created_at: string
          id: string
          params: Json
        }
        Insert: {
          action: string
          admin_email: string
          admin_user_id: string
          company_id?: string | null
          created_at?: string
          id?: string
          params?: Json
        }
        Update: {
          action?: string
          admin_email?: string
          admin_user_id?: string
          company_id?: string | null
          created_at?: string
          id?: string
          params?: Json
        }
        Relationships: [
          {
            foreignKeyName: "konsol_audit_logg_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_kundanteckningar: {
        Row: {
          company_id: string
          created_at: string
          id: string
          innehall: string
          skapad_av_email: string
          skapad_av_user_id: string
          typ: string
        }
        Insert: {
          company_id: string
          created_at?: string
          id?: string
          innehall: string
          skapad_av_email: string
          skapad_av_user_id: string
          typ?: string
        }
        Update: {
          company_id?: string
          created_at?: string
          id?: string
          innehall?: string
          skapad_av_email?: string
          skapad_av_user_id?: string
          typ?: string
        }
        Relationships: [
          {
            foreignKeyName: "konsol_kundanteckningar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_kundprofiler: {
        Row: {
          ansvarig: string | null
          company_id: string
          kundtyp: string
          manadspris_ore: number
          prisplan: string
          rabatt_procent: number
          rabatt_tom: string | null
          testperiod_manader: number
          updated_at: string
          updated_by_email: string
          uppfoljning_datum: string | null
        }
        Insert: {
          ansvarig?: string | null
          company_id: string
          kundtyp?: string
          manadspris_ore?: number
          prisplan?: string
          rabatt_procent?: number
          rabatt_tom?: string | null
          testperiod_manader?: number
          updated_at?: string
          updated_by_email: string
          uppfoljning_datum?: string | null
        }
        Update: {
          ansvarig?: string | null
          company_id?: string
          kundtyp?: string
          manadspris_ore?: number
          prisplan?: string
          rabatt_procent?: number
          rabatt_tom?: string | null
          testperiod_manader?: number
          updated_at?: string
          updated_by_email?: string
          uppfoljning_datum?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "konsol_kundprofiler_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: true
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_livscykel_steg: {
        Row: {
          company_id: string
          id: string
          notering: string | null
          status: string
          steg_key: string
          updated_at: string
          uppdaterad_av_email: string
        }
        Insert: {
          company_id: string
          id?: string
          notering?: string | null
          status?: string
          steg_key: string
          updated_at?: string
          uppdaterad_av_email: string
        }
        Update: {
          company_id?: string
          id?: string
          notering?: string | null
          status?: string
          steg_key?: string
          updated_at?: string
          uppdaterad_av_email?: string
        }
        Relationships: [
          {
            foreignKeyName: "konsol_livscykel_steg_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      konsol_support_samtycken: {
        Row: {
          aterkallad_at: string | null
          beviljad_av_email: string
          beviljad_av_user_id: string
          company_id: string
          created_at: string
          giltig_till: string
          id: string
        }
        Insert: {
          aterkallad_at?: string | null
          beviljad_av_email: string
          beviljad_av_user_id: string
          company_id: string
          created_at?: string
          giltig_till: string
          id?: string
        }
        Update: {
          aterkallad_at?: string | null
          beviljad_av_email?: string
          beviljad_av_user_id?: string
          company_id?: string
          created_at?: string
          giltig_till?: string
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "konsol_support_samtycken_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      kyc_assessments: {
        Row: {
          anteckningar: string | null
          beslutad_at: string | null
          company_id: string
          created_at: string
          giltig_till: string | null
          granskad_av: string | null
          id: string
          identitet_kontrollerad_at: string | null
          pep_kontrollerad_at: string | null
          pep_traff: boolean | null
          riskklass: string | null
          sanktion_kontrollerad_at: string | null
          sanktion_traff: boolean | null
          status: string
          syfte_och_art: string | null
          verklig_huvudman_kontrollerad_at: string | null
        }
        Insert: {
          anteckningar?: string | null
          beslutad_at?: string | null
          company_id: string
          created_at?: string
          giltig_till?: string | null
          granskad_av?: string | null
          id?: string
          identitet_kontrollerad_at?: string | null
          pep_kontrollerad_at?: string | null
          pep_traff?: boolean | null
          riskklass?: string | null
          sanktion_kontrollerad_at?: string | null
          sanktion_traff?: boolean | null
          status?: string
          syfte_och_art?: string | null
          verklig_huvudman_kontrollerad_at?: string | null
        }
        Update: {
          anteckningar?: string | null
          beslutad_at?: string | null
          company_id?: string
          created_at?: string
          giltig_till?: string | null
          granskad_av?: string | null
          id?: string
          identitet_kontrollerad_at?: string | null
          pep_kontrollerad_at?: string | null
          pep_traff?: boolean | null
          riskklass?: string | null
          sanktion_kontrollerad_at?: string | null
          sanktion_traff?: boolean | null
          status?: string
          syfte_och_art?: string | null
          verklig_huvudman_kontrollerad_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "kyc_assessments_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      lager_handelser: {
        Row: {
          a_pris: number | null
          antal: number
          batchnr: string | null
          company_id: string
          created_at: string | null
          created_by: string | null
          datum: string
          id: string
          inventering_id: string | null
          invoice_id: string | null
          kommentar: string | null
          leverans_id: string | null
          product_id: string
          supplier_invoice_id: string | null
          typ: string
        }
        Insert: {
          a_pris?: number | null
          antal: number
          batchnr?: string | null
          company_id: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          id?: string
          inventering_id?: string | null
          invoice_id?: string | null
          kommentar?: string | null
          leverans_id?: string | null
          product_id: string
          supplier_invoice_id?: string | null
          typ: string
        }
        Update: {
          a_pris?: number | null
          antal?: number
          batchnr?: string | null
          company_id?: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          id?: string
          inventering_id?: string | null
          invoice_id?: string | null
          kommentar?: string | null
          leverans_id?: string | null
          product_id?: string
          supplier_invoice_id?: string | null
          typ?: string
        }
        Relationships: [
          {
            foreignKeyName: "lager_handelser_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_handelser_inventering_id_fkey"
            columns: ["inventering_id"]
            isOneToOne: false
            referencedRelation: "lager_inventeringar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_handelser_invoice_id_fkey"
            columns: ["invoice_id"]
            isOneToOne: false
            referencedRelation: "invoices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_handelser_leverans_id_fkey"
            columns: ["leverans_id"]
            isOneToOne: false
            referencedRelation: "lager_leveranser"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_handelser_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_handelser_supplier_invoice_id_fkey"
            columns: ["supplier_invoice_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id"]
          },
        ]
      }
      lager_inventering_rader: {
        Row: {
          a_pris: number | null
          company_id: string
          id: string
          inventering_id: string
          product_id: string
          raknat: number | null
          saldo_vid_rakning: number | null
          varde: number | null
        }
        Insert: {
          a_pris?: number | null
          company_id: string
          id?: string
          inventering_id: string
          product_id: string
          raknat?: number | null
          saldo_vid_rakning?: number | null
          varde?: number | null
        }
        Update: {
          a_pris?: number | null
          company_id?: string
          id?: string
          inventering_id?: string
          product_id?: string
          raknat?: number | null
          saldo_vid_rakning?: number | null
          varde?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "lager_inventering_rader_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_inventering_rader_inventering_id_fkey"
            columns: ["inventering_id"]
            isOneToOne: false
            referencedRelation: "lager_inventeringar"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lager_inventering_rader_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      lager_inventeringar: {
        Row: {
          ansvarig: string | null
          benamning: string
          company_id: string
          created_at: string | null
          created_by: string | null
          datum: string
          forsakran_at: string | null
          forsakran_namn: string | null
          forsakran_user_id: string | null
          id: string
          nr: number
          status: string
          totalt_varde: number | null
        }
        Insert: {
          ansvarig?: string | null
          benamning: string
          company_id: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          forsakran_at?: string | null
          forsakran_namn?: string | null
          forsakran_user_id?: string | null
          id?: string
          nr: number
          status?: string
          totalt_varde?: number | null
        }
        Update: {
          ansvarig?: string | null
          benamning?: string
          company_id?: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          forsakran_at?: string | null
          forsakran_namn?: string | null
          forsakran_user_id?: string | null
          id?: string
          nr?: number
          status?: string
          totalt_varde?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "lager_inventeringar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      lager_leveranser: {
        Row: {
          anteckning: string | null
          company_id: string
          created_at: string | null
          created_by: string | null
          datum: string
          id: string
          leveransnr: number
          status: string
          typ: string
        }
        Insert: {
          anteckning?: string | null
          company_id: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          id?: string
          leveransnr: number
          status?: string
          typ: string
        }
        Update: {
          anteckning?: string | null
          company_id?: string
          created_at?: string | null
          created_by?: string | null
          datum?: string
          id?: string
          leveransnr?: number
          status?: string
          typ?: string
        }
        Relationships: [
          {
            foreignKeyName: "lager_leveranser_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      lonebesked: {
        Row: {
          ag_avgift: number
          ag_procent: number | null
          bruttolon: number
          company_id: string
          created_at: string
          employee_id: string | null
          id: string
          namn: string
          nettolon: number
          personnummer: string | null
          run_id: string
          sidoinkomst: boolean
          skatteavdrag: number
          skattekolumn: number | null
          skattetabell: number | null
          sort_order: number
          tillagg: Json
        }
        Insert: {
          ag_avgift?: number
          ag_procent?: number | null
          bruttolon?: number
          company_id: string
          created_at?: string
          employee_id?: string | null
          id?: string
          namn: string
          nettolon?: number
          personnummer?: string | null
          run_id: string
          sidoinkomst?: boolean
          skatteavdrag?: number
          skattekolumn?: number | null
          skattetabell?: number | null
          sort_order?: number
          tillagg?: Json
        }
        Update: {
          ag_avgift?: number
          ag_procent?: number | null
          bruttolon?: number
          company_id?: string
          created_at?: string
          employee_id?: string | null
          id?: string
          namn?: string
          nettolon?: number
          personnummer?: string | null
          run_id?: string
          sidoinkomst?: boolean
          skatteavdrag?: number
          skattekolumn?: number | null
          skattetabell?: number | null
          sort_order?: number
          tillagg?: Json
        }
        Relationships: [
          {
            foreignKeyName: "lonebesked_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "lonekorningar"
            referencedColumns: ["id"]
          },
        ]
      }
      lonekorningar: {
        Row: {
          beskrivning: string | null
          bokford: boolean
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          period: string
          status: string
          utbetalningsdag: string
          verifikation_id: string | null
        }
        Insert: {
          beskrivning?: string | null
          bokford?: boolean
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          period: string
          status?: string
          utbetalningsdag: string
          verifikation_id?: string | null
        }
        Update: {
          beskrivning?: string | null
          bokford?: boolean
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          period?: string
          status?: string
          utbetalningsdag?: string
          verifikation_id?: string | null
        }
        Relationships: []
      }
      mcp_audit_log: {
        Row: {
          company_id: string | null
          created_at: string
          error: string | null
          id: string
          params: Json
          status: string
          tool: string
          user_id: string
        }
        Insert: {
          company_id?: string | null
          created_at?: string
          error?: string | null
          id?: string
          params?: Json
          status: string
          tool: string
          user_id: string
        }
        Update: {
          company_id?: string | null
          created_at?: string
          error?: string | null
          id?: string
          params?: Json
          status?: string
          tool?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "mcp_audit_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      mcp_confirm_tokens: {
        Row: {
          company_id: string
          created_at: string
          expires_at: string
          id: string
          idempotency_key: string | null
          payload: Json
          tool: string
          used_at: string | null
          user_id: string
          verifikation_id: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          expires_at: string
          id?: string
          idempotency_key?: string | null
          payload: Json
          tool: string
          used_at?: string | null
          user_id: string
          verifikation_id?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          expires_at?: string
          id?: string
          idempotency_key?: string | null
          payload?: Json
          tool?: string
          used_at?: string | null
          user_id?: string
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "mcp_confirm_tokens_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_control_comments: {
        Row: {
          body: string
          company_id: string
          created_at: string
          id: string
          item_id: string
          user_id: string | null
        }
        Insert: {
          body: string
          company_id: string
          created_at?: string
          id?: string
          item_id: string
          user_id?: string | null
        }
        Update: {
          body?: string
          company_id?: string
          created_at?: string
          id?: string
          item_id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "monthly_control_comments_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "monthly_control_comments_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "monthly_control_items"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_control_events: {
        Row: {
          company_id: string
          created_at: string
          detail: Json
          event_type: string
          id: string
          item_id: string | null
          monthly_control_id: string | null
          user_id: string | null
        }
        Insert: {
          company_id: string
          created_at?: string
          detail?: Json
          event_type: string
          id?: string
          item_id?: string | null
          monthly_control_id?: string | null
          user_id?: string | null
        }
        Update: {
          company_id?: string
          created_at?: string
          detail?: Json
          event_type?: string
          id?: string
          item_id?: string | null
          monthly_control_id?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "monthly_control_events_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "monthly_control_events_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "monthly_control_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "monthly_control_events_monthly_control_id_fkey"
            columns: ["monthly_control_id"]
            isOneToOne: false
            referencedRelation: "monthly_controls"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_control_items: {
        Row: {
          action_url: string | null
          assigned_to: string | null
          company_id: string
          created_at: string
          description: string | null
          due_date: string | null
          id: string
          ignored_reason: string | null
          module: string
          monthly_control_id: string
          priority: string
          related_id: string | null
          related_type: string | null
          resolved_at: string | null
          resolved_by: string | null
          rule_key: string
          source_data: Json
          status: string
          suggested_action: string | null
          title: string
          updated_at: string
        }
        Insert: {
          action_url?: string | null
          assigned_to?: string | null
          company_id: string
          created_at?: string
          description?: string | null
          due_date?: string | null
          id?: string
          ignored_reason?: string | null
          module: string
          monthly_control_id: string
          priority?: string
          related_id?: string | null
          related_type?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          rule_key: string
          source_data?: Json
          status?: string
          suggested_action?: string | null
          title: string
          updated_at?: string
        }
        Update: {
          action_url?: string | null
          assigned_to?: string | null
          company_id?: string
          created_at?: string
          description?: string | null
          due_date?: string | null
          id?: string
          ignored_reason?: string | null
          module?: string
          monthly_control_id?: string
          priority?: string
          related_id?: string | null
          related_type?: string | null
          resolved_at?: string | null
          resolved_by?: string | null
          rule_key?: string
          source_data?: Json
          status?: string
          suggested_action?: string | null
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "monthly_control_items_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "monthly_control_items_monthly_control_id_fkey"
            columns: ["monthly_control_id"]
            isOneToOne: false
            referencedRelation: "monthly_controls"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_controls: {
        Row: {
          closed_at: string | null
          company_id: string
          created_at: string
          critical_count: number
          high_count: number
          id: string
          last_run_at: string | null
          low_count: number
          month: number
          normal_count: number
          progress_percent: number
          resolved_count: number
          status: string
          updated_at: string
          year: number
        }
        Insert: {
          closed_at?: string | null
          company_id: string
          created_at?: string
          critical_count?: number
          high_count?: number
          id?: string
          last_run_at?: string | null
          low_count?: number
          month: number
          normal_count?: number
          progress_percent?: number
          resolved_count?: number
          status?: string
          updated_at?: string
          year: number
        }
        Update: {
          closed_at?: string | null
          company_id?: string
          created_at?: string
          critical_count?: number
          high_count?: number
          id?: string
          last_run_at?: string | null
          low_count?: number
          month?: number
          normal_count?: number
          progress_percent?: number
          resolved_count?: number
          status?: string
          updated_at?: string
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "monthly_controls_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_deliveries: {
        Row: {
          channel: string | null
          clicked_at: string | null
          created_at: string | null
          delivered_at: string | null
          failed_at: string | null
          failure_reason: string | null
          id: string
          last_attempt_at: string | null
          opened_at: string | null
          provider: string | null
          provider_message_id: string | null
          queue_id: string | null
          status: string | null
        }
        Insert: {
          channel?: string | null
          clicked_at?: string | null
          created_at?: string | null
          delivered_at?: string | null
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          last_attempt_at?: string | null
          opened_at?: string | null
          provider?: string | null
          provider_message_id?: string | null
          queue_id?: string | null
          status?: string | null
        }
        Update: {
          channel?: string | null
          clicked_at?: string | null
          created_at?: string | null
          delivered_at?: string | null
          failed_at?: string | null
          failure_reason?: string | null
          id?: string
          last_attempt_at?: string | null
          opened_at?: string | null
          provider?: string | null
          provider_message_id?: string | null
          queue_id?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notification_deliveries_queue_id_fkey"
            columns: ["queue_id"]
            isOneToOne: true
            referencedRelation: "notification_queue"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_events: {
        Row: {
          acknowledged_at: string | null
          acknowledged_by: string | null
          actor_user_id: string | null
          company_id: string | null
          created_at: string | null
          dedupe_key: string | null
          event_type: string
          id: string
          object_id: string | null
          object_type: string | null
          payload: Json
        }
        Insert: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          actor_user_id?: string | null
          company_id?: string | null
          created_at?: string | null
          dedupe_key?: string | null
          event_type: string
          id?: string
          object_id?: string | null
          object_type?: string | null
          payload?: Json
        }
        Update: {
          acknowledged_at?: string | null
          acknowledged_by?: string | null
          actor_user_id?: string | null
          company_id?: string | null
          created_at?: string | null
          dedupe_key?: string | null
          event_type?: string
          id?: string
          object_id?: string | null
          object_type?: string | null
          payload?: Json
        }
        Relationships: [
          {
            foreignKeyName: "notification_events_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_preferences: {
        Row: {
          channel: string
          company_id: string | null
          enabled: boolean
          event_type: string
          id: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          channel: string
          company_id?: string | null
          enabled?: boolean
          event_type: string
          id?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          channel?: string
          company_id?: string | null
          enabled?: boolean
          event_type?: string
          id?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_preferences_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_provider_logs: {
        Row: {
          channel: string | null
          created_at: string | null
          id: string
          meta: Json
          provider: string | null
          queue_id: string | null
          status: string | null
        }
        Insert: {
          channel?: string | null
          created_at?: string | null
          id?: string
          meta?: Json
          provider?: string | null
          queue_id?: string | null
          status?: string | null
        }
        Update: {
          channel?: string | null
          created_at?: string | null
          id?: string
          meta?: Json
          provider?: string | null
          queue_id?: string | null
          status?: string | null
        }
        Relationships: []
      }
      notification_queue: {
        Row: {
          attempt_count: number
          body: string | null
          channel: string
          company_id: string | null
          created_at: string | null
          error_message: string | null
          event_id: string | null
          id: string
          idempotency_key: string | null
          link_url: string | null
          max_attempts: number
          next_retry_at: string | null
          object_id: string | null
          object_type: string | null
          priority: string
          read_at: string | null
          scheduled_at: string | null
          status: string
          subject: string | null
          updated_at: string | null
          user_id: string | null
        }
        Insert: {
          attempt_count?: number
          body?: string | null
          channel: string
          company_id?: string | null
          created_at?: string | null
          error_message?: string | null
          event_id?: string | null
          id?: string
          idempotency_key?: string | null
          link_url?: string | null
          max_attempts?: number
          next_retry_at?: string | null
          object_id?: string | null
          object_type?: string | null
          priority?: string
          read_at?: string | null
          scheduled_at?: string | null
          status?: string
          subject?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Update: {
          attempt_count?: number
          body?: string | null
          channel?: string
          company_id?: string | null
          created_at?: string | null
          error_message?: string | null
          event_id?: string | null
          id?: string
          idempotency_key?: string | null
          link_url?: string | null
          max_attempts?: number
          next_retry_at?: string | null
          object_id?: string | null
          object_type?: string | null
          priority?: string
          read_at?: string | null
          scheduled_at?: string | null
          status?: string
          subject?: string | null
          updated_at?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "notification_queue_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_queue_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "notification_events"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_subscriptions: {
        Row: {
          auth: string | null
          channel: string
          created_at: string | null
          endpoint: string | null
          id: string
          is_active: boolean
          opt_in: boolean
          p256dh: string | null
          phone: string | null
          user_id: string
        }
        Insert: {
          auth?: string | null
          channel: string
          created_at?: string | null
          endpoint?: string | null
          id?: string
          is_active?: boolean
          opt_in?: boolean
          p256dh?: string | null
          phone?: string | null
          user_id: string
        }
        Update: {
          auth?: string | null
          channel?: string
          created_at?: string | null
          endpoint?: string | null
          id?: string
          is_active?: boolean
          opt_in?: boolean
          p256dh?: string | null
          phone?: string | null
          user_id?: string
        }
        Relationships: []
      }
      notification_templates: {
        Row: {
          body: string
          channel: string
          created_at: string | null
          event_type: string
          id: string
          is_active: boolean
          lang: string
          required_vars: string[]
          subject: string | null
          updated_at: string | null
        }
        Insert: {
          body: string
          channel: string
          created_at?: string | null
          event_type: string
          id?: string
          is_active?: boolean
          lang?: string
          required_vars?: string[]
          subject?: string | null
          updated_at?: string | null
        }
        Update: {
          body?: string
          channel?: string
          created_at?: string | null
          event_type?: string
          id?: string
          is_active?: boolean
          lang?: string
          required_vars?: string[]
          subject?: string | null
          updated_at?: string | null
        }
        Relationships: []
      }
      ocr_provider_config: {
        Row: {
          folio_base_url: string | null
          folio_enabled: boolean
          id: boolean
          updated_at: string | null
          updated_by: string | null
        }
        Insert: {
          folio_base_url?: string | null
          folio_enabled?: boolean
          id?: boolean
          updated_at?: string | null
          updated_by?: string | null
        }
        Update: {
          folio_base_url?: string | null
          folio_enabled?: boolean
          id?: boolean
          updated_at?: string | null
          updated_by?: string | null
        }
        Relationships: []
      }
      platform_admins: {
        Row: {
          created_at: string | null
          email: string
        }
        Insert: {
          created_at?: string | null
          email: string
        }
        Update: {
          created_at?: string | null
          email?: string
        }
        Relationships: []
      }
      platform_audit_log: {
        Row: {
          action: string
          actor_email: string | null
          actor_id: string | null
          created_at: string
          detail: Json
          id: string
          target: string | null
        }
        Insert: {
          action: string
          actor_email?: string | null
          actor_id?: string | null
          created_at?: string
          detail?: Json
          id?: string
          target?: string | null
        }
        Update: {
          action?: string
          actor_email?: string | null
          actor_id?: string | null
          created_at?: string
          detail?: Json
          id?: string
          target?: string | null
        }
        Relationships: []
      }
      platform_user_roles: {
        Row: {
          email: string
          granted_at: string
          granted_by: string | null
          id: string
          role: string
        }
        Insert: {
          email: string
          granted_at?: string
          granted_by?: string | null
          id?: string
          role: string
        }
        Update: {
          email?: string
          granted_at?: string
          granted_by?: string | null
          id?: string
          role?: string
        }
        Relationships: []
      }
      products: {
        Row: {
          account_nr: string | null
          article_nr: string | null
          bestallningspunkt: number | null
          company_id: string | null
          created_at: string | null
          id: string
          inkopspris: number | null
          is_active: boolean | null
          lagerplats: string | null
          lagervara: boolean
          name: string
          type: string | null
          unit: string | null
          unit_price: number | null
          vat_rate: number | null
        }
        Insert: {
          account_nr?: string | null
          article_nr?: string | null
          bestallningspunkt?: number | null
          company_id?: string | null
          created_at?: string | null
          id?: string
          inkopspris?: number | null
          is_active?: boolean | null
          lagerplats?: string | null
          lagervara?: boolean
          name: string
          type?: string | null
          unit?: string | null
          unit_price?: number | null
          vat_rate?: number | null
        }
        Update: {
          account_nr?: string | null
          article_nr?: string | null
          bestallningspunkt?: number | null
          company_id?: string | null
          created_at?: string | null
          id?: string
          inkopspris?: number | null
          is_active?: boolean | null
          lagerplats?: string | null
          lagervara?: boolean
          name?: string
          type?: string | null
          unit?: string | null
          unit_price?: number | null
          vat_rate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      robo_bp_audit_log: {
        Row: {
          action: string
          company_id: string
          created_at: string
          detail: Json
          id: string
          user_id: string | null
        }
        Insert: {
          action: string
          company_id: string
          created_at?: string
          detail?: Json
          id?: string
          user_id?: string | null
        }
        Update: {
          action?: string
          company_id?: string
          created_at?: string
          detail?: Json
          id?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "robo_bp_audit_log_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      robo_bp_checks: {
        Row: {
          affected_objects: Json
          company_id: string
          confidence_label: string | null
          conversation_id: string | null
          created_at: string
          created_by: string | null
          decision_basis: string | null
          description: string | null
          fiscal_year_id: string | null
          id: string
          risk_level: string
          source: string
          status: string
          title: string
          updated_at: string
          view: string | null
        }
        Insert: {
          affected_objects?: Json
          company_id: string
          confidence_label?: string | null
          conversation_id?: string | null
          created_at?: string
          created_by?: string | null
          decision_basis?: string | null
          description?: string | null
          fiscal_year_id?: string | null
          id?: string
          risk_level?: string
          source?: string
          status?: string
          title: string
          updated_at?: string
          view?: string | null
        }
        Update: {
          affected_objects?: Json
          company_id?: string
          confidence_label?: string | null
          conversation_id?: string | null
          created_at?: string
          created_by?: string | null
          decision_basis?: string | null
          description?: string | null
          fiscal_year_id?: string | null
          id?: string
          risk_level?: string
          source?: string
          status?: string
          title?: string
          updated_at?: string
          view?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "robo_bp_checks_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      robo_bp_control_runs: {
        Row: {
          company_id: string
          fiscal_year_id: string | null
          id: string
          started_at: string
          started_by: string | null
          status: string
          summary: Json
        }
        Insert: {
          company_id: string
          fiscal_year_id?: string | null
          id?: string
          started_at?: string
          started_by?: string | null
          status?: string
          summary?: Json
        }
        Update: {
          company_id?: string
          fiscal_year_id?: string | null
          id?: string
          started_at?: string
          started_by?: string | null
          status?: string
          summary?: Json
        }
        Relationships: []
      }
      robo_bp_conversations: {
        Row: {
          company_id: string
          context_view: string | null
          created_at: string
          fiscal_year_id: string | null
          id: string
          title: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          company_id: string
          context_view?: string | null
          created_at?: string
          fiscal_year_id?: string | null
          id?: string
          title?: string | null
          updated_at?: string
          user_id?: string
        }
        Update: {
          company_id?: string
          context_view?: string | null
          created_at?: string
          fiscal_year_id?: string | null
          id?: string
          title?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "robo_bp_conversations_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      robo_bp_messages: {
        Row: {
          basis: string[] | null
          company_id: string
          content: string
          conversation_id: string
          created_at: string
          id: string
          risk_level: string | null
          role: string
          structured: Json | null
          user_id: string | null
        }
        Insert: {
          basis?: string[] | null
          company_id: string
          content?: string
          conversation_id: string
          created_at?: string
          id?: string
          risk_level?: string | null
          role: string
          structured?: Json | null
          user_id?: string | null
        }
        Update: {
          basis?: string[] | null
          company_id?: string
          content?: string
          conversation_id?: string
          created_at?: string
          id?: string
          risk_level?: string | null
          role?: string
          structured?: Json | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "robo_bp_messages_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "robo_bp_messages_conversation_id_fkey"
            columns: ["conversation_id"]
            isOneToOne: false
            referencedRelation: "robo_bp_conversations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "robo_bp_messages_konv_bolag_fkey"
            columns: ["conversation_id", "company_id"]
            isOneToOne: false
            referencedRelation: "robo_bp_conversations"
            referencedColumns: ["id", "company_id"]
          },
        ]
      }
      robo_bp_rules: {
        Row: {
          active: boolean
          approved_by: string | null
          company_id: string
          confidence: number
          counterparty: string
          created_at: string
          created_by: string | null
          id: string
          last_used_at: string | null
          org_nr: string | null
          source: string
          success_count: number
          suggested_account: string | null
          vat_handling: string | null
        }
        Insert: {
          active?: boolean
          approved_by?: string | null
          company_id: string
          confidence?: number
          counterparty: string
          created_at?: string
          created_by?: string | null
          id?: string
          last_used_at?: string | null
          org_nr?: string | null
          source?: string
          success_count?: number
          suggested_account?: string | null
          vat_handling?: string | null
        }
        Update: {
          active?: boolean
          approved_by?: string | null
          company_id?: string
          confidence?: number
          counterparty?: string
          created_at?: string
          created_by?: string | null
          id?: string
          last_used_at?: string | null
          org_nr?: string | null
          source?: string
          success_count?: number
          suggested_account?: string | null
          vat_handling?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "robo_bp_rules_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      robo_bp_settings: {
        Row: {
          categories: Json
          company_id: string
          moms_period: string | null
          sensitivity: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          categories?: Json
          company_id: string
          moms_period?: string | null
          sensitivity?: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          categories?: Json
          company_id?: string
          moms_period?: string | null
          sensitivity?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: []
      }
      salaries: {
        Row: {
          company_id: string | null
          created_at: string | null
          employee_name: string
          employer_fee: number | null
          gross_salary: number | null
          id: string
          net_salary: number | null
          period: string
          personal_nr: string | null
          status: string | null
          tax_deduction: number | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          employee_name: string
          employer_fee?: number | null
          gross_salary?: number | null
          id?: string
          net_salary?: number | null
          period: string
          personal_nr?: string | null
          status?: string | null
          tax_deduction?: number | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          employee_name?: string
          employer_fee?: number | null
          gross_salary?: number | null
          id?: string
          net_salary?: number | null
          period?: string
          personal_nr?: string | null
          status?: string | null
          tax_deduction?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "salaries_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      sie_imports: {
        Row: {
          accounts_created: number
          company_id: string
          created_at: string
          created_by: string | null
          encoding: string | null
          file_name: string
          id: string
          reverted_at: string | null
          reverted_by: string | null
          status: string
          ver_count: number
        }
        Insert: {
          accounts_created?: number
          company_id: string
          created_at?: string
          created_by?: string | null
          encoding?: string | null
          file_name?: string
          id?: string
          reverted_at?: string | null
          reverted_by?: string | null
          status?: string
          ver_count?: number
        }
        Update: {
          accounts_created?: number
          company_id?: string
          created_at?: string
          created_by?: string | null
          encoding?: string | null
          file_name?: string
          id?: string
          reverted_at?: string | null
          reverted_by?: string | null
          status?: string
          ver_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "sie_imports_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      skattekonto_regler: {
        Row: {
          aktiv: boolean
          company_id: string
          created_at: string
          created_by: string | null
          id: string
          matchtext: string
          motkonto: string
        }
        Insert: {
          aktiv?: boolean
          company_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          matchtext: string
          motkonto: string
        }
        Update: {
          aktiv?: boolean
          company_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          matchtext?: string
          motkonto?: string
        }
        Relationships: [
          {
            foreignKeyName: "skattekonto_regler_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      stripe_event_log: {
        Row: {
          created_at: string
          event_id: string
          type: string | null
        }
        Insert: {
          created_at?: string
          event_id: string
          type?: string | null
        }
        Update: {
          created_at?: string
          event_id?: string
          type?: string | null
        }
        Relationships: []
      }
      subscription_plans: {
        Row: {
          created_at: string
          currency: string
          description: string | null
          features: Json
          id: string
          is_active: boolean
          max_ai_operations_per_month: number | null
          max_companies: number | null
          max_documents_per_month: number | null
          max_invoices_per_month: number | null
          max_storage_mb: number | null
          max_users: number | null
          monthly_price: number
          name: string
          sort_order: number
          stripe_price_monthly: string | null
          stripe_price_yearly: string | null
          stripe_product_id: string | null
          support_level: string | null
          updated_at: string
          yearly_price: number
        }
        Insert: {
          created_at?: string
          currency?: string
          description?: string | null
          features?: Json
          id?: string
          is_active?: boolean
          max_ai_operations_per_month?: number | null
          max_companies?: number | null
          max_documents_per_month?: number | null
          max_invoices_per_month?: number | null
          max_storage_mb?: number | null
          max_users?: number | null
          monthly_price?: number
          name: string
          sort_order?: number
          stripe_price_monthly?: string | null
          stripe_price_yearly?: string | null
          stripe_product_id?: string | null
          support_level?: string | null
          updated_at?: string
          yearly_price?: number
        }
        Update: {
          created_at?: string
          currency?: string
          description?: string | null
          features?: Json
          id?: string
          is_active?: boolean
          max_ai_operations_per_month?: number | null
          max_companies?: number | null
          max_documents_per_month?: number | null
          max_invoices_per_month?: number | null
          max_storage_mb?: number | null
          max_users?: number | null
          monthly_price?: number
          name?: string
          sort_order?: number
          stripe_price_monthly?: string | null
          stripe_price_yearly?: string | null
          stripe_product_id?: string | null
          support_level?: string | null
          updated_at?: string
          yearly_price?: number
        }
        Relationships: []
      }
      supplier_accounting_rules: {
        Row: {
          account_name: string | null
          account_number: string
          allocation_pattern: Json | null
          belopp_type: string | null
          company_id: string
          confidence_score: number
          confirmation_count: number
          correction_count: number
          created_at: string
          created_by: string | null
          document_type: string | null
          id: string
          invoice_category: string | null
          line_keyword: string | null
          merchant_name: string | null
          status: string
          supplier_id: string | null
          supplier_name: string | null
          supplier_org_number: string | null
          updated_at: string
          updated_by: string | null
          vat_account: string | null
          vat_rate: number | null
        }
        Insert: {
          account_name?: string | null
          account_number: string
          allocation_pattern?: Json | null
          belopp_type?: string | null
          company_id: string
          confidence_score?: number
          confirmation_count?: number
          correction_count?: number
          created_at?: string
          created_by?: string | null
          document_type?: string | null
          id?: string
          invoice_category?: string | null
          line_keyword?: string | null
          merchant_name?: string | null
          status?: string
          supplier_id?: string | null
          supplier_name?: string | null
          supplier_org_number?: string | null
          updated_at?: string
          updated_by?: string | null
          vat_account?: string | null
          vat_rate?: number | null
        }
        Update: {
          account_name?: string | null
          account_number?: string
          allocation_pattern?: Json | null
          belopp_type?: string | null
          company_id?: string
          confidence_score?: number
          confirmation_count?: number
          correction_count?: number
          created_at?: string
          created_by?: string | null
          document_type?: string | null
          id?: string
          invoice_category?: string | null
          line_keyword?: string | null
          merchant_name?: string | null
          status?: string
          supplier_id?: string | null
          supplier_name?: string | null
          supplier_org_number?: string | null
          updated_at?: string
          updated_by?: string | null
          vat_account?: string | null
          vat_rate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_accounting_rules_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_accounting_rules_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_invoices: {
        Row: {
          amount_excl_vat: number | null
          betalning_ver_id: string | null
          bokford: boolean
          company_id: string | null
          created_at: string | null
          created_by: string | null
          currency: string | null
          document_id: string | null
          due_date: string | null
          id: string
          invoice_date: string | null
          invoice_nr: string | null
          kostnadskonto: string | null
          kreditfaktura: boolean | null
          lopnr: number | null
          makulerad: boolean
          momstyp: string
          ocr: string | null
          paid_amount: number
          paid_date: string | null
          status: string | null
          supplier_id: string | null
          total_amount: number | null
          vat_amount: number | null
          verifikation_id: string | null
        }
        Insert: {
          amount_excl_vat?: number | null
          betalning_ver_id?: string | null
          bokford?: boolean
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          currency?: string | null
          document_id?: string | null
          due_date?: string | null
          id?: string
          invoice_date?: string | null
          invoice_nr?: string | null
          kostnadskonto?: string | null
          kreditfaktura?: boolean | null
          lopnr?: number | null
          makulerad?: boolean
          momstyp?: string
          ocr?: string | null
          paid_amount?: number
          paid_date?: string | null
          status?: string | null
          supplier_id?: string | null
          total_amount?: number | null
          vat_amount?: number | null
          verifikation_id?: string | null
        }
        Update: {
          amount_excl_vat?: number | null
          betalning_ver_id?: string | null
          bokford?: boolean
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          currency?: string | null
          document_id?: string | null
          due_date?: string | null
          id?: string
          invoice_date?: string | null
          invoice_nr?: string | null
          kostnadskonto?: string | null
          kreditfaktura?: boolean | null
          lopnr?: number | null
          makulerad?: boolean
          momstyp?: string
          ocr?: string | null
          paid_amount?: number
          paid_date?: string | null
          status?: string | null
          supplier_id?: string | null
          total_amount?: number | null
          vat_amount?: number | null
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoices_betalning_ver_id_fkey"
            columns: ["betalning_ver_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_document_id_fkey"
            columns: ["document_id"]
            isOneToOne: false
            referencedRelation: "documents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          address: string | null
          aktiv: boolean | null
          anteckning: string | null
          artikelregistrering: boolean | null
          avgiftskod: string | null
          bank: string | null
          bankgiro: string | null
          betalkod: string | null
          betalningsvillkor: string | null
          bic: string | null
          category: string | null
          cfar: string | null
          clearingnr: string | null
          company_id: string | null
          created_at: string | null
          default_motkonto: string | null
          email: string | null
          faktura_adress: string | null
          faktura_adress2: string | null
          fax: string | null
          iban: string | null
          id: string
          inaktivera_betalfil: boolean | null
          is_active: boolean | null
          konteringsmall: string | null
          kontonr: string | null
          kontotyp: string | null
          kundnummer: string | null
          land: string | null
          landskod: string | null
          leverantorsnr: string | null
          momstyp: string | null
          name: string
          oresavrundning: boolean | null
          org_nr: string | null
          ort: string | null
          phone: string | null
          plusgiro: string | null
          postnr: string | null
          referens: string | null
          sni: string | null
          telefon2: string | null
          valuta: string | null
          vat_nummer: string | null
          webb: string | null
        }
        Insert: {
          address?: string | null
          aktiv?: boolean | null
          anteckning?: string | null
          artikelregistrering?: boolean | null
          avgiftskod?: string | null
          bank?: string | null
          bankgiro?: string | null
          betalkod?: string | null
          betalningsvillkor?: string | null
          bic?: string | null
          category?: string | null
          cfar?: string | null
          clearingnr?: string | null
          company_id?: string | null
          created_at?: string | null
          default_motkonto?: string | null
          email?: string | null
          faktura_adress?: string | null
          faktura_adress2?: string | null
          fax?: string | null
          iban?: string | null
          id?: string
          inaktivera_betalfil?: boolean | null
          is_active?: boolean | null
          konteringsmall?: string | null
          kontonr?: string | null
          kontotyp?: string | null
          kundnummer?: string | null
          land?: string | null
          landskod?: string | null
          leverantorsnr?: string | null
          momstyp?: string | null
          name: string
          oresavrundning?: boolean | null
          org_nr?: string | null
          ort?: string | null
          phone?: string | null
          plusgiro?: string | null
          postnr?: string | null
          referens?: string | null
          sni?: string | null
          telefon2?: string | null
          valuta?: string | null
          vat_nummer?: string | null
          webb?: string | null
        }
        Update: {
          address?: string | null
          aktiv?: boolean | null
          anteckning?: string | null
          artikelregistrering?: boolean | null
          avgiftskod?: string | null
          bank?: string | null
          bankgiro?: string | null
          betalkod?: string | null
          betalningsvillkor?: string | null
          bic?: string | null
          category?: string | null
          cfar?: string | null
          clearingnr?: string | null
          company_id?: string | null
          created_at?: string | null
          default_motkonto?: string | null
          email?: string | null
          faktura_adress?: string | null
          faktura_adress2?: string | null
          fax?: string | null
          iban?: string | null
          id?: string
          inaktivera_betalfil?: boolean | null
          is_active?: boolean | null
          konteringsmall?: string | null
          kontonr?: string | null
          kontotyp?: string | null
          kundnummer?: string | null
          land?: string | null
          landskod?: string | null
          leverantorsnr?: string | null
          momstyp?: string | null
          name?: string
          oresavrundning?: boolean | null
          org_nr?: string | null
          ort?: string | null
          phone?: string | null
          plusgiro?: string | null
          postnr?: string | null
          referens?: string | null
          sni?: string | null
          telefon2?: string | null
          valuta?: string | null
          vat_nummer?: string | null
          webb?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      support_ai_events: {
        Row: {
          answer: string | null
          company_id: string | null
          created_at: string
          escalated: boolean
          id: string
          in_scope: boolean | null
          model: string | null
          question: string | null
          route: string | null
          user_id: string | null
        }
        Insert: {
          answer?: string | null
          company_id?: string | null
          created_at?: string
          escalated?: boolean
          id?: string
          in_scope?: boolean | null
          model?: string | null
          question?: string | null
          route?: string | null
          user_id?: string | null
        }
        Update: {
          answer?: string | null
          company_id?: string | null
          created_at?: string
          escalated?: boolean
          id?: string
          in_scope?: boolean | null
          model?: string | null
          question?: string | null
          route?: string | null
          user_id?: string | null
        }
        Relationships: []
      }
      support_attachments: {
        Row: {
          company_id: string | null
          created_at: string
          file_name: string | null
          file_size: number | null
          id: string
          message_id: string | null
          mime_type: string | null
          note_id: string | null
          storage_path: string | null
          ticket_id: string
          uploaded_by_user_id: string | null
          visibility: string
        }
        Insert: {
          company_id?: string | null
          created_at?: string
          file_name?: string | null
          file_size?: number | null
          id?: string
          message_id?: string | null
          mime_type?: string | null
          note_id?: string | null
          storage_path?: string | null
          ticket_id: string
          uploaded_by_user_id?: string | null
          visibility?: string
        }
        Update: {
          company_id?: string | null
          created_at?: string
          file_name?: string | null
          file_size?: number | null
          id?: string
          message_id?: string | null
          mime_type?: string | null
          note_id?: string | null
          storage_path?: string | null
          ticket_id?: string
          uploaded_by_user_id?: string | null
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "support_attachments_message_id_fkey"
            columns: ["message_id"]
            isOneToOne: false
            referencedRelation: "support_messages"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_attachments_note_id_fkey"
            columns: ["note_id"]
            isOneToOne: false
            referencedRelation: "support_internal_notes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "support_attachments_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      support_internal_notes: {
        Row: {
          author_admin_id: string | null
          body: string
          created_at: string
          id: string
          ticket_id: string
        }
        Insert: {
          author_admin_id?: string | null
          body: string
          created_at?: string
          id?: string
          ticket_id: string
        }
        Update: {
          author_admin_id?: string | null
          body?: string
          created_at?: string
          id?: string
          ticket_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "support_internal_notes_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      support_messages: {
        Row: {
          body: string
          created_at: string
          id: string
          is_admin: boolean
          sender_user_id: string | null
          ticket_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          is_admin?: boolean
          sender_user_id?: string | null
          ticket_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          is_admin?: boolean
          sender_user_id?: string | null
          ticket_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "support_messages_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      support_reads: {
        Row: {
          last_read_at: string
          ticket_id: string
          user_id: string
        }
        Insert: {
          last_read_at?: string
          ticket_id: string
          user_id: string
        }
        Update: {
          last_read_at?: string
          ticket_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "support_reads_ticket_id_fkey"
            columns: ["ticket_id"]
            isOneToOne: false
            referencedRelation: "support_tickets"
            referencedColumns: ["id"]
          },
        ]
      }
      support_tickets: {
        Row: {
          assigned_admin_id: string | null
          category: string
          closed_at: string | null
          company_id: string | null
          created_at: string
          created_by_user_id: string | null
          id: string
          last_message_at: string | null
          priority: string
          status: string
          subject: string
          updated_at: string
        }
        Insert: {
          assigned_admin_id?: string | null
          category?: string
          closed_at?: string | null
          company_id?: string | null
          created_at?: string
          created_by_user_id?: string | null
          id?: string
          last_message_at?: string | null
          priority?: string
          status?: string
          subject: string
          updated_at?: string
        }
        Update: {
          assigned_admin_id?: string | null
          category?: string
          closed_at?: string | null
          company_id?: string | null
          created_at?: string
          created_by_user_id?: string | null
          id?: string
          last_message_at?: string | null
          priority?: string
          status?: string
          subject?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "support_tickets_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      swish_regler: {
        Row: {
          aktiv: boolean
          company_id: string
          created_at: string
          created_by: string | null
          customer_id: string
          id: string
          max_belopp: number
          min_belopp: number
          momssats: number
          motkonto: string
        }
        Insert: {
          aktiv?: boolean
          company_id: string
          created_at?: string
          created_by?: string | null
          customer_id: string
          id?: string
          max_belopp: number
          min_belopp: number
          momssats?: number
          motkonto: string
        }
        Update: {
          aktiv?: boolean
          company_id?: string
          created_at?: string
          created_by?: string | null
          customer_id?: string
          id?: string
          max_belopp?: number
          min_belopp?: number
          momssats?: number
          motkonto?: string
        }
        Relationships: [
          {
            foreignKeyName: "swish_regler_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "swish_regler_customer_id_fkey"
            columns: ["customer_id"]
            isOneToOne: false
            referencedRelation: "customers"
            referencedColumns: ["id"]
          },
        ]
      }
      system_error_log: {
        Row: {
          company_id: string | null
          component: string | null
          error_code: string | null
          id: string
          message: string | null
          metadata: Json | null
          occurred_at: string
          severity: string | null
        }
        Insert: {
          company_id?: string | null
          component?: string | null
          error_code?: string | null
          id?: string
          message?: string | null
          metadata?: Json | null
          occurred_at?: string
          severity?: string | null
        }
        Update: {
          company_id?: string | null
          component?: string | null
          error_code?: string | null
          id?: string
          message?: string | null
          metadata?: Json | null
          occurred_at?: string
          severity?: string | null
        }
        Relationships: []
      }
      uppdrag: {
        Row: {
          bokforingstakt: string | null
          byra_bolag_id: string
          byra_klient_id: string
          byraanstand_aktiv: boolean
          created_at: string
          id: string
          klient_bolag_id: string
          revisionsplikt: boolean
          skapad_av: string | null
          startdatum: string
          status: string
          updated_at: string
          uppdragsansvarig_anvandare_id: string | null
          uppdragstyp: string
        }
        Insert: {
          bokforingstakt?: string | null
          byra_bolag_id: string
          byra_klient_id: string
          byraanstand_aktiv?: boolean
          created_at?: string
          id?: string
          klient_bolag_id: string
          revisionsplikt?: boolean
          skapad_av?: string | null
          startdatum?: string
          status?: string
          updated_at?: string
          uppdragsansvarig_anvandare_id?: string | null
          uppdragstyp: string
        }
        Update: {
          bokforingstakt?: string | null
          byra_bolag_id?: string
          byra_klient_id?: string
          byraanstand_aktiv?: boolean
          created_at?: string
          id?: string
          klient_bolag_id?: string
          revisionsplikt?: boolean
          skapad_av?: string | null
          startdatum?: string
          status?: string
          updated_at?: string
          uppdragsansvarig_anvandare_id?: string | null
          uppdragstyp?: string
        }
        Relationships: [
          {
            foreignKeyName: "uppdrag_byra_bolag_id_fkey"
            columns: ["byra_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "uppdrag_byra_klient_id_fkey"
            columns: ["byra_klient_id"]
            isOneToOne: false
            referencedRelation: "byra_klient"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "uppdrag_klient_bolag_id_fkey"
            columns: ["klient_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      uppdragsuppgift: {
        Row: {
          byra_bolag_id: string
          created_at: string
          etikett: string
          id: string
          justerad_at: string | null
          justerad_av: string | null
          justerat_forfallodatum: string | null
          justering_anledning: string | null
          klarmarkerad_at: string | null
          klarmarkerad_av: string | null
          klient_bolag_id: string
          kommentar: string | null
          kopplat_underlag_id: string | null
          ordinarie_forfallodatum: string | null
          period_slut: string
          period_start: string
          revisionsstart_datum: string | null
          status: string
          updated_at: string
          uppdrag_id: string
          uppdragsansvarig_anvandare_id: string | null
        }
        Insert: {
          byra_bolag_id: string
          created_at?: string
          etikett: string
          id?: string
          justerad_at?: string | null
          justerad_av?: string | null
          justerat_forfallodatum?: string | null
          justering_anledning?: string | null
          klarmarkerad_at?: string | null
          klarmarkerad_av?: string | null
          klient_bolag_id: string
          kommentar?: string | null
          kopplat_underlag_id?: string | null
          ordinarie_forfallodatum?: string | null
          period_slut: string
          period_start: string
          revisionsstart_datum?: string | null
          status?: string
          updated_at?: string
          uppdrag_id: string
          uppdragsansvarig_anvandare_id?: string | null
        }
        Update: {
          byra_bolag_id?: string
          created_at?: string
          etikett?: string
          id?: string
          justerad_at?: string | null
          justerad_av?: string | null
          justerat_forfallodatum?: string | null
          justering_anledning?: string | null
          klarmarkerad_at?: string | null
          klarmarkerad_av?: string | null
          klient_bolag_id?: string
          kommentar?: string | null
          kopplat_underlag_id?: string | null
          ordinarie_forfallodatum?: string | null
          period_slut?: string
          period_start?: string
          revisionsstart_datum?: string | null
          status?: string
          updated_at?: string
          uppdrag_id?: string
          uppdragsansvarig_anvandare_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "uppdragsuppgift_byra_bolag_id_fkey"
            columns: ["byra_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "uppdragsuppgift_klient_bolag_id_fkey"
            columns: ["klient_bolag_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "uppdragsuppgift_uppdrag_id_fkey"
            columns: ["uppdrag_id"]
            isOneToOne: false
            referencedRelation: "uppdrag"
            referencedColumns: ["id"]
          },
        ]
      }
      user_companies: {
        Row: {
          company_id: string | null
          created_at: string | null
          email: string | null
          id: string
          moduler: string[] | null
          role: string | null
          user_id: string | null
        }
        Insert: {
          company_id?: string | null
          created_at?: string | null
          email?: string | null
          id?: string
          moduler?: string[] | null
          role?: string | null
          user_id?: string | null
        }
        Update: {
          company_id?: string | null
          created_at?: string | null
          email?: string | null
          id?: string
          moduler?: string[] | null
          role?: string | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_companies_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
        ]
      }
      vat_reports: {
        Row: {
          company_id: string
          created_at: string
          created_by: string | null
          difference: number
          id: string
          ingaende_moms: number
          moms_att_betala: number
          month: number
          period_end: string | null
          period_start: string | null
          status: string
          updated_at: string
          utgaende_moms: number
          verifikation_id: string | null
          year: number
        }
        Insert: {
          company_id: string
          created_at?: string
          created_by?: string | null
          difference?: number
          id?: string
          ingaende_moms?: number
          moms_att_betala?: number
          month: number
          period_end?: string | null
          period_start?: string | null
          status?: string
          updated_at?: string
          utgaende_moms?: number
          verifikation_id?: string | null
          year: number
        }
        Update: {
          company_id?: string
          created_at?: string
          created_by?: string | null
          difference?: number
          id?: string
          ingaende_moms?: number
          moms_att_betala?: number
          month?: number
          period_end?: string | null
          period_start?: string | null
          status?: string
          updated_at?: string
          utgaende_moms?: number
          verifikation_id?: string | null
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "vat_reports_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "vat_reports_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      verifikation_andringar: {
        Row: {
          company_id: string | null
          id: string
          original_id: string | null
          orsak: string
          rattelse_id: string | null
          skapad: string | null
          utford_av_epost: string | null
        }
        Insert: {
          company_id?: string | null
          id?: string
          original_id?: string | null
          orsak: string
          rattelse_id?: string | null
          skapad?: string | null
          utford_av_epost?: string | null
        }
        Update: {
          company_id?: string | null
          id?: string
          original_id?: string | null
          orsak?: string
          rattelse_id?: string | null
          skapad?: string | null
          utford_av_epost?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verifikation_andringar_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikation_andringar_original_id_fkey"
            columns: ["original_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikation_andringar_rattelse_id_fkey"
            columns: ["rattelse_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      verifikation_rows: {
        Row: {
          account_name: string | null
          account_nr: string
          avstamd: boolean | null
          debet: number | null
          id: string
          kredit: number | null
          sort_order: number | null
          transaction_info: string | null
          verifikation_id: string | null
        }
        Insert: {
          account_name?: string | null
          account_nr: string
          avstamd?: boolean | null
          debet?: number | null
          id?: string
          kredit?: number | null
          sort_order?: number | null
          transaction_info?: string | null
          verifikation_id?: string | null
        }
        Update: {
          account_name?: string | null
          account_nr?: string
          avstamd?: boolean | null
          debet?: number | null
          id?: string
          kredit?: number | null
          sort_order?: number | null
          transaction_info?: string | null
          verifikation_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verifikation_rows_verifikation_id_fkey"
            columns: ["verifikation_id"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
        ]
      }
      verifikationer: {
        Row: {
          beskrivning: string
          company_id: string | null
          created_at: string | null
          created_by: string | null
          datum: string
          ersatter: string | null
          id: string
          is_locked: boolean | null
          kommentar: string | null
          makulerad_av: string | null
          motpart: string | null
          motverkar: string | null
          rattad_av: string | null
          rattar: string | null
          sie_import_id: string | null
          status: string
          total_debet: number
          total_kredit: number
          ver_nr: string
          ver_serie: string | null
        }
        Insert: {
          beskrivning: string
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          datum: string
          ersatter?: string | null
          id?: string
          is_locked?: boolean | null
          kommentar?: string | null
          makulerad_av?: string | null
          motpart?: string | null
          motverkar?: string | null
          rattad_av?: string | null
          rattar?: string | null
          sie_import_id?: string | null
          status?: string
          total_debet: number
          total_kredit: number
          ver_nr: string
          ver_serie?: string | null
        }
        Update: {
          beskrivning?: string
          company_id?: string | null
          created_at?: string | null
          created_by?: string | null
          datum?: string
          ersatter?: string | null
          id?: string
          is_locked?: boolean | null
          kommentar?: string | null
          makulerad_av?: string | null
          motpart?: string | null
          motverkar?: string | null
          rattad_av?: string | null
          rattar?: string | null
          sie_import_id?: string | null
          status?: string
          total_debet?: number
          total_kredit?: number
          ver_nr?: string
          ver_serie?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "verifikationer_company_id_fkey"
            columns: ["company_id"]
            isOneToOne: false
            referencedRelation: "companies"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikationer_ersatter_fkey"
            columns: ["ersatter"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikationer_makulerad_av_fkey"
            columns: ["makulerad_av"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikationer_motverkar_fkey"
            columns: ["motverkar"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikationer_rattad_av_fkey"
            columns: ["rattad_av"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikationer_rattar_fkey"
            columns: ["rattar"]
            isOneToOne: false
            referencedRelation: "verifikationer"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "verifikationer_sie_import_id_fkey"
            columns: ["sie_import_id"]
            isOneToOne: false
            referencedRelation: "sie_imports"
            referencedColumns: ["id"]
          },
        ]
      }
      worker_health: {
        Row: {
          component: string
          consecutive_failures: number
          last_error: string | null
          last_failure_at: string | null
          last_success_at: string | null
          updated_at: string
        }
        Insert: {
          component: string
          consecutive_failures?: number
          last_error?: string | null
          last_failure_at?: string | null
          last_success_at?: string | null
          updated_at?: string
        }
        Update: {
          component?: string
          consecutive_failures?: number
          last_error?: string | null
          last_failure_at?: string | null
          last_success_at?: string | null
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      _assert_company_access: {
        Args: { p_company: string }
        Returns: undefined
      }
      _bokslut_attachment_guard: {
        Args: { p_attachment: string }
        Returns: Record<string, unknown>
      }
      _bokslut_check_guard: {
        Args: { p_check: string }
        Returns: Record<string, unknown>
      }
      _bokslut_recount: { Args: { p_eng: string }; Returns: undefined }
      _limit_for: {
        Args: { p_company_id: string; p_metric: string }
        Returns: number
      }
      _mc_item_guard: {
        Args: { p_item: string }
        Returns: Record<string, unknown>
      }
      _mc_recount: { Args: { p_control: string }; Returns: undefined }
      _notify_plan_limit: {
        Args: { p_company_id: string; p_metric: string; v: Json }
        Returns: undefined
      }
      _plan_limit_status: {
        Args: { p_company_id: string; p_metric: string }
        Returns: Json
      }
      _plan_used: {
        Args: { p_company_id: string; p_metric: string }
        Returns: number
      }
      _support_snip: { Args: { p: string }; Returns: string }
      acceptera_inbjudningar: { Args: never; Returns: Json }
      add_internal_note: {
        Args: { p_body: string; p_ticket_id: string }
        Returns: string
      }
      add_support_attachment: {
        Args: {
          p_file_name: string
          p_message_id: string
          p_mime: string
          p_note_id: string
          p_size: number
          p_storage_path: string
          p_visibility?: string
        }
        Returns: string
      }
      admin_acknowledge_system_error: {
        Args: { p_event_id: string }
        Returns: undefined
      }
      admin_cancel_notification: {
        Args: { p_queue_id: string }
        Returns: undefined
      }
      admin_company_usage_detail: {
        Args: { p_company_id: string }
        Returns: Json
      }
      admin_get_company: { Args: { p_company_id: string }; Returns: Json }
      admin_get_subscription: { Args: { p_company_id: string }; Returns: Json }
      admin_grant_platform_role: {
        Args: { p_email: string; p_role: string }
        Returns: undefined
      }
      admin_list_companies: {
        Args: { p_search?: string; p_state?: string }
        Returns: Json
      }
      admin_list_plans: { Args: never; Returns: Json }
      admin_list_platform_roles: { Args: never; Returns: Json }
      admin_list_subscriptions: {
        Args: { p_plan_id?: string; p_search?: string; p_status?: string }
        Returns: Json
      }
      admin_plan_usage_overview: {
        Args: {
          p_limit?: number
          p_limit_type?: string
          p_offset?: number
          p_plan_id?: string
          p_search?: string
          p_sort?: string
          p_status?: string
          p_sub_status?: string
        }
        Returns: Json
      }
      admin_retry_notification: {
        Args: { p_queue_id: string }
        Returns: undefined
      }
      admin_revoke_platform_role: {
        Args: { p_email: string; p_role: string }
        Returns: undefined
      }
      admin_send_upgrade_suggestion: {
        Args: { p_company_id: string; p_message: string; p_plan_id: string }
        Returns: undefined
      }
      admin_set_company_plan: {
        Args: {
          p_billing_period: string
          p_company_id: string
          p_plan_id: string
        }
        Returns: undefined
      }
      admin_set_company_service_state: {
        Args: {
          p_company_id: string
          p_note?: string
          p_notify?: boolean
          p_reason?: string
          p_state: string
        }
        Returns: Json
      }
      admin_set_plan_active: {
        Args: { p_active: boolean; p_id: string }
        Returns: undefined
      }
      admin_set_subscription_dates: {
        Args: {
          p_company_id: string
          p_current_period_end: string
          p_trial_ends_at: string
        }
        Returns: undefined
      }
      admin_set_subscription_discount: {
        Args: { p_company_id: string; p_percent: number }
        Returns: undefined
      }
      admin_set_subscription_grace: {
        Args: { p_company_id: string; p_grace_until: string }
        Returns: string
      }
      admin_set_subscription_status: {
        Args: { p_company_id: string; p_status: string }
        Returns: undefined
      }
      admin_sync_service_state: {
        Args: { p_company_id: string }
        Returns: string
      }
      admin_system_overview: { Args: never; Returns: Json }
      admin_upsert_plan: {
        Args: {
          p_description: string
          p_features: Json
          p_id: string
          p_max_ai: number
          p_max_companies: number
          p_max_documents: number
          p_max_invoices: number
          p_max_storage_mb: number
          p_max_users: number
          p_monthly: number
          p_name: string
          p_stripe_price_monthly?: string
          p_stripe_price_yearly?: string
          p_stripe_product_id?: string
          p_support_level: string
          p_yearly: number
        }
        Returns: string
      }
      ai_claim_job: {
        Args: { p_company_id: string; p_document_id: string; p_user_id: string }
        Returns: Json
      }
      ai_finish_job: {
        Args: {
          p_company_id: string
          p_cooldown_seconds?: number
          p_document_id: string
          p_error?: string
          p_status: string
          p_user_id?: string
        }
        Returns: undefined
      }
      aml_run_checks: { Args: { p_company_id: string }; Returns: Json }
      annual_report_ai_context: { Args: { p_draft: string }; Returns: Json }
      annual_report_finalize_server_pdf: {
        Args: {
          p_checksum: string
          p_export: string
          p_file_name: string
          p_file_size: number
          p_quality_report?: Json
          p_quality_status?: string
          p_render_engine?: string
          p_storage_path: string
        }
        Returns: undefined
      }
      annual_report_generate_ai_texts: {
        Args: { p_draft: string }
        Returns: number
      }
      annual_report_generate_k2_draft: {
        Args: { p_engagement: string }
        Returns: Json
      }
      annual_report_get_export_download_url: {
        Args: { p_export: string }
        Returns: Json
      }
      annual_report_get_or_create_draft: {
        Args: { p_engagement: string }
        Returns: Json
      }
      annual_report_list_exports: {
        Args: { p_draft: string }
        Returns: {
          checksum: string | null
          company_id: string
          created_at: string
          draft_id: string
          engagement_id: string
          error: string | null
          export_type: string
          file_name: string | null
          file_path: string | null
          file_size: number | null
          generated_at: string | null
          generated_by: string | null
          id: string
          quality_report: Json
          quality_status: string
          render_engine: string | null
          status: string
          storage_bucket: string | null
          storage_path: string | null
          validation_summary: Json
        }[]
        SetofOptions: {
          from: "*"
          to: "annual_report_exports"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      annual_report_list_sections: {
        Args: { p_draft: string }
        Returns: {
          ai_generated: boolean
          ai_generated_at: string | null
          ai_model: string | null
          ai_prompt_version: string | null
          ai_source_summary: Json
          company_id: string
          content: string | null
          created_at: string
          draft_id: string
          id: string
          requires_review: boolean
          review_comment: string | null
          review_status: string
          reviewed_at: string | null
          reviewed_by: string | null
          section_key: string
          sort_order: number
          source_references: Json
          structured_data: Json
          title: string
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "annual_report_draft_sections"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      annual_report_list_validation_items: {
        Args: { p_draft: string }
        Returns: {
          company_id: string
          created_at: string
          description: string | null
          draft_id: string
          engagement_id: string
          id: string
          ignored_at: string | null
          ignored_by: string | null
          ignored_reason: string | null
          resolved_at: string | null
          resolved_by: string | null
          section_id: string | null
          severity: string
          source: string
          source_data: Json
          status: string
          suggested_action: string | null
          title: string
          updated_at: string
          validation_key: string
        }[]
        SetofOptions: {
          from: "*"
          to: "annual_report_validation_items"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      annual_report_mark_export_failed: {
        Args: { p_error?: string; p_export: string }
        Returns: undefined
      }
      annual_report_mark_export_ready: {
        Args: {
          p_export: string
          p_file_name?: string
          p_file_path?: string
          p_file_size?: number
        }
        Returns: undefined
      }
      annual_report_prepare_export: {
        Args: { p_draft: string; p_export_type: string }
        Returns: Json
      }
      annual_report_request_server_pdf: {
        Args: { p_draft: string }
        Returns: Json
      }
      annual_report_run_pdf_quality_check: {
        Args: { p_export: string }
        Returns: Json
      }
      annual_report_run_validation: { Args: { p_draft: string }; Returns: Json }
      annual_report_save_ai_texts: {
        Args: { p_draft: string; p_payload: Json }
        Returns: number
      }
      annual_report_set_draft_status: {
        Args: { p_comment?: string; p_draft: string; p_status: string }
        Returns: undefined
      }
      annual_report_set_section_status: {
        Args: { p_comment?: string; p_section: string; p_status: string }
        Returns: undefined
      }
      annual_report_set_validation_item_status: {
        Args: { p_comment?: string; p_item: string; p_status: string }
        Returns: undefined
      }
      annual_report_update_section: {
        Args: {
          p_content: string
          p_review_comment?: string
          p_section: string
        }
        Returns: undefined
      }
      apply_email_unsubscribe: {
        Args: { p_event_type: string; p_user_id: string }
        Returns: number
      }
      ar_arkiv_forvaltare: { Args: { p_company: string }; Returns: boolean }
      ar_bolagsadmin: { Args: { p_company: string }; Returns: boolean }
      ar_byra_admin: { Args: { p_byra_bolag_id: string }; Returns: boolean }
      ar_byra_medlem: { Args: never; Returns: boolean }
      ar_min_klient: { Args: { p_company: string }; Returns: boolean }
      ar_section_label: { Args: { p_key: string }; Returns: string }
      arkiv_arkivera_systemfil: {
        Args: {
          p_beskrivning: string
          p_company: string
          p_file_name: string
          p_file_size: number
          p_hoppa_om_finns?: boolean
          p_kalla: string
          p_mime_type: string
          p_storage_path: string
          p_systemnyckel: string
        }
        Returns: string
      }
      arkiv_skapa_standardmappar: {
        Args: { p_company: string }
        Returns: number
      }
      assert_period_open: {
        Args: { p_company: string; p_datum: string }
        Returns: undefined
      }
      assign_mc_item: {
        Args: { p_item: string; p_user: string }
        Returns: undefined
      }
      assign_support_ticket: {
        Args: { p_admin_id: string; p_ticket_id: string }
        Returns: undefined
      }
      bas_class: { Args: { p_nr: string }; Returns: number }
      bas_type: { Args: { p_nr: string }; Returns: string }
      billing_admin_ids: { Args: never; Returns: string[] }
      bokfor_verifikation: {
        Args: {
          p_beskrivning: string
          p_company_id: string
          p_created_by?: string
          p_datum: string
          p_ersatter?: string
          p_kommentar?: string
          p_motpart?: string
          p_rader: Json
          p_serie: string
          p_source?: string
        }
        Returns: {
          beskrivning: string
          company_id: string | null
          created_at: string | null
          created_by: string | null
          datum: string
          ersatter: string | null
          id: string
          is_locked: boolean | null
          kommentar: string | null
          makulerad_av: string | null
          motpart: string | null
          motverkar: string | null
          rattad_av: string | null
          rattar: string | null
          sie_import_id: string | null
          status: string
          total_debet: number
          total_kredit: number
          ver_nr: string
          ver_serie: string | null
        }
        SetofOptions: {
          from: "*"
          to: "verifikationer"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      bokslut_ai_context: { Args: { p_engagement: string }; Returns: Json }
      bokslut_assign_check: {
        Args: { p_check: string; p_user: string }
        Returns: undefined
      }
      bokslut_can: {
        Args: { p_action: string; p_company: string }
        Returns: boolean
      }
      bokslut_comment_check: {
        Args: { p_check: string; p_comment: string }
        Returns: undefined
      }
      bokslut_create_attachment: {
        Args: {
          p_account_nr?: string
          p_avstamt?: number
          p_check_id?: string
          p_engagement: string
          p_saldo?: number
          p_source?: string
          p_source_data?: Json
          p_title: string
          p_type: string
        }
        Returns: string
      }
      bokslut_generate_ai_suggestions: {
        Args: { p_engagement: string }
        Returns: number
      }
      bokslut_generate_attachment_suggestions: {
        Args: { p_engagement: string }
        Returns: number
      }
      bokslut_get_or_create: {
        Args: { p_company: string; p_fiscal_year_id: string }
        Returns: Json
      }
      bokslut_list_ai_suggestions: {
        Args: { p_engagement: string }
        Returns: {
          company_id: string
          confidence: number | null
          created_at: string
          engagement_id: string
          id: string
          model: string | null
          reasoning: string | null
          related_attachment_id: string | null
          related_check_id: string | null
          review_comment: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          risk_level: string
          source_data: Json
          status: string
          suggested_next_action: string | null
          suggestion_type: string
          summary: string | null
          title: string
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "bokslut_ai_suggestions"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      bokslut_list_attachments: {
        Args: { p_engagement: string }
        Returns: {
          account_nr: string | null
          avstamt_belopp: number | null
          check_id: string | null
          comment: string | null
          company_id: string
          created_at: string
          created_by: string | null
          differens: number | null
          engagement_id: string
          id: string
          reviewed_at: string | null
          reviewed_by: string | null
          rule_key: string | null
          saldo_huvudbok: number | null
          source: string | null
          source_data: Json
          status: string
          title: string
          type: string
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "bokslut_attachments"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      bokslut_my_permissions: { Args: { p_company: string }; Returns: Json }
      bokslut_open_counts: { Args: { p_company: string }; Returns: Json }
      bokslut_save_ai_suggestions: {
        Args: { p_engagement: string; p_items: Json; p_model?: string }
        Returns: number
      }
      bokslut_set_ai_suggestion_status: {
        Args: { p_comment?: string; p_status: string; p_suggestion: string }
        Returns: undefined
      }
      bokslut_set_attachment_status: {
        Args: { p_attachment: string; p_comment?: string; p_status: string }
        Returns: undefined
      }
      bokslut_set_check_status: {
        Args: { p_check: string; p_comment?: string; p_status: string }
        Returns: undefined
      }
      bokslut_sync_comment: {
        Args: {
          p_base_revision: number
          p_check: string
          p_client_created_at: string
          p_comment: string
          p_idempotency_key: string
          p_operation_type: string
        }
        Returns: Json
      }
      bokslut_update_attachment: {
        Args: {
          p_account_nr?: string
          p_attachment: string
          p_avstamt?: number
          p_comment?: string
          p_saldo?: number
          p_source?: string
          p_source_data?: Json
          p_title?: string
        }
        Returns: undefined
      }
      byra_skapa_klient: {
        Args: {
          p_byra_bolag_id: string
          p_foretagsform?: string
          p_momsperiod?: string
          p_namn: string
          p_org_nr?: string
        }
        Returns: Json
      }
      byra_synliga_bolag_ids: { Args: never; Returns: string[] }
      byra_uppdatera_uppgifter: {
        Args: {
          p_adress?: string
          p_byra_bolag_id: string
          p_epost?: string
          p_namn: string
          p_org_nr?: string
          p_postnr?: string
          p_postort?: string
          p_telefon?: string
          p_webb?: string
        }
        Returns: undefined
      }
      byrastod_markera_forsenade: { Args: never; Returns: number }
      can_company_write: { Args: { p_company_id: string }; Returns: boolean }
      can_manage_billing: { Args: never; Returns: boolean }
      can_manage_operations: { Args: never; Returns: boolean }
      can_view_billing: { Args: never; Returns: boolean }
      can_view_operations: { Args: never; Returns: boolean }
      can_view_support: { Args: never; Returns: boolean }
      check_all_plan_limits: { Args: { p_company_id: string }; Returns: Json }
      check_plan_limit: {
        Args: { p_company_id: string; p_metric: string }
        Returns: Json
      }
      clear_chart_of_accounts: { Args: { p_company: string }; Returns: Json }
      comment_mc_item: {
        Args: { p_body: string; p_item: string }
        Returns: string
      }
      create_support_ticket: {
        Args: {
          p_body: string
          p_category: string
          p_company_id: string
          p_priority: string
          p_subject: string
        }
        Returns: Json
      }
      cron_run_monthly_controls: { Args: never; Returns: undefined }
      customer_close_support_ticket: {
        Args: { p_ticket_id: string }
        Returns: undefined
      }
      customer_reply_support_ticket: {
        Args: { p_body: string; p_ticket_id: string }
        Returns: string
      }
      delete_account_safe: {
        Args: { p_account_nr: string; p_company: string }
        Returns: Json
      }
      enforce_plan_limit: {
        Args: { p_company_id: string; p_metric: string }
        Returns: Json
      }
      first_open_booking_date: { Args: { p_company: string }; Returns: string }
      gallra_gdpr_loggar: {
        Args: never
        Returns: {
          raderade: number
          tabell: string
        }[]
      }
      get_ocr_provider_config: { Args: never; Returns: Json }
      get_support_ticket: { Args: { p_id: string }; Returns: Json }
      has_ai_feature: {
        Args: { p_company: string; p_key: string }
        Returns: boolean
      }
      has_kyc_clearance: { Args: { p_company_id: string }; Returns: boolean }
      has_platform_role: { Args: { p_role: string }; Returns: boolean }
      ignore_mc_item: {
        Args: { p_item: string; p_reason: string }
        Returns: undefined
      }
      import_chart_of_accounts: {
        Args: {
          p_company: string
          p_filename: string
          p_mode: string
          p_rows: Json
        }
        Returns: Json
      }
      is_platform_admin: { Args: never; Returns: boolean }
      is_read_only_admin: { Args: never; Returns: boolean }
      is_superadmin: { Args: never; Returns: boolean }
      justera_uppgift_deadline: {
        Args: {
          p_anledning: string
          p_nytt_datum: string
          p_uppgift_id: string
        }
        Returns: {
          byra_bolag_id: string
          created_at: string
          etikett: string
          id: string
          justerad_at: string | null
          justerad_av: string | null
          justerat_forfallodatum: string | null
          justering_anledning: string | null
          klarmarkerad_at: string | null
          klarmarkerad_av: string | null
          klient_bolag_id: string
          kommentar: string | null
          kopplat_underlag_id: string | null
          ordinarie_forfallodatum: string | null
          period_slut: string
          period_start: string
          revisionsstart_datum: string | null
          status: string
          updated_at: string
          uppdrag_id: string
          uppdragsansvarig_anvandare_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "uppdragsuppgift"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      list_support_admins: { Args: never; Returns: Json }
      list_support_tickets: {
        Args: {
          p_assigned_admin_id?: string
          p_company_id?: string
          p_priority?: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      log_accounting_audit: {
        Args: {
          p_action: string
          p_after?: Json
          p_before?: Json
          p_company_id?: string
          p_entity: string
          p_entity_ref: string
          p_metadata?: Json
          p_source?: string
        }
        Returns: undefined
      }
      log_ai_error: {
        Args: {
          p_attempts: number
          p_company_id: string
          p_document_id: string
          p_error_body: string
          p_error_code: string
          p_kind: string
          p_model: string
          p_provider: string
          p_request_id: string
          p_status_code: number
          p_user_id: string
        }
        Returns: undefined
      }
      log_bokslut_denied: {
        Args: {
          p_action: string
          p_company?: string
          p_context?: Json
          p_engagement?: string
          p_reason?: string
        }
        Returns: undefined
      }
      log_inbox_download: {
        Args: {
          p_company_id: string
          p_file_count: number
          p_kind: string
          p_section: string
        }
        Returns: undefined
      }
      log_platform_audit: {
        Args: { p_action: string; p_detail?: Json; p_target: string }
        Returns: undefined
      }
      log_robo_bp_event: {
        Args: { p_action: string; p_company: string; p_detail?: Json }
        Returns: string
      }
      log_support_attachment_download: {
        Args: { p_attachment_id: string }
        Returns: undefined
      }
      makulera_verifikation: {
        Args: { p_orsak?: string; p_ver_id: string }
        Returns: Json
      }
      map_stripe_status: { Args: { p: string }; Returns: string }
      mark_support_read: { Args: { p_ticket_id: string }; Returns: undefined }
      mc_open_counts: { Args: { p_company: string }; Returns: Json }
      min_byra_ids: { Args: never; Returns: string[] }
      mina_byraer: { Args: never; Returns: string[] }
      mina_klientbolag: { Args: never; Returns: string[] }
      my_platform_access: { Args: never; Returns: Json }
      my_subscription: { Args: { p_company_id: string }; Returns: Json }
      next_ver_nr: {
        Args: { p_company_id: string; p_serie?: string }
        Returns: string
      }
      notify_event: {
        Args: {
          p_actor?: string
          p_channels?: string[]
          p_company_id: string
          p_dedupe_key?: string
          p_event_type: string
          p_link_url?: string
          p_object_id?: string
          p_object_type?: string
          p_payload?: Json
          p_priority?: string
          p_user_ids?: string[]
        }
        Returns: string
      }
      notify_subscription_lifecycle: { Args: never; Returns: Json }
      notify_vat_report_ready: {
        Args: {
          p_company_id: string
          p_period: string
          p_verifikation_id: string
        }
        Returns: string
      }
      purge_test_data: { Args: { p_company: string }; Returns: Json }
      radera_senaste_verifikation: { Args: { p_ver_id: string }; Returns: Json }
      ratta_verifikation: {
        Args: { p_datum?: string; p_orsak: string; p_ver_id: string }
        Returns: Json
      }
      record_ai_usage: {
        Args: { p_company_id: string; p_kind?: string }
        Returns: undefined
      }
      record_worker_health: {
        Args: { p_component: string; p_error?: string; p_ok: boolean }
        Returns: number
      }
      render_template: {
        Args: { p_tmpl: string; p_vars: Json }
        Returns: string
      }
      reopen_mc_item: { Args: { p_item: string }; Returns: undefined }
      reply_support_ticket: {
        Args: {
          p_attachment_count?: number
          p_body: string
          p_ticket_id: string
        }
        Returns: string
      }
      report_system_error:
        | {
            Args: {
              p_company_id?: string
              p_component: string
              p_message: string
            }
            Returns: string
          }
        | {
            Args: {
              p_company_id?: string
              p_component: string
              p_error_code?: string
              p_message: string
              p_metadata?: Json
              p_occurred_at?: string
              p_severity?: string
            }
            Returns: string
          }
      request_subscription_change: {
        Args: {
          p_company_id: string
          p_desired_plan_id: string
          p_message: string
        }
        Returns: string
      }
      reset_company: {
        Args: { p_company: string; p_opts: Json }
        Returns: Json
      }
      resolve_mc_item: { Args: { p_item: string }; Returns: undefined }
      robo_bp_context:
        | {
            Args: { p_company: string; p_fiscal_year_id?: string }
            Returns: Json
          }
        | {
            Args: {
              p_company: string
              p_fiscal_year_id?: string
              p_question?: string
              p_view?: string
            }
            Returns: Json
          }
      robo_bp_create_check: {
        Args: {
          p_affected_objects?: Json
          p_company: string
          p_confidence_label?: string
          p_conversation_id?: string
          p_decision_basis?: string
          p_description: string
          p_fiscal_year_id: string
          p_risk_level: string
          p_title: string
          p_view: string
        }
        Returns: string
      }
      robo_bp_get_settings: { Args: { p_company: string }; Returns: Json }
      robo_bp_run_control: {
        Args: { p_company: string; p_fiscal_year_id?: string }
        Returns: Json
      }
      robo_bp_save_settings: {
        Args: {
          p_categories: Json
          p_company: string
          p_moms_period?: string
          p_sensitivity: string
        }
        Returns: Json
      }
      robo_bp_set_check_status: {
        Args: { p_check: string; p_status: string }
        Returns: string
      }
      robo_bp_set_control_observation_status: {
        Args: { p_code: string; p_run_id: string; p_status: string }
        Returns: Json
      }
      run_bokslut_analysis: { Args: { p_engagement: string }; Returns: Json }
      run_monthly_control: {
        Args: { p_company_id: string; p_month: number; p_year: number }
        Returns: Json
      }
      run_scheduled_notifications: { Args: never; Returns: Json }
      run_scheduled_plan_enforcement: { Args: never; Returns: Json }
      run_subscription_grace_enforcement: { Args: never; Returns: number }
      safe_uuid: { Args: { t: string }; Returns: string }
      seed_bas_accounts: { Args: { p_company: string }; Returns: Json }
      send_test_notification: {
        Args: { p_channel: string; p_company_id: string }
        Returns: string
      }
      set_bokslut_engagement_status: {
        Args: { p_engagement: string; p_status: string }
        Returns: undefined
      }
      set_notification_preference: {
        Args: {
          p_channel: string
          p_company_id: string
          p_enabled: boolean
          p_event_type: string
        }
        Returns: undefined
      }
      set_ocr_provider_config: {
        Args: { p_base_url: string; p_enabled: boolean }
        Returns: Json
      }
      sie_importera_verifikation: {
        Args: {
          p_beskrivning: string
          p_company: string
          p_datum: string
          p_rader: Json
          p_sie_import_id: string
          p_ver_nr: string
          p_ver_serie: string
        }
        Returns: string
      }
      skapa_beta_ansokan: {
        Args: { p_bolagsnamn: string; p_meddelande?: string; p_org_nr?: string }
        Returns: Json
      }
      start_mc_item: { Args: { p_item: string }; Returns: undefined }
      stripe_checkout_context: {
        Args: {
          p_billing_period: string
          p_company_id: string
          p_plan_id: string
        }
        Returns: Json
      }
      stripe_handle_event: {
        Args: {
          p_client_reference?: string
          p_customer_id?: string
          p_event_id: string
          p_invoice_id?: string
          p_next_attempt?: string
          p_period_end?: string
          p_period_start?: string
          p_price_id?: string
          p_stripe_status?: string
          p_subscription_id?: string
          p_type: string
        }
        Returns: string
      }
      support_admin_ids: { Args: never; Returns: string[] }
      support_admin_queue_count: { Args: never; Returns: number }
      support_unread_count: { Args: never; Returns: number }
      sync_company_service_state_from_billing: {
        Args: { p_company: string }
        Returns: string
      }
      update_support_ticket_priority: {
        Args: { p_priority: string; p_ticket_id: string }
        Returns: undefined
      }
      update_support_ticket_status: {
        Args: { p_status: string; p_ticket_id: string }
        Returns: undefined
      }
      upsert_vat_report: {
        Args: {
          p_company_id: string
          p_difference?: number
          p_ingaende: number
          p_month: number
          p_status: string
          p_utgaende: number
          p_verifikation_id?: string
          p_year: number
        }
        Returns: string
      }
      user_company_ids: { Args: never; Returns: string[] }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
