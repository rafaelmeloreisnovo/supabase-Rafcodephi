# RAFAELIA Ω — Nested provenance and custody V1

Status: PROPOSAL_DRAFT_HOLD. This document and its SQL are source artifacts only. They are not a Supabase migration and were not applied to a provider database.

## Intent

Represent a project inside another project while preserving every earlier relationship and every source observation. A later name, parent, timestamp or correction becomes a new event with a predecessor reference. It never overwrites the original observation.

## Authority boundary

- Google Drive stores the documentary source and append-only receipts.
- GitHub stores this schema candidate, its contract and exact revisions.
- Supabase would store a private metadata/index graph only after a selected active project, backup/restore test, rights review, RLS tests and independent review.
- Original files remain at their authoritative source. This design does not copy raw documents by default.

## Reconstruction model

project_registry identifies a logical project. custody_events records source names, source dates, source times, timezone, observed time, recorded time, source revision, commit, evidence reference and optional hashes. project_edges records historical typed relationships. A CONTAINS edge is the nesting relation.

The recursive view raf_private.project_ancestry reconstructs all recorded ancestors:

```sql
select
  child_project_id,
  ancestor_project_id,
  depth,
  project_path,
  edge_id,
  observed_at,
  evidence_ref,
  child_name,
  ancestor_name
from raf_private.project_ancestry
order by child_project_id, depth, observed_at, edge_id;
```

To reconstruct a timeline for one project:

```sql
select
  event_seq,
  event_id,
  event_kind,
  source_name,
  source_created_at,
  source_updated_at,
  source_timezone,
  occurred_at,
  observed_at,
  recorded_at,
  source_revision,
  source_commit_sha,
  evidence_ref,
  content_sha256,
  previous_event_hash_sha256,
  event_hash_sha256,
  supersedes_event_id
from raf_private.custody_events
where project_id = '<approved-project-id>'
order by event_seq, recorded_at, event_id;
```

The placeholder must be replaced only inside an authorized isolated database test. It is intentionally not a real project ID.

## Acceptance gates

1. Static parse and exact-head CI.
2. Cycle rejection for CONTAINS.
3. Edge/event alignment rejection.
4. Append-only rejection for update and delete.
5. Parent-event and supersession reconstruction.
6. Positive and negative RLS and direct-table access cases.
7. Backup/restore and provider advisor readback.

A database hash is an integrity signal, not proof of human authorship or immutable storage. Privileged database roles can bypass triggers, so Drive/GitHub receipts and independent recomputation remain part of the custody chain.

R3: F_ok=nested structure and custody fields specified; F_gap=provider and runtime evidence absent; F_next=isolated static/CI validation, then one non-sensitive metadata pilot.
