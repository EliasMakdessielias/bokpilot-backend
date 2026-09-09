-- Migration byrastod_scope_v1 (2026-09-09): byrastod_markera_forsenade tar ett valfritt
-- byråfilter. Edge-funktionen byrastod-jobb kör som service_role och skickar anroparens
-- egna byråer (mina_byraer) vid manuell körning; cron (ingen lista) markerar alla.
-- Bakgrund: granskningen 2026-08-25 fann att en byråmedlem kunde köra jobbet över ALLA
-- byråer och få andra byråers uppdrags-id:n i svaret. Klientlogik: supabase/functions/
-- byrastod-jobb/index.ts + _shared/byra.ts.
--
-- Signaturen ändras (ny parameter) → den gamla nollargumentsversionen måste droppas,
-- annars blir PostgREST-anropet tvetydigt. Anrop utan argument matchar fortfarande
-- (parametern har default), så en odeployad edge-funktion fortsätter fungera.
drop function if exists public.byrastod_markera_forsenade();

create or replace function public.byrastod_markera_forsenade(p_byra_bolag_ids uuid[] default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare v_antal int;
begin
  if not public._ar_betrodd_backend() and not public.ar_byra_medlem() then
    raise exception 'endast byråmedlem eller systemjobb';
  end if;
  -- En inloggad byråmedlem begränsas alltid till sina egna byråer, oavsett parameter.
  if not public._ar_betrodd_backend() then
    p_byra_bolag_ids := array(select public.mina_byraer());
  end if;
  update public.uppdragsuppgift set status = 'forsenad', updated_at = now()
  where status in ('ej_paborjad', 'pagar')
    and coalesce(justerat_forfallodatum, ordinarie_forfallodatum) < current_date
    and (p_byra_bolag_ids is null or byra_bolag_id = any (p_byra_bolag_ids));
  get diagnostics v_antal = row_count;
  return v_antal;
end $$;

revoke all on function public.byrastod_markera_forsenade(uuid[]) from public, anon, authenticated;
grant execute on function public.byrastod_markera_forsenade(uuid[]) to service_role;
