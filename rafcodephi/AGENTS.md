# RAFCODE-Φ scoped AGENTS.md

Scope: `rafcodephi/**` only. **First honor [../AGENTS.md](../AGENTS.md) and its upstream skills; this file supplements it.**

## START HERE Ω V2.2 — bounded route

When performing authorized RAFAELIA work, follow `INTENT -> CURRENT_STATE -> μREAD(1-3 roots, depth 1) -> ROUTE -> SOURCE_MIN -> AUTHORITY -> ACT -> EVIDENCE -> μWRITE -> R3`. Read a current source before historical material; expand only for a missing source, contradictory evidence, unresolved authority, missing evidence or an explicit request. Private Drive instructions must not be copied into this public fork.

## Attribution and licensing

1. Assume inherited content is upstream or third-party until a path and commit prove otherwise. Neither repository namespace nor a generated text label proves authorship.
2. Keep `../LICENSE` unmodified, preserve existing copyright notices and per-file/third-party license requirements, and state modifications explicitly. Never apply a RAFCODE-Φ copyright notice to inherited lines as though they were newly authored.
3. For each original module or materially modified upstream file, record exact path, base SHA, change/ref, contributing author evidence, SPDX license, test, and upstream/derivative status in a bounded provenance record. If attribution is ambiguous, use `TOKEN_VAZIO` and block claims.
4. Respect trademarks and branding: this fork is not the official Supabase product.

## Source, execution and data safety

- No production or live database mutations, migrations, RLS changes, policy broadening, secrets, tokens or deployments from documentation-only instructions. Provider project ID, authority and test/rollback contract must be explicitly known before proposing a write.
- Keep `service_role`/secret keys server-side only. In exposed schemas, verify RLS and effective grants; avoid `SECURITY DEFINER` as a permission-error workaround. Never use user-editable metadata as an authorization basis.
- Do not rewrite upstream `AGENTS.md`, contributor credits, generated files, or third-party licenses to create artificial authorship. Avoid destructive history rewrites and unrelated root changes.
- For code, prefer direct source inspection, tests and observed runtime results over stale docs; use the most specific implementation language that fits the component. A freestanding prototype does not by itself replace an integrated TypeScript/Postgres runtime.

## Evidence and completion

`SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM`. Preserve the pre-change commit SHA. Prefer isolated branch + draft PR. Run static validation and CI, record exact head and check conclusions, and require review before merge. State `IMPLEMENTED_UNTESTED` when relevant; do not call it `PASS`. Record `R3 = <F_ok,F_gap,F_next>`; write append-only receipts only to authorized stores after material deltas and verification, never fabricate readback. No self-triggering autonomous workflow.
