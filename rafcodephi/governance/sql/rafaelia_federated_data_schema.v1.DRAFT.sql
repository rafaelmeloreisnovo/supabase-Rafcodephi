-- RAFAELIA Ω — SCHEMA CANDIDATE ONLY. DO NOT AUTO-APPLY.
-- Public fork: no private data, source URLs, credentials, project IDs, or secrets.
-- Approval, provider authority, cost, RLS negative tests and backup are missing.
-- This is NOT under supabase/migrations and is NOT deployed.
begin;

create schema if not exists raf_private;
revoke all on schema raf_private from public, anon, authenticated;

create table raf_private.source_registry (
  source_id uuid primary key,
  provider text not null check (provider in ('github','google_drive','supabase','other')),
  opaque_locator text not null,
  source_version text not null,
  content_sha256 text check (content_sha256 ~ '^[0-9a-f]{64}$'),
  original_owner text not null,
  declared_purpose text not null,
  legal_basis text,
  license_and_rights text not null,
  access_class text not null default 'UNCLASSIFIED'
    check (access_class in ('PUBLIC_APPROVED','INTERNAL','CONFIDENTIAL','RESTRICTED','CHILD_SAFEGUARD','UNCLASSIFIED')),
  retention_until timestamptz,
  observed_at timestamptz not null default now(),
  check (access_class not in ('RESTRICTED','CHILD_SAFEGUARD')
         or (legal_basis is not null and retention_until is not null)),
  unique(provider, opaque_locator, source_version)
);
create table raf_private.lineage_edges (
  edge_id uuid primary key,
  source_id uuid not null references raf_private.source_registry(source_id),
  target_id uuid not null references raf_private.source_registry(source_id),
  relation text not null
    check (relation in ('DERIVED_FROM','ATTESTS','SUPERSEDES','RELATED_TO','PUBLISHED_AS')),
  evidence_ref text not null,
  created_at timestamptz not null default now(),
  check (source_id <> target_id)
);
create table raf_private.evidence_events (
  event_id text primary key,
  parent_event_id text,
  source_id uuid references raf_private.source_registry(source_id),
  event_kind text not null,
  event_digest_sha256 text check (event_digest_sha256 ~ '^[0-9a-f]{64}$'),
  evidence_ref text not null,
  decision text not null,
  created_at timestamptz not null default now()
);
create table raf_private.publication_reviews (
  review_id uuid primary key,
  publication_id uuid not null,
  reviewer_identity_ref text not null,
  approver_identity_ref text not null,
  legal_and_rights_receipt text not null,
  sanitization_receipt text not null,
  privacy_risk_decision text not null check (privacy_risk_decision in ('APPROVE_PUBLIC','DENY','HOLD')),
  decided_at timestamptz not null default now(),
  check (reviewer_identity_ref <> approver_identity_ref)
);

alter table raf_private.source_registry enable row level security;
alter table raf_private.lineage_edges enable row level security;
alter table raf_private.evidence_events enable row level security;
alter table raf_private.publication_reviews enable row level security;
revoke all on all tables in schema raf_private from public, anon, authenticated;
-- Deliberately NO client policy and NO client grant on raf_private.
-- Publication service must verify private publication_reviews before mutation.
-- Database administrator / service key bypass limitations need separate controls.

create table public.rafaelia_map_releases (
  release_id uuid primary key,
  slug text not null unique check (length(slug) between 1 and 120),
  title text not null check (length(title) between 1 and 160),
  state text not null default 'staged' check (state in ('staged','published','revoked')),
  published_at timestamptz,
  check (state <> 'published' or published_at is not null)
);
create table public.rafaelia_map_nodes (
  release_id uuid not null references public.rafaelia_map_releases(release_id),
  node_key text not null check(length(node_key) between 1 and 120),
  kind text not null check(length(kind) between 1 and 80),
  title text not null check(length(title) between 1 and 160),
  summary text not null default '' check(length(summary) <= 500),
  primary key (release_id,node_key)
);
create table public.rafaelia_map_edges (
  release_id uuid not null,
  source_key text not null,
  target_key text not null,
  kind text not null check(length(kind) between 1 and 80),
  primary key (release_id,source_key,target_key,kind),
  foreign key (release_id,source_key)
    references public.rafaelia_map_nodes(release_id,node_key),
  foreign key (release_id,target_key)
    references public.rafaelia_map_nodes(release_id,node_key)
);
create table public.rafaelia_map_chart_points (
  point_id uuid primary key,
  release_id uuid not null,
  node_key text not null,
  series text not null check(length(series) between 1 and 80),
  x_label text not null check(length(x_label) <= 100),
  y_value numeric not null,
  foreign key (release_id,node_key)
    references public.rafaelia_map_nodes(release_id,node_key)
);

alter table public.rafaelia_map_releases enable row level security;
alter table public.rafaelia_map_nodes enable row level security;
alter table public.rafaelia_map_edges enable row level security;
alter table public.rafaelia_map_chart_points enable row level security;
revoke all on public.rafaelia_map_releases, public.rafaelia_map_nodes,
  public.rafaelia_map_edges, public.rafaelia_map_chart_points from public, anon, authenticated;
grant select on public.rafaelia_map_releases, public.rafaelia_map_nodes,
  public.rafaelia_map_edges, public.rafaelia_map_chart_points to anon, authenticated;

create policy rafaelia_map_releases_read on public.rafaelia_map_releases
  for select to anon, authenticated using (state = 'published');
create policy rafaelia_map_nodes_read on public.rafaelia_map_nodes
  for select to anon, authenticated using (
    exists (select 1 from public.rafaelia_map_releases r
      where r.release_id = rafaelia_map_nodes.release_id and r.state = 'published')
  );
create policy rafaelia_map_edges_read on public.rafaelia_map_edges
  for select to anon, authenticated using (
    exists (select 1 from public.rafaelia_map_releases r
      where r.release_id = rafaelia_map_edges.release_id and r.state = 'published')
  );
create policy rafaelia_map_chart_points_read on public.rafaelia_map_chart_points
  for select to anon, authenticated using (
    exists (select 1 from public.rafaelia_map_releases r
      where r.release_id = rafaelia_map_chart_points.release_id and r.state = 'published')
  );

-- Intentionally no INSERT/UPDATE/DELETE policies for public clients.
-- PostgreSQL privileges, role ownership, Data API settings, and provider
-- default grants must be independently inspected before any deployment.
-- This script does not create public views, functions, or storage policies.
commit;
