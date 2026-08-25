-- Fix till etapp 3: audit_verifikation blockerade sanktionerad företagsradering.
--
-- Bakgrund: audit_log.company_id har FK ON DELETE CASCADE mot companies. Vid radering av
-- ett bolag raderas verifikationerna via cascade, och audit-triggern försöker då skriva en
-- audit-rad för ett bolag som är på väg bort → foreign_key_violation.
--
-- Första försöket kollade "finns bolaget kvar?" och kastade felet om så var fallet. Det
-- fungerade inte: under cascade-raderingen är companies-raden fortfarande synlig i
-- statementets snapshot, så villkoret slog till och blockerade raderingen.
--
-- Rätt semantik: foreign_key_violation mot audit_log kan i praktiken BARA uppstå när
-- bolaget försvinner — den sväljs. Alla andra fel kastas, så audit fortfarande inte kan
-- tystas i drift (BFL 5 kap: bokföring utan spår får inte ske).
create or replace function public.audit_verifikation() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                         case when auth.uid() is not null then 'ui' else 'system' end);
begin
  begin
    if tg_op = 'INSERT' then
      perform public.log_accounting_audit('verification_created', 'verifikation', new.id::text, v_src,
        jsonb_build_object('ver_nr', new.ver_nr, 'ver_serie', new.ver_serie, 'datum', new.datum,
          'total_debet', new.total_debet, 'total_kredit', new.total_kredit), new.company_id, null, null);
    elsif tg_op = 'UPDATE' then
      perform public.log_accounting_audit('verification_updated', 'verifikation', new.id::text, v_src,
        jsonb_build_object('ver_nr', new.ver_nr), new.company_id,
        jsonb_build_object('beskrivning', old.beskrivning, 'total_debet', old.total_debet, 'total_kredit', old.total_kredit, 'is_locked', old.is_locked),
        jsonb_build_object('beskrivning', new.beskrivning, 'total_debet', new.total_debet, 'total_kredit', new.total_kredit, 'is_locked', new.is_locked));
    elsif tg_op = 'DELETE' then
      perform public.log_accounting_audit('verification_deleted_current_legacy_flow', 'verifikation', old.id::text, v_src,
        jsonb_build_object('warning', 'Legacy deletion flow, should be replaced by reversal flow'), old.company_id,
        jsonb_build_object('ver_nr', old.ver_nr, 'ver_serie', old.ver_serie, 'datum', old.datum, 'beskrivning', old.beskrivning,
          'total_debet', old.total_debet, 'total_kredit', old.total_kredit,
          'rader', (select coalesce(jsonb_agg(jsonb_build_object('konto', vr.account_nr, 'debet', vr.debet, 'kredit', vr.kredit) order by vr.sort_order), '[]'::jsonb)
                    from public.verifikation_rows vr where vr.verifikation_id = old.id)), null);
    end if;
  exception
    when foreign_key_violation then
      null;   -- bolaget raderas (cascade) – audit-raden har inget att peka på
    when others then
      raise;  -- allt annat är ett riktigt auditfel och stoppar transaktionen
  end;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
