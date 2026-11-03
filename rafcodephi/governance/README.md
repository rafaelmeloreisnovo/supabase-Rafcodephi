# RAFAELIA Ω — Federated data governance for Supabase (review candidate)
## Reconstruction module

[Private reconstruction links](RECONSTRUCTION_LINKS_V1.md) provides source-to-execution queries, evidence boundaries, and transactional tests. The proposal status below describes the original federation design; provider deployment and data coverage are recorded separately in private module receipts.

Status: PROPOSAL_DRAFT_HOLD. Source artifacts only. No database, RLS, Storage or production data were modified. Public repository: never paste private project IDs, locations, names of children, secret keys, private Drive content, or allegations about individuals.

## Authority and purpose

- Code, schema draft, SQL tests: this fork, scoped only under rafcodephi/governance. Upstream Supabase retains its own copyright and Apache-2.0 license.
- Cross-repository route and trustworthy current status: private Mapa; original source code: original producer repository.
- Drive: current documentary source, original record and append-only receipts. Supabase: candidate operational metadata/index and public sanitized snapshot, **not** an instant replacement for custody originals.
- Existing Supabase projects were observed inactive at review; selecting/reactivating them, costs, lawful rights, source ownership, privacy review, and real deployment are separate provider authority gates.

## Data products

1. Protected metadata registry records source provider, version, hash where available, owner, purpose, lawful basis, retention and privacy class. It does not take raw documents by default.
2. Typed lineage edges and receipts form a graph. A hash detects byte changes **only if independently recomputed and securely stored**; a SQL row alone is not immutable/WORM or proof of human authorship.
3. Curated public map releases contain typed nodes, typed edges and numeric chart points. No arbitrary JSON, raw sources, personal coordinates, private URLs, credentials, evidence packages or exact source identifiers.
4. Private object storage is optional, after bucket access, backup, encryption, lawful purpose and retention are approved. Public output is a separate review and sanitization operation, never a read-through of private tables.
5. Frontend web hosting is distinct from Supabase: a public Mapa site/app must separately consume read-only curated endpoints and apply rate limiting and cache revocation.

## Default-deny & publication

UNCLASSIFIED implies HOLD, not public. Public release requires independent review, legal/right-to-share check, child safeguarding, a protected approval receipt, validation of aggregate reidentification risks, a deliberately executed promotion step and rollback/removal process. Never infer that combating crime or child exploitation authorizes private surveillance, disclosure or access to third-party data. Lawful requests to appropriate authorities are a distinct controlled process, not an administrator bypass.

A private row must never become public merely by a boolean flag; the public release is materialized from a reviewed sanitized payload. The draft SQL exposes only rows of releases whose state is published; it **does not itself** cryptographically validate the reviewer identities, so this gate MUST be implemented and tested separately before applying.

## DMAIC and standards mapping

| Phase | CTQ/control | Evidence gate |
| --- | --- | --- |
| DEFINE | lawful purpose, subject/ownership, source-of-truth and exact classification | catalog with declared owner/rights |
| MEASURE | source-hash coverage, classified share, missing provenance, security baseline and cost | measurable population and readback |
| ANALYZE | path to public leak, IDOR/RLS bypass, user metadata spoofing, minors, chart reidentification, service key and non-WORM logs | threat model and privacy impact review |
| IMPROVE | minimum schema, deny-by-default RLS and grants, private bucket, source preserving ingest | isolated migration, fixtures and reviewer |
| CONTROL | zero unauthorized read/write in test matrix, reproducible source, immutable external receipts, revocation/rollback | exact head CI, provider-side tests, negative API cases, restore drill |

Use ISO/IEC 27001:2022 for information security management, ISO/IEC 27701:2025 for privacy, ISO 8000-1:2022 for data-quality principles, ISO 9001 for quality-management process, NIST SP 800-207 Zero Trust, NIST CSF 2.0 and applicable LGPD/ECA Digital safeguards. Specific RFC/IEEE standards must be selected by protocol/product. User-mentioned ISO 501 is TOKEN_VAZIO_STANDARD_ID_AMBIGUOUS. This is mapping to concepts, NOT a certification or statistical Six Sigma proof.

## Pre-deployment stop / acceptance

1. Provider project and cost explicitly selected and authorized; backups and restore proven.
2. Data-owner list, origin/rights/license, purpose, lawful basis, retention and child-risk classification for the **selected pilot dataset**.
3. Validate applied DDL in isolated environment; inspect exposed schemas/role grants; assert no client grant or policy on raf_private.
4. Verify positive/negative API cases for anonymous and authenticated users including staged, published, revoked, cross-tenant IDOR, direct table and view access, inserts/updates/deletes, Storage private bucket, JWT spoofing, signed URLs and service-role secrecy.
5. Execute independent publication approval, verify cache purge and public withdrawal, test a controlled restore and inspect provider security advisors.
6. Manual source checks and exact-SHA CI readback; no automatic merge or provider writes until gates satisfied.

Rollback while draft: close without merge. Once live: stop publishing, revoke affected release, invalidate caches/URLs, restore from tested backup when necessary and append an incident/correction event. Never delete source history silently.

R3: F_ok=source schema and controls drafted; F_gap=live service, lawful source scope, tests and independent authorization; F_next=single non-sensitive seed dataset and exact provider verification.
