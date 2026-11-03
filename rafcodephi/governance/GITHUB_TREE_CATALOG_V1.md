# RAFAELIA Ω — Private GitHub tree catalog V1 (review gate)

Status: **DRAFT/HOLD — not deployed**. SPDX-License-Identifier: Apache-2.0.
Scope: original, additive fork module under \`rafcodephi/governance/sql/\`; inherits upstream Supabase licensing. No upstream paths changed.

## Why
The existing private repository census indexes repository-level observations, while the source-reference index is a curated evidence index. Neither is a complete file-tree catalog. This proposal adds **two private, append-only metadata tables**, without multiplying canonical Mapa nodes or importing source bytes.

- \`github_tree_scan_receipts_v1\` captures exact provider repository ID, commit SHA, tree SHA, bounded prefix/cursor, source-read scope, counts, digest, and partial/truncated status.
- \`github_tree_entries_v1\` captures Git tree paths, object types/modes/SHAs, nullable size, provider observation evidence, and the parent scan. A composite foreign key prevents an entry from borrowing a receipt for a different repo/commit. A unique (repo ID, commit, path) prevents silent duplicates.
- All records remain \`claim_allowed=false\`; no endpoint, job, service-role credential, or public grant is created. RLS is **FORCED** and no \`anon\`/\`authenticated\` grants are issued.
- Provider metadata can contain sensitive file names; the catalog stays in \`raf_private\` and must never be mirrored into a public repo or dashboard.

## Producer/consumer and provenance
Authority for the schema is this producer repository's reviewed PR. GitHub provider read is a separate evidence gate; producer Git commit/tree SHA must be bound **before** loading each batch. A SHA shaped like a Git OID is not independent proof of provider read, content equivalence, software behavior, or authorship. The recorded SHA-256 manifest must be computed from canonicalized, bounded metadata and its byte encoding retained in a private receipt. Do not store raw file contents, access tokens, private account IDs, or serialized provider responses.

## Execution contract (not implemented here)
1. Privileged runner obtains an authorized exact HEAD/commit and root tree SHA; no implicit branch drift. Resolve ownership/rights/privacy scope for each repository.
2. Read a bounded provider tree prefix or page. Git Trees recursive responses can be truncated; they are **not** intrinsically paginated. Use a provider-approved cursor/partition strategy; never classify a truncation as exhaustive coverage.
3. Validate all metadata; reject unsafe paths/control characters and unknown modes. Enforce batch cap 1–1000, preferably 50–100. Compute deterministic manifest SHA-256; preserve TOKEN_VAZIO rather than substituting zero/false.
4. In one privileged transaction, insert a new scan receipt and its candidate entries. **Before** using \`ON CONFLICT DO NOTHING\`, check that any existing (repo ID, commit, path) binds to the same Git object SHA, type, mode, and size-known state; abort and record a discrepancy if not. Receipt observed/inserted counts must equal observed SQL outcome.
5. Read back scoped counts, check idempotence on replay, privacy grants, RLS, and old-table baselines. Emit append-only external receipt; do not auto-promote claims. Do not create self-triggering recursions.

## Deployment gate
- Only after independent review and an explicit approved rollout in the selected provider project.
- Run \`github_tree_catalog_v1.test.sql\` in a disposable database after applying the draft, or combine DDL + tests in a single explicit transaction ending ROLLBACK.
- Negative tests: cross-repository receipt binding, conflicting object at same commit/path, unsafe path, claim escalation, UPDATE/DELETE/TRUNCATE, anon/auth grants, and RLS.
- Before promotion: check security/performance advisors, lock/statement timeouts, performance plan, backup/restore, and client REST negatives.
- Rollback while draft: close PR without merge. Live append-only records are never silently deleted; schema rollback requires a separate reviewed maintenance/backup plan.

## Claim gate
\`SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM\`.
\`IMPLEMENTED_UNTESTED != PASS\`.
\`claim_allowed=false\` for global completion, independent provenance, authenticated runner, Android device, or end-to-end automation until separately evidenced.
