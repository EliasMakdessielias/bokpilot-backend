-- Etapp 2 av BFL-härdningen: spärra ändring av bokföringsdata (BFL 5 kap 5 §).
-- Bygger på etapp 1:s observationsläge (trg_observe_ver_mutation, trg_audit_ver_rows).
-- Ingen bokföringsaktivitet har skett sedan 2026-07-25, så spärren aktiveras i stiltje.
--
-- Tre hål sluts:
--   1. UPDATE av verifikationer: alla fält utom status och is_locked spärras
--      (fail-closed via jsonb-jämförelse — även framtida kolumner skyddas tills
--      de uttryckligen undantas). Rättelse-/makulerings-/resetflödena släpps
--      förbi via sina befintliga transaktionslokala GUC:ar.
--   2. UPDATE av verifikation_rows: bokföringsdata på rader spärras oavsett
--      moderns status (tidigare skyddades bara makulerad-familjen och låsta
--      perioder). Avstämningsmarkeringen (avstamd) är fortsatt fri — samma
--      särfall som audit-/periodlåstriggrarna.
--   3. INSERT i komplett verifikation: när radsummorna nått huvudets totaler
--      tas inga nya rader emot. De sanktionerade radskrivarna släpps förbi:
--      ratta/makulera kör redan under app.makulera_insert; bokfor_verifikation
--      och sie_importera_verifikation får den nya flaggan app.ver_insert.
--
-- radera_senaste_verifikation påverkas inte (beslut 2026-08-24: behålls,
-- paritet med Visma/Fortnox): den uppdaterar aldrig bokföringsdata och raderar
-- via app.radera_senaste + kaskad.

-- ── 1) Huvudet: endast status och is_locked får ändras osanktionerat ──────
create or replace function public.enforce_immutabel_verifikation() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_old jsonb; v_new jsonb; v_falt text[];
begin
  if coalesce(current_setting('app.rattelse_link',     true), '') = 'on'
     or coalesce(current_setting('app.makulera_insert', true), '') = 'on'
     or coalesce(current_setting('app.periodlas_bypass',true), '') = 'on' then
    return new;
  end if;
  v_old := to_jsonb(old) - 'status' - 'is_locked';
  v_new := to_jsonb(new) - 'status' - 'is_locked';
  if v_old is distinct from v_new then
    select array_agg(t.k order by t.k) into v_falt
    from jsonb_object_keys(v_old || v_new) as t(k)
    where v_old -> t.k is distinct from v_new -> t.k;
    raise exception 'BOKFÖRINGSDATA_LÅST: Verifikation % är bokförd – fälten [%] kan inte ändras (BFL 5 kap 5 §). Använd Rätta eller Makulera.',
      old.ver_nr, array_to_string(v_falt, ', ');
  end if;
  return new;
end $$;

drop trigger if exists trg_immutabel_verifikation on public.verifikationer;
create trigger trg_immutabel_verifikation
  before update on public.verifikationer
  for each row execute function public.enforce_immutabel_verifikation();

-- ── 2 + 3) Raderna: spärrad ändring + komplett-regeln för nya rader ───────
-- (Radering är redan helt spärrad av trg_forbjud_ver_rows_delete.)
create or replace function public.enforce_immutabel_ver_rows() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_nr text; v_tot_debet numeric; v_tot_kredit numeric;
  v_sum_debet numeric; v_sum_kredit numeric;
begin
  if coalesce(current_setting('app.periodlas_bypass', true), '') = 'on'
     or coalesce(current_setting('app.makulera_insert', true), '') = 'on'
     or coalesce(current_setting('app.ver_insert',      true), '') = 'on' then
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- Enbart avstämningsmarkering: arbetsmarkering, inte bokföringsdata.
    if new.verifikation_id is not distinct from old.verifikation_id
       and new.account_nr = old.account_nr
       and new.account_name is not distinct from old.account_name
       and coalesce(new.debet, 0) = coalesce(old.debet, 0)
       and coalesce(new.kredit, 0) = coalesce(old.kredit, 0)
       and new.transaction_info is not distinct from old.transaction_info
       and new.sort_order is not distinct from old.sort_order then
      return new;
    end if;
    select v.ver_nr into v_nr from public.verifikationer v
      where v.id = coalesce(old.verifikation_id, new.verifikation_id);
    if found then
      raise exception 'BOKFÖRINGSDATA_LÅST: Raderna i verifikation % är bokförda och kan inte ändras (BFL 5 kap 5 §). Använd Rätta eller Makulera.', v_nr;
    end if;
    return new;   -- modern borta (kaskad) – inget att skydda
  end if;

  -- INSERT: en verifikation är komplett när radsummorna nått huvudets totaler.
  select v.ver_nr, v.total_debet, v.total_kredit into v_nr, v_tot_debet, v_tot_kredit
    from public.verifikationer v where v.id = new.verifikation_id;
  if not found then return new; end if;
  select coalesce(sum(coalesce(r.debet, 0)), 0), coalesce(sum(coalesce(r.kredit, 0)), 0)
    into v_sum_debet, v_sum_kredit
    from public.verifikation_rows r where r.verifikation_id = new.verifikation_id;
  if coalesce(v_tot_debet, 0) + coalesce(v_tot_kredit, 0) > 0
     and round(v_sum_debet, 2) >= round(coalesce(v_tot_debet, 0), 2)
     and round(v_sum_kredit, 2) >= round(coalesce(v_tot_kredit, 0), 2) then
    raise exception 'VERIFIKATION_KOMPLETT: Verifikation % är komplett – nya rader kan inte läggas till (BFL 5 kap 5 §). Använd Rätta.', v_nr;
  end if;
  return new;
