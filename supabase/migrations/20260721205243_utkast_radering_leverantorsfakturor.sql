-- Spiris-modellen: OBOKFÖRDA leverantörsfakturor är utkast — de får raderas spårlöst
-- (underlaget bevaras och återgår till Inkorgen). Bokförda fakturor ingår i bokföringen
-- och raderas ALDRIG via delete — de makuleras/rättas (BFL 5 kap). Skyddet ligger i DB
-- så ingen klient kan kringgå det.
create or replace function public.forbjud_bokford_faktura_radering()
returns trigger language plpgsql as $$
begin
  if old.bokford or old.verifikation_id is not null then
    raise exception 'Bokförda leverantörsfakturor raderas inte — makulera i stället (rättelse enligt bokföringslagen).';
  end if;
  return old;
end $$;
drop trigger if exists trg_forbjud_bokford_faktura_radering on public.supplier_invoices;
create trigger trg_forbjud_bokford_faktura_radering before delete on public.supplier_invoices
  for each row execute function public.forbjud_bokford_faktura_radering();
