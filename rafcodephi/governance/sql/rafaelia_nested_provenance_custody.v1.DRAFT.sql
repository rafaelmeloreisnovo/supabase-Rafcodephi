-- RAFAELIA Ω — NESTED PROVENANCE AND CUSTODY CANDIDATE V1
-- SOURCE-ONLY DESIGN. DO NOT APPLY TO A PROVIDER PROJECT.
-- Public fork: no private URLs, project IDs, credentials, raw documents, or personal data.
-- Authority gates still required: target project, backup/restore, rights, RLS tests, reviewer, exact-head CI.
-- SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM.

begin;

create schema if not exists raf_private;
revoke all on schema raf_private from public, anon, authenticated;

-- One immutable identity row per logical project/container.
-- Mutable names, timestamps and source observations belong to custody_events.
create table raf_private.project_registry (
  project_id uuid primary key,
  project_key text not null unique check (length(project_key) between 1 and 240),
  project_kind text not null check (length(project_kind) between 1 and 80),
  display_name text not null check (length(display_name) between 1 and 240),
  source_provider text not null check (
    source_provider in ('github','google_drive','supabase','alphaxiv','local','other')
  ),
  source_locator text not null,
  source_revision text,
  source_created_at timestamptz,
  source_updated_at timestamptz,
  source_timezone text,
  first_observed_at timestamptz not null,
  recorded_at timestamptz not null default clock_timestamp(),
  content_sha256 text check (content_sha256 ~ '^[0-9a-f]{64}$'),
  access_class text not null default 'UNCLASSIFIED' check (
    access_class in (
      'PUBLIC_APPROVED','INTERNAL','CONFIDENTIAL','RESTRICTED',
      'CHILD_SAFEGUARD','UNCLASSIFIED'
    )
  ),
  missing_reason text,
  check (
    source_created_at is null
    or source_updated_at is null
    or source_created_at <= source_updated_at
  )
);

-- Every observed change is a new event. No UPDATE/DELETE is allowed by the
-- database trigger below; corrections use supersedes_event_id.
create table raf_private.custody_events (
  event_id uuid primary key,
  event_seq bigint generated always as identity unique,
  project_id uuid not null references raf_private.project_registry(project_id),
  parent_event_id uuid,
  supersedes_event_id uuid,
  related_project_id uuid references raf_private.project_registry(project_id),
  event_kind text not null check (
    event_kind in (
      'DISCOVERED','INGESTED_METADATA','RENAMED','RELOCATED',
      'SNAPSHOT_OBSERVED','DERIVED','SUPERSEDED','REVIEWED',
      'PUBLISHED','REVOKED','CORRECTED','GAP_RECORDED'
    )
  ),
  source_provider text not null check (
    source_provider in ('github','google_drive','supabase','alphaxiv','local','other')
  ),
  source_locator text not null,
  source_revision text,
  source_commit_sha text,
  source_name text,
  source_created_at timestamptz,
  source_updated_at timestamptz,
  source_timezone text,
  occurred_at timestamptz,
  observed_at timestamptz not null,
  recorded_at timestamptz not null default clock_timestamp(),
  evidence_ref text not null,
  content_sha256 text check (content_sha256 ~ '^[0-9a-f]{64}$'),
  previous_event_hash_sha256 text check (
    previous_event_hash_sha256 is null
    or previous_event_hash_sha256 ~ '^[0-9a-f]{64}$'
  ),
  event_hash_sha256 text check (event_hash_sha256 ~ '^[0-9a-f]{64}$'),
  missing_reason text,
  notes text,
  unique (project_id, event_id),
  foreign key (project_id, parent_event_id)
    references raf_private.custody_events(project_id, event_id),
  foreign key (project_id, supersedes_event_id)
    references raf_private.custody_events(project_id, event_id),
  check (
    source_created_at is null
    or source_updated_at is null
    or source_created_at <= source_updated_at
  ),
  check (parent_event_id is null or parent_event_id <> event_id),
  check (supersedes_event_id is null or supersedes_event_id <> event_id)
);

-- A project can be nested in another project without overwriting its older
-- parent. A new edge records a new observed relationship.
create table raf_private.project_edges (
  edge_id uuid primary key,
  event_id uuid not null references raf_private.custody_events(event_id),
  parent_project_id uuid not null references raf_private.project_registry(project_id),
  child_project_id uuid not null references raf_private.project_registry(project_id),
  relation text not null check (relation in ('CONTAINS','DERIVED_FROM','RELATED_TO')),
  effective_from timestamptz,
  effective_to timestamptz,
  observed_at timestamptz not null,
  recorded_at timestamptz not null default clock_timestamp(),
  evidence_ref text not null,
  previous_edge_id uuid references raf_private.project_edges(edge_id),
  check (parent_project_id <> child_project_id),
  check (effective_from is null or effective_to is null or effective_from <= effective_to),
  unique (event_id, parent_project_id, child_project_id, relation)
);

