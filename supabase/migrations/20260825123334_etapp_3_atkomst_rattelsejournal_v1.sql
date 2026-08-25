-- Etapp 3 av BFL-härdningen: åtkomsträttigheter, rättelsejournal och auditintegritet.
-- Bygger på etapp 1 (loggning) och etapp 2 (trigger-spärrar mot ändring av bokföringsdata).
--
-- Problemet: anon och authenticated hade FULL DML (inkl. TRUNCATE) på verifikationer,
-- verifikation_rows, audit_log och verifikation_andringar. Etapp 2:s triggrar stoppade
-- ändringar, men rättigheterna var ett onödigt djupförsvarshål — och audit_log kunde
-- skrivas/raderas direkt av klienten.
--
-- Hindret: bokfor_verifikation och radera_senaste_verifikation var SECURITY INVOKER och
-- körde alltså sin DML som den inloggade användaren — att bara dra in rättigheterna hade
-- brutit all bokföring. Därför konverteras båda till SECURITY DEFINER med EXPLICIT
-- åtkomstkontroll (_assert_company_access) som ersätter det RLS-skydd de förlitade sig på.

-- ── 1) bokfor_verifikation: DEFINER + explicit åtkomstkontroll ────────────
create or replace function public.bokfor_verifikation(
  p_company_id uuid, p_serie text, p_datum date, p_beskrivning text, p_rader jsonb,
  p_motpart text default null, p_created_by uuid default null, p_source text default null,
  p_kommentar text default null, p_ersatter uuid default null
) returns public.verifikationer
language plpgsql security definer set search_path = public as $$
declare
  v_nr text;
  v_ver public.verifikationer;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  rad jsonb;
  i int := 0;
begin
  -- Ersätter RLS-skyddet som gällde när funktionen var SECURITY INVOKER.
  perform public._assert_company_access(p_company_id);

  if p_source is not null and p_source in ('ai', 'mcp') then
    perform set_config('app.audit_source', p_source, true);
  end if;
  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'Verifikationen saknar rader';
  end if;
  select coalesce(sum(coalesce((x->>'debet')::numeric, 0)), 0),
         coalesce(sum(coalesce((x->>'kredit')::numeric, 0)), 0)
    into v_debet, v_kredit
    from jsonb_array_elements(p_rader) x;
  if round(v_debet, 2) <> round(v_kredit, 2) then
    raise exception 'Verifikationen balanserar inte (debet %, kredit %)', v_debet, v_kredit;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_company_id::text || '|' || p_serie, 0));
  v_nr := public.next_ver_nr(p_company_id, p_serie);

  insert into public.verifikationer
    (company_id, ver_nr, ver_serie, datum, beskrivning, motpart, kommentar, ersatter,
     total_debet, total_kredit, created_by)
  values
    (p_company_id, v_nr, p_serie, p_datum, left(p_beskrivning, 500),
     nullif(trim(coalesce(p_motpart, '')), ''), nullif(trim(coalesce(p_kommentar, '')), ''),
     p_ersatter, round(v_debet, 2), round(v_kredit, 2),
     coalesce(p_created_by, auth.uid()))
  returning * into v_ver;

  perform set_config('app.ver_insert', 'on', true);
  for rad in select * from jsonb_array_elements(p_rader) loop
    insert into public.verifikation_rows
      (verifikation_id, account_nr, account_name, debet, kredit, transaction_info, sort_order)
    values
      (v_ver.id, rad->>'account_nr', rad->>'account_name',
       coalesce((rad->>'debet')::numeric, 0), coalesce((rad->>'kredit')::numeric, 0),
       nullif(rad->>'transaction_info', ''), coalesce((rad->>'sort_order')::int, i));
    i := i + 1;
  end loop;
  perform set_config('app.ver_insert', 'off', true);

  return v_ver;
end $$;

