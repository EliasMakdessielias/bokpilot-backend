-- robo_bp_messages måste tillhöra samma bolag som sin konversation.
-- Kontrollen finns även i edge-funktionen robo-bp-chat, men den skriver med
-- service role och kringgår därmed RLS. En sammansatt främmande nyckel gäller
-- däremot ALLTID, även för service role — därför ligger garantin här.
alter table public.robo_bp_conversations
  drop constraint if exists robo_bp_conversations_id_company_key;
alter table public.robo_bp_conversations
  add constraint robo_bp_conversations_id_company_key unique (id, company_id);

alter table public.robo_bp_messages
  drop constraint if exists robo_bp_messages_konv_bolag_fkey;
alter table public.robo_bp_messages
  add constraint robo_bp_messages_konv_bolag_fkey
  foreign key (conversation_id, company_id)
  references public.robo_bp_conversations (id, company_id)
  on delete cascade;
