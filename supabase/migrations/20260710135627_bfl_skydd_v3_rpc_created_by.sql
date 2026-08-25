-- BFL-skydd v3: bokfor_verifikation får valfri p_created_by (för betrodda server-
-- anrop som MCP-connectorn, där auth.uid() är null men användaren är känd och
-- verifierad i applikationslagret). Klientanrop påverkas inte (default = auth.uid()).
-- Gamla signaturen droppas för att undvika överlagringstvetydighet i PostgREST.

drop function if exists public.bokfor_verifikation(uuid, text, date, text, jsonb, text);

create or replace function public.bokfor_verifikation(
  p_company_id uuid,
  p_serie text,
  p_datum date,
  p_beskrivning text,
  p_rader jsonb,
  p_motpart text default null,
  p_created_by uuid default null
) returns public.verifikationer
language plpgsql
as $$
declare
  v_nr text;
  v_ver public.verifikationer;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  rad jsonb;
  i int := 0;
begin
  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'Verifikationen saknar rader';
  end if;
  select coalesce(sum(coalesce((x->>'debet')::numeric, 0)), 0),
         coalesce(sum(coalesce((x->>'kredit')::numeric, 0)), 0)
    into v_debet, v_kredit
    from jsonb_array_elements(p_rader) x;
  if round(v_debet, 2) <> round(v_kredit, 2) then
    raise exception 'Verifikationen balanserar inte (debet %, kredit %)', v_debet, v_kredit;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || '|' || p_serie, 0));
  v_nr := public.next_ver_nr(p_company_id, p_serie);

  insert into public.verifikationer
    (company_id, ver_nr, ver_serie, datum, beskrivning, motpart, total_debet, total_kredit, created_by)
  values
    (p_company_id, v_nr, p_serie, p_datum, left(p_beskrivning, 500),
     nullif(trim(coalesce(p_motpart, '')), ''), round(v_debet, 2), round(v_kredit, 2),
     coalesce(p_created_by, auth.uid()))
  returning * into v_ver;

  for rad in select * from jsonb_array_elements(p_rader) loop
    insert into public.verifikation_rows
      (verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
    values
      (v_ver.id, rad->>'account_nr', rad->>'account_name',
       coalesce((rad->>'debet')::numeric, 0), coalesce((rad->>'kredit')::numeric, 0),
       nullif(rad->>'transaction_info', ''), coalesce((rad->>'sort_order')::int, i));
    i := i + 1;
  end loop;

  return v_ver;
end $$;
