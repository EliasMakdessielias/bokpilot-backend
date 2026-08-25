-- SIE-importen skrev tidigare header och rader i två separata anrop från klienten
-- — enda stället i systemet som gick förbi den atomiska bokföringsvägen. Gick
-- radinsertet fel försökte klienten städa med radera_senaste_verifikation, som
-- bara fungerar om posten är seriens högsta nummer; SIE-filer i fallande ordning
-- lämnade därför kvar en header UTAN rader, som ändå räknades in i
-- balansräkningen via total_debet.
--
-- Här sker allt i EN transaktion, med balanskontroll i databasen som sista
-- försvar (klienten kontrollerar redan i src/lib/sieValidering.js).
-- Verifikationsnumret bevaras från källsystemet — det är hela poängen med en
-- SIE-import — men unikhetsvillkoret ger ett begripligt fel i stället för ett
-- rått databasfel.
create or replace function public.sie_importera_verifikation(
  p_company       uuid,
  p_ver_nr        text,
  p_ver_serie     text,
  p_datum         date,
  p_beskrivning   text,
  p_rader         jsonb,
  p_sie_import_id uuid
)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_id uuid;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  v_diff numeric;
begin
  perform public._assert_company_access(p_company);

  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'SIE_TOM: Verifikation % saknar konteringsrader.', p_ver_nr;
  end if;

  select coalesce(sum(round((r->>'debet')::numeric, 2)), 0),
         coalesce(sum(round((r->>'kredit')::numeric, 2)), 0)
    into v_debet, v_kredit
  from jsonb_array_elements(p_rader) r;

  v_diff := round(v_debet - v_kredit, 2);
  if v_diff <> 0 then
    raise exception 'SIE_OBALANS: Verifikation % balanserar inte (debet %, kredit %, differens %).',
      p_ver_nr, v_debet, v_kredit, v_diff;
  end if;

  if exists (select 1 from verifikationer where company_id = p_company and ver_nr = p_ver_nr) then
    raise exception 'SIE_DUBBLETT: Verifikationsnumret % finns redan i bolaget.', p_ver_nr;
  end if;

  insert into verifikationer (company_id, ver_nr, ver_serie, datum, beskrivning,
                              total_debet, total_kredit, created_by, sie_import_id)
  values (p_company, p_ver_nr, p_ver_serie, p_datum, coalesce(p_beskrivning, 'SIE-import'),
          v_debet, v_kredit, auth.uid(), p_sie_import_id)
  returning id into v_id;

  insert into verifikation_rows (verifikation_id, account_nr, account_name, debet, kredit, sort_order)
  select v_id,
         r->>'account_nr',
         coalesce(r->>'account_name', ''),
         round((r->>'debet')::numeric, 2),
         round((r->>'kredit')::numeric, 2),
         (r->>'sort_order')::int
  from jsonb_array_elements(p_rader) r;

  return v_id;
end;
$function$;

revoke execute on function public.sie_importera_verifikation(uuid, text, text, date, text, jsonb, uuid) from public, anon;
