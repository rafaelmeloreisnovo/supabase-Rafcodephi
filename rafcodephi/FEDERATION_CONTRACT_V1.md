# RAFCODE-Φ — Federated Provenance Contract V1

**Status:** IMPLEMENTED_UNTESTED for live providers. This is a specification and JSON Schema on an unmerged GitHub draft PR. It is **not an active database**, deployed CI, research validation, or publication of a new scientific claim.

## Boundaries

GitHub is the code and CI authority; the repository is an upstream Supabase fork, and all existing Apache-2.0 and third-party notices remain in force. Google Drive is the authorized private longitudinal ledger/index; do **not** publish private Drive identifiers, private receipt content, credentials, keys or personal notes in this public fork. Supabase is a separate provider; two projects were listed INACTIVE on 2026-11-02, and neither has been authorized for a project-specific migration, restore, RLS change or chargeable branch. alphaXiv contains paper sources and optional private library membership; a paper or saved folder is neither runtime execution nor a claim of authorship.

## Machine contract and guarantees

The adjacent [JSON Schema](FEDERATED_RECEIPT_V1.schema.json) is draft 2020-12. Keep SOURCE, ARTIFACT, AUTHORITY, EXECUTION, EVIDENCE and CLAIM distinct. A verified locator names a provider, exact ref and visibility; unknowns use `{"state":"TOKEN_VAZIO","reason":"..."}`, never `null`, zero, missing fields, or synthetic IDs. **A known locator with unknown visibility must not be published.** The schema rejects execution `PASS` without an exact execution reference and rejects `claim.allowed=true` unless authority, execution PASS and evidence are verified. Syntactic validity is necessary but insufficient: semantic correctness, legal authorship and scientific validity require additional review.

Typed relations are `derived_from | observed_in | validated_by | supersedes | blocked_by | indexes`. The recipient must verify each edge and enforce uniqueness/deduplication by `mu_id + parent + source.ref`; JSON Schema cannot enforce ledger uniqueness. The receipt includes actionable gaps, next step and rollback, plus optional parent and relations. Preserve old records by append-only supersession rather than destructive overwrite.

## Known state on 2026-11-02

[GitHub PR #1](https://github.com/rafaelmeloreisnovo/supabase-Rafcodephi/pull/1) remained OPEN/DRAFT; starting head `fd2e3cd8ad3b03c15f5992e96c9d0f5e50dbafb8` showed a six-file documentation-only diff. GitHub check runs were 0; GitHub branch protection endpoint returned 403 (integration permission), whereas ruleset list returned empty. Accordingly enforcement is `TOKEN_VAZIO`, not a proven absence of protection. No Supabase SQL, database read, restore, migration, RLS change or deployment has been executed.

## Literature and prior-art boundary

External works read through alphaXiv, credited to their authors rather than RAFCODE-Φ:

- Auge et al. (2025), [workflow + data provenance, dimensions and granularity](https://www.alphaxiv.org/abs/2504.11278).
- Samuel et al. (2026), [ReproScore: repository readiness versus actual execution outcomes](https://www.alphaxiv.org/abs/2605.13275).
- Pellizzari di San Girolamo and Tosoni (2026), [linking code archives, papers, Software Heritage and Wikidata](https://www.alphaxiv.org/abs/2609.21667).

These motivate typed, auditable sources and separate static/operational checks. This fork has **not** implemented these papers' research systems. Saving a paper to alphaXiv does not prove an implementation or a novelty claim.

## Acceptance, evidence, rollback

Validate schema syntax, conservative positive and negative cases, exact GitHub readback and unchanged root LICENSE. Separate `PASS_SCOPED_LOCAL` from `CI_NOT_RUN` and `PROVIDER_NOT_RUN`. No auto-merge, live provider write or new CI workflow. Halt with `ROUTE_STATE=BLOCKED` and typed `TOKEN_VAZIO` when source, authority, target or evidence rule is missing. Rollback: close the unmerged draft, or revert this isolated documentation commit if merged. Record material deltas to authorized Drive shard with exact readback.

`SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM`

SPDX-License-Identifier: Apache-2.0
