
-- SPDX-License-Identifier: Apache-2.0
-- Additive private reconstruction index. No corpus contents or client grants.
CREATE TABLE raf_private.reconstruction_batches_v1 (
  batch_key text PRIMARY KEY CHECK (length(batch_key) BETWEEN 8 AND 160),
  observed_at timestamptz NOT NULL DEFAULT now(),
  source_queries jsonb NOT NULL CHECK (jsonb_typeof(source_queries) = 'array'),
  coverage_state text NOT NULL CHECK (coverage_state IN ('SEARCH_LIMIT_REACHED_PARTIAL','SEARCH_SCOPED_PARTIAL')),
  observed_metadata integer NOT NULL CHECK (observed_metadata >= 0),
  inserted_metadata integer NOT NULL CHECK (inserted_metadata BETWEEN 0 AND observed_metadata),
  metadata_manifest_sha256 text NOT NULL CHECK (metadata_manifest_sha256 ~ '^[0-9a-f]{64}$'),
  baseline jsonb NOT NULL,
  claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false)
);
CREATE TABLE raf_private.reconstruction_links_v1 (
  link_key text PRIMARY KEY CHECK (length(link_key) BETWEEN 8 AND 160),
  batch_key text NOT NULL REFERENCES raf_private.reconstruction_batches_v1(batch_key) ON DELETE RESTRICT,
  index_item_pk uuid NOT NULL REFERENCES raf_private.drive_metadata_index_v1(item_pk) ON DELETE RESTRICT,
  project_key text NOT NULL CHECK (length(project_key) BETWEEN 2 AND 120),
  relation_kind text NOT NULL CHECK (relation_kind IN ('DOCUMENTS_CI_RUN','DOCUMENTS_SOURCE','REPORTS_DEVICE_FAILURE')),
  document_text_sha256 text NOT NULL CHECK (document_text_sha256 ~ '^[0-9a-f]{64}$'),
  github_repository text NOT NULL CHECK (github_repository ~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'),
  github_commit_sha text NOT NULL CHECK (github_commit_sha ~ '^[0-9a-f]{40}$'),
  github_path text NOT NULL CHECK (length(github_path) BETWEEN 1 AND 500 AND github_path !~ '(^/|(^|/)\.\.(/|$))'),
  github_blob_sha text NOT NULL CHECK (github_blob_sha ~ '^[0-9a-f]{40}$'),
  evidence_state text NOT NULL CHECK (evidence_state IN ('CI_SUCCESS_SCOPED','CI_NO_STEPS','SOURCE_VERIFIED','DEVICE_FAILURE_REPORTED')),
  execution_scope text NOT NULL CHECK (execution_scope IN ('HOSTED_CI','SOURCE_ONLY','DOCUMENTED_DEVICE_REPORT')),
  run_id bigint,
  run_attempt integer,
  run_head_sha text,
  run_conclusion text,
  observed_step_count integer,
  checkout_binding text NOT NULL CHECK (checkout_binding IN ('EXPLICIT_HEAD_REF','DEFAULT_PR_CHECKOUT_NOT_PROVEN','NOT_APPLICABLE')),
  source_statement text NOT NULL CHECK (length(source_statement) BETWEEN 1 AND 2000),
  evidence_refs jsonb NOT NULL CHECK (jsonb_typeof(evidence_refs) = 'array' AND jsonb_array_length(evidence_refs) > 0 AND octet_length(evidence_refs::text) <= 12000),
  remaining_gaps text[] NOT NULL CHECK (cardinality(remaining_gaps) > 0),
  next_step text NOT NULL CHECK (length(next_step) BETWEEN 1 AND 1500),
  device_runtime_verified boolean NOT NULL DEFAULT false CHECK (device_runtime_verified = false),
  claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false),
  observed_at timestamptz NOT NULL DEFAULT now(),
  supersedes_link_key text REFERENCES raf_private.reconstruction_links_v1(link_key) ON DELETE RESTRICT,
  CHECK (supersedes_link_key IS NULL OR supersedes_link_key <> link_key),
  CHECK (
    (relation_kind = 'DOCUMENTS_CI_RUN'
      AND execution_scope = 'HOSTED_CI'
      AND evidence_state IN ('CI_SUCCESS_SCOPED','CI_NO_STEPS')
      AND run_id IS NOT NULL AND run_id > 0
      AND run_attempt IS NOT NULL AND run_attempt > 0
      AND run_head_sha IS NOT NULL AND run_head_sha = github_commit_sha
      AND run_conclusion IS NOT NULL
      AND observed_step_count IS NOT NULL AND observed_step_count >= 0
      AND checkout_binding <> 'NOT_APPLICABLE')
    OR
    (relation_kind <> 'DOCUMENTS_CI_RUN'
      AND run_id IS NULL AND run_attempt IS NULL AND run_head_sha IS NULL
      AND run_conclusion IS NULL AND observed_step_count IS NULL
      AND checkout_binding = 'NOT_APPLICABLE')
  ),
  CHECK (evidence_state <> 'CI_SUCCESS_SCOPED' OR (run_conclusion = 'success' AND observed_step_count > 0)),
  CHECK (evidence_state <> 'CI_NO_STEPS' OR (run_conclusion = 'failure' AND observed_step_count = 0)),
  CHECK (relation_kind <> 'DOCUMENTS_SOURCE' OR (evidence_state = 'SOURCE_VERIFIED' AND execution_scope = 'SOURCE_ONLY')),
  CHECK (relation_kind <> 'REPORTS_DEVICE_FAILURE' OR (evidence_state = 'DEVICE_FAILURE_REPORTED' AND execution_scope = 'DOCUMENTED_DEVICE_REPORT'))
);
CREATE INDEX reconstruction_links_v1_document_idx ON raf_private.reconstruction_links_v1(index_item_pk);
CREATE INDEX reconstruction_links_v1_project_idx ON raf_private.reconstruction_links_v1(project_key);
CREATE INDEX reconstruction_links_v1_batch_idx ON raf_private.reconstruction_links_v1(batch_key);
CREATE INDEX reconstruction_links_v1_supersedes_idx ON raf_private.reconstruction_links_v1(supersedes_link_key);

