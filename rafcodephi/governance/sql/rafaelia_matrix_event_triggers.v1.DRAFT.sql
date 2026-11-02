-- RAFAELIA Ω: EVENT/TRIGGER PILOT V1 - PROPOSAL ONLY / NEVER AUTO-APPLY
-- SPDX-License-Identifier: Apache-2.0
-- Depends on rafcodephi/governance/sql/rafaelia_federated_data_schema.v1.DRAFT.sql.
-- NOT A MIGRATION. No live database write is authorized by this file.
-- No PII, child identifiers, raw documents, credentials, or IP addresses.
-- DDL and privileged routines require independent review and sandbox tests.

begin;

-- Administrative source/tenant binding: a valid foreign key does NOT by itself
-- prove that a source is authorized for the caller's domain.
-- No runtime/client access to this mapping is granted by this proposal.
create table raf_private.matrix_source_tenants (
  tenant_id uuid not null,
  source_id uuid not null references raf_private.source_registry(source_id),
  admitted_at timestamptz not null default clock_timestamp(),
  authority_ref text not null check (length(authority_ref) between 8 and 160),
  primary key (tenant_id, source_id)
);

create table raf_private.matrix_events (
  event_id uuid primary key,
  tenant_id uuid not null,
  stream_id uuid not null,
  sequence_no bigint not null check (sequence_no >= 1),
  predecessor_event_id uuid references raf_private.matrix_events(event_id),
  source_id uuid not null references raf_private.source_registry(source_id),
  target_source_id uuid references raf_private.source_registry(source_id),
  action text not null check (action in
    ('ADD_RELATION','SUPERSEDE','RESTRICT','ERASURE_REQUEST','ERASURE_RECORDED','ACCESS_REVIEW')),
  relation_type text check (relation_type in
    ('DERIVED_FROM','OBSERVED_IN','VALIDATED_BY','SUPERSEDES','BLOCKED_BY','INDEXES')),
  access_class text not null check (access_class in
    ('PUBLIC_APPROVED','INTERNAL','CONFIDENTIAL','RESTRICTED',
     'CHILD_SAFEGUARD','UNCLASSIFIED')),
  actor_hmac_sha256 text not null check (actor_hmac_sha256 ~ '^[0-9a-f]{64}$'),
  purpose_code text not null check (purpose_code ~ '^[a-z][a-z0-9_]{2,63}$'),
  policy_ref text not null check (length(policy_ref) between 3 and 160),
  legal_basis_ref text not null check (length(legal_basis_ref) between 3 and 160),
  request_ref text not null check (length(request_ref) between 8 and 160),
  evidence_sha256 text not null check (evidence_sha256 ~ '^[0-9a-f]{64}$'),
  registered_at timestamptz not null default clock_timestamp(),
  unique (tenant_id, stream_id, sequence_no),
  check (source_id is distinct from target_source_id),
  check ((action <> 'ADD_RELATION') or
         (target_source_id is not null and relation_type is not null))
);

create index matrix_events_source_idx
  on raf_private.matrix_events(tenant_id, source_id, registered_at desc);
create index matrix_events_target_idx
  on raf_private.matrix_events(tenant_id, target_source_id)
  where target_source_id is not null;

-- Transactional outbox: delivery is an independent, acknowledged operation.
-- Outbox state may be mutable; its parent event history is append-only.
create table raf_private.matrix_event_outbox (
  event_id uuid primary key references raf_private.matrix_events(event_id),
  enqueued_at timestamptz not null default clock_timestamp(),
  delivered_at timestamptz,
  delivery_attempts integer not null default 0 check (delivery_attempts >= 0)
);

-- Dedicated NOLOGIN role; no membership or external client credentials assigned.
do $role$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'raf_matrix_ingestor') then
    create role raf_matrix_ingestor nologin noinherit;
  end if;
end
$role$;

revoke all on raf_private.matrix_source_tenants,
  raf_private.matrix_events, raf_private.matrix_event_outbox
  from public, anon, authenticated;
revoke all on schema raf_private from public, anon, authenticated;

alter table raf_private.matrix_source_tenants enable row level security;
alter table raf_private.matrix_events enable row level security;
alter table raf_private.matrix_event_outbox enable row level security;

