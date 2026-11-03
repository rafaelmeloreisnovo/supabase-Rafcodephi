-- RAFAELIA Ω / private evidence for exact cross-provider text comparison.
-- A stored receipt is NOT a proof of mobile runtime, ownership, or whole-corpus equivalence.
-- Git SHA is calculated from authenticated Drive UTF-8 text, not a raw-binary file stream.
CREATE TABLE raf_private.drive_github_correspondence_v1(
  evidence_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  index_item_pk uuid NOT NULL REFERENCES raf_private.drive_metadata_index_v1(item_pk) ON DELETE RESTRICT,
  drive_file_id text NOT NULL,
  github_repository text NOT NULL,
  github_commit_sha text NOT NULL CHECK(github_commit_sha ~ '^[0-9a-f]{40}$'),
  github_path text NOT NULL,
  github_blob_sha text NOT NULL CHECK(github_blob_sha ~ '^[0-9a-f]{40}$'),
  computed_from_drive_text_git_blob_sha text NOT NULL
     CHECK(computed_from_drive_text_git_blob_sha ~ '^[0-9a-f]{40}$'),
  drive_reported_size_bytes bigint CHECK(drive_reported_size_bytes>=0),
  drive_text_utf8_bytes bigint NOT NULL CHECK(drive_text_utf8_bytes>=0),
  source_text_equal boolean NOT NULL,
  sha1_selftests integer NOT NULL CHECK(sha1_selftests BETWEEN 0 AND 3),
  comparison_method text NOT NULL DEFAULT 'CONNECTOR_UTF8_TEXT_AND_GIT_BLOB_SHA1'
    CHECK(comparison_method='CONNECTOR_UTF8_TEXT_AND_GIT_BLOB_SHA1'),
  comparison_result text NOT NULL CHECK(comparison_result IN('TEXT_EXACT_GIT_BLOB_MATCH','MISMATCH','TOKEN_VAZIO')),
  raw_binary_download_covered boolean NOT NULL DEFAULT false CHECK(raw_binary_download_covered=false),
  android_runtime_covered boolean NOT NULL DEFAULT false CHECK(android_runtime_covered=false),
  claim_allowed boolean NOT NULL DEFAULT false CHECK(claim_allowed=false),
  observed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  UNIQUE(drive_file_id,github_repository,github_commit_sha,github_path,github_blob_sha,comparison_method),
  CHECK(comparison_result <> 'TEXT_EXACT_GIT_BLOB_MATCH' OR
     (source_text_equal AND github_blob_sha=computed_from_drive_text_git_blob_sha
      AND sha1_selftests=3 AND drive_reported_size_bytes=drive_text_utf8_bytes))
);
CREATE INDEX drive_github_correspondence_index_item_idx
  ON raf_private.drive_github_correspondence_v1(index_item_pk);
ALTER TABLE raf_private.drive_github_correspondence_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.drive_github_correspondence_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON raf_private.drive_github_correspondence_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER drive_github_correspondence_immutable BEFORE UPDATE OR DELETE
 ON raf_private.drive_github_correspondence_v1 FOR EACH ROW
 EXECUTE FUNCTION raf_private.reject_drive_metadata_mutation_v1();
