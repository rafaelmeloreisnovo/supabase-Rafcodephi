-- RAFAELIA Ω / scoped driver-selector + L9 projection, source-only producer contract
-- Provider-private rows are seeded separately; no credential, private source ID, or raw data here.
-- DDL reviewed as append-only prototype; only privileged SQL caller can execute the function.
CREATE SCHEMA IF NOT EXISTS raf_private;
REVOKE ALL ON SCHEMA raf_private FROM PUBLIC,anon,authenticated;
CREATE TABLE raf_private.mapa_driver_catalog_v1(
 driver_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 driver_key text NOT NULL CHECK (driver_key ~ '^[a-z][a-z0-9_]{2,63}$'),
 driver_version integer NOT NULL DEFAULT 1 CHECK (driver_version>=1),
 adapter text NOT NULL CHECK (adapter IN ('GITHUB_JSONL_MIRROR','GOOGLE_DRIVE_METADATA','SUPABASE_METADATA','GEOLM_Q16')),
 readiness text NOT NULL CHECK (readiness IN ('READY_SCOPED','BLOCKED_AUTH','BLOCKED_REVIEW','BLOCKED_NO_GEOMETRY')),
 source_ref text NOT NULL CHECK (length(source_ref) BETWEEN 4 AND 500),
 source_blob_sha text CHECK (source_blob_sha ~ '^[0-9a-f]{40}$'),
 previous_driver_pk uuid REFERENCES raf_private.mapa_driver_catalog_v1(driver_pk),
 created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 UNIQUE(driver_key,driver_version),
 CHECK ((readiness='READY_SCOPED')=(source_blob_sha IS NOT NULL))
);
CREATE TABLE raf_private.mapa_driver_projection_v1(
 projection_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 driver_pk uuid NOT NULL REFERENCES raf_private.mapa_driver_catalog_v1(driver_pk),
 source_blob_sha text NOT NULL,
 record_id text NOT NULL,
 dim_l9 jsonb NOT NULL CHECK(jsonb_typeof(dim_l9)='object'),
 source_provider text NOT NULL,
 node_type text NOT NULL,
 epistemic_state text,
 sensitivity text NOT NULL CHECK(sensitivity IN ('PRIVATE','PUBLIC')),
 inbound_degree integer NOT NULL CHECK(inbound_degree>=0),
 outbound_degree integer NOT NULL CHECK(outbound_degree>=0),
 latitude double precision,
 longitude double precision,
 geometry_state text NOT NULL DEFAULT 'TOKEN_VAZIO_NO_COORDINATES' CHECK(geometry_state='TOKEN_VAZIO_NO_COORDINATES'),
 created_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 UNIQUE(driver_pk,source_blob_sha,record_id),
 FOREIGN KEY(source_blob_sha,record_id) REFERENCES raf_private.mapa_cross_source_registry_v1(source_blob_sha,record_id) ON DELETE RESTRICT,
 CHECK(latitude IS NULL AND longitude IS NULL)
);
CREATE TABLE raf_private.mapa_driver_run_receipts_v1(
 run_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 driver_pk uuid NOT NULL REFERENCES raf_private.mapa_driver_catalog_v1(driver_pk),
 source_blob_sha text NOT NULL CHECK(source_blob_sha ~ '^[0-9a-f]{40}$'),
 result text NOT NULL CHECK(result IN ('PASS_SCOPED')),
 inserted_rows integer NOT NULL CHECK(inserted_rows>=0),
 total_rows integer NOT NULL CHECK(total_rows>=0),
 materialized_edges integer NOT NULL CHECK(materialized_edges>=0),
 executed_at timestamptz NOT NULL DEFAULT transaction_timestamp(),
 claim_allowed boolean NOT NULL DEFAULT false CHECK(claim_allowed=false),
 execution_evidence text NOT NULL DEFAULT 'SUPABASE_SQL_TRANSACTION' CHECK(execution_evidence='SUPABASE_SQL_TRANSACTION')
);
ALTER TABLE raf_private.mapa_driver_catalog_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.mapa_driver_catalog_v1 FORCE ROW LEVEL SECURITY;
ALTER TABLE raf_private.mapa_driver_projection_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.mapa_driver_projection_v1 FORCE ROW LEVEL SECURITY;
ALTER TABLE raf_private.mapa_driver_run_receipts_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.mapa_driver_run_receipts_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE raf_private.mapa_driver_catalog_v1,raf_private.mapa_driver_projection_v1,raf_private.mapa_driver_run_receipts_v1 FROM PUBLIC,anon,authenticated;
CREATE FUNCTION raf_private.reject_mapa_driver_mutation_v1() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $fn$
BEGIN RAISE EXCEPTION 'append-only driver map: updates/deletes prohibited'; END; $fn$;
REVOKE ALL ON FUNCTION raf_private.reject_mapa_driver_mutation_v1() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER map_driver_catalog_immutable BEFORE UPDATE OR DELETE ON raf_private.mapa_driver_catalog_v1 FOR EACH ROW EXECUTE FUNCTION raf_private.reject_mapa_driver_mutation_v1();
CREATE TRIGGER map_driver_projection_immutable BEFORE UPDATE OR DELETE ON raf_private.mapa_driver_projection_v1 FOR EACH ROW EXECUTE FUNCTION raf_private.reject_mapa_driver_mutation_v1();
CREATE TRIGGER map_driver_run_immutable BEFORE UPDATE OR DELETE ON raf_private.mapa_driver_run_receipts_v1 FOR EACH ROW EXECUTE FUNCTION raf_private.reject_mapa_driver_mutation_v1();
CREATE FUNCTION raf_private.populate_mapa_driver_v1(p_driver_key text,p_expected_blob_sha text)
RETURNS TABLE(run_pk uuid,newly_inserted integer,total_nodes integer,materialized_edges integer,result text)
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,raf_private AS $fn$
DECLARE d raf_private.mapa_driver_catalog_v1%ROWTYPE;
 added integer; total integer; edges_n integer; expected_n integer; rid uuid;
