create or replace function public.mina_byraer()
returns setof uuid language sql stable security definer set search_path = ''
as $$
  select bm.byra_bolag_id from public.byra_medlemskap bm
  where bm.anvandare_id = auth.uid() and bm.aktiv = true
$$;

create or replace function public.mina_klientbolag()
returns setof uuid language sql stable security definer set search_path = ''
as $$
  select bk.klient_bolag_id from public.byra_klient bk
  where bk.status = 'aktiv' and bk.byra_bolag_id in (select public.mina_byraer())
$$;

create or replace function public.ar_min_klient(p_company uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select p_company in (select public.mina_klientbolag()) $$;

revoke execute on function public.mina_byraer() from anon;
revoke execute on function public.mina_klientbolag() from anon;
revoke execute on function public.ar_min_klient(uuid) from anon;

drop policy if exists "kyc_select_byra" on public.kyc_assessments;
create policy "kyc_select_byra" on public.kyc_assessments for select to authenticated
  using (company_id in (select public.mina_klientbolag()));
drop policy if exists "kyc_insert_byra" on public.kyc_assessments;
create policy "kyc_insert_byra" on public.kyc_assessments for insert to authenticated
  with check (company_id in (select public.mina_klientbolag()));
drop policy if exists "kyc_update_byra" on public.kyc_assessments;
create policy "kyc_update_byra" on public.kyc_assessments for update to authenticated
  using (company_id in (select public.mina_klientbolag()))
  with check (company_id in (select public.mina_klientbolag()));

drop policy if exists "aml_select_byra" on public.aml_flags;
create policy "aml_select_byra" on public.aml_flags for select to authenticated
  using (company_id in (select public.mina_klientbolag()));
drop policy if exists "aml_insert_byra" on public.aml_flags;
create policy "aml_insert_byra" on public.aml_flags for insert to authenticated
  with check (company_id in (select public.mina_klientbolag()));
drop policy if exists "aml_update_byra" on public.aml_flags;
create policy "aml_update_byra" on public.aml_flags for update to authenticated
  using (company_id in (select public.mina_klientbolag()))
  with check (company_id in (select public.mina_klientbolag()));

alter table public.aml_installningar
  add column if not exists byra_bolag_id uuid references public.companies(id) on delete cascade;

update public.aml_installningar
   set byra_bolag_id = (select bm.byra_bolag_id from public.byra_medlemskap bm limit 1)
 where byra_bolag_id is null;

delete from public.aml_installningar where byra_bolag_id is null;

alter table public.aml_installningar drop constraint if exists aml_installningar_pkey;
alter table public.aml_installningar alter column byra_bolag_id set not null;
alter table public.aml_installningar add primary key (byra_bolag_id);
alter table public.aml_installningar alter column id drop not null;

drop policy if exists "aml_install_select_byra" on public.aml_installningar;
create policy "aml_install_select_byra" on public.aml_installningar for select to authenticated
  using (byra_bolag_id in (select public.mina_byraer()));
drop policy if exists "aml_install_update_byra" on public.aml_installningar;
create policy "aml_install_update_byra" on public.aml_installningar for update to authenticated
  using (byra_bolag_id in (select public.mina_byraer()))
  with check (byra_bolag_id in (select public.mina_byraer()));
drop policy if exists "aml_install_insert_byra" on public.aml_installningar;
create policy "aml_install_insert_byra" on public.aml_installningar for insert to authenticated
  with check (byra_bolag_id in (select public.mina_byraer()));

create or replace function public.has_kyc_clearance(p_company_id uuid)
returns boolean language sql stable security definer set search_path to 'public'
as $function$
  select case
    when not (public.ar_min_klient(p_company_id)
              or p_company_id in (select public.user_company_ids())
              or public.is_platform_admin())
    then null
    else exists (
      select 1 from kyc_assessments k
      where k.company_id = p_company_id
        and k.status = 'godkand'
        and (k.giltig_till is null or k.giltig_till >= current_date)
        and coalesce(k.sanktion_traff, false) = false
        and k.created_at = (select max(created_at) from kyc_assessments where company_id = p_company_id)
    )
    and not exists (
      select 1 from aml_flags f
      where f.company_id = p_company_id and f.typ = 'sanktionstraff' and f.status = 'oppen'
    )
  end;
$function$;
