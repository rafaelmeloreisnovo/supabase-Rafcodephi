-- RAFAELIA Ω / ACTUAL Drive metadata inventory in private Supabase (scoped ChatGPT connector pilot).
-- This SQL is source code only. Data rows must originate from returned Drive provider metadata, never guesses.
-- SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM.
-- Does not enable standalone Google OAuth; google_drive_official driver retains BLOCKED_AUTH.
CREATE TABLE raf_private.drive_metadata_index_v1 (
  item_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_pk uuid NOT NULL REFERENCES raf_private.mapa_driver_catalog_v1(driver_pk) ON DELETE RESTRICT,
  account_alias text NOT NULL DEFAULT 'oficial' CHECK (account_alias='oficial'),
  source_file_id text NOT NULL CHECK (length(source_file_id) BETWEEN 10 AND 256),
  source_root_id text NOT NULL CHECK (length(source_root_id) BETWEEN 10 AND 256),
  source_parent_id text,
  source_name text NOT NULL CHECK (length(source_name) BETWEEN 1 AND 500),
  source_kind text NOT NULL CHECK (source_kind IN ('FILE','FOLDER','TOKEN_VAZIO')),
  mime_type text,
  size_bytes bigint CHECK (size_bytes IS NULL OR size_bytes >= 0),
  provider_created_at timestamptz,
  provider_modified_at timestamptz,
  provider_url text NOT NULL CHECK (length(provider_url) BETWEEN 20 AND 1000),
  version_fingerprint_sha256 text NOT NULL CHECK (version_fingerprint_sha256 ~ '^[0-9a-f]{64}$'),
  source_content_sha256 text CHECK (source_content_sha256 IS NULL OR source_content_sha256 ~ '^[0-9a-f]{64}$'),
  content_evidence text NOT NULL DEFAULT 'NOT_READ' CHECK (content_evidence='NOT_READ'),
  index_evidence text NOT NULL DEFAULT 'DRIVE_OAUTH_METADATA_READ' CHECK (index_evidence='DRIVE_OAUTH_METADATA_READ'),
  index_state text NOT NULL DEFAULT 'METADATA_OBSERVED' CHECK (index_state='METADATA_OBSERVED'),
  original_preserved boolean NOT NULL DEFAULT true CHECK(original_preserved=true),
  claim_allowed boolean NOT NULL DEFAULT false CHECK(claim_allowed=false),
  observed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE(source_file_id,version_fingerprint_sha256)
);
CREATE INDEX drive_metadata_index_root_idx
  ON raf_private.drive_metadata_index_v1(source_root_id,observed_at DESC);
CREATE INDEX drive_metadata_index_parent_idx
  ON raf_private.drive_metadata_index_v1(source_parent_id);
CREATE INDEX drive_metadata_index_name_idx
  ON raf_private.drive_metadata_index_v1(source_name);

CREATE TABLE raf_private.drive_metadata_scan_receipts_v1(
  scan_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_root_id text NOT NULL,
  driver_pk uuid NOT NULL REFERENCES raf_private.mapa_driver_catalog_v1(driver_pk) ON DELETE RESTRICT,
  provider text NOT NULL DEFAULT 'GOOGLE_DRIVE_CHATGPT_CONNECTOR' CHECK(provider='GOOGLE_DRIVE_CHATGPT_CONNECTOR'),
  observed_items integer NOT NULL CHECK(observed_items>=0),
  inserted_items integer NOT NULL CHECK(inserted_items>=0 AND inserted_items<=observed_items),
  max_requested integer NOT NULL CHECK(max_requested>0),
  coverage_state text NOT NULL CHECK(coverage_state IN('BOUNDED_DIRECT_CHILDREN','LIMIT_REACHED_PARTIAL','ROOT_ONLY')),
  provider_read_scope text NOT NULL DEFAULT 'DIRECT_CHILDREN_ONLY' CHECK(provider_read_scope='DIRECT_CHILDREN_ONLY'),
  source_content_access text NOT NULL DEFAULT 'NO_CONTENT' CHECK(source_content_access='NO_CONTENT'),
  claim_allowed boolean NOT NULL DEFAULT false CHECK(claim_allowed=false),
  executed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK(coverage_state<>'ROOT_ONLY' OR observed_items=1)
);
ALTER TABLE raf_private.drive_metadata_index_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.drive_metadata_index_v1 FORCE ROW LEVEL SECURITY;
ALTER TABLE raf_private.drive_metadata_scan_receipts_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.drive_metadata_scan_receipts_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE raf_private.drive_metadata_index_v1,raf_private.drive_metadata_scan_receipts_v1
  FROM PUBLIC,anon,authenticated;
CREATE FUNCTION raf_private.reject_drive_metadata_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $fn$
BEGIN RAISE EXCEPTION 'append_only_metadata_index_mutation_rejected'; END; $fn$;
REVOKE ALL ON FUNCTION raf_private.reject_drive_metadata_mutation_v1()
  FROM PUBLIC,anon,authenticated;
CREATE TRIGGER drive_metadata_index_immutable BEFORE UPDATE OR DELETE
 ON raf_private.drive_metadata_index_v1 FOR EACH ROW EXECUTE FUNCTION raf_private.reject_drive_metadata_mutation_v1();
CREATE TRIGGER drive_metadata_receipt_immutable BEFORE UPDATE OR DELETE
 ON raf_private.drive_metadata_scan_receipts_v1 FOR EACH ROW EXECUTE FUNCTION raf_private.reject_drive_metadata_mutation_v1();
