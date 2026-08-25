-- Seed utan räkenskapsår (2026-07-15, Elias beslut): nya bolag får kontoplanen
-- automatiskt men INGET förinställt räkenskapsår — första året väljs medvetet i
-- startguiden (kalenderår eller brutet; valideras av rakenskapsar_regler +
-- src/lib/rakenskapsar.js). Ersätter seed_new_company från seed_new_companies.sql.
create or replace function seed_new_company() returns trigger as $$
begin
  insert into accounts (company_id, account_nr, name, vat_code, is_active)
    select NEW.id, account_nr, name, vat_code, is_active from bas_accounts
    on conflict (company_id, account_nr) do nothing;
  return NEW;
end;
$$ language plpgsql security definer;
