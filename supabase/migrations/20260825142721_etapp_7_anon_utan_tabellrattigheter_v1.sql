-- Etapp 7: `anon` hade fortfarande full DML (SELECT/INSERT/UPDATE/DELETE/TRUNCATE/
-- REFERENCES/TRIGGER) på ~101 tabeller. Etapp 3 tog de fem bokföringstabellerna och
-- etapp 4 elva interna — resten stod kvar sedan Supabases standardgrants.
--
-- Empiriskt verifierat före ändringen att rättigheterna är verkningslösa i dag: anon
-- läser 0 rader ur samtliga 101 tabeller och 0 av 101 skrivförsök går igenom (RLS
-- stoppar alla). Frontenden gör dessutom noll anon-anrop — hela produktionsbundeln
-- är genomsökt. Indragningen är därför ren defense-in-depth: den tar bort beroendet
-- av att varje enskild RLS-policy är korrekt skriven.
--
-- `authenticated` lämnas HELT orörd.
do $$
declare t record; n int := 0;
begin
  for t in
    select c.relname
    from pg_class c
    join pg_namespace ns on ns.oid = c.relnamespace and ns.nspname = 'public'
    where c.relkind in ('r','p','v','m','f')
      and exists (
        select 1 from information_schema.role_table_grants g
        where g.table_schema = 'public' and g.table_name = c.relname and g.grantee = 'anon')
  loop
    execute format('revoke all on table public.%I from anon', t.relname);
    n := n + 1;
  end loop;
  raise notice 'Tabeller dar anon fick rattigheter indragna: %', n;
end$$;

-- Framtida tabeller skapade av postgres ska inte heller ge anon något.
alter default privileges for role postgres in schema public revoke all on tables from anon;