alter table raf_private.project_registry enable row level security;
alter table raf_private.custody_events enable row level security;
alter table raf_private.project_edges enable row level security;
revoke all on all tables in schema raf_private from public, anon, authenticated;

create or replace function raf_private.reject_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append_only_violation: % on %', TG_OP, TG_TABLE_NAME;
end;
$$;

create trigger project_registry_append_only
before update or delete on raf_private.project_registry
for each row execute function raf_private.reject_mutation();

create trigger custody_events_append_only
before update or delete on raf_private.custody_events
for each row execute function raf_private.reject_mutation();

create trigger project_edges_append_only
before update or delete on raf_private.project_edges
for each row execute function raf_private.reject_mutation();

create or replace function raf_private.reject_project_cycle()
returns trigger
language plpgsql
as $$
declare
  cycle_found boolean;
begin
  if NEW.relation = 'CONTAINS' then
    if NEW.parent_project_id = NEW.child_project_id then
      raise exception 'cycle_rejected: project cannot contain itself';
    end if;

    with recursive ancestors(project_id) as (
      select NEW.parent_project_id
      union
      select e.parent_project_id
      from raf_private.project_edges e
      join ancestors a on a.project_id = e.child_project_id
      where e.relation = 'CONTAINS'
    )
    select exists (
      select 1 from ancestors where project_id = NEW.child_project_id
    ) into cycle_found;

    if cycle_found then
      raise exception 'cycle_rejected: CONTAINS edge would close an existing ancestry loop';
    end if;
  end if;
  return NEW;
end;
$$;

create or replace function raf_private.reject_edge_event_mismatch()
returns trigger
language plpgsql
as $$
declare
  event_project uuid;
  event_related uuid;
begin
  if NEW.relation = 'CONTAINS' then
    select e.project_id, e.related_project_id
      into event_project, event_related
      from raf_private.custody_events e
     where e.event_id = NEW.event_id;

    if event_project is distinct from NEW.child_project_id
       or event_related is distinct from NEW.parent_project_id then
      raise exception 'provenance_edge_rejected: event must identify child project and related parent';
    end if;
  end if;
  return NEW;
end;
$$;

create trigger project_edges_event_alignment
before insert on raf_private.project_edges
for each row execute function raf_private.reject_edge_event_mismatch();

create trigger project_edges_no_cycle
before insert on raf_private.project_edges
for each row execute function raf_private.reject_project_cycle();

-- Recursive reconstruction of all recorded CONTAINS ancestry.
-- The path is bounded by the cycle guard and remains historical because edges
-- are never updated or deleted.
create view raf_private.project_ancestry
with (security_invoker = true)
as
with recursive ancestry(
  child_project_id,
  ancestor_project_id,
  depth,
  project_path,
  edge_id,
  observed_at,
  evidence_ref
) as (
  select
    e.child_project_id,
    e.parent_project_id,
    1,
    array[e.child_project_id, e.parent_project_id]::uuid[],
    e.edge_id,
    e.observed_at,
    e.evidence_ref
  from raf_private.project_edges e
  where e.relation = 'CONTAINS'

  union all

  select
    a.child_project_id,
    e.parent_project_id,
    a.depth + 1,
    a.project_path || e.parent_project_id,
    e.edge_id,
    e.observed_at,
    e.evidence_ref
  from ancestry a
  join raf_private.project_edges e
    on e.child_project_id = a.ancestor_project_id
   and e.relation = 'CONTAINS'
  where not (e.parent_project_id = any(a.project_path))
)
select
  a.child_project_id,
  a.ancestor_project_id,
  a.depth,
  a.project_path,
  a.edge_id,
  a.observed_at,
  a.evidence_ref,
  child.display_name as child_name,
  ancestor.display_name as ancestor_name
from ancestry a
join raf_private.project_registry child
  on child.project_id = a.child_project_id
join raf_private.project_registry ancestor
  on ancestor.project_id = a.ancestor_project_id;

comment on schema raf_private is
  'Private append-only provenance graph. Keep originals at their authoritative source.';
comment on table raf_private.project_registry is
  'Immutable logical project identity; historical names and timestamps are custody events.';
comment on table raf_private.custody_events is
  'Append-only source observations with names, timestamps, revisions, hashes and evidence refs.';
comment on table raf_private.project_edges is
  'Historical typed relationships; CONTAINS edges reconstruct nested project ancestry.';
comment on view raf_private.project_ancestry is
  'Recursive read model for reconstructing project containment without erasing prior edges.';

commit;
