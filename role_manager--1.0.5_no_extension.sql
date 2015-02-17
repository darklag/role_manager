CREATE SCHEMA IF NOT EXISTS role_manager;

SET search_path = role_manager;

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
        password := role_manager.generate_password(p_password_length);
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
        password := role_manager.generate_password(p_password_length);
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
        password := role_manager.generate_password(p_password_length);
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
CREATE FUNCTION generate_password(int) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT ARRAY_TO_STRING(ARRAY_AGG(SUBSTR(A.chars, (RANDOM()*1000)::int%(LENGTH(A.chars))+1, 1)), '')
    FROM (SELECT 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'::varchar AS chars) A,
    (SELECT generate_series(1, $1, 1) AS line) B;
$$;
/*
 * Assign default privileges to application roles.
 * Also alters the default privileges of objects created by the owner role so anything it creates gets the privileges listed below.
 *
 * NOTE: This function assumes the application roles will be getting blanket permissions on all objects in the
 *      database that it is being run on. If the application roles only need permissions on specific objects
 *      in the database, DO NOT use this function and just do manual GRANT commands for whatever is needed.
 *
 * p_owner - by setting to FALSE, allows skipping of changing existing database objects' ownership
 *
 * Owner role - all object in database are changed to being owned by this role
 * App role - All schemas are given USAGE
 *          - All database tables are given SELECT, INSERT, UPDATE, DELETE, TRUNCATE privileges. 
 *          - All functions are given EXECUTE.
 *          - All sequences are given USAGE, SELECT, UPDATE
 * Readonly role - All schemas are given USAGE
 *               - All tables are given SELECT
 *
 * There was an exception added for the dblink functions. Some of these must be owned by a superuser to work properly.
*/

CREATE FUNCTION set_app_privileges (p_appname text,  p_owner boolean DEFAULT true, p_debug boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE

v_dbname            text;
v_app_exists        int;
v_app_role          text;
v_owner_exists      int;
v_owner_role        text;
v_readonly_exists   int;
v_readonly_role     text;
v_row               record;
v_row_skip          record;
v_sql               text;

BEGIN

v_owner_role := p_appname || '_owner';
v_app_role := p_appname || '_app';
v_readonly_role := p_appname || '_readonly';

SELECT count(*) INTO v_app_exists FROM pg_roles WHERE rolname = v_app_role;
SELECT count(*) INTO v_readonly_exists FROM pg_roles WHERE rolname = v_readonly_role;
SELECT count(*) INTO v_owner_exists FROM pg_roles WHERE rolname = v_owner_role;

FOR v_row IN 
    SELECT nspname 
    FROM pg_catalog.pg_namespace 
    WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'schema_evolution_manager', 'setup_postgresql')
    AND nspname NOT LIKE 'pg_toast%'
    AND nspname NOT LIKE 'pg_temp%'
LOOP

    IF v_app_exists > 0 THEN
        -- Alter default privileges of owner role so anything created by it grants necessary privs to app role.
        v_sql := 'ALTER DEFAULT PRIVILEGES FOR ROLE '||quote_ident(v_owner_role)||' GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON TABLES TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;
        v_sql := 'ALTER DEFAULT PRIVILEGES FOR ROLE '||quote_ident(v_owner_role)||' GRANT ALL ON SEQUENCES TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;
        v_sql := 'ALTER DEFAULT PRIVILEGES FOR ROLE '||quote_ident(v_owner_role)||' GRANT EXECUTE ON FUNCTIONS TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;

        -- Grant privileges to any existing objects
        v_sql := 'GRANT USAGE ON SCHEMA '||quote_ident(v_row.nspname)||' TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;

        v_sql := 'GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA '||quote_ident(v_row.nspname)||' TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;

        v_sql := 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA '||quote_ident(v_row.nspname)||' TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;

        v_sql := 'GRANT ALL ON ALL SEQUENCES IN SCHEMA '||quote_ident(v_row.nspname)||' TO '||quote_ident(v_app_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;
    END IF;

    IF v_readonly_exists > 0 THEN
        -- Alter default privileges of owner role so anything created by it grants necessary privs to readonly role.
        v_sql := 'ALTER DEFAULT PRIVILEGES FOR ROLE '||quote_ident(v_owner_role)||' GRANT SELECT ON TABLES TO '||quote_ident(v_readonly_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;

        v_sql := 'GRANT USAGE ON SCHEMA '||quote_ident(v_row.nspname)||' TO '||quote_ident(v_readonly_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;

        v_sql := 'GRANT SELECT ON ALL TABLES IN SCHEMA '||quote_ident(v_row.nspname)||' TO '||quote_ident(v_readonly_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF;
        EXECUTE v_sql;
    END IF;

END LOOP;

IF p_owner THEN
    IF v_owner_exists = 0 THEN
        RAISE EXCEPTION 'Change ownership option set to TRUE but owner role % does not exist', v_owner_role;
    END IF;

    -- Set database ownership
    v_dbname := current_database();
    v_sql := 'ALTER DATABASE '||quote_ident(v_dbname)||' OWNER TO '||quote_ident(v_owner_role);
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF; EXECUTE v_sql;

    -- Set schema ownership
    FOR v_row IN 
        SELECT nspname AS name FROM pg_catalog.pg_namespace 
        WHERE nspname NOT IN ('pg_catalog', 'information_schema')
        AND nspname NOT LIKE 'pg_toast%'
        AND nspname NOT LIKE 'pg_temp%'
    LOOP
        v_sql := 'ALTER SCHEMA '||quote_ident(v_row.name)||' OWNER TO '||quote_ident(v_owner_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set table ownership
    FOR v_row IN
        SELECT schemaname, tablename FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER TABLE '||quote_ident(v_row.schemaname)||'.'||quote_ident(v_row.tablename)||' OWNER TO '||quote_ident(v_owner_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set function ownership
    <<main_function_loop>>
    FOR v_row IN 
        SELECT n.nspname, p.proname, '('||pg_catalog.pg_get_function_identity_arguments(p.oid)||')' AS arglist,
            CASE WHEN p.proisagg THEN 'AGGREGATE'
                ELSE 'FUNCTION'
            END AS altertype
        FROM pg_proc p, pg_namespace n WHERE p.pronamespace = n.oid AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        -- Check if it is a function in dblink. Skip if so.
        FOR v_row_skip IN 
            SELECT f.proname, '('||pg_catalog.pg_get_function_identity_arguments(f.oid)||')' as arglist
            FROM pg_catalog.pg_depend d
            JOIN pg_catalog.pg_extension p ON d.refobjid = p.oid
            JOIN pg_catalog.pg_proc f ON d.objid = f.oid
            WHERE extname = 'dblink'
        LOOP
            --TODO REMOVE 
            RAISE NOTICE 'v_row_skip.proname: %, v_row.proname: %, v_row_skip.arglist: %, v_row.arglist: %', v_row_skip.proname, v_row.proname, v_row_skip.arglist, v_row.arglist;
            IF v_row_skip.proname = v_row.proname AND v_row_skip.arglist = v_row.arglist THEN
                CONTINUE main_function_loop;
            END IF;
        END LOOP;

        -- If no matches, change ownership
        v_sql := 'ALTER '||v_row.altertype||' '||quote_ident(v_row.nspname)||'.'||quote_ident(v_row.proname)||v_row.arglist||' OWNER TO '||quote_ident(v_owner_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set sequence ownership
    FOR v_row IN
        SELECT n.nspname, c.relname FROM pg_class c 
        JOIN pg_namespace n ON c.relnamespace = n.oid 
        WHERE relkind = 'S' and n.nspname not in ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER SEQUENCE '||quote_ident(v_row.nspname)||'.'||quote_ident(v_row.relname)||' OWNER TO '||quote_ident(v_owner_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set view ownership
    FOR v_row IN
        SELECT n.nspname, c.relname FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE relkind = 'v' and n.nspname not in ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER VIEW '||quote_ident(v_row.nspname)||'.'||quote_ident(v_row.relname)||' OWNER TO '||quote_ident(v_owner_role);
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;
    -- TODO Deal with other objects that need ownership handled

END IF;

END
$$;
