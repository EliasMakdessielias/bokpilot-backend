alter table public.user_companies
  drop constraint if exists user_companies_role_check;
alter table public.user_companies
  add constraint user_companies_role_check check (role in ('admin', 'member'));

alter table public.user_companies alter column role set default 'member';

create or replace function public.ar_bolagsadmin(p_company uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.user_companies uc
    where uc.company_id = p_company
      and uc.user_id = auth.uid()
      and uc.role = 'admin'
  );
$$;

create or replace function public.acceptera_inbjudningar()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid   uuid := auth.uid();
  v_email text := auth.jwt() ->> 'email';
  v_antal int  := 0;
  r record;
begin
  if v_uid is null or v_email is null then
    raise exception 'ATKOMST_NEKAD: Du måste vara inloggad.';
  end if;

  for r in
    select id, company_id, coalesce(role, 'member') as role
    from public.company_invites
    where status = 'pending'
      and lower(email) = lower(v_email)
  loop
    insert into public.user_companies (user_id, company_id, role, email)
    values (v_uid, r.company_id,
            case when r.role = 'admin' then 'admin' else 'member' end,
            v_email)
    on conflict (user_id, company_id) do nothing;

    update public.company_invites
       set status = 'accepted'
     where id = r.id;

    v_antal := v_antal + 1;
  end loop;

  return jsonb_build_object('accepterade', v_antal);
end;
$$;

revoke execute on function public.acceptera_inbjudningar() from anon;
grant execute on function public.acceptera_inbjudningar() to authenticated;
revoke execute on function public.ar_bolagsadmin(uuid) from anon;

drop policy if exists "uc_insert" on public.user_companies;

drop policy if exists "uc_delete" on public.user_companies;
create policy "uc_delete" on public.user_companies for delete
  using (user_id = auth.uid() or public.ar_bolagsadmin(company_id));

create or replace function public.forbjud_sista_admin_bort()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if OLD.role = 'admin'
     and not exists (
       select 1 from public.user_companies uc
       where uc.company_id = OLD.company_id
         and uc.role = 'admin'
         and uc.id <> OLD.id
     )
  then
    raise exception 'SISTA_ADMIN: Bolaget måste ha minst en administratör. Utse en ny innan du tar bort den sista.';
  end if;
  return OLD;
end;
$$;

drop trigger if exists trg_forbjud_sista_admin_bort on public.user_companies;
create trigger trg_forbjud_sista_admin_bort
  before delete on public.user_companies
  for each row execute function public.forbjud_sista_admin_bort();

drop policy if exists "ci_company" on public.company_invites;
create policy "ci_company" on public.company_invites for all
  using (public.ar_bolagsadmin(company_id))
  with check (public.ar_bolagsadmin(company_id));

drop policy if exists "ci_invitee_update" on public.company_invites;
create policy "ci_invitee_update" on public.company_invites for update
  using (lower(email) = lower(auth.jwt() ->> 'email'))
  with check (lower(email) = lower(auth.jwt() ->> 'email'));