BEGIN
 SELECT * INTO d FROM raf_private.mapa_driver_catalog_v1 WHERE driver_key=p_driver_key ORDER BY driver_version DESC LIMIT 1;
 IF NOT FOUND OR d.readiness <> 'READY_SCOPED' THEN RAISE EXCEPTION 'DRIVER_NOT_READY_OR_UNKNOWN'; END IF;
 IF p_expected_blob_sha IS DISTINCT FROM d.source_blob_sha THEN RAISE EXCEPTION 'SOURCE_BLOB_MISMATCH'; END IF;
 SELECT count(*) INTO expected_n FROM raf_private.mapa_cross_source_registry_v1 WHERE source_blob_sha=p_expected_blob_sha;
 IF expected_n=0 THEN RAISE EXCEPTION 'MISSING_PROVIDER_SOURCE_ROWS'; END IF;
 INSERT INTO raf_private.mapa_driver_projection_v1
  (driver_pk,source_blob_sha,record_id,dim_l9,source_provider,node_type,epistemic_state,sensitivity,inbound_degree,outbound_degree)
 SELECT d.driver_pk,r.source_blob_sha,r.record_id,
  jsonb_build_object(
    'L',r.record_doc #> '{source,observed_at}',
    'O',r.record_doc #> '{classification,domain}',
    'T',r.record_doc #> '{source,provider}',
    'P',jsonb_build_object('source_blob_sha',r.source_blob_sha,'source_record_commit',r.record_doc #>> '{version,commit_sha}'),
    'C',r.record_doc -> 'node_type',
    'R',jsonb_build_object('inbound',(SELECT count(*) FROM raf_private.mapa_cross_source_edges_v1 e WHERE e.source_blob_sha=r.source_blob_sha AND e.target_record_id=r.record_id),
                          'outbound',(SELECT count(*) FROM raf_private.mapa_cross_source_edges_v1 e WHERE e.source_blob_sha=r.source_blob_sha AND e.source_record_id=r.record_id)),
    'I',to_jsonb(r.record_id),
    'E',to_jsonb(jsonb_array_length(r.record_doc->'evidence_refs')),
    'A',r.record_doc -> 'next_verifiable_step'
  ),
  r.record_doc #>> '{source,provider}',
  r.record_doc ->> 'node_type',
  r.record_doc #>> '{classification,epistemic_state}',
  r.record_doc #>> '{classification,sensitivity}',
  (SELECT count(*)::int FROM raf_private.mapa_cross_source_edges_v1 e WHERE e.source_blob_sha=r.source_blob_sha AND e.target_record_id=r.record_id),
  (SELECT count(*)::int FROM raf_private.mapa_cross_source_edges_v1 e WHERE e.source_blob_sha=r.source_blob_sha AND e.source_record_id=r.record_id)
 FROM raf_private.mapa_cross_source_registry_v1 r WHERE r.source_blob_sha=p_expected_blob_sha
 ON CONFLICT(driver_pk,source_blob_sha,record_id) DO NOTHING;
 GET DIAGNOSTICS added=ROW_COUNT;
 SELECT count(*) INTO total FROM raf_private.mapa_driver_projection_v1 WHERE driver_pk=d.driver_pk AND source_blob_sha=p_expected_blob_sha;
 SELECT count(*) INTO edges_n FROM raf_private.mapa_cross_source_edges_v1 WHERE source_blob_sha=p_expected_blob_sha;
 IF total <> expected_n OR
    (SELECT coalesce(sum(outbound_degree),0) FROM raf_private.mapa_driver_projection_v1 WHERE driver_pk=d.driver_pk AND source_blob_sha=p_expected_blob_sha) <> edges_n
 THEN RAISE EXCEPTION 'PROJECTION_PARITY_FAILED'; END IF;
 INSERT INTO raf_private.mapa_driver_run_receipts_v1(driver_pk,source_blob_sha,result,inserted_rows,total_rows,materialized_edges)
 VALUES(d.driver_pk,p_expected_blob_sha,'PASS_SCOPED',added,total,edges_n) RETURNING mapa_driver_run_receipts_v1.run_pk INTO rid;
 RETURN QUERY SELECT rid,added,total,edges_n,'PASS_SCOPED'::text;
END; $fn$;
REVOKE ALL ON FUNCTION raf_private.populate_mapa_driver_v1(text,text) FROM PUBLIC,anon,authenticated;
