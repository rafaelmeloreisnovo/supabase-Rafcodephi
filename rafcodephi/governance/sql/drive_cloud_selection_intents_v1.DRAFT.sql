-- RAFAELIA Ω: private cloud-folder selection control plane, no file copies.
-- Producer: supabase-Rafcodephi; no Google tokens, data bytes, or folder IDs in Git.
-- SOURCE != ARTIFACT != EXECUTION != EVIDENCE != CLAIM.
-- Existing driver map is referenced, NOT replaced. Physical Drive access stays BLOCKED_AUTH.

CREATE TABLE raf_private.drive_cloud_selection_intents_v1 (
    selection_pk uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    request_key uuid NOT NULL UNIQUE,
    driver_pk uuid NOT NULL
        REFERENCES raf_private.mapa_driver_catalog_v1(driver_pk) ON DELETE RESTRICT,
    owner_uid uuid NOT NULL,
    provider text NOT NULL DEFAULT 'GOOGLE_DRIVE'
        CHECK (provider = 'GOOGLE_DRIVE'),
    folder_id text NOT NULL
        CHECK (folder_id ~ '^[A-Za-z0-9_-]{10,256}$'),
    folder_sha256 text NOT NULL CHECK (folder_sha256 ~ '^[0-9a-f]{64}$'),
    selection_status text NOT NULL DEFAULT 'BLOCKED_GOOGLE_OAUTH'
        CHECK (selection_status = 'BLOCKED_GOOGLE_OAUTH'),
    scope text NOT NULL DEFAULT 'PRIVATE_METADATA_ONLY'
        CHECK (scope = 'PRIVATE_METADATA_ONLY'),
    content_downloaded boolean NOT NULL DEFAULT false CHECK (content_downloaded = false),
    copied_to_device boolean NOT NULL DEFAULT false CHECK (copied_to_device = false),
    claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false),
    parent_selection_pk uuid
        REFERENCES raf_private.drive_cloud_selection_intents_v1(selection_pk) ON DELETE RESTRICT,
    evidence_state text NOT NULL DEFAULT 'TOKEN_VAZIO_GOOGLE_PROVIDER_UNVERIFIED'
        CHECK (evidence_state = 'TOKEN_VAZIO_GOOGLE_PROVIDER_UNVERIFIED'),
    requested_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
CREATE INDEX drive_cloud_selection_owner_time_idx
    ON raf_private.drive_cloud_selection_intents_v1(owner_uid, requested_at DESC);
CREATE INDEX drive_cloud_selection_driver_idx
    ON raf_private.drive_cloud_selection_intents_v1(driver_pk);

ALTER TABLE raf_private.drive_cloud_selection_intents_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.drive_cloud_selection_intents_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE raf_private.drive_cloud_selection_intents_v1
    FROM PUBLIC, anon, authenticated;

CREATE FUNCTION raf_private.reject_drive_cloud_selection_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $fn$
BEGIN
    RAISE EXCEPTION 'drive cloud selections are append-only';
END; $fn$;
REVOKE ALL ON FUNCTION raf_private.reject_drive_cloud_selection_mutation_v1()
    FROM PUBLIC, anon, authenticated;
CREATE TRIGGER drive_cloud_selection_immutable
BEFORE UPDATE OR DELETE ON raf_private.drive_cloud_selection_intents_v1
FOR EACH ROW EXECUTE FUNCTION raf_private.reject_drive_cloud_selection_mutation_v1();

-- Strictly private privileged request registrar; no public/anon/authenticated EXECUTE.
-- The caller MUST verify the owner's user JWT separately before invoking.
-- This function DOES NOT contact Google Drive or read any file.
CREATE FUNCTION raf_private.register_drive_cloud_selection_v1(
    p_owner_uid uuid, p_folder_id text, p_request_key uuid
) RETURNS TABLE (
    out_selection_pk uuid, out_selection_status text, out_folder_sha256 text
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,raf_private AS $fn$
DECLARE
    v_driver_pk uuid;
    v_prior raf_private.drive_cloud_selection_intents_v1%ROWTYPE;
BEGIN
    IF p_owner_uid IS NULL OR p_request_key IS NULL OR
        p_folder_id IS NULL OR p_folder_id !~ '^[A-Za-z0-9_-]{10,256}$'
    THEN
        RAISE EXCEPTION 'INVALID_PRIVATE_SELECTION_REQUEST';
    END IF;

    SELECT d.driver_pk INTO v_driver_pk
    FROM raf_private.mapa_driver_catalog_v1 AS d
    WHERE d.driver_key='google_drive_official'
    ORDER BY d.driver_version DESC LIMIT 1;
    IF v_driver_pk IS NULL THEN
        RAISE EXCEPTION 'GOOGLE_DRIVE_DRIVER_NOT_FOUND';
    END IF;

    INSERT INTO raf_private.drive_cloud_selection_intents_v1(
        request_key, driver_pk, owner_uid, folder_id, folder_sha256
    ) VALUES(p_request_key, v_driver_pk, p_owner_uid, p_folder_id,
             encode(sha256(convert_to(p_folder_id,'UTF8')),'hex'))
    ON CONFLICT (request_key) DO NOTHING;

    SELECT * INTO v_prior
    FROM raf_private.drive_cloud_selection_intents_v1
    WHERE request_key=p_request_key;

    IF v_prior.selection_pk IS NULL OR
        v_prior.owner_uid IS DISTINCT FROM p_owner_uid OR
        v_prior.folder_id IS DISTINCT FROM p_folder_id OR
        v_prior.driver_pk IS DISTINCT FROM v_driver_pk
    THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_SOURCE';
    END IF;

    RETURN QUERY SELECT v_prior.selection_pk, v_prior.selection_status, v_prior.folder_sha256;
END; $fn$;
REVOKE ALL ON FUNCTION raf_private.register_drive_cloud_selection_v1(uuid,text,uuid)
    FROM PUBLIC, anon, authenticated;
),
    selection_status text NOT NULL DEFAULT 'BLOCKED_GOOGLE_OAUTH'
        CHECK (selection_status = 'BLOCKED_GOOGLE_OAUTH'),
    scope text NOT NULL DEFAULT 'PRIVATE_METADATA_ONLY'
        CHECK (scope = 'PRIVATE_METADATA_ONLY'),
    content_downloaded boolean NOT NULL DEFAULT false CHECK (content_downloaded = false),
    copied_to_device boolean NOT NULL DEFAULT false CHECK (copied_to_device = false),
    claim_allowed boolean NOT NULL DEFAULT false CHECK (claim_allowed = false),
    parent_selection_pk uuid
        REFERENCES raf_private.drive_cloud_selection_intents_v1(selection_pk) ON DELETE RESTRICT,
    evidence_state text NOT NULL DEFAULT 'TOKEN_VAZIO_GOOGLE_PROVIDER_UNVERIFIED'
        CHECK (evidence_state = 'TOKEN_VAZIO_GOOGLE_PROVIDER_UNVERIFIED'),
    requested_at timestamptz NOT NULL DEFAULT transaction_timestamp()
);
CREATE INDEX drive_cloud_selection_owner_time_idx
    ON raf_private.drive_cloud_selection_intents_v1(owner_uid, requested_at DESC);
