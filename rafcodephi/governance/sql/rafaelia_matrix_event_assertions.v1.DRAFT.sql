-- RAFAELIA Ω — READ-ONLY STRUCTURAL ASSERTIONS, DRAFT.
-- Run only in an authorized isolated PostgreSQL 15 sandbox AFTER the
-- candidate schema V1 and event triggers V1 are explicitly applied there.
-- This tests catalog structure, NOT authorization behavior or tamper evidence.
do $assert$
declare
  t text;
  n integer;
begin
  if pg_catalog.to_regclass('raf_private.matrix_source_tenants') is null
     or pg_catalog.to_regclass('raf_private.matrix_events') is null
     or pg_catalog.to_regclass('raf_private.matrix_event_outbox') is null
     or pg_catalog.to_regclass('raf_private.source_registry') is null then
    raise exception 'missing approved predecessor or event structures';
  end if;

  foreach t in array array['matrix_source_tenants','matrix_events','matrix_event_outbox'] loop
    if not exists (
      select 1 from pg_catalog.pg_class c
      join pg_catalog.pg_namespace ns on ns.oid = c.relnamespace
      where ns.nspname = 'raf_private' and c.relname = t
        and c.relrowsecurity
    ) then
      raise exception 'RLS disabled for %', t;
    end if;
    if pg_catalog.has_table_privilege('anon', 'raf_private.' || t, 'SELECT')
      or pg_catalog.has_table_privilege('anon', 'raf_private.' || t, 'INSERT')
      or pg_catalog.has_table_privilege('authenticated', 'raf_private.' || t, 'SELECT')
      or pg_catalog.has_table_privilege('authenticated', 'raf_private.' || t, 'INSERT') then
      raise exception 'unexpected client table grant for %', t;
    end if;
  end loop;

  select count(*) into n
    from pg_catalog.pg_trigger tr
    where tr.tgrelid = 'raf_private.matrix_events'::pg_catalog.regclass
      and not tr.tgisinternal
      and tr.tgenabled in ('O','A')
      and tr.tgname in
        ('matrix_validate_event','matrix_outbox_event',
         'matrix_no_update_delete','matrix_no_truncate');
  if n <> 4 then
    raise exception 'expected four enabled event triggers; found %', n;
  end if;

  if exists (
    select 1 from pg_catalog.pg_policies p
    where p.schemaname = 'raf_private'
      and p.tablename in ('matrix_events','matrix_event_outbox')
      and ('anon' = any(p.roles) or 'authenticated' = any(p.roles)
           or 'public' = any(p.roles))
  ) then
    raise exception 'untrusted policy found in private event tables';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_roles where rolname = 'raf_matrix_ingestor'
      and not rolcanlogin
  ) then
    raise exception 'ingestor must be NOLOGIN';
  end if;
  raise notice 'STRUCTURE_PASS only; runtime negative tests still mandatory';
end;
$assert$;