end $$;

drop trigger if exists trg_immutabel_ver_rows on public.verifikation_rows;
create trigger trg_immutabel_ver_rows
  before insert or update on public.verifikation_rows
  for each row execute function public.enforce_immutabel_ver_rows();

-- ── 4a) bokfor_verifikation: sanktionera den atomiska radinsättningen ─────
-- Identisk med nuvarande definition sånär som på app.ver_insert runt radloopen.
create or replace function public.bokfor_verifikation(
  p_company_id uuid, p_serie text, p_datum date, p_beskrivning text, p_rader jsonb,
  p_motpart text default null, p_created_by uuid default null, p_source text default null,
  p_kommentar text default null, p_ersatter uuid default null
) returns public.verifikationer
language plpgsql as $$
declare
  v_nr text;
  v_ver public.verifikationer;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  rad jsonb;
  i int := 0;
begin
  if p_source is not null and p_source in ('ai', 'mcp') then
    perform set_config('app.audit_source', p_source, true);   -- läses av audit-triggrarna
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

  perform set_config('app.ver_insert', 'on', true);   -- sanktionerad atomisk radinsättning (etapp 2)
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

-- ── 4b) sie_importera_verifikation: samma sanktionsflagga ─────────────────
create or replace function public.sie_importera_verifikation(
  p_company uuid, p_ver_nr text, p_ver_serie text, p_datum date,
  p_beskrivning text, p_rader jsonb, p_sie_import_id uuid
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_debet numeric := 0;
  v_kredit numeric := 0;
  v_diff numeric;
begin
  perform public._assert_company_access(p_company);

  if p_rader is null or jsonb_array_length(p_rader) = 0 then
    raise exception 'SIE_TOM: Verifikation % saknar konteringsrader.', p_ver_nr;
  end if;

  select coalesce(sum(round((r->>'debet')::numeric, 2)), 0),
         coalesce(sum(round((r->>'kredit')::numeric, 2)), 0)
    into v_debet, v_kredit
  from jsonb_array_elements(p_rader) r;

  v_diff := round(v_debet - v_kredit, 2);
  if v_diff <> 0 then
    raise exception 'SIE_OBALANS: Verifikation % balanserar inte (debet %, kredit %, differens %).',
      p_ver_nr, v_debet, v_kredit, v_diff;
  end if;

  if exists (select 1 from verifikationer where company_id = p_company and ver_nr = p_ver_nr) then
    raise exception 'SIE_DUBBLETT: Verifikationsnumret % finns redan i bolaget.', p_ver_nr;
  end if;

  insert into verifikationer (company_id, ver_nr, ver_serie, datum, beskrivning,
                              total_debet, total_kredit, created_by, sie_import_id)
  values (p_company, p_ver_nr, p_ver_serie, p_datum, coalesce(p_beskrivning, 'SIE-import'),
          v_debet, v_kredit, auth.uid(), p_sie_import_id)
  returning id into v_id;

  perform set_config('app.ver_insert', 'on', true);   -- sanktionerad atomisk radinsättning (etapp 2)
  insert into verifikation_rows (verifikation_id, account_nr, account_name, debet, kredit, sort_order)
  select v_id,
         r->>'account_nr',
         coalesce(r->>'account_name', ''),
         round((r->>'debet')::numeric, 2),
         round((r->>'kredit')::numeric, 2),
         (r->>'sort_order')::int
  from jsonb_array_elements(p_rader) r;
  perform set_config('app.ver_insert', 'off', true);

  return v_id;
end;
$$;
