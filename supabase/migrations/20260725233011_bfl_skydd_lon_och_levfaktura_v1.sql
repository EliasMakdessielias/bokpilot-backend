-- BFL-skydd som saknades: gränssnittet spärrade, men databasen gjorde det inte.
-- Allt som går via PostgREST kunde alltså kringgå spärren.
--
-- 1) Bokförda lönekörningar kunde raderas (kaskad till lonebesked). Lönebeskeden
--    är räkenskapsinformation och underlag till AGI (BFL 7 kap. 2 §) — och
--    löneverifikationen blev kvar utan underlag.
create or replace function public.forbjud_bokford_lonekorning_radering()
returns trigger
language plpgsql
as $$
begin
  if coalesce(OLD.bokford, false) = true
     and coalesce(current_setting('app.periodlas_bypass', true), '') <> 'on' then
    raise exception 'BFL_SKYDD: Lönekörningen är bokförd och kan inte raderas. Rätta med en omvänd verifikation i stället.';
  end if;
  return OLD;
end;
$$;

drop trigger if exists trg_forbjud_bokford_lonekorning_radering on public.lonekorningar;
create trigger trg_forbjud_bokford_lonekorning_radering
  before delete on public.lonekorningar
  for each row execute function public.forbjud_bokford_lonekorning_radering();

-- 2) Bokförda leverantörsfakturor kunde ÄNDRAS. Raderingsskyddet fanns sedan
--    tidigare (utkast_radering_leverantorsfakturor.sql), men bara för DELETE —
--    trots att filens egen kommentar utlovar att "ingen klient kan kringgå det".
--    Belopp, moms och kostnadskonto på en bokförd faktura styr vad som redan
--    ligger i böckerna; ändras de stämmer inte verifikationen med underlaget.
create or replace function public.forbjud_andring_bokford_levfaktura()
returns trigger
language plpgsql
as $$
begin
  if coalesce(OLD.bokford, false) = true
     and coalesce(current_setting('app.periodlas_bypass', true), '') <> 'on'
     and (OLD.total_amount is distinct from NEW.total_amount
       or OLD.vat_amount   is distinct from NEW.vat_amount
       or OLD.kostnadskonto is distinct from NEW.kostnadskonto
       or OLD.invoice_date is distinct from NEW.invoice_date
       or OLD.supplier_id  is distinct from NEW.supplier_id)
  then
    raise exception 'BFL_SKYDD: Fakturan är bokförd – belopp, moms, konto, datum och leverantör kan inte ändras. Makulera och bokför om i stället.';
  end if;
  return NEW;
end;
$$;

drop trigger if exists trg_forbjud_andring_bokford_levfaktura on public.supplier_invoices;
create trigger trg_forbjud_andring_bokford_levfaktura
  before update on public.supplier_invoices
  for each row execute function public.forbjud_andring_bokford_levfaktura();
