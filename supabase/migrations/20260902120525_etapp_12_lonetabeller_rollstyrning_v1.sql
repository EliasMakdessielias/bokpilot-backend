-- Etapp 12: rollstyrning på lönetabellerna.
--
-- employees, lonebesked, lonekorningar, salaries och agi_deklarationer hade alla
-- policyn "company_id in (select user_company_ids())" FOR ALL. RLS skilde alltså bara
-- på bolag, inte på roll: en praktikant eller en klientanvändare inlagd för att
-- attestera fakturor kunde läsa och ändra personnummer, clearingnummer, kontonummer
-- och löneuppgifter. Art. 25.2 GDPR kräver att uppgifter inte som standard görs
-- tillgängliga för fler än nödvändigt.
--
-- Kolumnen user_companies.role (admin|member) fanns men användes inte i någon
-- policy, och user_companies.moduler (text[]) var påbörjad men oimplementerad.
-- Båda tas nu i bruk: lönedata nås av bolagsadministratörer, samt av medlemmar som
-- uttryckligen fått modulen 'lon'.
--
-- Alla nuvarande medlemmar är admin, så ingen tappar åtkomst i dag. Lönetabellerna
-- är dessutom tomma (0 rader) — det här är en förutsättning för första lönekörningen,
-- inte en rättelse av något som redan läckt.

create or replace function public.mina_lonebolag()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $fn$
  select uc.company_id
  from public.user_companies uc
  where uc.user_id = auth.uid()
    and (uc.role = 'admin' or 'lon' = any(coalesce(uc.moduler, '{}'::text[])));
$fn$;

revoke execute on function public.mina_lonebolag() from public, anon;
grant execute on function public.mina_lonebolag() to authenticated;

-- Audit för personuppgiftstabeller. Loggar ALDRIG värden — bara vilken rad, vilken
-- åtgärd, vem, och vilka kolumner som ändrades. audit_log är läsbar för bolagets
-- medlemmar, så fulla rader hade läckt personnummer bakvägen till dem som inte
-- får se lönetabellerna.
create or replace function public.audit_personuppgifter()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare v_ref text; v_company uuid; v_andrade text[];
begin
  if tg_op = 'DELETE' then
    v_ref := old.id::text; v_company := old.company_id;
  else
    v_ref := new.id::text; v_company := new.company_id;
  end if;

  if tg_op = 'UPDATE' then
    select array_agg(n.key order by n.key) into v_andrade
    from jsonb_each(to_jsonb(new)) n
    where n.value is distinct from (to_jsonb(old) -> n.key);
  end if;

  perform public.log_accounting_audit(
    lower(tg_op), tg_table_name, v_ref, 'trigger',
    jsonb_build_object('personuppgifter', true,
                       'andrade_kolumner', coalesce(v_andrade, '{}'::text[])),
    v_company, null, null);

  return coalesce(new, old);
end $fn$;

revoke execute on function public.audit_personuppgifter() from public, anon, authenticated;

drop trigger if exists trg_audit_personuppgifter on public.employees;
create trigger trg_audit_personuppgifter
  after insert or update or delete on public.employees
  for each row execute function public.audit_personuppgifter();

drop trigger if exists trg_audit_personuppgifter on public.lonebesked;
create trigger trg_audit_personuppgifter
  after insert or update or delete on public.lonebesked
  for each row execute function public.audit_personuppgifter();

-- Byt ut de fem breda policyerna mot rollstyrda.
do $$
declare t text;
begin
  foreach t in array array['employees','lonebesked','lonekorningar','salaries','agi_deklarationer'] loop
    execute format('drop policy if exists %I on public.%I', t || '_policy', t);
    execute format(
      'create policy %I on public.%I as permissive for all to authenticated
         using (company_id in (select public.mina_lonebolag()))
         with check (company_id in (select public.mina_lonebolag()))',
      t || '_lon_policy', t);
  end loop;
end $$;
