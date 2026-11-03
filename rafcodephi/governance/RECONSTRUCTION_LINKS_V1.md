# Private reconstruction links

This additive index connects a Drive metadata observation to a pinned GitHub source and, when available, a provider workflow run. It lets an authorized operator recover the document, source revision, test result, remaining gaps, and next validation step without copying the source corpus into Postgres.

## Read a chain

Run through an authorized database connection:

```sql
select * from raf_private.search_reconstruction_v1('Vectra', 20);
select * from raf_private.search_reconstruction_v1('Termux', 20);
select * from raf_private.search_reconstruction_v1('RAFCODE', 20);
```

Search is literal, case-insensitive, and limited to 1–100 results. A matching document alone is not content equivalence or execution proof. The pre-existing `search_drive_metadata_v1` remains the file lookup entry point.

## Evidence contract

| State | What it records |
| --- | --- |
| SOURCE_VERIFIED | The named GitHub path was read at the recorded commit and blob. |
| CI_SUCCESS_SCOPED | The provider reports a successful run with observed steps, associated with the recorded head. |
| CI_NO_STEPS | The provider reports failure without observed steps. It is not a failed test verdict. |
| DEVICE_FAILURE_REPORTED | A documentary device failure report, without recertifying the original device evidence. |

`checkout_binding` distinguishes a workflow that explicitly selects the PR head from an unresolved default PR checkout. A workflow can succeed by verifying that a negative snapshot remains accurate; read `source_statement` and `remaining_gaps`, not just the provider conclusion.

All rows keep `device_runtime_verified=false` and `claim_allowed=false`. Device evidence requires a separately reviewed contract. Hashes of connector text do not establish binary-file identity.

## Files and access

- [Schema and bounded query](sql/reconstruction_links_v1.sql).
- [Transactional negative tests](sql/reconstruction_links_v1.test.sql).

The existing private metadata table is reused. Two additive tables store search receipts and typed reconstruction links. They use forced RLS and deny PUBLIC, anon, and authenticated access. The read function is SECURITY INVOKER with a fixed empty search path. No public RPC, client credential, autonomous worker, or new workflow is introduced.

Apply the schema once through a reviewed migration. Populate real metadata only after reading the provider. Insert a batch receipt and its source-bound links transactionally. Replay must insert no duplicate observations; never update a historical row. Search-seeded metadata may use its own file ID as the scope root; this does not assert full ancestry. The parent ID remains the provider-observed parent.

Keep search filters, cursor exhaustion, MIME scope, manifest digest, and baseline in the private batch record. Exhausting a filtered search does not establish whole-Drive coverage or an atomic snapshot.

## Validation and rollback

The test file uses an existing private link only as a transactional fixture, checks 17 cases, and rolls back. It rejects unsupported physical claims, mismatched or null run heads, success without steps, missing source references, mutations, unsafe limits, and client reads. Run through a role authorized to perform these tests. It leaves no test rows.

For a correction, insert a successor with `supersedes_link_key`; the read function marks superseded observations. For an operational rollback, stop using the additive query and return to the pre-existing metadata query. Preserve the source records, batch receipts, and predecessor schema. Do not automatically drop tables or remove evidence.

## Provenance

- Producer: this repository; new files under `rafcodephi/governance/`.
- Base commit: `fcf759af37f8a4a5a4ac63bdb595811e0ff1532b`.
- Change: `feat/private-reconstruction-links-20261103`; exact commit and blob references belong in the private execution receipt.
- Origin: newly authored reconstruction schema, SQL tests, and documentation; not a claim to the upstream Supabase implementation.
- Contribution attribution: Git commit metadata records the writing actor; user direction and private data provenance remain in the private receipt.
- License: Apache-2.0, following the repository license; upstream notices remain unchanged.
- Runtime boundary: hosted PostgreSQL orchestration, not a freestanding device kernel.
