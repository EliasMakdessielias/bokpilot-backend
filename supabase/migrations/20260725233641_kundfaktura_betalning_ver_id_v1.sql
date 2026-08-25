-- Kundfakturor saknade koppling till BETALNINGENS verifikation. När en inbetalning
-- bokfördes sattes bara status = 'paid'; makulera_verifikation kunde därför inte
-- veta vilken faktura betalningen hörde till och nollade bara verifikation_id.
-- Följden: makulerades en felaktig kundinbetalning blev bankhändelsen 'unmatched'
-- igen, men fakturan låg kvar som 'paid' och plockades inte upp av matchningen i
-- Kassa och bank (som filtrerar på status = 'sent'). Betalningen gick alltså inte
-- att bokföra om.
--
-- Leverantörsfakturor har redan betalning_ver_id och hanteras korrekt — här
-- speglas samma modell.
alter table public.invoices
  add column if not exists betalning_ver_id uuid references public.verifikationer(id) on delete set null;

create index if not exists invoices_betalning_ver_id_idx
  on public.invoices (betalning_ver_id) where betalning_ver_id is not null;

-- Återställ kundfakturan när betalningsverifikationen makuleras.
do $mig$
declare
  v_def text; v_ny text;
  s text := 'update public.bank_transactions set status = ''unmatche';
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'makulera_verifikation';

  if v_def is null then raise exception 'makulera_verifikation hittades inte'; end if;
  if position(s in v_def) = 0 then raise exception 'Ankarmönstret saknas — granska funktionen manuellt'; end if;

  v_ny := replace(v_def, s,
    'update public.invoices set status = ''sent'', betalning_ver_id = null'
    || ' where betalning_ver_id = v_orig.id; '
    || s);

  execute v_ny;
end $mig$;
