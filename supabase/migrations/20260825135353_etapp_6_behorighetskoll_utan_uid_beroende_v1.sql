-- Etapp 6: fyra funktioner kopplade sin behörighetskoll till att en aktör FINNS
-- (`if auth.uid() is not null and not <koll>`) i stället för till behörighet. Kollen
-- hoppades därmed över i varje kontext där auth.uid() är null.
--
-- Rätt semantik: hoppa över kollen endast för bevisat betrodda backendkontexter
-- (service_role via edge functions, samt cron/migrationer utan PostgREST-kontext).
-- För allt annat ska behörigheten krävas. Medlemskapsvillkoren lämnas oförändrade,
-- så ingen användare får mer eller mindre åtkomst än i dag.

create or replace function public._ar_betrodd_backend()
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare v text;
begin
  v := nullif(current_setting('request.jwt.claims', true), '');
  if v is null then
    return true;    -- ingen PostgREST-kontext alls: cron, migrationer, psql
  end if;
  return (v::jsonb ->> 'role') = 'service_role';
exception when others then
  return false;     -- fail-closed: går kontexten inte att avgöra, kräv behörighet
end $fn$;

revoke execute on function public._ar_betrodd_backend() from public, anon, authenticated;

do $$
declare
  mal text[] := array[
    'makulera_verifikation(uuid,text)',
    'ratta_verifikation(uuid,text,date)',
    'run_monthly_control(uuid,integer,integer)',
    'byrastod_markera_forsenade()'
  ];
  f text; def text; ny text; antal int;
begin
  foreach f in array mal loop
    def := pg_get_functiondef(('public.' || f)::regprocedure);
    ny := def;

    -- makulera_verifikation / ratta_verifikation
    ny := replace(ny,
      'if v_actor is not null and not exists (',
      'if not public._ar_betrodd_backend() and not exists (');

    -- run_monthly_control
    ny := replace(ny,
      'if auth.uid() is not null and not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=p_company_id) then',
      'if not public._ar_betrodd_backend() and not exists (select 1 from user_companies uc where uc.user_id=auth.uid() and uc.company_id=p_company_id) then');

    -- byrastod_markera_forsenade
    ny := replace(ny,
      'if auth.uid() is not null and not public.ar_byra_medlem() then',
      'if not public._ar_betrodd_backend() and not public.ar_byra_medlem() then');

    if ny = def then
      raise exception 'Ingen ersattning traffade i % - vaktsatsen ser annorlunda ut an vantat, avbryter', f;
    end if;

    -- ingen av funktionerna far ha kvar det gamla monstret efteråt
    if ny ~ 'auth\.uid\(\) is not null and not' or ny ~ 'v_actor is not null and not' then
      raise exception 'Kvarvarande gammalt monster i % efter ersattning, avbryter', f;
    end if;

    execute ny;
  end loop;
end$$;
