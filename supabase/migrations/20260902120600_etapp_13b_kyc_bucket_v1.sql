-- Etapp 13b: privat bucket för kundkännedomsunderlag.
--
-- Migrationen 20260725191343_arkiv_v1c_regelefterlevnad tog bort arkivmappen
-- "Uppdrag och kundkännedom" med motiveringen att KYC-materialet hör hemma i
-- KYC-lagret, som "redan har rätt bevarandetid" — men KYC-lagret hade ingen
-- fillagring. Den enda plats där ett registerutdrag kunde arkiveras var alltså
-- bortbyggd på felaktig premiss. Här återställs möjligheten, på rätt ställe.
--
-- Sökvägsformat: <company_id>/<kyc_id>/<uuid>.<ext>. Scopet är byråns klientbolag,
-- precis som kyc_assessments. Ingen DELETE-policy: PTL 5 kap. 3 § kräver fem års
-- bevarande.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('kyc', 'kyc', false, 20971520,
        array['application/pdf','image/png','image/jpeg','image/jpg','image/webp'])
on conflict (id) do nothing;

drop policy if exists kyc_obj_select on storage.objects;
create policy kyc_obj_select on storage.objects for select to authenticated
  using (bucket_id = 'kyc'
         and (storage.foldername(name))[1] in (select k::text from public.mina_klientbolag() k));

drop policy if exists kyc_obj_insert on storage.objects;
create policy kyc_obj_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'kyc'
              and (storage.foldername(name))[1] in (select k::text from public.mina_klientbolag() k));
