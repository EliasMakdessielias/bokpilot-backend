-- Följdfix till etapp 8: forbjud_sista_admin_bort blockerade även den sanktionerade
-- avvecklingen, eftersom kaskaden från companies träffar user_companies och triggern
-- vägrar ta bort den siste administratören.
--
-- Kravet på minst en administratör skyddar mot att ett LEVANDE bolag blir utan ägare.
-- Vid en avsiktlig avveckling av hela bolaget är kravet meningslöst — det finns inget
-- bolag kvar att administrera. Flaggan app.bfl_avveckla sätts endast av avveckla_bolag(),
-- som i sin tur kräver plattformsadmin, en angiven orsak och skriver en permanent post
-- i platform_audit_log innan raderingen sker.
create or replace function public.forbjud_sista_admin_bort()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
begin
  -- Sanktionerad avveckling av hela bolaget: kravet på kvarvarande admin gäller inte.
  if current_setting('app.bfl_avveckla', true) = 'on' then
    return OLD;
  end if;

  if OLD.role = 'admin'
     and not exists (
       select 1 from public.user_companies uc
       where uc.company_id = OLD.company_id
         and uc.role = 'admin'
         and uc.id <> OLD.id
     )
  then
    raise exception 'SISTA_ADMIN: Bolaget måste ha minst en administratör. Utse en ny innan du tar bort den sista.';
  end if;
  return OLD;
end $fn$;
