-- Byråstöd etapp A — härdning efter granskning (spegel: supabase/byrastod_v1b.sql).

alter table public.byra_klient
  drop constraint byra_klient_byra_bolag_id_fkey,
  add constraint byra_klient_byra_bolag_id_fkey
    foreign key (byra_bolag_id) references public.companies(id) on delete restrict;
alter table public.byra_klient
  drop constraint byra_klient_klient_bolag_id_fkey,
  add constraint byra_klient_klient_bolag_id_fkey
    foreign key (klient_bolag_id) references public.companies(id) on delete restrict;
alter table public.byra_medlemskap
  drop constraint byra_medlemskap_byra_bolag_id_fkey,
  add constraint byra_medlemskap_byra_bolag_id_fkey
    foreign key (byra_bolag_id) references public.companies(id) on delete restrict;

create or replace function public.ar_byra_medlem() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.byra_medlemskap
    where anvandare_id = auth.uid() and aktiv
  );
$$;
