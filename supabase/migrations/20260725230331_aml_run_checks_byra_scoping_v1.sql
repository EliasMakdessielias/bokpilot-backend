do $mig$
declare
  v_def text;
  v_ny  text;
  s1 text := 'v_installningar aml_installningar%rowtype;';
  s2 text := 'if not public.ar_byra_medlem() then';
  s3 text := '''endast byråmedlem får köra AML-kontroller''';
  s4 text := 'select * into v_installningar from aml_installningar limit 1;';
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'aml_run_checks';

  if v_def is null then raise exception 'aml_run_checks hittades inte'; end if;
  if position(s1 in v_def) = 0 then raise exception 'Mönster 1 saknas'; end if;
  if position(s2 in v_def) = 0 then raise exception 'Mönster 2 saknas'; end if;
  if position(s3 in v_def) = 0 then raise exception 'Mönster 3 saknas'; end if;
  if position(s4 in v_def) = 0 then raise exception 'Mönster 4 saknas'; end if;

  v_ny := v_def;
  v_ny := replace(v_ny, s1, s1 || ' v_byra uuid;');
  v_ny := replace(v_ny, s2, 'if not public.ar_min_klient(p_company_id) then');
  v_ny := replace(v_ny, s3, '''ATKOMST_NEKAD: bolaget är inte klient hos din byrå''');
  v_ny := replace(v_ny, s4,
    'select bk.byra_bolag_id into v_byra from byra_klient bk'
    || ' where bk.klient_bolag_id = p_company_id and bk.status = ''aktiv'''
    || ' and bk.byra_bolag_id in (select public.mina_byraer()) limit 1;'
    || ' insert into aml_installningar (byra_bolag_id) values (v_byra) on conflict (byra_bolag_id) do nothing;'
    || ' select * into v_installningar from aml_installningar where byra_bolag_id = v_byra;');

  execute v_ny;
end $mig$;
