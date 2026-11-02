-- RAFAELIA Ω — private metadata deduplication candidate (source-only).
-- Not a migration. Do not apply or run against a provider database without
-- project selection, authority, classification, backup, independent review,
-- RLS/privileges testing, and a rollback receipt.
-- Prerequisite: reviewed raf_private schema from
-- rafaelia_federated_data_schema.v1.DRAFT.sql (also NOT DEPLOYED).
-- No user data, external folder IDs, tokens or private locators appear here.
-- Source != Artifact != Execution != Evidence != Claim.
BEGIN;

CREATE TABLE raf_private.dedup_entities_v1 (
  canonical_key text PRIMARY KEY
    CHECK (length(canonical_key) BETWEEN 5 AND 512 AND canonical_key <> 'TOKEN_VAZIO'),
  entity_kind text NOT NULL
    CHECK (entity_kind IN ('paper', 'document', 'code_object', 'receipt', 'other')),
  identity_evidence_ref text NOT NULL CHECK (length(identity_evidence_ref) > 0),
  identity_status text NOT NULL DEFAULT 'UNVERIFIED'
    CHECK (identity_status IN ('UNVERIFIED', 'SOURCE_ASSERTED', 'INDEPENDENTLY_VERIFIED')),
  access_class text NOT NULL DEFAULT 'UNCLASSIFIED'
    CHECK (access_class IN ('PUBLIC_APPROVED', 'INTERNAL', 'CONFIDENTIAL',
                            'RESTRICTED', 'CHILD_SAFEGUARD', 'UNCLASSIFIED')),
  first_observed_at timestamptz NOT NULL DEFAULT now(),
  claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false)
);

-- One source membership is NOT the same as one entity. The same paper can
-- occur in multiple source collections without losing those relations.
-- For PostgreSQL >= 15: NULLS NOT DISTINCT prevents replays of UNKNOWN
-- revisions from silently multiplying identical memberships.
CREATE TABLE raf_private.dedup_occurrences_v1 (
  occurrence_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  provider text NOT NULL CHECK (provider IN (
    'alphaxiv', 'arxiv', 'github', 'google_drive', 'supabase', 'other')),
  source_item_key text NOT NULL CHECK (length(source_item_key) > 0),
  scope_key text NOT NULL CHECK (length(scope_key) > 0),
  source_revision text NULL CHECK (source_revision <> ''),
  relation_kind text NOT NULL CHECK (relation_kind IN (
    'MEMBER_OF', 'OBSERVED_AT', 'MIRRORS', 'REFERENCES', 'OTHER')),
  canonical_key text NULL REFERENCES raf_private.dedup_entities_v1(canonical_key),
  evidence_ref text NOT NULL CHECK (length(evidence_ref) > 0),
  content_sha256 text NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  first_observed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE NULLS NOT DISTINCT
    (provider, source_item_key, scope_key, source_revision, relation_kind)
);
CREATE INDEX dedup_occurrences_v1_canonical_key_idx
  ON raf_private.dedup_occurrences_v1 (canonical_key);

-- The provider/namespace pair is the deduplication key for an occurrence,
-- never a filename, title, hash alone, or a fuzzy semantic similarity.
-- For alphaXiv public arXiv papers: canonical_key = 'arxiv:' || verified ID
-- without a version suffix. The folder ID belongs ONLY in scope_key.
-- Preserve every distinct folder membership in dedup_occurrences_v1.
-- If identity authority is unknown, keep canonical_key NULL, not a guessed
-- 'arxiv:*', not zero, and never an automatic cross-provider merge.
-- Use INSERT ... ON CONFLICT ... DO NOTHING for exact replay only; changes
-- of identity/classification require reviewed superseding evidence events.

ALTER TABLE raf_private.dedup_entities_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.dedup_occurrences_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON raf_private.dedup_entities_v1,
  raf_private.dedup_occurrences_v1 FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE raf_private.dedup_occurrences_v1_occurrence_id_seq
  FROM PUBLIC, anon, authenticated;
-- No client grants, RLS policies, SECURITY DEFINER functions, data migration,
-- public views, snapshots, or publish actions are created by this candidate.
COMMIT;
