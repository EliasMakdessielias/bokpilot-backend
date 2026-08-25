-- Räkenskapsårsskydd (BFL 7 kap; REGELEFTERLEVNAD.md åtgärd 11).
-- 1) Bokföring kräver att företaget har räkenskapsår upplagt (tidigare: inga år = ingen spärr).
-- 2) Räkenskapsår med bokförda verifikationer kan inte raderas, och datumgränserna kan inte
--    ändras så att bokförda poster hamnar utanför året.
-- Bypass: app.periodlas_bypass (endast reset/purge) + företag under cascade-radering.

create or replace function public.assert_period_open(p_company uuid, p_datum date) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_lock text; v_lock_end date; v_fy int; v_open int;
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then return; end if;
  if p_company is null or p_datum is null then return; end if;

  select bokforing_last_tom into v_lock from public.companies where id = p_company;
  if not found then return; end if;   -- företaget håller på att raderas (cascade) – inget att skydda

  if v_lock is not null and v_lock <> '' then
    if v_lock ~ '^\d{4}-\d{2}$' then
      v_lock_end := (to_date(v_lock || '-01', 'YYYY-MM-DD') + interval '1 month - 1 day')::date;
    elsif v_lock ~ '^\d{4}-\d{2}-\d{2}$' then
      v_lock_end := to_date(v_lock, 'YYYY-MM-DD');
    end if;
    if v_lock_end is not null and p_datum <= v_lock_end then
      raise exception 'PERIODLÅST: Bokföringen är låst till och med %. Verifikationer daterade % eller tidigare kan inte skapas, ändras eller raderas. Justera låset under Inställningar om det är fel.', v_lock, v_lock_end;
    end if;
  end if;

  select count(*) into v_fy from public.fiscal_years where company_id = p_company;
  if v_fy = 0 then
    raise exception 'RÄKENSKAPSÅR SAKNAS: Företaget har inget räkenskapsår upplagt. Lägg upp räkenskapsår under Inställningar → Räkenskapsår innan du bokför.';
  end if;
  select count(*) into v_open from public.fiscal_years
    where company_id = p_company and status = 'active' and p_datum between start_date and end_date;
  if v_open = 0 then
    raise exception 'PERIODLÅST: Datumet % ligger utanför öppet räkenskapsår. Öppna rätt räkenskapsår under Inställningar → Räkenskapsår.', p_datum;
  end if;
end $$;

create or replace function public.skydda_rakenskapsar() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_antal int;
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if not exists (select 1 from public.companies where id = old.company_id) then
    return case when tg_op = 'DELETE' then old else new end;   -- cascade vid företagsradering
  end if;
  if tg_op = 'DELETE' then
    select count(*) into v_antal from public.verifikationer
      where company_id = old.company_id and datum between old.start_date and old.end_date;
    if v_antal > 0 then
      raise exception 'RÄKENSKAPSÅRSSKYDD: Räkenskapsår % innehåller % bokförda verifikationer och kan inte raderas (BFL 7 kap). Makulera posterna eller kontakta support om året är felupplagt.', old.year, v_antal;
    end if;
    return old;
  end if;
  -- UPDATE: statusbyten är fria, men datumgränserna får inte ändras så att
  -- bokförda poster hamnar utanför året.
  if new.start_date is distinct from old.start_date or new.end_date is distinct from old.end_date then
    select count(*) into v_antal from public.verifikationer
      where company_id = old.company_id
        and datum between old.start_date and old.end_date
        and datum not between new.start_date and new.end_date;
    if v_antal > 0 then
      raise exception 'RÄKENSKAPSÅRSSKYDD: % bokförda verifikationer skulle hamna utanför räkenskapsår % med de nya datumgränserna. Ändringen stoppades.', v_antal, old.year;
    end if;
  end if;
  return new;
end $$;

drop trigger if exists trg_skydda_rakenskapsar on public.fiscal_years;
create trigger trg_skydda_rakenskapsar
  before update or delete on public.fiscal_years
  for each row execute function public.skydda_rakenskapsar();
