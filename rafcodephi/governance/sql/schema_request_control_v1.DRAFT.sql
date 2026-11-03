-- SPDX-License-Identifier: Apache-2.0
-- RAFAELIA Ω / bounded PRIVATE schema-request bridge, V1.
-- DRAFT/HOLD: no arbitrary DDL inside row triggers; no public API access.
-- Idempotent only for first application to an empty target; review migration drift.
BEGIN;

CREATE SCHEMA IF NOT EXISTS raf_private;
REVOKE ALL ON SCHEMA raf_private FROM PUBLIC, anon, authenticated;

CREATE TABLE raf_private.schema_change_requests (
  request_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_request_id uuid REFERENCES raf_private.schema_change_requests(request_id),
  provider text NOT NULL CHECK (provider IN ('github','google_drive','supabase','other')),
  source_ref text NOT NULL CHECK (length(source_ref) BETWEEN 1 AND 256),
  source_revision text NOT NULL CHECK (length(source_revision) BETWEEN 1 AND 160),
  source_sha256 text CHECK (source_sha256 ~ '^[0-9a-f]{64}$'),
  source_observed_at timestamptz,
  actor_ref text NOT NULL CHECK (length(actor_ref) BETWEEN 1 AND 120),
  purpose text NOT NULL CHECK (length(purpose) BETWEEN 1 AND 500),
  legal_basis text NOT NULL DEFAULT 'TOKEN_VAZIO',
  data_class text NOT NULL DEFAULT 'UNCLASSIFIED'
    CHECK (data_class IN ('UNCLASSIFIED','INTERNAL','CONFIDENTIAL','RESTRICTED','CHILD_SAFEGUARD','PUBLIC_APPROVED')),
  target_schema text NOT NULL DEFAULT 'raf_workspace' CHECK (target_schema = 'raf_workspace'),
  proposed_table text NOT NULL CHECK (proposed_table ~ '^[a-z][a-z0-9_]{0,62}$'),
  columns_proposal jsonb NOT NULL CHECK (jsonb_typeof(columns_proposal) = 'array'),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK (octet_length(columns_proposal::text) <= 16384),
  CHECK (parent_request_id IS NULL OR parent_request_id <> request_id)
);

CREATE TABLE raf_private.schema_change_events (
  event_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL REFERENCES raf_private.schema_change_requests(request_id),
  parent_event_id uuid REFERENCES raf_private.schema_change_events(event_id),
  kind text NOT NULL CHECK (kind IN
    ('REQUESTED','REVIEW_APPROVED','REVIEW_DENIED','MIGRATION_APPLIED','MIGRATION_FAILED','ROLLBACK_RECORDED')),
  actor_ref text NOT NULL CHECK (length(actor_ref) BETWEEN 1 AND 120),
  authority_ref text NOT NULL CHECK (length(authority_ref) BETWEEN 1 AND 256),
  evidence_ref text NOT NULL CHECK (length(evidence_ref) BETWEEN 1 AND 512),
  evidence_sha256 text CHECK (evidence_sha256 ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
  CHECK (parent_event_id IS NULL OR parent_event_id <> event_id)
);

CREATE INDEX schema_change_events_request_time_idx
  ON raf_private.schema_change_events (request_id, created_at, event_id);
CREATE INDEX schema_change_requests_created_idx
  ON raf_private.schema_change_requests (created_at, request_id);

ALTER TABLE raf_private.schema_change_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.schema_change_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON raf_private.schema_change_requests, raf_private.schema_change_events
  FROM PUBLIC, anon, authenticated;
-- Private schema also has no GRANT to service_role by default.
-- Privileged operations require a separate reviewed service/migration boundary.

CREATE FUNCTION raf_private.reject_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog AS $fn$
BEGIN
  RAISE EXCEPTION 'RAFAELIA append-only: insert successor, do not update/delete';
END;
$fn$;

CREATE TRIGGER schema_request_immutable
BEFORE UPDATE OR DELETE ON raf_private.schema_change_requests
FOR EACH ROW EXECUTE FUNCTION raf_private.reject_mutation_v1();

CREATE TRIGGER schema_event_immutable
BEFORE UPDATE OR DELETE ON raf_private.schema_change_events
FOR EACH ROW EXECUTE FUNCTION raf_private.reject_mutation_v1();

CREATE FUNCTION raf_private.enqueue_schema_request_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path = pg_catalog AS $fn$
BEGIN
  INSERT INTO raf_private.schema_change_events
    (request_id, kind, actor_ref, authority_ref, evidence_ref)
  VALUES
    (NEW.request_id, 'REQUESTED', NEW.actor_ref,
     'TOKEN_VAZIO:INDEPENDENT_APPROVAL_PENDING',
     'request:' || NEW.request_id::text);
  RETURN NEW;
END;
$fn$;

CREATE TRIGGER schema_request_enqueue
AFTER INSERT ON raf_private.schema_change_requests
FOR EACH ROW EXECUTE FUNCTION raf_private.enqueue_schema_request_v1();

REVOKE ALL ON FUNCTION raf_private.reject_mutation_v1() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION raf_private.enqueue_schema_request_v1() FROM PUBLIC, anon, authenticated;

COMMENT ON SCHEMA raf_private IS 'RAFAELIA private metadata / default deny. Not exposed to client API.';
COMMENT ON TABLE raf_private.schema_change_requests IS
  'Proposal/blueprint only. An INSERT does NOT create a table. Approved DDL is an independently reviewed migration.';
COMMENT ON TABLE raf_private.schema_change_events IS
  'Append-only logical decision events. Not WORM, not a trusted timestamp or substitute for independent receipts.';

COMMIT;
