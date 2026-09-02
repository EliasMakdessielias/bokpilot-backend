-- Etapp 15: operatörsloggen blir append-only på riktigt.
--
-- konsol/index.ts rad 6 påstår att konsol_audit_logg är "append-only", men tabellen
-- hade ingen trigger och inga RLS-policies — skyddet var enbart att bara service_role
-- kommer åt den. Den nyckeln delas av alla 32 edge functions. Vem som helst med den
-- kunde alltså radera eller skriva om spåren av operatörens åtgärder.
--
-- Jämför verifikation_andringar, som har en riktig appendonly-trigger sedan etapp 3.
--
-- Enda tillåtna ändringen: FK:n mot companies är ON DELETE SET NULL, så vid en
-- bolagsradering sätts company_id till null. Den uppdateringen släpps igenom om och
-- endast om INGET annat fält ändras.

create or replace function public.konsol_audit_appendonly()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'UPDATE'
     and old.company_id is not null
     and new.company_id is null
     and (to_jsonb(new) - 'company_id') = (to_jsonb(old) - 'company_id') then
    return new;
  end if;
  raise exception
    'KONSOL_LOGG_APPENDONLY: operatörsloggen är append-only — % är inte tillåtet. Behandlingshistorik ska bevaras (BFL 5 kap. 11 §).',
    lower(tg_op);
end $fn$;

revoke execute on function public.konsol_audit_appendonly() from public, anon, authenticated;

drop trigger if exists trg_konsol_audit_appendonly on public.konsol_audit_logg;
create trigger trg_konsol_audit_appendonly
  before update or delete on public.konsol_audit_logg
  for each row execute function public.konsol_audit_appendonly();

drop trigger if exists trg_konsol_audit_no_truncate on public.konsol_audit_logg;
create trigger trg_konsol_audit_no_truncate
  before truncate on public.konsol_audit_logg
  for each statement execute function public.konsol_audit_appendonly();