-- ── 2) radera_senaste_verifikation: DEFINER + explicit åtkomstkontroll ────
-- (Behålls enligt beslut 2026-08-24 — paritet med Visma/Fortnox.)
create or replace function public.radera_senaste_verifikation(p_ver_id uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v public.verifikationer;
  v_max_nr int;
  v_nr int;
begin
  select * into v from public.verifikationer where id = p_ver_id;
  if not found then
    raise exception 'Verifikationen finns inte';
  end if;
  -- Ersätter RLS-filtreringen som gällde när funktionen var SECURITY INVOKER.
  perform public._assert_company_access(v.company_id);

  if coalesce(v.status, 'aktiv') <> 'aktiv' then
    raise exception 'Endast aktiva verifikationer kan tas bort – makulerade/rättade poster bevaras';
  end if;
  select max(nullif(regexp_replace(ver_nr, '\D', '', 'g'), '')::int) into v_max_nr
    from public.verifikationer
   where company_id = v.company_id and ver_serie = v.ver_serie;
  v_nr := nullif(regexp_replace(v.ver_nr, '\D', '', 'g'), '')::int;
  if v_nr is distinct from v_max_nr then
    raise exception 'Endast den senaste verifikationen i serien kan tas bort (nummerserien måste vara obruten) – använd Makulera';
  end if;

  perform set_config('app.radera_senaste', 'on', true);

  update public.supplier_invoices
     set bokford = false, verifikation_id = null
   where company_id = v.company_id and verifikation_id = p_ver_id;

  update public.supplier_invoices
     set status = 'unpaid', paid_date = null, betalning_ver_id = null,
         paid_amount = greatest(0, round(coalesce(paid_amount, 0) - coalesce(v.total_debet, 0), 2))
   where company_id = v.company_id and betalning_ver_id = p_ver_id;

  update public.bank_transactions
     set status = 'unmatched', verifikation_id = null
   where company_id = v.company_id and verifikation_id = p_ver_id;

  delete from public.verifikationer where id = p_ver_id;
  perform set_config('app.radera_senaste', '', true);
  return jsonb_build_object('ok', true, 'ver_nr', v.ver_nr);
end $$;

-- ── 3) audit_verifikation: audit kan inte längre tystas ───────────────────
-- Tidigare svaldes ALLA fel tyst ("exception when others then null"), vilket innebar att
-- en verifikation kunde bokföras utan spår. Nu kastas felet vidare — UTOM när bolaget
-- håller på att raderas (audit_log.company_id har FK ON DELETE CASCADE, så auditskrivning
-- under cascade-radering är både omöjlig och meningslös).
create or replace function public.audit_verifikation() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_src text := coalesce(nullif(current_setting('app.audit_source', true), ''),
                         case when auth.uid() is not null then 'ui' else 'system' end);
  v_company uuid := case when tg_op = 'DELETE' then old.company_id else new.company_id end;
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
  exception when others then
    -- Finns bolaget kvar är detta ett riktigt auditfel → stoppa transaktionen (BFL 5 kap).
    if exists (select 1 from public.companies where id = v_company) then
      raise;
    end if;
    -- Annars: cascade-radering av bolaget pågår, audit är meningslös.
  end;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

-- ── 4) Rättelsejournal: verifikation_andringar fylls automatiskt ──────────
-- Tabellen fanns men skrevs aldrig (0 rader trots genomförda rättelser). En AFTER-trigger
-- på statusövergången ger journalen utan att röra de stora RPC:erna.
create or replace function public.journalfor_verifikationsandring() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_motpart_id uuid := coalesce(new.rattad_av, new.makulerad_av);
begin
  if new.status in ('rattad', 'makulerad')
     and old.status is distinct from new.status
     and v_motpart_id is not null then
    insert into public.verifikation_andringar
      (company_id, original_id, rattelse_id, orsak, utford_av_epost)
    values (
      new.company_id, new.id, v_motpart_id,
      (select left(v.beskrivning, 500) from public.verifikationer v where v.id = v_motpart_id),
      coalesce(auth.jwt() ->> 'email', 'system')
    );
  end if;
  return new;
end $$;

drop trigger if exists trg_journalfor_andring on public.verifikationer;
create trigger trg_journalfor_andring
  after update of status on public.verifikationer
  for each row execute function public.journalfor_verifikationsandring();

-- ── 5) Rättelsejournalen är append-only ───────────────────────────────────
create or replace function public.verifikation_andringar_appendonly() returns trigger
language plpgsql as $$
begin
  if current_setting('app.periodlas_bypass', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'RÄTTELSEJOURNAL: posterna är oföränderliga (BFL 5 kap 5 §) och kan varken ändras eller raderas.';
end $$;

drop trigger if exists trg_andringar_appendonly on public.verifikation_andringar;
create trigger trg_andringar_appendonly
  before update or delete on public.verifikation_andringar
  for each row execute function public.verifikation_andringar_appendonly();

-- ── 6) Åtkomsträttigheter: klienten får läsa, aldrig skriva ───────────────
-- Skrivning sker uteslutande via SECURITY DEFINER-RPC:er med egna kontroller.
revoke all on public.verifikationer            from anon;
revoke all on public.verifikation_rows         from anon;
revoke all on public.verifikation_andringar    from anon;
revoke all on public.audit_log                 from anon;
revoke all on public.ai_bokforing_logg         from anon;

revoke insert, update, delete, truncate, references, trigger on public.verifikationer         from authenticated;
revoke insert, update, delete, truncate, references, trigger on public.verifikation_rows      from authenticated;
revoke insert, update, delete, truncate, references, trigger on public.verifikation_andringar from authenticated;
revoke insert, update, delete, truncate, references, trigger on public.audit_log              from authenticated;
revoke        update, delete, truncate                       on public.ai_bokforing_logg      from authenticated;

grant select on public.verifikationer         to authenticated;
grant select on public.verifikation_rows      to authenticated;
grant select on public.verifikation_andringar to authenticated;
grant select on public.audit_log              to authenticated;

-- Avstämningsmarkeringen är arbetsdata, inte bokföringsdata (samma särfall som i etapp 2).
grant update (avstamd) on public.verifikation_rows to authenticated;
