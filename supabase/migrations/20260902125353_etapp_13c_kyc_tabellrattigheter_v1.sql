-- Följdfix etapp 13a: tabellrättigheterna ska motsvara avsikten, inte bara RLS.
--
-- Supabases standardrättigheter (ALTER DEFAULT PRIVILEGES) ger authenticated ALL på
-- varje ny tabell som postgres skapar. Etapp 13a återkallade bara från public/anon,
-- så authenticated behöll DELETE/TRUNCATE m.m. på kyc_huvudman och UPDATE/DELETE på
-- kyc_bilagor. RLS utan delete-policy hindrade raderingen i praktiken, men skyddet
-- ska ligga i båda lagren. Avsikt: huvudman select/insert/update (rättelser av
-- ägarandel och kontrollsätt är legitima), bilagor select/insert (bevismaterial
-- ändras inte i efterhand; borttag sker via avveckling/arkiv).
revoke delete, truncate, references, trigger on public.kyc_huvudman from authenticated;
revoke update, delete, truncate, references, trigger on public.kyc_bilagor from authenticated;
