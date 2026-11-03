# RAFDB ↔ Supabase private event bridge V1

Producer and schema authority: `rafaelmeloreisnovo/supabase-Rafcodephi/rafcodephi/governance/sql/rafdb_federated_events_v1.DRAFT.sql`.
Database authority: verified active Rafcodephi Supabase project, **not the inactive legacy project**; project identifiers and private data intentionally omitted from this public fork.
Consumers/producers: RafGitTools (control plane), RafPolimata (bounded C11 compiler/RAFDB), instituto-Rafael/relativity-living-light (scientific evidence producer), and ZIPRAF object custody where explicitly authorized.

**Scope:** append-only event **metadata** with exact repo/commit, parent, event type, status, artifact pointer+SHA256 when available, CI run ID and evidence URL. Distinguishes source/artifact/run/evidence/claim. No raw large data, customer/health records, credentials, or pipeline logs are copied. Original GitHub, Drive and Supabase Storage objects remain authoritative.

**Crucial:** database triggers may enforce append-only but **may not compile code or run DDL from untrusted rows**. A trusted authenticated worker must *independently* validate an explicit `PIPELINE_REQUESTED` event, route it to an allowed CI compiler (RafPolimata producer), then append separate observed receipt events. Writing a request event does **not** start GitHub Actions.

Security: private `raf_private`; RLS enabled without policies; explicit revocation for PUBLIC/anon/authenticated/service_role; no REST Data API grant. No SECURITY DEFINER. No inherited table changes or automatic project-to-project replication. A database owner can bypass logical immutability: do not claim WORM.

To smoke-test from an approved SQL executor after migration: run `rafdb_federated_events_v1.test.sql` (transaction intentionally rolls back), validate `pg_policies`, `has_table_privilege`, trigger metadata and the deterministic readback of exact event keys.

**Data placement:** small relational metadata in PostgreSQL; large immutable ZIPRAF payloads via private authorized Supabase Storage or original GitHub/Drive, with checksum and pointer. Never insert raw private payloads solely to satisfy the slogan "all data in the database."

**Limitations:** not cross-repo E2E; no client adapter, no bidirectional sync, no certified CI compiler integration, no MySQL/Oracle performance comparison, no default source imports. `claim_allowed=false`.

Rollback: stop ingestion; preserve/independently export any inserted records; after owner review and only if empty/fully exported, remove the new table and helper function via separate superseding migration. Existing tables remain untouched.
