-- beta_ansokan_orgnr_v1 (2026-09-09): organisationsnummer krävs och kontrolleras i databasen.
--
-- Registreringsformuläret kräver sedan 2026-09-09 organisationsnummer (BokPilot tillhandahålls
-- näringsidkare; enskild firma anger personnummer), men kravet låg bara i webbläsaren —
-- skapa_beta_ansokan() tog emot null och vad som helst (granskningsfynd M5 2026-09-09).
-- Nu normaliseras numret till NNNNNN-NNNN (tolv siffror med sekel 16/19/20 kortas) och
-- kontrollsiffran räknas med Luhn, som gäller både organisations- och personnummer.
-- Samma regler som src/lib/orgnr.js i kundappen. Det verkliga konsumentfiltret är
-- fortfarande det manuella godkännandet i konsolen.

create or replace function public.orgnr_normaliserat(p text)
 returns text
 language plpgsql
 immutable
as $function$
declare
  d text := regexp_replace(coalesce(p, ''), '\D', '', 'g');
  s int := 0; n int; i int;
begin
  if length(d) = 12 and left(d, 2) in ('16', '19', '20') then d := substr(d, 3); end if;
  if length(d) <> 10 then return null; end if;
  for i in 1..10 loop
    n := substr(d, i, 1)::int;
    if i % 2 = 1 then n := n * 2; if n > 9 then n := n - 9; end if; end if;
    s := s + n;
  end loop;
  if s % 10 <> 0 then return null; end if;
  return substr(d, 1, 6) || '-' || substr(d, 7, 4);
end $function$;

revoke all on function public.orgnr_normaliserat(text) from public, anon;
grant execute on function public.orgnr_normaliserat(text) to authenticated, service_role;

create or replace function public.skapa_beta_ansokan(
  p_bolagsnamn text,
  p_org_nr text default null,
  p_meddelande text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_epost text := coalesce(auth.jwt() ->> 'email', '');
  v_approved boolean := coalesce(((auth.jwt() -> 'app_metadata') ->> 'approved')::boolean, false);
  v_company uuid;
  v_ansokan uuid;
  v_org_nr text := public.orgnr_normaliserat(p_org_nr);
begin
  if v_user is null then
    raise exception 'Ej inloggad';
  end if;
  if p_bolagsnamn is null or length(trim(p_bolagsnamn)) = 0 then
    raise exception 'Bolagsnamn saknas';
  end if;
  -- 2026-09-09: organisationsnummer (eller personnummer för enskild firma) krävs och ska ha giltig kontrollsiffra.
  if v_org_nr is null then
    raise exception 'Ange ett giltigt organisationsnummer (tio siffror, t.ex. 556123-4567)';
  end if;
  if length(coalesce(p_meddelande, '')) > 2000 then
    raise exception 'Meddelandet är för långt (max 2000 tecken)';
  end if;
  -- Idempotent: har användaren redan ett bolag skapas inget nytt.
  if exists (select 1 from user_companies where user_id = v_user) then
    raise exception 'Användaren är redan kopplad till ett bolag';
  end if;

  insert into companies (name, org_nr, suspended)
    values (trim(p_bolagsnamn), v_org_nr, not v_approved)
    returning id into v_company;

  insert into user_companies (user_id, company_id, role, email)
    values (v_user, v_company, 'admin', v_epost);

  if not v_approved then
    insert into beta_ansokningar (user_id, company_id, epost, bolagsnamn, org_nr, meddelande)
      values (v_user, v_company, v_epost, trim(p_bolagsnamn),
              v_org_nr,
              nullif(trim(coalesce(p_meddelande, '')), ''))
      returning id into v_ansokan;
  end if;

  return jsonb_build_object('company_id', v_company, 'ansokan_id', v_ansokan);
end $$;
