# RAFAELIA Ω — Transactional matrix triggers / zero-trust pilot V1

Status: **DRAFT_SOURCE_ONLY / NOT_DEPLOYED / DB_NOT_RUN / claim_allowed=false**.
Independent source module: [SQL](sql/rafaelia_matrix_event_triggers.v1.DRAFT.sql).
Structural check: [SQL](sql/rafaelia_matrix_event_assertions.v1.DRAFT.sql).
Depends on the existing proposed federation schema V1, but it does **not** amend
`supabase/migrations` or affect the upstream monorepo. Public fork: only generic
code and synthetic metadata; do not commit private receipts or children's data.

## Architecture / compilation analogy

ZIPRAF-style specialization applies to **module boundaries and acceptance gates**,
not to making PostgreSQL freestanding. Native PostgreSQL trigger functions must
run in its controlled server runtime; optional C/ASM freestanding modules can
process independently exported non-sensitive data, never bypass the DB access policy.

| Module | Contract | Specialized action |
| --- | --- | --- |
| registry V1 (predecessor) | source_id + owner/purpose/class/retention | classify original source |
| matrix_events | append-only event envelope | represent typed, reversible relationships |
| matrix_validate_before_insert | BEFORE INSERT row trigger | class consistency, predecessor sequence, purpose metadata |
| matrix_enqueue_after_insert | AFTER INSERT row trigger | insert transactional outbox pointer |
| matrix_append_only_guard | UPDATE/DELETE/TRUNCATE trigger | reject normal event history mutation |
| matrix_event_outbox | stable event id | relay to a trusted, idempotent downstream worker |
| external custody | independent receipt/hash/backup | detect tampering and verify audit completeness |

No UPDATE of the event stream. Operational outbox delivery status is separately
mutable but must have a later immutable delivery receipt. Append-only by trigger
does not prevent database owners from disabling triggers or modifying WAL; preserve
off-provider custody. Row triggers cannot audit SELECT, failed or rolled-back
attempts, privileged DDL, or external provider access: configure scoped pgAudit,
API logs and independent archival with lawful retention.

## Data minimization / child safeguarding

The event table contains **metadata only**: UUID references, keyed HMAC actor
pseudonym, purpose code, legal-basis/policy references, class and evidence digest.
No names, birthdates, raw content, IP addresses, location trails, biometrics or
sensitive allegation text. The HMAC key lives in an independently controlled
backend KMS and is never stored in SQL/Git or issued to a client. A SHA-256-looking
string is not proof: compute and attest it independently. A pseudonym is still
potentially personal data where linkage is possible.

An `ERASURE_REQUEST` records that a request entered the workflow;
`ERASURE_RECORDED` must only be emitted after independently verified completion.
Neither event automatically erases anything. Legitimate erasure/blocking,
retention limits, backups, legal holds and crypto-shredding are separate
controlled processes. A child's best interests take priority; do not make
privacy data permanently undeletable. No publication bridge exists here.

## Permission boundary

The script creates a `NOLOGIN` role but does **not** assign membership.
No `anon` or `authenticated` table grants, policies or routines are added.
All tables reside in the existing private schema, which must not be exposed in
Supabase Data API. A vetted, authenticated backend policy decision point must
bind actor, purpose, lawful basis and tenant *before* granting the ingestor
role to a scoped service identity. Caller-provided event metadata is not verified
identity by itself. RLS does not protect against table owners and BYPASSRLS roles;
SECURITY DEFINER routines need an independent review and least-privilege owner.

**Two provider projects were observed INACTIVE on 2026-11-02.** Neither is
selected as migration target. No restore, billing, schema, database, RLS or
provider-key change has been performed.

## Falsifier / negative tests — mandatory before deployment

| Test | Expected |
| --- | --- |
| `anon` and `authenticated` direct SELECT/INSERT | DENY |
| Cross-tenant IDOR, cross-stream predecessor | DENY |
| Sequence zero, skipped sequence or duplicate sequence | DENY |
| Wrong or missing predecessor event | DENY |
| UPDATE / DELETE / TRUNCATE history | DENY for ordinary roles |
| Unclassified source labeled as public | DENY |
| Child safeguard source linked to lower class | DENY |
| Link to dissimilar classification | DENY |
| Unapproved service identity or forged actor/purpose | DENY at backend PDP |
| Duplicate event / retry | Idempotent failure or safe dedup receipt |
| Concurrent competing writes in same stream | Exactly one ordered successor |
| Injected trigger failure | Roll back BOTH event and outbox |
| Successful trusted insert | Exactly one outbox row, matching event id |
| Direct outbox tampering | DENY |
| Unauthorized view, Storage object or signed URL | DENY |
| Data subject erasure/blocking request | Legally reviewed action with minimal surviving metadata |
| Owner/BYPASSRLS or trigger disable | Independent off-provider alert and custody |
| Privileged DDL and SELECT | Covered by scoped pgAudit/API logging, not trigger |
| Full restore and withdrawal | Reconstructed history and expired/public caches invalidated |

The structural check only inspects catalogs and is NOT a substitute for these
behavioral tests. Record expected/observed result, provider version, role,
database snapshot/backup, precise SQL revision and terminal receipt.
Do not run against live data as a first test.

## Stop / release gate

1. Select and authorize each provider target *independently*; check cost and
   restoration paths; keep two projects isolated by default.
2. Read actual roles, exposed schemas, grants, RLS, table owner, pgAudit config,
   KMS, WAL/retention, source rights and personal-data footprint.
3. Apply proposed predecessor and successor in an isolated sandbox only,
   then run negative/positive tests and provider security advisors.
4. Require independent legal/privacy/child-safeguard review; use two-person
   approval for any release of sanitized public data.
5. Run exact-head CI, reviewed migration diff, clean rollback drill,
   immutable external receipt/readback; only then consider provider deployment.
6. Publish only audited sanitized outputs, never private matrices.

Rollback while draft: close the draft PR without merge.
Rollback in sandbox: drop *only* objects created by this module after snapshot
verification; retain external evidence, never use CASCADE or history rewrite
without explicit scoped authority.

Refs: NIST SP 800-207; LGPD Lei 13.709/2018; ANPD Enunciado 1/2023;
Lei 15.211/2025 (proteção digital de crianças e adolescentes); Supabase
RLS and PostgreSQL triggers/pgaudit documentation.

R3=<source proposal committed, provider runtime/negative tests NOT_RUN,
review isolated scope and provider/rights/backup gates>.
