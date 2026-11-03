-- SPDX-License-Identifier: Apache-2.0
-- RAFAELIA / RAFDB federated metadata/CI receipt ledger v1.
-- Additive private schema, no raw corpus, no secrets, no DDL executor.
-- SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM.
BEGIN;
CREATE SCHEMA IF NOT EXISTS raf_private;

CREATE TABLE raf_private.rafdb_federated_events_v1 (
  event_key text PRIMARY KEY
    CHECK (length(event_key) BETWEEN 8 AND 160 AND event_key ~ '^[a-zA-Z0-9:_./-]+$'),
  parent_event_key text REFERENCES raf_private.rafdb_federated_events_v1(event_key),
  producer_repository text NOT NULL
    CHECK (length(producer_repository) <= 150 AND producer_repository ~ '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'),
  producer_commit_sha text NOT NULL CHECK (producer_commit_sha ~ '^[0-9a-f]{40}$'),
  event_kind text NOT NULL CHECK (event_kind IN
    ('SOURCE_OBSERVED','PIPELINE_REQUESTED','CI_OBSERVED','ARTIFACT_INDEXED',
     'DATASET_REFERENCED','VALIDATION_OBSERVED','FAILURE_RECORDED','ROLLBACK_RECORDED')),
  event_state text NOT NULL DEFAULT 'TOKEN_VAZIO' CHECK (event_state IN
    ('TOKEN_VAZIO','OBSERVED','IMPLEMENTED_UNTESTED','PASS','FAIL','BLOCKED','SKIPPED')),
  source_ref text NOT NULL CHECK (length(source_ref) BETWEEN 1 AND 500),
  run_id bigint CHECK (run_id > 0),
  run_attempt integer CHECK (run_attempt > 0),
  payload_locator text CHECK (length(payload_locator) BETWEEN 1 AND 500 AND position('?' IN payload_locator)=0),
  payload_sha256 text CHECK (payload_sha256 ~ '^[0-9a-f]{64}$'),
  evidence_ref text NOT NULL CHECK (length(evidence_ref) BETWEEN 1 AND 500),
  gap text NOT NULL DEFAULT 'TOKEN_VAZIO' CHECK (length(gap) BETWEEN 1 AND 500),
  claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false),
  observed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  inserted_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CONSTRAINT rafdb_no_self_parent CHECK (parent_event_key IS DISTINCT FROM event_key),
  CONSTRAINT rafdb_payload_pair CHECK ((payload_locator IS NULL) = (payload_sha256 IS NULL)),
  CONSTRAINT rafdb_pass_ci_evidence CHECK
   (event_state <> 'PASS' OR (event_kind IN ('CI_OBSERVED','VALIDATION_OBSERVED')
       AND run_id IS NOT NULL AND evidence_ref <> 'TOKEN_VAZIO'))
);

CREATE INDEX rafdb_events_producer_time_v1
 ON raf_private.rafdb_federated_events_v1(producer_repository, observed_at DESC, event_key);
CREATE INDEX rafdb_events_parent_v1
 ON raf_private.rafdb_federated_events_v1(parent_event_key) WHERE parent_event_key IS NOT NULL;
CREATE INDEX rafdb_events_kind_time_v1
 ON raf_private.rafdb_federated_events_v1(event_kind, inserted_at DESC);

ALTER TABLE raf_private.rafdb_federated_events_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE raf_private.rafdb_federated_events_v1 FROM PUBLIC, anon, authenticated, service_role;
-- No RLS policies, no Data API grant: only separately authorized database owner can insert.
-- Existing private-schema grants, policies, other tables and pipelines are untouched.

CREATE FUNCTION raf_private.rafdb_reject_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog AS $rafdb$
BEGIN
  RAISE EXCEPTION 'RAFDB append-only: record a successor event instead'
    USING ERRCODE = '23514';
END;
$rafdb$;

CREATE TRIGGER rafdb_event_immutable_v1
 BEFORE UPDATE OR DELETE ON raf_private.rafdb_federated_events_v1
 FOR EACH ROW EXECUTE FUNCTION raf_private.rafdb_reject_mutation_v1();

REVOKE ALL ON FUNCTION raf_private.rafdb_reject_mutation_v1() FROM PUBLIC, anon, authenticated, service_role;
COMMENT ON TABLE raf_private.rafdb_federated_events_v1 IS
 'RAFAELIA private, source-bound, append-only event metadata; not a durable execution queue, SQL compiler, proof of E2E integration, WORM custody, or raw data store.';
COMMIT;