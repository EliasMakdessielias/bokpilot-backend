-- Kontoutdraget som arkiverat underlag: källfilen från en bankinläsning sparas som
-- dokument (kategori 'kontoutdrag') och kopplas till inläsningsbatchen. Betalnings-
-- verifikationer hittar sitt underlag via kedjan verifikation → bankhändelse →
-- import_batch → dokument (BFL 7 kap: kontoutdraget är räkenskapsinformation).
alter table public.documents add column if not exists import_batch uuid;
create index if not exists idx_documents_import_batch on public.documents(import_batch) where import_batch is not null;
