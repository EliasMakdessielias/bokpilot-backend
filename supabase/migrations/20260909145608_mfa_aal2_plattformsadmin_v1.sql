-- mfa_aal2_plattformsadmin_v1 (2026-09-09): plattformsadmin kräver steg 2 i databasen.
--
-- is_platform_admin() ligger bakom 18 RLS-policies och 8 funktioner (is_superadmin,
-- has_platform_role, my_platform_access, can_* …). Hittills räckte det att JWT:ns e-post
-- fanns i platform_admins — även med en aal1-token från en session som ännu inte gått
-- igenom tvåfaktorns steg 2. Nu krävs claimen aal = 'aal2' SÅ SNART kontot har en
-- verifierad MFA-faktor (auth.mfa_factors.status = 'verified'). Konton utan faktor är
-- opåverkade, så ingen låses ute innan de själva aktiverat skyddet (granskningsfynd F1,
-- regelefterlevnad 2026-09-09). service_role saknar e-post i JWT:n och var aldrig admin här.
create or replace function public.is_platform_admin()
 returns boolean
 language sql
 stable
 security definer
 set search_path to 'public'
as $function$
  select exists(select 1 from platform_admins where lower(email) = lower(auth.jwt() ->> 'email'))
     and (
       coalesce(auth.jwt() ->> 'aal', 'aal1') = 'aal2'
       or not exists (
         select 1 from auth.mfa_factors f
         where f.user_id = auth.uid() and f.status = 'verified'
       )
     )
$function$;
