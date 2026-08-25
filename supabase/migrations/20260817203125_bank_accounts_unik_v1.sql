-- Dubblettstädning + unikhetsskydd för bank_accounts.
-- Bakgrund: ensureStandardBankAccounts() (klienten) seedade standardkontona i
-- kapplöpning 2026-07-21 (två sidladdningar samtidigt) → tre dubbletter för ett
-- bolag. Inga tabeller refererar bank_accounts (varken FK eller mjuka kolumner) —
-- radering av tvillingarna är riskfri.

-- 1. Radera yngre tvillingar: behåll äldsta raden per (company_id, account_nr).
delete from public.bank_accounts ba
using public.bank_accounts aldre
where aldre.company_id = ba.company_id
  and aldre.account_nr = ba.account_nr
  and aldre.id <> ba.id
  and (aldre.created_at < ba.created_at
       or (aldre.created_at = ba.created_at and aldre.id < ba.id));

-- 2. Unikt index: ett bankkonto per bokföringskonto och bolag. Gör också att
--    klientens upsert med on_conflict=company_id,account_nr fungerar atomiskt.
create unique index if not exists bank_accounts_company_account_nr_unik
  on public.bank_accounts (company_id, account_nr);
