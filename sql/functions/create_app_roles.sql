/*
 * Create the 3 required roles for use in database applications
 * p_appname - Required. Application namd that will be used as basename for roles
 * p_app_role - set whether to create an application read/write role (appname_app). Default true.
 * p_readonly_role - set whether to create a readonly role (appname_readonly). Default true.
 * p_owner_role - set whether to create an owner role (appname_owner). Default true.
 * p_set_passwords - set passwords for the roles that are created. Default true.
 * p_password_length - character length of password. Default 12.
 */
CREATE FUNCTION create_app_roles(
    p_appname text
    , p_app_role boolean DEFAULT true
    , p_readonly_role boolean DEFAULT true
    , p_owner_role boolean DEFAULT true
    , p_set_password boolean DEFAULT true
    , p_password_length int DEFAULT 12
    , out rolename text
    , out password text)
RETURNS SETOF record
    LANGUAGE plpgsql
    AS $$
DECLARE

v_sql               text;

BEGIN

IF p_app_role THEN
    rolename := p_appname || '_app';
    v_sql := 'CREATE ROLE '||quote_ident(rolename)||' WITH LOGIN';
    IF p_set_password THEN
        password := @extschema@.generate_password(p_password_length);
        v_sql := v_sql || ' PASSWORD '||quote_literal(password);
    ELSE
        password := '';
    END IF;
    EXECUTE v_sql;
    RETURN NEXT;
END IF;

IF p_readonly_role THEN
    rolename := p_appname || '_readonly';
    v_sql := 'CREATE ROLE '||quote_ident(rolename)||' WITH LOGIN';
    IF p_set_password THEN
        password := @extschema@.generate_password(p_password_length);
        v_sql := v_sql || ' PASSWORD '||quote_literal(password);
    ELSE
        password := '';
    END IF;
    EXECUTE v_sql;
    RETURN NEXT;
END IF;

IF p_owner_role THEN
    rolename := p_appname || '_owner';
    v_sql := 'CREATE ROLE '||quote_ident(rolename)||' WITH LOGIN';
    IF p_set_password THEN
        password := @extschema@.generate_password(p_password_length);
        v_sql := v_sql || ' PASSWORD '||quote_literal(password);
    ELSE
        password := '';
    END IF;
    EXECUTE v_sql;
    RETURN NEXT;
END IF;

RETURN;

END
$$;
