-- RAFAELIA Ω: real PRIVILEGED search + reconstructible Drive folder path over observed metadata.
-- No Google API calls here. No client-facing EXECUTE grants, no content or mobile runtime claims.
CREATE FUNCTION raf_private.search_drive_metadata_v1(p_term text,p_limit integer DEFAULT 20)
RETURNS TABLE(item_id text,item_name text,item_kind text,source_url text,
              parent_id text,source_modified timestamptz)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,raf_private AS $fn$
 WITH latest AS (
  SELECT DISTINCT ON(source_file_id) source_file_id,source_name,source_kind,
       provider_url,source_root_id,source_parent_id,provider_modified_at,observed_at
  FROM raf_private.drive_metadata_index_v1
  ORDER BY source_file_id,provider_modified_at DESC NULLS LAST,
           (source_parent_id IS NOT NULL) DESC,observed_at DESC
 )
 SELECT s.source_file_id,s.source_name,s.source_kind,s.provider_url,
    CASE WHEN s.source_file_id=s.source_root_id THEN s.source_parent_id
         ELSE coalesce(s.source_parent_id,s.source_root_id) END,
    s.provider_modified_at
 FROM latest s
 WHERE p_term IS NOT NULL AND length(btrim(p_term))>=2
  AND s.source_name ILIKE ('%' || p_term || '%')
 ORDER BY s.provider_modified_at DESC NULLS LAST,s.source_name
 LIMIT LEAST(GREATEST(coalesce(p_limit,20),1),50);
$fn$;
REVOKE ALL ON FUNCTION raf_private.search_drive_metadata_v1(text,integer)
 FROM PUBLIC,anon,authenticated;

CREATE FUNCTION raf_private.resolve_drive_path_v1(p_source_file_id text)
RETURNS TABLE(depth integer,item_id text,item_name text,parent_id text,relation_evidence text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,raf_private AS $fn$
 WITH RECURSIVE latest AS (
  SELECT DISTINCT ON(source_file_id) source_file_id,source_name,
   source_root_id,source_parent_id,provider_modified_at,observed_at
  FROM raf_private.drive_metadata_index_v1
  ORDER BY source_file_id,provider_modified_at DESC NULLS LAST,
           (source_parent_id IS NOT NULL) DESC,observed_at DESC
 ), walk AS (
  SELECT 0::integer AS depth,s.source_file_id AS item_id,s.source_name AS item_name,
    CASE WHEN s.source_file_id=s.source_root_id THEN s.source_parent_id
         ELSE coalesce(s.source_parent_id,s.source_root_id) END AS parent_id,
    CASE WHEN s.source_parent_id IS NOT NULL THEN 'PROVIDER_PARENT_ID'::text
         WHEN s.source_file_id<>s.source_root_id THEN 'PROVIDER_SCOPED_FOLDER_LISTING'::text
         ELSE 'TOKEN_VAZIO_PARENT'::text END AS relation_evidence,
    ARRAY[s.source_file_id]::text[] AS visited
  FROM latest s WHERE s.source_file_id=p_source_file_id
  UNION ALL
  SELECT w.depth+1,s.source_file_id,s.source_name,
    CASE WHEN s.source_file_id=s.source_root_id THEN s.source_parent_id
         ELSE coalesce(s.source_parent_id,s.source_root_id) END,
    CASE WHEN s.source_parent_id IS NOT NULL THEN 'PROVIDER_PARENT_ID'::text
         WHEN s.source_file_id<>s.source_root_id THEN 'PROVIDER_SCOPED_FOLDER_LISTING'::text
         ELSE 'TOKEN_VAZIO_PARENT'::text END,
    w.visited || s.source_file_id
  FROM walk w JOIN latest s ON s.source_file_id=w.parent_id
  WHERE w.depth<16 AND NOT (s.source_file_id=ANY(w.visited))
 )
 SELECT w.depth,w.item_id,w.item_name,w.parent_id,w.relation_evidence
 FROM walk w ORDER BY w.depth;
$fn$;
REVOKE ALL ON FUNCTION raf_private.resolve_drive_path_v1(text)
 FROM PUBLIC,anon,authenticated;
