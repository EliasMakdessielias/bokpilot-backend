-- Etapp 5: RLS-policies som anropar auth.uid()/auth.jwt()/auth.role() direkt omvärderas
-- en gång PER RAD. Inlindade i (select ...) beräknar Postgres dem en gång per fråga (InitPlan).
-- Semantiken är oförändrad — endast utvärderingsfrekvensen ändras.
-- Urvalet tar bara policies där INGEN förekomst redan är inlindad, därför är en global
-- ersättning trygg.
do $$
declare
  pol record;
  v_q text; v_w text; v_ddl text; antal int := 0;
begin
  for pol in
    select cls.relname as tabell, pl.polname as namn, pl.polpermissive as permissiv,
           case pl.polcmd when 'r' then 'select' when 'a' then 'insert' when 'w' then 'update'
                          when 'd' then 'delete' else 'all' end as cmd,
           coalesce((select string_agg(quote_ident(rr.rolname), ', ' order by rr.rolname)
                     from pg_roles rr where rr.oid = any(pl.polroles)), 'public') as roller,
           pg_get_expr(pl.polqual, pl.polrelid) as q,
           pg_get_expr(pl.polwithcheck, pl.polrelid) as w
    from pg_policy pl
    join pg_class cls on cls.oid = pl.polrelid
    join pg_namespace ns on ns.oid = cls.relnamespace and ns.nspname = 'public'
    where (pg_get_expr(pl.polqual, pl.polrelid) ~ 'auth\.(uid|jwt|role)\(\)'
           and pg_get_expr(pl.polqual, pl.polrelid) !~ '\(\s*SELECT\s+auth\.')
       or (pg_get_expr(pl.polwithcheck, pl.polrelid) ~ 'auth\.(uid|jwt|role)\(\)'
           and pg_get_expr(pl.polwithcheck, pl.polrelid) !~ '\(\s*SELECT\s+auth\.')
  loop
    v_q := regexp_replace(pol.q, 'auth\.(uid|jwt|role)\(\)', '( SELECT auth.\1())', 'g');
    v_w := regexp_replace(pol.w, 'auth\.(uid|jwt|role)\(\)', '( SELECT auth.\1())', 'g');

    execute format('drop policy %I on public.%I', pol.namn, pol.tabell);

    v_ddl := format('create policy %I on public.%I as %s for %s to %s',
                    pol.namn, pol.tabell,
                    case when pol.permissiv then 'permissive' else 'restrictive' end,
                    pol.cmd, pol.roller);
    if v_q is not null then v_ddl := v_ddl || format(' using (%s)', v_q); end if;
    if v_w is not null then v_ddl := v_ddl || format(' with check (%s)', v_w); end if;
    execute v_ddl;
    antal := antal + 1;
  end loop;
  raise notice 'Omskrivna policies: %', antal;
end$$;
