-- Restore the frozen implicit PUBLIC EXECUTE baseline for the app owner.
-- Do not run if concurrent global ACL changes have occurred.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $rollback$
DECLARE
  owner_oid oid := (SELECT oid FROM pg_roles WHERE rolname=current_user);
  unexpected_grants integer;
BEGIN
  IF session_user<>current_user THEN RAISE EXCEPTION 'Executor must be session user'; END IF;
  SELECT count(*) INTO unexpected_grants FROM pg_default_acl d,
    LATERAL aclexplode(d.defaclacl) acl
  WHERE d.defaclrole=owner_oid AND d.defaclnamespace=0 AND d.defaclobjtype='f'
    AND (acl.grantee<>owner_oid OR acl.is_grantable);
  IF unexpected_grants<>0 THEN RAISE EXCEPTION 'Global ACL drift; refuse rollback'; END IF;
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I GRANT EXECUTE ON FUNCTIONS TO PUBLIC',current_user);
  IF EXISTS (SELECT 1 FROM pg_default_acl d WHERE d.defaclrole=owner_oid
    AND d.defaclnamespace=0 AND d.defaclobjtype='f') THEN
    RAISE EXCEPTION 'Implicit global default row not restored exactly';
  END IF;
END
$rollback$;
COMMIT;
SELECT 'DAY136_FUTURE_FUNCTION_DEFAULT_ROLLBACK_PASS' AS status;
