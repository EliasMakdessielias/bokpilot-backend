-- Inköpssidan kunde bara hantera vanlig svensk moms. En faktura med omvänd
-- betalningsskyldighet (bygg), ett unionsinternt förvärv eller en import
-- bokfördes som K 2440 / D kostnadskonto helt utan moms — köparens egen utgående
-- moms och motsvarande avdrag uteblev.
--
-- Följd för en byggfaktura på 200 000 kr: rutorna 24 (beskattningsunderlag),
-- 30 (utgående moms 50 000) och 48 (ingående moms 50 000) blev tomma. Bolaget
-- redovisade 0 i stället för 50 000 i utgående moms — en oriktig uppgift, trots
-- att momsen netto är noll.
--
-- Fältet styr konteringen i src/lib/bokforing.js (levfakturaRader):
--   normal      K 2440 / D 2640 / D kostnadskonto
--   omvand_bygg K 2440 / D kostnadskonto / K 2617 / D 2647   (ML 16 kap.)
--   eu_forvarv  K 2440 / D kostnadskonto / K 2614 / D 2645   (unionsinternt förvärv)
--   import      K 2440 / D kostnadskonto / K 2615 / D 2645   (import av varor)
alter table public.supplier_invoices
  add column if not exists momstyp text not null default 'normal';

alter table public.supplier_invoices
  drop constraint if exists supplier_invoices_momstyp_check;
alter table public.supplier_invoices
  add constraint supplier_invoices_momstyp_check
  check (momstyp in ('normal', 'omvand_bygg', 'eu_forvarv', 'import'));
