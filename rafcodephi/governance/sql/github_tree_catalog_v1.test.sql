-- SPDX-License-Identifier: Apache-2.0
-- Run in an isolated database AFTER applying github_tree_catalog_v1.DRAFT.sql.
-- All fixture writes roll back; no real user/provider data is required.
BEGIN;
SET LOCAL lock_timeout = '3s';
SET LOCAL statement_timeout = '30s';
DO $test$
DECLARE
  k text := 'test:rollback:gh-tree:v1';
  changed integer;
  passed integer := 0;
BEGIN
  INSERT INTO raf_private.github_tree_scan_receipts_v1(
    scan_key,provider_repo_id,repository_full_name,source_ref,commit_sha,root_tree_sha,
    requested_limit,observed_entries,inserted_entries,rejected_entries,coverage_state,
    provider_truncated,manifest_sha256
  ) VALUES (
    k,'1','example/metadata-fixture','main',repeat('a',40),repeat('b',40),
    2,1,1,0,'PAGE_PARTIAL',NULL,repeat('c',64)
  );
  INSERT INTO raf_private.github_tree_entries_v1(
    scan_key,provider_repo_id,repository_full_name,commit_sha,
    source_path,object_type,object_mode,object_sha,size_bytes,metadata_fingerprint_sha256
  ) VALUES (
    k,'1','example/metadata-fixture',repeat('a',40),
    'src/main.c','blob','100644',repeat('d',40),NULL,repeat('e',64)
  );
  IF (SELECT count(*) FROM raf_private.github_tree_entries_v1 WHERE scan_key=k) <> 1 THEN
    RAISE EXCEPTION 'valid scoped insert failed';
  END IF;
  passed := passed+1;

  INSERT INTO raf_private.github_tree_scan_receipts_v1(
    scan_key,provider_repo_id,repository_full_name,source_ref,commit_sha,root_tree_sha,
    requested_limit,observed_entries,inserted_entries,rejected_entries,coverage_state,
    provider_truncated,manifest_sha256
  ) VALUES (
    k,'1','example/metadata-fixture','main',repeat('a',40),repeat('b',40),
    2,1,1,0,'PAGE_PARTIAL',NULL,repeat('c',64)
  ) ON CONFLICT (scan_key) DO NOTHING;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'receipt replay inserted data'; END IF;
  passed := passed+1;

  INSERT INTO raf_private.github_tree_entries_v1(
    scan_key,provider_repo_id,repository_full_name,commit_sha,
    source_path,object_type,object_mode,object_sha,size_bytes,metadata_fingerprint_sha256
  ) VALUES (k,'1','example/metadata-fixture',repeat('a',40),
    'src/main.c','blob','100644',repeat('d',40),NULL,repeat('e',64))
  ON CONFLICT (provider_repo_id,commit_sha,source_path) DO NOTHING;
  GET DIAGNOSTICS changed = ROW_COUNT;
  IF changed <> 0 THEN RAISE EXCEPTION 'entry replay inserted data'; END IF;
  passed := passed+1;

  BEGIN
    INSERT INTO raf_private.github_tree_entries_v1(
      scan_key,provider_repo_id,repository_full_name,commit_sha,source_path,
      object_type,object_mode,object_sha,metadata_fingerprint_sha256
    ) VALUES(k,'1','example/metadata-fixture',repeat('a',40),'src/main.c',
      'blob','100644',repeat('f',40),repeat('e',64));
    RAISE EXCEPTION 'conflicting same-commit path accepted';
  EXCEPTION WHEN unique_violation THEN passed:=passed+1; END;

  BEGIN
    INSERT INTO raf_private.github_tree_entries_v1(
      scan_key,provider_repo_id,repository_full_name,commit_sha,source_path,
      object_type,object_mode,object_sha,metadata_fingerprint_sha256
    ) VALUES(k,'1','example/metadata-fixture',repeat('a',40),'../escape',
      'blob','100644',repeat('f',40),repeat('e',64));
    RAISE EXCEPTION 'unsafe path accepted';
  EXCEPTION WHEN check_violation THEN passed:=passed+1; END;

  BEGIN
    INSERT INTO raf_private.github_tree_entries_v1(
      scan_key,provider_repo_id,repository_full_name,commit_sha,source_path,
      object_type,object_mode,object_sha,metadata_fingerprint_sha256
    ) VALUES(k,'2','example/metadata-fixture',repeat('a',40),'src/other.c',
      'blob','100644',repeat('f',40),repeat('e',64));
    RAISE EXCEPTION 'foreign scope accepted';
  EXCEPTION WHEN foreign_key_violation THEN passed:=passed+1; END;

  BEGIN
    INSERT INTO raf_private.github_tree_entries_v1(
      scan_key,provider_repo_id,repository_full_name,commit_sha,source_path,
      object_type,object_mode,object_sha,metadata_fingerprint_sha256,claim_allowed
    ) VALUES(k,'1','example/metadata-fixture',repeat('a',40),'src/claim.c',
      'blob','100644',repeat('f',40),repeat('e',64),true);
    RAISE EXCEPTION 'claim promotion accepted';
  EXCEPTION WHEN check_violation THEN passed:=passed+1; END;

  BEGIN
    INSERT INTO raf_private.github_tree_entries_v1(
      scan_key,provider_repo_id,repository_full_name,commit_sha,source_path,
      object_type,object_mode,object_sha,metadata_fingerprint_sha256
    ) VALUES(k,'1','example/metadata-fixture',repeat('a',40),'src/bad_mode',
      'tree','100644',repeat('f',40),repeat('e',64));
    RAISE EXCEPTION 'invalid object-mode/type accepted';
  EXCEPTION WHEN check_violation THEN passed:=passed+1; END;

  BEGIN
    UPDATE raf_private.github_tree_entries_v1 SET object_sha=repeat('f',40) WHERE false;
    RAISE EXCEPTION 'zero-row UPDATE allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed:=passed+1; END;
  BEGIN
    DELETE FROM raf_private.github_tree_entries_v1 WHERE false;
    RAISE EXCEPTION 'DELETE allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed:=passed+1; END;
  BEGIN
    TRUNCATE raf_private.github_tree_entries_v1;
    RAISE EXCEPTION 'TRUNCATE allowed';
  EXCEPTION WHEN SQLSTATE '55000' THEN passed:=passed+1; END;

  IF has_table_privilege('anon','raf_private.github_tree_entries_v1','SELECT')
     OR has_table_privilege('authenticated','raf_private.github_tree_entries_v1','SELECT')
     OR has_table_privilege('anon','raf_private.github_tree_scan_receipts_v1','INSERT')
     OR has_table_privilege('authenticated','raf_private.github_tree_scan_receipts_v1','INSERT')
     OR NOT (SELECT relforcerowsecurity
       FROM pg_class WHERE oid='raf_private.github_tree_entries_v1'::regclass)
     OR NOT (SELECT relforcerowsecurity
       FROM pg_class WHERE oid='raf_private.github_tree_scan_receipts_v1'::regclass)
  THEN RAISE EXCEPTION 'private ACL/RLS gate failed'; END IF;
  passed := passed+1;

  IF passed <> 12 THEN RAISE EXCEPTION 'expected 12 tests, got %',passed; END IF;
END;
$test$;
ROLLBACK;
SELECT 'SCOPED_12_TESTS_ROLLED_BACK' AS result;
