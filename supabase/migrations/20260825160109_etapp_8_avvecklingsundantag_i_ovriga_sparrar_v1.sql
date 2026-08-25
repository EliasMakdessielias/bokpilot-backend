-- Följdfix 2 till etapp 8. Kaskaden från companies passerar ett trettiotal
-- DELETE-triggrar. De flesta respekterar redan app.periodlas_bypass, som
-- avveckla_bolag() sätter, men fem gör det inte och blockerade därför även den
-- sanktionerade avvecklingen:
--   enforce_company_write_lock (15 tabeller), protect_locked_account,
--   arkiv_skydda_rakenskapsinfo, arkiv_mapp_fore_radering,
--   forbjud_bokford_faktura_radering
--
-- Undantaget begränsas till TG_OP = 'DELETE'. Insert och update påverkas inte,
-- så spärrarnas egentliga syfte — att skydda levande bolags data — är intakt.
do $do$
declare
  mal text[] := array[
    'enforce_company_write_lock()',
    'protect_locked_account()',
    'arkiv_skydda_rakenskapsinfo()',
    'arkiv_mapp_fore_radering()',
    'forbjud_bokford_faktura_radering()'
  ];
  f text; def text; ny text; n int := 0;
  vakt constant text := $g$
  -- Sanktionerad avveckling av hela bolaget (se avveckla_bolag): spärren gäller inte.
  if tg_op = 'DELETE' and current_setting('app.bfl_avveckla', true) = 'on' then
    return OLD;
  end if;
$g$;
begin
  foreach f in array mal loop
    def := pg_get_functiondef(('public.' || f)::regprocedure);

    if def ~ 'bfl_avveckla' then
      continue;                      -- redan patchad, idempotent
    end if;

    ny := regexp_replace(def, E'\nbegin\n', E'\nbegin\n' || vakt, '');

    if ny = def then
      raise exception 'Kunde inte infoga avvecklingsvakt i % — funktionens struktur ser annorlunda ut än väntat. Avbryter utan att ändra något.', f;
    end if;

    execute ny;
    n := n + 1;
  end loop;

  if n = 0 then
    raise exception 'Ingen funktion patchades — kontrollera mållistan.';
  end if;
  raise notice 'Avvecklingsvakt inlagd i % funktioner', n;
end $do$;
