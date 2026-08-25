-- Följdfix 4 till etapp 8 — samma kaskadfälla som i etapp 3, nu i arkivlagret.
--
-- audit_log.company_id har FK ON DELETE CASCADE mot companies. När ett bolag raderas
-- fyrar arkiv_fil_logga_radering och försöker skriva en auditrad som pekar på ett bolag
-- som är på väg bort -> foreign_key_violation som avbryter hela raderingen.
--
-- Att i stället kontrollera "finns bolaget kvar?" fungerar INTE: raden syns fortfarande
-- i statementets ögonblicksbild. Rätt lösning är att fånga specifikt
-- foreign_key_violation — den kan bara betyda att bolaget försvinner — och släppa
-- igenom den. Allt annat ska fortfarande avbryta transaktionen (BFL 5 kap.).
create or replace function public.arkiv_fil_logga_radering()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare v_rad record; v_action text;
begin
  if tg_op = 'DELETE' then
    v_rad := old; v_action := 'radera_permanent';
  else
    if new.raderad_at is null or old.raderad_at is not null then return new; end if;
    v_rad := new; v_action := 'radera';
    new.raderad_av := auth.uid();
  end if;

  begin
    insert into audit_log (company_id, entity, entity_ref, action, old_data, changed_by, source)
    values (v_rad.company_id, 'arkiv_fil', v_rad.id::text, v_action,
            jsonb_build_object('file_name', v_rad.file_name, 'mapp_id', v_rad.mapp_id,
                               'document_id', v_rad.document_id, 'kalla', v_rad.kalla),
            auth.uid(), 'ui');
  exception when foreign_key_violation then
    null;   -- bolaget raderas (cascade) - auditraden skulle ända bort med det
  end;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end $fn$;
