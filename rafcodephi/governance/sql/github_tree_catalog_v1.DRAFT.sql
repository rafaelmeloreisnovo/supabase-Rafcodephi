-- SPDX-License-Identifier: Apache-2.0
-- RAFAELIA Ω | REVIEW ONLY | private GitHub tree metadata and checkpoint ledger.
-- SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM.
-- Must NOT be deployed/merged without provider review, scoped rights and tests.
-- Uses an existing raf_private schema. No content bytes, tokens or public grants.
CREATE TABLE raf_private.github_tree_scan_receipts_v1 (
  scan_key text PRIMARY KEY CHECK (length(scan_key) BETWEEN 12 AND 180),
  provider_repo_id text NOT NULL CHECK (provider_repo_id ~ '^[0-9]{1,20}$'),
  repository_full_name text NOT NULL CHECK (repository_full_name ~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'),
  source_ref text NOT NULL CHECK (length(source_ref) BETWEEN 1 AND 255),
  commit_sha text NOT NULL CHECK (commit_sha ~ '^[0-9a-f]{40}$'),
  root_tree_sha text NOT NULL CHECK (root_tree_sha ~ '^[0-9a-f]{40}$'),
  source_prefix text NOT NULL DEFAULT '' CHECK (
    length(source_prefix) <= 1800 AND
    source_prefix !~ '(^/|(^|/)\.\.(/|$)|[[:cntrl:]])'
  ),
  cursor_before text CHECK (cursor_before IS NULL OR length(cursor_before) <= 1024),
  cursor_after text CHECK (cursor_after IS NULL OR length(cursor_after) <= 1024),
  requested_limit integer NOT NULL CHECK (requested_limit BETWEEN 1 AND 1000),
  observed_entries integer NOT NULL CHECK (observed_entries BETWEEN 0 AND requested_limit),
  inserted_entries integer NOT NULL CHECK (inserted_entries BETWEEN 0 AND observed_entries),
  rejected_entries integer NOT NULL CHECK (rejected_entries BETWEEN 0 AND observed_entries),
  coverage_state text NOT NULL CHECK (coverage_state IN (
    'PAGE_PARTIAL','PAGE_LIMIT_REACHED','PROVIDER_TRUNCATED','PREFIX_EXHAUSTED_SCOPED'
  )),
  provider_truncated boolean,
  manifest_sha256 text NOT NULL CHECK (manifest_sha256 ~ '^[0-9a-f]{64}$'),
  metadata_evidence text NOT NULL DEFAULT 'GITHUB_TREE_PROVIDER_METADATA'
    CHECK (metadata_evidence = 'GITHUB_TREE_PROVIDER_METADATA'),
  source_content_access text NOT NULL DEFAULT 'NO_CONTENT'
    CHECK (source_content_access = 'NO_CONTENT'),
  claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false),
  observed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CONSTRAINT github_tree_receipt_scope_unique_v1
    UNIQUE (scan_key,provider_repo_id,repository_full_name,commit_sha),
  CONSTRAINT github_tree_receipt_counts_v1 CHECK (inserted_entries + rejected_entries <= observed_entries),
  CONSTRAINT github_tree_truncation_v1
    CHECK (coverage_state <> 'PROVIDER_TRUNCATED' OR provider_truncated IS TRUE)
);

CREATE TABLE raf_private.github_tree_entries_v1 (
  entry_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scan_key text NOT NULL,
  provider_repo_id text NOT NULL CHECK (provider_repo_id ~ '^[0-9]{1,20}$'),
  repository_full_name text NOT NULL CHECK (repository_full_name ~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'),
  commit_sha text NOT NULL CHECK (commit_sha ~ '^[0-9a-f]{40}$'),
  source_path text NOT NULL CHECK (
    length(source_path) BETWEEN 1 AND 1800 AND
    source_path !~ '(^/|(^|/)\.\.(/|$)|[[:cntrl:]])'
  ),
  object_type text NOT NULL CHECK (object_type IN ('blob','tree','commit')),
  object_mode text NOT NULL CHECK (object_mode IN ('100644','100755','120000','040000','160000')),
  object_sha text NOT NULL CHECK (object_sha ~ '^[0-9a-f]{40}$'),
  size_bytes bigint CHECK (size_bytes IS NULL OR size_bytes >= 0),
  metadata_fingerprint_sha256 text NOT NULL CHECK (metadata_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
  metadata_evidence text NOT NULL DEFAULT 'GITHUB_TREE_PROVIDER_METADATA'
    CHECK (metadata_evidence = 'GITHUB_TREE_PROVIDER_METADATA'),
  content_evidence text NOT NULL DEFAULT 'NOT_READ'
    CHECK (content_evidence = 'NOT_READ'),
  claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false),
  indexed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CONSTRAINT github_tree_entry_mode_type_v1 CHECK (
    (object_type = 'blob' AND object_mode IN ('100644','100755','120000')) OR
    (object_type = 'tree' AND object_mode = '040000') OR
    (object_type = 'commit' AND object_mode = '160000')
  ),
  CONSTRAINT github_tree_entry_scan_scope_fk_v1 FOREIGN KEY
    (scan_key,provider_repo_id,repository_full_name,commit_sha)
    REFERENCES raf_private.github_tree_scan_receipts_v1
      (scan_key,provider_repo_id,repository_full_name,commit_sha) ON DELETE RESTRICT,
  CONSTRAINT github_tree_entry_exact_path_unique_v1
    UNIQUE (provider_repo_id,commit_sha,source_path)
);

CREATE INDEX github_tree_receipts_repo_commit_idx_v1
  ON raf_private.github_tree_scan_receipts_v1 (provider_repo_id,commit_sha,observed_at DESC);
CREATE INDEX github_tree_entries_scan_idx_v1
  ON raf_private.github_tree_entries_v1 (scan_key);
CREATE INDEX github_tree_entries_repo_commit_idx_v1
  ON raf_private.github_tree_entries_v1 (repository_full_name,commit_sha);

CREATE FUNCTION raf_private.reject_github_tree_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $fn$
BEGIN
  RAISE EXCEPTION 'append-only Git tree index: use a new scan receipt or successor'
    USING ERRCODE = '55000';
END;
$fn$;
CREATE TRIGGER github_tree_scan_receipts_append_only_v1
  BEFORE UPDATE OR DELETE OR TRUNCATE ON raf_private.github_tree_scan_receipts_v1
  FOR EACH STATEMENT EXECUTE FUNCTION raf_private.reject_github_tree_mutation_v1();
CREATE TRIGGER github_tree_entries_append_only_v1
  BEFORE UPDATE OR DELETE OR TRUNCATE ON raf_private.github_tree_entries_v1
  FOR EACH STATEMENT EXECUTE FUNCTION raf_private.reject_github_tree_mutation_v1();

ALTER TABLE raf_private.github_tree_scan_receipts_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.github_tree_scan_receipts_v1 FORCE ROW LEVEL SECURITY;
ALTER TABLE raf_private.github_tree_entries_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.github_tree_entries_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON raf_private.github_tree_scan_receipts_v1, raf_private.github_tree_entries_v1
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION raf_private.reject_github_tree_mutation_v1()
  FROM PUBLIC, anon, authenticated;

COMMENT ON TABLE raf_private.github_tree_entries_v1 IS
  'Private metadata-only Git object path index, pinned to commit and provider scan. Not a corpus replica or runtime proof.';
COMMENT ON TABLE raf_private.github_tree_scan_receipts_v1 IS
  'Append-only source-page receipts. PREFIX_EXHAUSTED_SCOPED is not a whole-repository or global-completeness claim.';
