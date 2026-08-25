-- Assistenthistorik (2026-07-21): assistent_logg utökas så varje förfrågan bär
-- sin prompt, vald mall och status — historikpanelen i Bokföringsassistenten visar
-- pågående och historiska körningar per bolag (RLS-select finns sedan v1).
alter table public.assistent_logg
  add column mall_key text,
  add column prompt text,
  add column svar text,
  add column status text not null default 'klar' check (status in ('pagaende','klar','fel'));
