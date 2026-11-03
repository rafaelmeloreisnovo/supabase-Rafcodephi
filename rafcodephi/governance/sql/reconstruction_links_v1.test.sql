
-- SPDX-License-Identifier: Apache-2.0
-- Run only after the private index has at least one real link. Always rolls back.
BEGIN;
SET LOCAL statement_timeout = '30s';
DO $test$
DECLARE
  r raf_private.reconstruction_links_v1%ROWTYPE;
  changed integer;
  passed integer := 0;
BEGIN
  SELECT * INTO STRICT r FROM raf_private.reconstruction_links_v1 ORDER BY link_key LIMIT 1;
  r.link_key := '__reconstruction_test_valid__';
  r.relation_kind := 'DOCUMENTS_CI_RUN';
  r.execution_scope := 'HOSTED_CI';
  r.evidence_state := 'CI_SUCCESS_SCOPED';
  r.run_id := 1;
  r.run_attempt := 1;
  r.run_head_sha := r.github_commit_sha;
  r.run_conclusion := 'success';
  r.observed_step_count := 1;
  r.checkout_binding := 'EXPLICIT_HEAD_REF';
  INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
  INSERT INTO raf_private.reconstruction_links_v1 SELECT r.* ON CONFLICT(link_key) DO NOTHING;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'replay not idempotent'; END IF;
  passed := passed + 1;
  r.link_key := '__reconstruction_test_invalid__';

  BEGIN
    r.device_runtime_verified := true;
    INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
    RAISE EXCEPTION 'physical promotion accepted';
  EXCEPTION WHEN check_violation THEN passed := passed + 1; END;
  r.device_runtime_verified := false;

  BEGIN
    r.claim_allowed := true;
    INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
    RAISE EXCEPTION 'claim promotion accepted';
  EXCEPTION WHEN check_violation THEN passed := passed + 1; END;
  r.claim_allowed := false;

  BEGIN
    r.run_head_sha := repeat('0',40);
    INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
    RAISE EXCEPTION 'mismatched head accepted';
  EXCEPTION WHEN check_violation THEN passed := passed + 1; END;
  r.run_head_sha := r.github_commit_sha;

  BEGIN
    r.observed_step_count := 0;
    INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
    RAISE EXCEPTION 'success without steps accepted';
  EXCEPTION WHEN check_violation THEN passed := passed + 1; END;
  r.observed_step_count := 1;

  BEGIN
    r.run_head_sha := NULL;
    INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
    RAISE EXCEPTION 'null head accepted';
  EXCEPTION WHEN check_violation THEN passed := passed + 1; END;
  r.run_head_sha := r.github_commit_sha;

  BEGIN
    r.index_item_pk := '00000000-0000-0000-0000-000000000000';
    INSERT INTO raf_private.reconstruction_links_v1 SELECT r.*;
    RAISE EXCEPTION 'missing document accepted';
  EXCEPTION WHEN foreign_key_violation THEN passed := passed + 1; END;

  BEGIN
    UPDATE raf_private.reconstruction_links_v1 SET claim_allowed=false WHERE link_key='__reconstruction_test_valid__';
    RAISE EXCEPTION 'update accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed := passed + 1; END;
  BEGIN
    DELETE FROM raf_private.reconstruction_links_v1 WHERE link_key='__reconstruction_test_valid__';
    RAISE EXCEPTION 'delete accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed := passed + 1; END;
  BEGIN
    TRUNCATE raf_private.reconstruction_links_v1;
    RAISE EXCEPTION 'truncate accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed := passed + 1; END;
  BEGIN
    UPDATE raf_private.reconstruction_batches_v1 SET claim_allowed=false WHERE false;
    RAISE EXCEPTION 'batch update accepted';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed := passed + 1; END;

  BEGIN
    PERFORM * FROM raf_private.search_reconstruction_v1(NULL,20);
    RAISE EXCEPTION 'null search accepted';
  EXCEPTION WHEN invalid_parameter_value THEN passed := passed + 1; END;
  BEGIN
    PERFORM * FROM raf_private.search_reconstruction_v1('v',20);
    RAISE EXCEPTION 'short search accepted';
  EXCEPTION WHEN invalid_parameter_value THEN passed := passed + 1; END;
  BEGIN
    PERFORM * FROM raf_private.search_reconstruction_v1('vectra',101);
    RAISE EXCEPTION 'unbounded limit accepted';
  EXCEPTION WHEN invalid_parameter_value THEN passed := passed + 1; END;
  IF EXISTS (SELECT 1 FROM raf_private.search_reconstruction_v1(''';select pg_sleep(10);--',20)) THEN
    RAISE EXCEPTION 'unexpected literal search match';
  END IF;
  passed := passed + 1;

  EXECUTE 'SET LOCAL ROLE anon';
  BEGIN
    PERFORM * FROM raf_private.search_reconstruction_v1('vectra',20);
    RAISE EXCEPTION 'anon query permitted';
  EXCEPTION WHEN insufficient_privilege THEN passed := passed + 1; END;
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM * FROM raf_private.reconstruction_links_v1;
    RAISE EXCEPTION 'authenticated read permitted';
  EXCEPTION WHEN insufficient_privilege THEN passed := passed + 1; END;
  EXECUTE 'RESET ROLE';

  IF passed <> 17 THEN RAISE EXCEPTION 'expected 17 tests, got %',passed; END IF;
END;
$test$;
ROLLBACK;
SELECT 'PASS_SCOPED_17_POSTGRES_TESTS_ROLLED_BACK' AS result;
