-- SPDX-License-Identifier: Apache-2.0
-- Run AFTER applying governance schema, in an isolated DB.
-- Synthetic fixture rolls back; this is not an API / cross-provider test.
BEGIN;
DO $test$
DECLARE
  v_req uuid := gen_random_uuid();
  v_count integer;
  v_rejected boolean := false;
BEGIN
  INSERT INTO raf_private.schema_change_requests
    (request_id, provider, source_ref, source_revision, actor_ref, purpose,
     columns_proposal)
  VALUES
    (v_req, 'other', 'fixture:test-only', 'v1', 'test-actor',
     'synthetic validation', '[{"name":"id","type":"uuid"}]'::jsonb);

  SELECT count(*) INTO v_count FROM raf_private.schema_change_events
    WHERE request_id = v_req AND kind = 'REQUESTED';
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Expected 1 enqueued event, got %', v_count;
  END IF;

  BEGIN
    UPDATE raf_private.schema_change_requests
      SET purpose = 'forbidden' WHERE request_id = v_req;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'Append-only UPDATE was not rejected'; END IF;

  IF has_schema_privilege('anon','raf_private','USAGE') OR
     has_schema_privilege('authenticated','raf_private','USAGE') OR
     has_table_privilege('anon','raf_private.schema_change_requests','SELECT') OR
     has_table_privilege('authenticated','raf_private.schema_change_events','INSERT') THEN
    RAISE EXCEPTION 'Unexpected client grant';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='raf_private' AND c.relname='schema_change_requests' AND c.relrowsecurity
  ) THEN RAISE EXCEPTION 'RLS not enabled'; END IF;
  RAISE NOTICE 'Scoped structural/append-only/grant tests passed (transaction will roll back)';
END;
$test$;
ROLLBACK;
-- Additional gates NOT_RUN: real anonymous REST, authenticated IDOR, backup restore,
-- independent approval, exact-HEAD CI, actual migration runner, external receipts.
