# RAFAELIA — security and data quality acceptance gates

Status: SPECIFIED, NOT_RUN. No database project selected; two connected provider projects were inactive at observation.

## Data access matrix

| Case | Expected outcome |
| --- | --- |
| Anonymous request to private registry | DENY |
| Authenticated user without ownership to private registry | DENY |
| Anonymous request to unapproved map release | NO ROWS |
| Anonymous request to published, independently approved map release | SELECT sanitized fields only |
| Unauthenticated INSERT, UPDATE or DELETE on map data | DENY |
| Authenticated attempt at unauthorized update | DENY |
| Revoked release and stale cache | NO ACCESS after tested invalidation |
| Private bucket, service-role key, unexpected exposed view | DENY and incident |
| Records concerning minors or identifiable persons in public labels and charts | BLOCK PUBLICATION |
| Small-cell statistics, linkage or geolocation reidentification | BLOCK until privacy review |
| Public publication without two independent approvals | BLOCK |
| Missing copyright, source rights, lawful basis, retention or proof of consent when required | BLOCK |
| Backup failure or provider-cost authorization missing | STOP |

## DMAIC evidence

DEFINE: target dataset, lawful purpose, exact owner, failure mode.
MEASURE: coverage of revisions, content hashes, classifications and defects.
ANALYZE: threat model, reidentification, privacy and upstream rights.
IMPROVE: isolated schema, private data storage, curated public graph and restricted API.
CONTROL: reproducible fixtures for anonymous and authenticated roles, security advisor results, rollback, audit receipt and independent reviewer.

Before deployment, inspect current Supabase grants, row-level security, exposed schemas, views, Storage policies, default privileges and secrets. Do not infer them from documentation. Record exact test input, expected outcome, observed provider result and revision. Skipped is not PASS. Never assert ISO certification or statistical Six Sigma capability without relevant evidence.

The public codebase may contain this specification, but not personal records, credentials, child identifiers, private documents or unpublished allegations.
