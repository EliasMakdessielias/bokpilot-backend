-- Byråstöd v4b (2026-07-14): städar bort oanvänd variabel ur sista admin-skyddet.
create or replace function public.skydda_sista_byra_admin()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if old.roll = 'admin' and old.aktiv
     and (tg_op = 'DELETE' or new.roll <> 'admin' or not new.aktiv) then
    if not exists (
      select 1 from byra_medlemskap
      where byra_bolag_id = old.byra_bolag_id and id <> old.id and aktiv and roll = 'admin'
    ) then
      raise exception 'Byråns sista administratör kan inte inaktiveras, nedgraderas eller tas bort';
    end if;
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end $$;
