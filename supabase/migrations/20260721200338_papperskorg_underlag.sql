-- Papperskorg för underlag: mjuk radering i Inkorgen. raderad_at satt = ligger i
-- papperskorgen (filen behålls i storage); null = aktiv. Återställning nollar fältet.
-- Permanent radering (rad + storagefil) görs uttryckligen från papperskorgen.
-- Bokförda underlag (verifikation_id satt) raderas aldrig — BFL:s arkiveringskrav.
alter table public.documents add column raderad_at timestamptz;
comment on column public.documents.raderad_at is 'Mjuk radering (papperskorgen i Inkorgen). null = aktiv. Filen ligger kvar i storage tills permanent radering.';
