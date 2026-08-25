-- current_setting(..., true) ger NULL när flaggan inte är satt, vilket gjorde
-- att sanktionerad loggades som null i stället för false. Coalesce till ''.

create or replace function public.observe_verifikation_mutation()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_falt text[] := '{}'::text[]; v_sanktionerad boolean;
begin
  if new.company_id  is distinct from old.company_id  then v_falt := v_falt || 'company_id'::text;  end if;
  if new.ver_nr      is distinct from old.ver_nr      then v_falt := v_falt || 'ver_nr'::text;      end if;
  if new.ver_serie   is distinct from old.ver_serie   then v_falt := v_falt || 'ver_serie'::text;   end if;
  if new.datum       is distinct from old.datum       then v_falt := v_falt || 'datum'::text;       end if;
  if new.beskrivning is distinct from old.beskrivning then v_falt := v_falt || 'beskrivning'::text; end if;
  if new.motpart     is distinct from old.motpart     then v_falt := v_falt || 'motpart'::text;     end if;
  if new.kommentar   is distinct from old.kommentar   then v_falt := v_falt || 'kommentar'::text;   end if;
  if coalesce(new.total_debet,0)  <> coalesce(old.total_debet,0)  then v_falt := v_falt || 'total_debet'::text;  end if;
  if coalesce(new.total_kredit,0) <> coalesce(old.total_kredit,0) then v_falt := v_falt || 'total_kredit'::text; end if;

  if array_length(v_falt, 1) is null then
    return new;   -- endast status-/kopplingsfält: rättelseflödets normala arbete
  end if;

  v_sanktionerad := coalesce(current_setting('app.rattelse_link',   true), '') = 'on'
                 or coalesce(current_setting('app.makulera_insert', true), '') = 'on'
                 or coalesce(current_setting('app.periodlas_bypass',true), '') = 'on';

  perform public.log_accounting_audit(
    'verification_mutation_observed', 'verifikation', new.id::text,
    nullif(current_setting('app.audit_source', true), ''),
    jsonb_build_object('ver_nr', old.ver_nr, 'andrade_falt', v_falt, 'sanktionerad', v_sanktionerad),
    new.company_id,
    jsonb_build_object('ver_nr', old.ver_nr, 'ver_serie', old.ver_serie, 'datum', old.datum,
      'beskrivning', old.beskrivning, 'motpart', old.motpart, 'kommentar', old.kommentar,
      'total_debet', old.total_debet, 'total_kredit', old.total_kredit),
    jsonb_build_object('ver_nr', new.ver_nr, 'ver_serie', new.ver_serie, 'datum', new.datum,
      'beskrivning', new.beskrivning, 'motpart', new.motpart, 'kommentar', new.kommentar,
      'total_debet', new.total_debet, 'total_kredit', new.total_kredit)
  );
  return new;
end $$;
