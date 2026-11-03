# RAFAELIA Ω — Trigger-to-migration governance bridge V1

**State:** DRAFT / HOLD. **Never auto-run a blueprint from a client row.**
Producer: this repository's `rafcodephi/governance`; federated routing: `Mapa`.
This file supplements the existing `raf_private.source_registry`,
`lineage_edges`, `evidence_events` candidate schema; it does not clone or
overwrite those three layers. Historical source databases remain independent.

## Intent and trust boundary

```
SOURCE (GitHub / Drive / legacy Supabase, explicit revision)
  -> PRIVATE schema_change_requests (metadata only)
  -> AFTER INSERT trigger -> schema_change_events (REQUESTED)
  -> authority / rights / DPIA / zero-trust / backup / reviewer
  -> separate versioned DDL migration (manual/CI approved)
  -> observed SQL metadata + tested RLS/grants + migration receipt
  -> Drive μWRITE and Mapa route pointer (source IDs/hashes only)
```

**A row-level trigger never executes CREATE TABLE.** The trigger only creates
a request audit event. PostgreSQL DDL is compiled from an allowlisted,
validated specification by an independently approved executor. JSONB in
`columns_proposal` is **untrusted data**, not executable SQL. No SECURITY
DEFINER functions, anonymous writes, cross-project DDL, or automatic
publication. New tables in exposed schemas require RLS + explicit grants +
negative API tests. DDL monitoring can be added later only with evaluated
event triggers/pgaudit and resource limits.

## Schemas, identity and governance

- `raf_private`: schema requests/events and the independent source/lineage/
  evidence schema candidate; unexposed and denied to API roles.
- `raf_workspace`: reserved target namespace; this migration does NOT
  create it or any user-requested target table.
- `request_id`/parent, `source_revision`/`source_sha256`,
  `source_observed_at`, timestamps and event linkage support reconstruction.
  Keep distinct *source-reported*, *observed*, and *provider-created* times.
- Corrections become new requests/events with a parent pointer. Logical
  append-only triggers do not guarantee WORM: database owners can bypass them.
  Anchor signed/independent digests and receipts in an authorized custody
  system before asserting tamper resistance.
- Default `UNCLASSIFIED` and `legal_basis=TOKEN_VAZIO` are STOP states.
  No raw documents, identity secrets, health/child data, or source payloads
  may be copied without separate permission and lawful purpose.

## Gates (NIST/ISO/IEEE guidance, NOT certification)

- NIST SP 800-207 + CSF 2.0: identity-per-request, least privilege, deny by
  default, threat model, incident/rollback and provider access verification.
- ISO/IEC 27001:2022, ISO/IEC 27701:2025: security/privacy management,
  lawful purpose, retention, rights, and privacy impact assessment.
- ISO 8000-1:2022 and ISO 9001: information quality, reproducible
  provenance, controlled change; the exact standard edition/clauses need
  independent verification where applied.
- IEEE controls: use only a specific, verified applicable standard; no blanket
  IEEE certification claim. LGPD and safeguarding of vulnerable people take
  priority over convenience or external exposure.
- DMAIC Define/Measure/Analyze/Improve/Control; Six Sigma statistical level
  is **not** claimed.

## Acceptance before provider deployment

Run `schema_request_control_v1.test.sql` on isolated PostgreSQL. Independently
test REST `anon`/`authenticated`, RLS denial, status transitions, revocation,
backup/restore, no secrets, source rights and metadata-minimization. Obtain
review of exact GitHub HEAD and provider project authority; write timestamped
positive/negative receipt. Do not merge/promote on a green source-only test.

## Rollback

Draft: close the PR, preserve baseline. For any future applied migration:
stop intake; capture audit export and an independent backup; remove only
new empty objects after explicit data-safe review; record a superseding receipt.
Never erase historical schema, source ownership, existing DDL, or a receipt.
