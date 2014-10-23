-- Exclude pg_toast table from privilege/ownership chanages.

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
*/

CREATE OR REPLACE FUNCTION set_app_privileges (p_appname text,  p_owner boolean DEFAULT true, p_debug boolean DEFAULT false) RETURNS void
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
    FOR v_row IN 
        SELECT n.nspname, p.proname, '('||pg_catalog.pg_get_function_identity_arguments(p.oid)||')' AS arglist
        FROM pg_proc p, pg_namespace n WHERE p.pronamespace = n.oid AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER FUNCTION '||quote_ident(v_row.nspname)||'.'||quote_ident(v_row.proname)||v_row.arglist||' OWNER TO '||quote_ident(v_owner_role);
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


    -- TODO Deal with other objects that need ownership handled

END IF;

END
$$;
