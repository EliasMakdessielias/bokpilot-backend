-- bfl_skydd v6: bokfor_verifikation får p_kommentar och p_ersatter så att ALLT sätts
-- i den atomiska INSERT:en (ultragranskning 2026-07-10):
--   * p_ersatter vid INSERT → trg_validate_ver_links validerar rättelsekedjan (originalet
--     måste vara status='rattad', samma bolag) och audit-triggern loggar
--     verification_replacement_created/verification_corrected – båda förbigicks när
--     ersatter sattes via UPDATE i efterhand.
--   * p_kommentar vid INSERT → inga okontrollerade efterhandsuppdateringar som kunde
--     tappa kommentaren tyst.
-- Signaturbyte kräver drop (PostgREST-överlagring).

drop function if exists public.bokfor_verifikation(uuid, text, date, text, jsonb, text, uuid, text);

create or replace function public.bokfor_verifikation(
  p_company_id uuid, p_serie text, p_datum date, p_beskrivning text, p_rader jsonb,
  p_motpart text default null, p_created_by uuid default null, p_source text default null,
  p_kommentar text default null, p_ersatter uuid default null
) returns public.verifikationer
language plpgsql as $$
declare
  v_nr text;
  v_ver public.verifikationer;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  rad jsonb;
  i int := 0;
begin
  if p_source is not null and p_source in ('ai', 'mcp') then
    perform set_config('app.audit_source', p_source, true);   -- läses av audit-triggrarna
  end if;
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
    (company_id, ver_nr, ver_serie, datum, beskrivning, motpart, kommentar, ersatter,
     total_debet, total_kredit, created_by)
  values
    (p_company_id, v_nr, p_serie, p_datum, left(p_beskrivning, 500),
     nullif(trim(coalesce(p_motpart, '')), ''), nullif(trim(coalesce(p_kommentar, '')), ''),
     p_ersatter, round(v_debet, 2), round(v_kredit, 2),
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

grant execute on function public.bokfor_verifikation(uuid, text, date, text, jsonb, text, uuid, text, text, uuid) to authenticated, service_role;
