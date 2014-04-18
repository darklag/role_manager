/*
 * Create the 3 required roles for use in database applications
 */
CREATE FUNCTION create_app_roles(p_appname text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE

v_app_role          text;
v_owner_role        text;
v_readonly_role     text;

BEGIN

v_owner_role := p_appname || '_owner';
v_app_role := p_appname || '_app';
v_readonly_role := p_appname || '_readonly';

EXECUTE 'CREATE ROLE '||v_owner_role||' WITH LOGIN';
EXECUTE 'CREATE ROLE '||v_app_role||' WITH LOGIN';
EXECUTE 'CREATE ROLE '||v_readonly_role||' WITH LOGIN';

RETURN 'The following roles have been created: '||v_owner_role||', '||v_app_role||', '||v_readonly_role;

END
$$;