CREATE INDEX drive_cloud_selection_driver_idx
    ON raf_private.drive_cloud_selection_intents_v1(driver_pk);

ALTER TABLE raf_private.drive_cloud_selection_intents_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE raf_private.drive_cloud_selection_intents_v1 FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE raf_private.drive_cloud_selection_intents_v1
    FROM PUBLIC, anon, authenticated;

CREATE FUNCTION raf_private.reject_drive_cloud_selection_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $fn$
BEGIN
    RAISE EXCEPTION 'drive cloud selections are append-only';
END; $fn$;
REVOKE ALL ON FUNCTION raf_private.reject_drive_cloud_selection_mutation_v1()
    FROM PUBLIC, anon, authenticated;
CREATE TRIGGER drive_cloud_selection_immutable
BEFORE UPDATE OR DELETE ON raf_private.drive_cloud_selection_intents_v1
FOR EACH ROW EXECUTE FUNCTION raf_private.reject_drive_cloud_selection_mutation_v1();

-- Strictly private privileged request registrar; no public/anon/authenticated EXECUTE.
-- The caller MUST verify the owner's user JWT separately before invoking.
-- This function DOES NOT contact Google Drive or read any file.
CREATE FUNCTION raf_private.register_drive_cloud_selection_v1(
    p_owner_uid uuid, p_folder_id text, p_request_key uuid
) RETURNS TABLE (
    out_selection_pk uuid, out_selection_status text, out_folder_sha256 text
)
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,raf_private AS $fn$
DECLARE
    v_driver_pk uuid;
    v_prior raf_private.drive_cloud_selection_intents_v1%ROWTYPE;
BEGIN
    IF p_owner_uid IS NULL OR p_request_key IS NULL OR
        p_folder_id IS NULL OR p_folder_id !~ '^[A-Za-z0-9_-]{10,256}$'
    THEN
        RAISE EXCEPTION 'INVALID_PRIVATE_SELECTION_REQUEST';
    END IF;

    SELECT d.driver_pk INTO v_driver_pk
    FROM raf_private.mapa_driver_catalog_v1 AS d
    WHERE d.driver_key='google_drive_official'
    ORDER BY d.driver_version DESC LIMIT 1;
    IF v_driver_pk IS NULL THEN
        RAISE EXCEPTION 'GOOGLE_DRIVE_DRIVER_NOT_FOUND';
    END IF;

    INSERT INTO raf_private.drive_cloud_selection_intents_v1(
        request_key, driver_pk, owner_uid, folder_id
    ) VALUES(p_request_key, v_driver_pk, p_owner_uid, p_folder_id)
    ON CONFLICT (request_key) DO NOTHING;

    SELECT * INTO v_prior
    FROM raf_private.drive_cloud_selection_intents_v1
    WHERE request_key=p_request_key;

    IF v_prior.selection_pk IS NULL OR
        v_prior.owner_uid IS DISTINCT FROM p_owner_uid OR
        v_prior.folder_id IS DISTINCT FROM p_folder_id OR
        v_prior.driver_pk IS DISTINCT FROM v_driver_pk
    THEN
        RAISE EXCEPTION 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_SOURCE';
    END IF;

    RETURN QUERY SELECT v_prior.selection_pk, v_prior.selection_status, v_prior.folder_sha256;
END; $fn$;
REVOKE ALL ON FUNCTION raf_private.register_drive_cloud_selection_v1(uuid,text,uuid)
    FROM PUBLIC, anon, authenticated;
