-- Additive Day136 deviation: GLOBAL future-function defaults for app owner.
-- Requires separate authorization: this also affects future functions outside
-- public when created by the same owner. Existing functions are unchanged.
BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '30s';
DO $patch$
DECLARE
  owner_oid oid := (SELECT oid FROM pg_roles WHERE rolname=current_user);
  unexpected_grants integer;
BEGIN
  IF session_user <> current_user THEN RAISE EXCEPTION 'Executor must be session user'; END IF;
  IF (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relkind IN ('r','p') AND c.relowner=owner_oid
      AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.classid='pg_class'::regclass
        AND d.objid=c.oid AND d.deptype='e')) <> 28 THEN
    RAISE EXCEPTION 'Expected all 28 app tables owned by executor';
  END IF;
  -- Do not silently broaden this delta to explicit global grants to other roles.
  SELECT count(*) INTO unexpected_grants FROM pg_default_acl d,
    LATERAL aclexplode(d.defaclacl) acl
  WHERE d.defaclrole=owner_oid AND d.defaclnamespace=0 AND d.defaclobjtype='f'
    AND acl.grantee NOT IN (0,owner_oid);
  IF unexpected_grants<>0 THEN RAISE EXCEPTION 'Unexpected global function grants; abort'; END IF;
  EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %I REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC',current_user);
  IF EXISTS (SELECT 1 FROM aclexplode(COALESCE(
    (SELECT defaclacl FROM pg_default_acl WHERE defaclrole=owner_oid
      AND defaclnamespace=0 AND defaclobjtype='f'),acldefault('f',owner_oid))) acl
    WHERE acl.grantee=0 AND acl.privilege_type='EXECUTE') THEN
    RAISE EXCEPTION 'Global PUBLIC default EXECUTE remains';
  END IF;
END
$patch$;
COMMIT;
SELECT 'DAY136_FUTURE_FUNCTION_DEFAULT_PATCH_PASS' AS status;