grant usage on schema raf_private to raf_matrix_ingestor;
grant insert on raf_private.matrix_events to raf_matrix_ingestor;
create policy matrix_ingestor_insert on raf_private.matrix_events
  for insert to raf_matrix_ingestor with check (true);
-- Absolutely no INSERT/SELECT/UPDATE/DELETE grants or RLS policies for
-- anon/authenticated; no direct outbox write grants to the ingestor.
-- Role membership and a trusted policy decision point must be separately reviewed.

create function raf_private.matrix_validate_before_insert()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
declare
  v_class text;
  v_last_event uuid;
  v_last_no bigint;
begin
  -- This function has privileged access only to validate ordered metadata.
  -- hashtextextended collisions only over-serialize; uniqueness enforces identity.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.tenant_id::text || ':' || new.stream_id::text, 0)
  );
  select s.access_class into v_class
    from raf_private.source_registry s
    join raf_private.matrix_source_tenants b on b.source_id = s.source_id
    where s.source_id = new.source_id and b.tenant_id = new.tenant_id;
  if not found or new.access_class is distinct from v_class then
    raise exception 'source classification missing or mismatched'
      using errcode = '23514';
  end if;

  -- A link to a child-safeguard or other protected source must never
  -- lower the target's classification (strict equality in this pilot).
  if new.target_source_id is not null and not exists (
    select 1 from raf_private.source_registry s
    join raf_private.matrix_source_tenants b on b.source_id = s.source_id
     where s.source_id = new.target_source_id and b.tenant_id = new.tenant_id
       and s.access_class = new.access_class
  ) then
    raise exception 'cross-classification link denied'
      using errcode = '23514';
  end if;

  select e.event_id, e.sequence_no into v_last_event, v_last_no
    from raf_private.matrix_events e
    where e.tenant_id = new.tenant_id and e.stream_id = new.stream_id
    order by e.sequence_no desc limit 1;
  if v_last_no is null then
    if new.sequence_no <> 1 or new.predecessor_event_id is not null then
      raise exception 'first event must be sequence 1 without predecessor'
        using errcode = '23514';
    end if;
  elsif new.sequence_no <> v_last_no + 1
        or new.predecessor_event_id is distinct from v_last_event then
    raise exception 'sequence/predecessor mismatch'
      using errcode = '23514';
  end if;

  -- Never trust caller-supplied timestamps as forensic time evidence.
  new.registered_at := pg_catalog.clock_timestamp();
  return new;
end;
$fn$;

create function raf_private.matrix_enqueue_after_insert()
returns trigger language plpgsql security definer set search_path = ''
as $fn$
begin
  insert into raf_private.matrix_event_outbox(event_id) values (new.event_id);
  return null;
end;
$fn$;

create function raf_private.matrix_append_only_guard()
returns trigger language plpgsql security invoker set search_path = ''
as $fn$
begin
  raise exception 'append-only event stream: mutation prohibited'
    using errcode = '55000';
end;
$fn$;

revoke all on function raf_private.matrix_validate_before_insert()
  from public, anon, authenticated;
revoke all on function raf_private.matrix_enqueue_after_insert()
  from public, anon, authenticated;
revoke all on function raf_private.matrix_append_only_guard()
  from public, anon, authenticated;

create trigger matrix_validate_event
  before insert on raf_private.matrix_events for each row
  execute function raf_private.matrix_validate_before_insert();

create trigger matrix_outbox_event
  after insert on raf_private.matrix_events for each row
  execute function raf_private.matrix_enqueue_after_insert();

create trigger matrix_no_update_delete
  before update or delete on raf_private.matrix_events for each row
  execute function raf_private.matrix_append_only_guard();

create trigger matrix_no_truncate
  before truncate on raf_private.matrix_events for each statement
  execute function raf_private.matrix_append_only_guard();

commit;

-- LIMITS: Database owners/BYPASSRLS roles can bypass RLS and disable triggers.
-- A hash field does NOT establish integrity by itself: externally re-hash,
-- sign/anchor bounded receipts in an independently controlled immutable store.
-- Ordinary triggers cannot audit SELECT, rolled-back attempts or DDL:
-- independently configure pgaudit, provider access logs and retention.
-- Erasure request/recorded events do not erase personal data: lawful erasure,
-- key destruction, backups and retention need a separate verified workflow.
