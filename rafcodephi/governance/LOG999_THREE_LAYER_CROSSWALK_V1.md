# LOG999 Ω — Three-layer projection (research candidate / HOLD)

**State:** SOURCE_BOUND_DERIVED_CANDIDATE; PG15_NOT_RUN; PROVIDER_NOT_RUN; claim_allowed=false.
Scoped to RAFCODE-Φ fork of `supabase/supabase` (Apache-2.0). This PR is neither database execution nor upstream authorship.

## Source versus experimental extension

The original [RafPolimata mathematical research fixture](https://github.com/rafaelmeloreisnovo/RafPolimata/blob/main/docs/COGNITIVE_SPIRAL_CUBE_10X10X10_V1.md) includes a finite 10×10×10 grid (0..999), three vector arms separated by 120°, the example `999/936=111/104`, `L(x)=ln(ln(x))` for real `x>1`, arm weights `(sqrt(pi)/5,sqrt(pi)/12,sqrt(5)/9)`, and a decreasing Fibonacci-dependent radius. A RAFAELIA Drive atlas independently documents outward inverse scaling `(2/sqrt(3))^n`.

The **new composition** is `n=0..42, a=0,1,2; r_n=999*(2/sqrt(3))^n; L_n=ln(ln(r_n/936)); theta(n,a)=n*pi/6+2*pi*a/3`. It is **not** the original discrete Fibonacci recurrence. Radius growth does not expand a stored cube or produce 42 proved attractors. The number 42 is only a fixture bound.

## Reuse existing private SQL candidate — no redundant tables

The fork already has an *unexecuted* candidate at [data federation draft](./sql/rafaelia_federated_data_schema.v1.DRAFT.sql). Reuse its three physical table proposals as **semantic** overlays rather than proposing duplicates:

| arm | semantic layer | existing physical DRAFT table | primary key | gap |
|---|---|---|---|---|
| 0 | identity | `raf_private.source_registry` | `source_id` | no verified row-to-spiral-step binding |
| 1 | relations | `raf_private.lineage_edges` | `edge_id` | source-target binding must be read from actual FKs |
| 2 | evidence | `raf_private.evidence_events` | `event_id` | event-to-`edge_id` FK absent: TOKEN_VAZIO |

The existing `raf_private.publication_reviews` is a fourth **governance gate**, not a fourth arm. Mathematical arms are not claims about the identity of historic Supabase tables. The [adjacent SQL draft](./sql/log999_three_layer_projection.v1.DRAFT.sql) is **read-only** and synthetically generates 129 rows with `generate_series`; it does not read, create, expose or modify provider tables.

## Gates, rights and rollback

This is a **public** repository. No private Drive content, archive payload, token, service key, provider project identifier or personal data is committed. Preserve original authorship and upstream license. Do not place this candidate under `supabase/migrations`; no provider has been selected or restored.

Local arithmetic/static checks: 129 candidate points; seed ratio 999/936; exact `n=2` radius 1332; monotone radial growth; real loglog domain and inverse; 120° separation. This does not establish PostgreSQL execution, RLS safety, query performance, security certification or authorized lineage.

Before promotion: PG15 isolated runtime; separate `anon`, `authenticated`, owner and service-role negative tests; explicit row-to-step mapping; source-rights/privacy review; snapshot/rollback; CI from the exact head; independent authorization. Until then: `claim_allowed=false`.

Rollback: close the unmerged draft PR; no provider DB undo is needed, since no provider write was performed.

## Related reading (context only, not a derivation or test)

- [Relational Database Data Lineage Ontology](https://www.alphaxiv.org/abs/2605.16068): typed semantic lineage for missing dependencies.
- [Aligning Provenance with Authorization](https://www.alphaxiv.org/abs/2605.26497): authorization graph distinct from execution provenance.
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security): grants and row-level controls are separate deployment gates.

R3 = <F_ok: bounded non-mutating projection draft; F_gap: actual PG15/RLS/authority/edge receipts; F_next: isolated sandbox tests>.
