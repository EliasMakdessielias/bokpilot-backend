-- Lagen (1955:257) om inventering av varulager för inkomstbeskattningen ställer
-- två krav som modulen inte uppfyllde:
--   1 § Förteckningen ska ange VÄRDET för varje post. Vi sparade bara räknat
--       antal och saldo — värdet räknades fram i efterhand ur händelseloggen och
--       ändrades därmed retroaktivt när senare händelser flyttade snittpriset.
--   2 § Förteckningen ska undertecknas med FÖRSÄKRAN PÅ HEDER OCH SAMVETE om att
--       ingen lagertillgång undantagits. Någon sådan fanns inte.
--   3 § Uppfylls inte föreskrifterna godtas inte lagervärdet vid beskattningen.
--
-- Därför fryses värdet per post när inventeringen slutförs, och försäkran lagras
-- med namn, användar-id och tidpunkt. Slutförda inventeringar kan inte längre
-- ändras — de är underlaget till lagervärderingen (BFL 7 kap. 2 §).

alter table public.lager_inventering_rader
  add column if not exists a_pris numeric,          -- snittpris vid slutförandet
  add column if not exists varde  numeric;          -- raknat * a_pris, fryst

alter table public.lager_inventeringar
  add column if not exists forsakran_namn    text,
  add column if not exists forsakran_user_id uuid,
  add column if not exists forsakran_at      timestamptz,
  add column if not exists totalt_varde      numeric;

-- En slutförd inventering är låst: varken huvud eller rader får ändras.
create or replace function public.lager_inventering_last()
returns trigger
language plpgsql
as $$
declare v_status text;
begin
  if coalesce(current_setting('app.periodlas_bypass', true), '') = 'on' then
    return coalesce(NEW, OLD);
  end if;

  if TG_TABLE_NAME = 'lager_inventeringar' then
    if OLD.status = 'slutford' then
      raise exception 'INVENTERING_LAST: Inventering % är slutförd och kan inte ändras eller tas bort. Gör en ny inventering i stället.', OLD.nr;
    end if;
    return coalesce(NEW, OLD);
  end if;

  select status into v_status from public.lager_inventeringar where id = OLD.inventering_id;
  if v_status = 'slutford' then
    raise exception 'INVENTERING_LAST: Raden hör till en slutförd inventering och kan inte ändras. Förteckningen är underlag till lagervärderingen (lag 1955:257).';
  end if;
  return coalesce(NEW, OLD);
end;
$$;

drop trigger if exists trg_lager_inventering_last on public.lager_inventeringar;
create trigger trg_lager_inventering_last
  before update or delete on public.lager_inventeringar
  for each row execute function public.lager_inventering_last();

drop trigger if exists trg_lager_inventering_rader_last on public.lager_inventering_rader;
create trigger trg_lager_inventering_rader_last
  before update or delete on public.lager_inventering_rader
  for each row execute function public.lager_inventering_last();
