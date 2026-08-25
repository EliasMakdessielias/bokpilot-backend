-- Lagermodulens egen filosofi (supabase/lager.sql rad 3): "händelseloggen
-- (lager_handelser) är sanningskällan – saldo, snittpris och lagervärde beräknas
-- ur den". Trots det låg en öppen `for all`-policy på tabellen: varje
-- bolagsmedlem kunde uppdatera och radera historiken fritt, utan trigger och utan
-- audit. "Makulera leverans" hårdraderade dessutom händelserna.
--
-- Eftersom lagervärdet bokförs som differens mot konto 1460 innebar det att
-- underlaget till en REDAN BOKFÖRD lagervärdering kunde ändras i efterhand.
-- Bokföringsposten gick då inte längre att följa och förstå — kärnan i
-- BFL 1 kap. 2 § p. 8 c och 7 kap. 2 §.
--
-- Loggen är nu append-only: felaktiga händelser rättas med en MOTBOKANDE
-- händelse (omvänt tecken på antal), precis som en felaktig verifikation rättas
-- med en omvänd verifikation. Klientsidan gör detta i Lager.jsx (makuleraLeverans).
create or replace function public.lager_handelser_appendonly()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.periodlas_bypass', true), '') = 'on' then
    return coalesce(NEW, OLD);
  end if;

  if TG_OP = 'DELETE' then
    raise exception 'LAGER_LAST: Lagerhändelser kan inte raderas – de är underlag till lagervärderingen (BFL 7 kap. 2 §). Rätta med en motbokande händelse i stället.';
  end if;

  raise exception 'LAGER_LAST: Lagerhändelser kan inte ändras i efterhand. Rätta med en motbokande händelse i stället.';
end;
$$;

drop trigger if exists trg_lager_handelser_appendonly on public.lager_handelser;
create trigger trg_lager_handelser_appendonly
  before update or delete on public.lager_handelser
  for each row execute function public.lager_handelser_appendonly();
