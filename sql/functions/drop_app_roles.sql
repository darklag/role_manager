/*
 * Drop the 3 roles that were created by create_app_roles for use in database applications
 * p_appname - Required. Application name that was used as the basename for the roles.
 * p_app_role - set whether to drop the application read/write role (appname_app). Default true.
 * p_readonly_role - set whether to drop the readonly role (appname_readonly). Default true.
 * p_owner_role - set whether to drop the owner role (appname_owner). Default true.
 */
CREATE FUNCTION drop_app_roles(p_appname text, p_app_role boolean DEFAULT true, p_readonly_role boolean DEFAULT true, p_owner_role boolean DEFAULT true) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE

v_app_role          text;
v_owner_role        text;
v_readonly_role     text;
v_return            text;

BEGIN

v_owner_role := p_appname || '_owner';
v_app_role := p_appname || '_app';
v_readonly_role := p_appname || '_readonly';
v_return := 'The following roles have been dropped:';

IF p_app_role THEN
    EXECUTE 'DROP ROLE IF EXISTS '||v_app_role;
    v_return := v_return || ' ' ||v_app_role;
END IF;

IF p_readonly_role THEN
    EXECUTE 'DROP ROLE IF EXISTS '||v_readonly_role;
    v_return := v_return || ' ' ||v_readonly_role;
END IF;

IF p_owner_role THEN
    EXECUTE 'DROP ROLE IF EXISTS '||v_owner_role;
    v_return := v_return || ' ' ||v_owner_role;
END IF;

RETURN v_return;

END
$$;
