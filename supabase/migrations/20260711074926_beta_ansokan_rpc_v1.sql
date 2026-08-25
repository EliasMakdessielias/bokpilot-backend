-- Atomisk beta-registrering: bolag + admin-koppling + ansökan i EN transaktion.
-- Ersätter klientens tre separata inserts som föll på RLS (RETURNING på companies
-- kräver select-policy som förutsätter user_companies-kopplingen — hönan och ägget).
-- Förgodkända användare (app_metadata.approved) får aktivt bolag utan ansökan.
-- Spegel: bocker-app/supabase/beta_ansokningar.sql

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
begin
  if v_user is null then
    raise exception 'Ej inloggad';
  end if;
  if p_bolagsnamn is null or length(trim(p_bolagsnamn)) = 0 then
    raise exception 'Bolagsnamn saknas';
  end if;
  if length(coalesce(p_meddelande, '')) > 2000 then
    raise exception 'Meddelandet är för långt (max 2000 tecken)';
  end if;
  -- Idempotent: har användaren redan ett bolag skapas inget nytt.
  if exists (select 1 from user_companies where user_id = v_user) then
    raise exception 'Användaren är redan kopplad till ett bolag';
  end if;

  insert into companies (name, org_nr, suspended)
    values (trim(p_bolagsnamn), nullif(trim(coalesce(p_org_nr, '')), ''), not v_approved)
    returning id into v_company;

  insert into user_companies (user_id, company_id, role, email)
    values (v_user, v_company, 'admin', v_epost);

  if not v_approved then
    insert into beta_ansokningar (user_id, company_id, epost, bolagsnamn, org_nr, meddelande)
      values (v_user, v_company, v_epost, trim(p_bolagsnamn),
              nullif(trim(coalesce(p_org_nr, '')), ''),
              nullif(trim(coalesce(p_meddelande, '')), ''))
      returning id into v_ansokan;
  end if;

  return jsonb_build_object('company_id', v_company, 'ansokan_id', v_ansokan);
end $$;

revoke all on function public.skapa_beta_ansokan(text, text, text) from public, anon;
grant execute on function public.skapa_beta_ansokan(text, text, text) to authenticated;
