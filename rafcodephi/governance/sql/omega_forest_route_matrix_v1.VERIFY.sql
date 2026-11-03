-- RAFAELIA Ω | read-only provider gate for a private, previously deployed view.
-- NOT a migration; no DDL/DML, no data materialization, no public identifiers or samples.
-- Expected: each row pass=true. Any failure -> HOLD; never promote claim_allowed.
WITH
  map_source AS (
    SELECT count(*)::bigint AS n
    FROM raf_private.mapa_cross_source_edges_v1 AS e
    JOIN raf_private.mapa_driver_projection_v1 AS a
      ON a.source_blob_sha=e.source_blob_sha AND a.record_id=e.source_record_id
    JOIN raf_private.mapa_driver_projection_v1 AS b
      ON b.source_blob_sha=e.source_blob_sha AND b.record_id=e.target_record_id
  ),
  omega_source AS (
    SELECT count(*)::bigint AS n FROM raf_private.omega_semantic_edges_v1
  ),
  route_summary AS (
    SELECT count(*)::bigint AS total,
           count(DISTINCT route_key)::bigint AS unique_routes,
           count(*) FILTER (WHERE forest='mapa')::bigint AS from_map,
           count(*) FILTER (WHERE forest='omega_semantic')::bigint AS from_omega,
           count(*) FILTER (WHERE route_key IS NULL OR source_node IS NULL OR target_node IS NULL)::bigint AS null_endpoints,
           count(*) FILTER (WHERE claim_allowed IS DISTINCT FROM false)::bigint AS promoted,
           count(*) FILTER (
             WHERE mathematical_antiderivative_state NOT LIKE 'TOKEN_VAZIO%'
                OR polynomial_state NOT LIKE 'TOKEN_VAZIO%'
           )::bigint AS invented_formula,
           count(*) FILTER (
             WHERE (predicate='DERIVES_FROM') IS DISTINCT FROM
               (reverse_provenance_state='PROVENANCE_BACKTRACE_AS_DECLARED_NOT_MATH')
           )::bigint AS derivation_mismatch
    FROM raf_private.omega_forest_route_matrix_v1
  ),
  safety AS (
    SELECT
      (SELECT coalesce('security_invoker=true'=ANY(c.reloptions),false)
         FROM pg_class AS c JOIN pg_namespace AS n ON n.oid=c.relnamespace
         WHERE n.nspname='raf_private' AND c.relname='omega_forest_route_matrix_v1') AS invoker,
      NOT has_table_privilege('anon','raf_private.omega_forest_route_matrix_v1','SELECT') AS anon_denied,
      NOT has_table_privilege('authenticated','raf_private.omega_forest_route_matrix_v1','SELECT') AS authenticated_denied,
      NOT has_schema_privilege('anon','raf_private','USAGE') AS anon_schema_denied,
      NOT has_schema_privilege('authenticated','raf_private','USAGE') AS authenticated_schema_denied,
      (SELECT count(*)=3 AND bool_and(c.relrowsecurity AND c.relforcerowsecurity)
       FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
       WHERE n.nspname='raf_private'
         AND c.relname IN ('mapa_cross_source_edges_v1','mapa_driver_projection_v1','omega_semantic_edges_v1')
      ) AS sources_force_rls
  )
SELECT check_name, expected, observed, passed
FROM map_source AS m CROSS JOIN omega_source AS o
CROSS JOIN route_summary AS r CROSS JOIN safety AS s
CROSS JOIN LATERAL (
  VALUES
    ('source_map_join',m.n::text,r.from_map::text,r.from_map=m.n),
    ('source_omega',o.n::text,r.from_omega::text,r.from_omega=o.n),
    ('source_total',(m.n+o.n)::text,r.total::text,r.total=m.n+o.n),
    ('distinct_route_keys',r.total::text,r.unique_routes::text,r.unique_routes=r.total),
    ('non_null_endpoints','0',r.null_endpoints::text,r.null_endpoints=0),
    ('no_claim_promotion','0',r.promoted::text,r.promoted=0),
    ('no_formula_invention','0',r.invented_formula::text,r.invented_formula=0),
    ('backtrace_not_math','0',r.derivation_mismatch::text,r.derivation_mismatch=0),
    ('security_invoker','true',coalesce(s.invoker,false)::text,s.invoker IS TRUE),
    ('anon_select_denied','true',s.anon_denied::text,s.anon_denied),
    ('authenticated_select_denied','true',s.authenticated_denied::text,s.authenticated_denied),
    ('anon_schema_denied','true',s.anon_schema_denied::text,s.anon_schema_denied),
    ('authenticated_schema_denied','true',s.authenticated_schema_denied::text,s.authenticated_schema_denied),
    ('source_force_rls','true',s.sources_force_rls::text,s.sources_force_rls)
) AS checks(check_name,expected,observed,passed)
ORDER BY check_name;
