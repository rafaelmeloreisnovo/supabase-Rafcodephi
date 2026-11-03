-- Run in a dedicated review transaction, never as a production ingestion.
-- Expected: both DML mutation attempts are rejected, no row persists.
BEGIN;
INSERT INTO raf_private.rafdb_federated_events_v1
(event_key, producer_repository, producer_commit_sha, event_kind, event_state, source_ref, evidence_ref)
VALUES
('rafdb:test:revert-v1', 'rafaelmeloreisnovo/RafPolimata',
 '17346c9e0182a716a11d0b362b644b954f4592a1', 'SOURCE_OBSERVED', 'OBSERVED',
 'github:rafaelmeloreisnovo/RafPolimata', 'review:test-only');
DO $test$
BEGIN
  BEGIN
    UPDATE raf_private.rafdb_federated_events_v1 SET gap='mutation'
     WHERE event_key='rafdb:test:revert-v1';
    RAISE EXCEPTION 'FAILED: update was allowed';
  EXCEPTION WHEN SQLSTATE '23514' THEN
    NULL;
  END;
  BEGIN
    DELETE FROM raf_private.rafdb_federated_events_v1
      WHERE event_key='rafdb:test:revert-v1';
    RAISE EXCEPTION 'FAILED: delete was allowed';
  EXCEPTION WHEN SQLSTATE '23514' THEN
    NULL;
  END;
  IF NOT EXISTS (SELECT 1 FROM raf_private.rafdb_federated_events_v1
                 WHERE event_key='rafdb:test:revert-v1') THEN
    RAISE EXCEPTION 'FAILED: source event disappeared';
  END IF;
END;
$test$;
ROLLBACK;
