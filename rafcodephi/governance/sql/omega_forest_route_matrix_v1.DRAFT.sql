-- RAFAELIA Ω | SQL source snapshot from deployed Supabase migration 20261103080004.
-- REVIEW ONLY / existing deployed view: do not replay on production without checking drift.
-- Private security_invoker projection: no source duplication, no semantic claim promotion.
-- Source of truth: Supabase project ehwltgfrvbkmjqjjfoqn migration rafaelia_omega_forest_route_matrix_v1.
CREATE VIEW raf_private.omega_forest_route_matrix_v1 WITH (security_invoker = true) AS
 WITH forest AS (
         SELECT 'mapa'::text AS forest,
            (((('mapa:'::text || e.source_blob_sha) || ':'::text) || e.source_record_id) || ':'::text) || e.relation_ordinal::text AS route_key,
            e.source_record_id AS source_node,
            e.target_record_id AS target_node,
            e.predicate,
            e.relation_state AS evidence_state,
            e.source_blob_sha AS source_ref,
            e.evidence_id AS evidence_ref,
            e.weight_q16,
            NULLIF(a.dim_l9 ->> 'O'::text, ''::text) AS from_o,
            NULLIF(b.dim_l9 ->> 'O'::text, ''::text) AS to_o,
            NULLIF(a.dim_l9 ->> 'T'::text, ''::text) AS from_t,
            NULLIF(b.dim_l9 ->> 'T'::text, ''::text) AS to_t,
            NULLIF(a.dim_l9 ->> 'L'::text, ''::text) AS from_l,
            NULLIF(b.dim_l9 ->> 'L'::text, ''::text) AS to_l
           FROM raf_private.mapa_cross_source_edges_v1 e
             JOIN raf_private.mapa_driver_projection_v1 a ON a.source_blob_sha = e.source_blob_sha AND a.record_id = e.source_record_id
             JOIN raf_private.mapa_driver_projection_v1 b ON b.source_blob_sha = e.source_blob_sha AND b.record_id = e.target_record_id
        UNION ALL
         SELECT 'omega_semantic'::text AS text,
            'omega:'::text || s.relation_key,
            s.from_case_id,
            s.to_case_id,
            s.predicate,
            s.evidence_state,
            s.source_ref,
            s.relation_key,
            NULL::integer AS int4,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text,
            NULL::text AS text
           FROM raf_private.omega_semantic_edges_v1 s
        )
 SELECT forest,
    route_key,
    source_node,
    target_node,
    predicate,
    evidence_state,
    source_ref,
    evidence_ref,
    weight_q16,
        CASE
            WHEN from_o IS NOT NULL AND to_o IS NOT NULL AND from_o <> to_o THEN 'ORTHOGONAL_CATEGORY_CANDIDATE_NOT_CAUSAL'::text
            ELSE 'TOKEN_VAZIO_NO_DISTINCT_CATEGORY'::text
        END AS orthogonal_state,
        CASE
            WHEN from_t IS NOT NULL AND to_t IS NOT NULL AND from_t <> to_t THEN 'TRANSVERSAL_PROVIDER_CANDIDATE_NOT_CAUSAL'::text
            ELSE 'TOKEN_VAZIO_NO_DISTINCT_PROVIDER'::text
        END AS transversal_state,
        CASE
            WHEN from_l IS NOT NULL AND to_l IS NOT NULL AND from_l <> to_l THEN 'LONGITUDINAL_TIME_DISTINCT_ORDER_UNVERIFIED'::text
            ELSE 'TOKEN_VAZIO_NO_DISTINCT_TIME'::text
        END AS longitudinal_state,
        CASE
            WHEN predicate = 'DERIVES_FROM'::text THEN 'PROVENANCE_BACKTRACE_AS_DECLARED_NOT_MATH'::text
            ELSE 'TOKEN_VAZIO_NO_DERIVATION_EDGE'::text
        END AS reverse_provenance_state,
    'TOKEN_VAZIO_REQUIRES_FUNCTION_DOMAIN_AND_CONSTANT'::text AS mathematical_antiderivative_state,
    'TOKEN_VAZIO_REQUIRES_POLYNOMIAL_DEFINITION'::text AS polynomial_state,
    false AS claim_allowed
   FROM forest;
REVOKE ALL ON TABLE raf_private.omega_forest_route_matrix_v1 FROM PUBLIC, anon, authenticated;
COMMENT ON VIEW raf_private.omega_forest_route_matrix_v1 IS 'Private metadata-only 40-route projection of existing Mapa/omega forests; L9 categories are candidates; mathematical operators need domains; claim_allowed=false.';
-- Readback: 32 Mapa + 8 Omega routes, 40 distinct route keys, 32 O / 14 T / 4 L candidates, 7 DERIVES_FROM; anon/auth deny; 0 claims.
-- GAPS: direct REST API negative canary and independent review NOT_RUN; mathematical antiderivative and polynomial TOKEN_VAZIO.