CREATE FUNCTION raf_private.reject_reconstruction_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $fn$
BEGIN
  RAISE EXCEPTION 'append-only reconstruction records: insert a superseding observation' USING ERRCODE = '55000';
END;
$fn$;
CREATE TRIGGER reconstruction_links_immutable_v1 BEFORE UPDATE OR DELETE OR TRUNCATE
ON raf_private.reconstruction_links_v1 FOR EACH STATEMENT EXECUTE FUNCTION raf_private.reject_reconstruction_mutation_v1();
CREATE TRIGGER reconstruction_batches_immutable_v1 BEFORE UPDATE OR DELETE OR TRUNCATE
ON raf_private.reconstruction_batches_v1 FOR EACH STATEMENT EXECUTE FUNCTION raf_private.reject_reconstruction_mutation_v1();
ALTER TABLE raf_private.reconstruction_links_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.reconstruction_links_v1 FORCE ROW LEVEL SECURITY;
ALTER TABLE raf_private.reconstruction_batches_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.reconstruction_batches_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON raf_private.reconstruction_links_v1, raf_private.reconstruction_batches_v1 FROM PUBLIC, anon, authenticated;

CREATE FUNCTION raf_private.search_reconstruction_v1(p_term text, p_limit integer DEFAULT 20)
RETURNS TABLE (
  link_key text, project_key text, document_title text, document_url text,
  github_repository text, github_commit_sha text, github_path text, github_blob_sha text,
  relation_kind text, evidence_state text, execution_scope text,
  run_id bigint, run_attempt integer, run_head_sha text, run_conclusion text,
  checkout_binding text, source_statement text, evidence_refs jsonb,
  remaining_gaps text[], next_step text, device_runtime_verified boolean,
  document_text_sha256 text, observed_at timestamptz, superseded boolean
)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = '' AS $fn$
BEGIN
  IF p_term IS NULL OR length(btrim(p_term)) NOT BETWEEN 2 AND 100
     OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'term must contain 2..100 characters; limit must be 1..100' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
    SELECT l.link_key,l.project_key,d.source_name,d.provider_url,
           l.github_repository,l.github_commit_sha,l.github_path,l.github_blob_sha,
           l.relation_kind,l.evidence_state,l.execution_scope,
           l.run_id,l.run_attempt,l.run_head_sha,l.run_conclusion,
           l.checkout_binding,l.source_statement,l.evidence_refs,
           l.remaining_gaps,l.next_step,l.device_runtime_verified,
           l.document_text_sha256,l.observed_at,
           EXISTS (SELECT 1 FROM raf_private.reconstruction_links_v1 s WHERE s.supersedes_link_key = l.link_key)
    FROM raf_private.reconstruction_links_v1 l
    JOIN raf_private.drive_metadata_index_v1 d ON d.item_pk = l.index_item_pk
    WHERE strpos(lower(l.project_key || ' ' || d.source_name || ' ' ||
                       l.github_repository || ' ' || l.github_path || ' ' || l.source_statement),
                 lower(btrim(p_term))) > 0
    ORDER BY l.observed_at DESC, l.link_key
    LIMIT p_limit;
END;
$fn$;
REVOKE ALL ON FUNCTION raf_private.reject_reconstruction_mutation_v1() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION raf_private.search_reconstruction_v1(text,integer) FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE raf_private.reconstruction_links_v1 IS 'Private evidence links; report, source and CI are distinct. No physical runtime or whole-corpus claims.';
