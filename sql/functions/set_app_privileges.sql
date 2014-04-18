/*
 * Assign default privileges to application roles
 * p_owner - by setting to FALSE, allows skipping of changing existing database objects' ownership
 *
 * Owner role - all object in database are changed to being owned by this role
 * App role - All schemas are given USAGE
            - All database tables are given SELECT, INSERT, UPDATE, DELETE, TRUNCATE privileges. 
            - All functions are given EXECUTE.
            - All sequences are given USAGE, SELECT, UPDATE
 * Readonly role - All schemas are given USAGE
                 - All tables are given SELECT

*/

CREATE FUNCTION set_app_privileges (p_appname text, p_owner boolean DEFAULT true, p_debug boolean DEFAULT false) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE

v_dbname            text;
v_app_role          text;
v_owner_role        text;
v_readonly_role     text;
v_row               record;
v_sql               text;

BEGIN

v_owner_role := p_appname || '_owner';
v_app_role := p_appname || '_app';
v_readonly_role := p_appname || '_readonly';

FOR v_row IN 
    SELECT nspname FROM pg_catalog.pg_namespace WHERE nspname NOT IN ('pg_catalog', 'information_schema', 'schema_evolution_manager', 'setup_postgresql')
LOOP
    v_sql := 'GRANT USAGE ON SCHEMA '||v_row.nspname||' TO '||v_app_role||','||v_readonly_role;
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF;
    EXECUTE v_sql;

    v_sql := 'GRANT SELECT, INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA '||v_row.nspname||' TO '||v_app_role;
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF;
    EXECUTE v_sql;

    v_sql := 'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA '||v_row.nspname||' TO '||v_app_role;
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF;
    EXECUTE v_sql;

    v_sql := 'GRANT ALL ON ALL SEQUENCES IN SCHEMA '||v_row.nspname||' TO '||v_app_role;
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF;
    EXECUTE v_sql;

    v_sql := 'GRANT SELECT ON ALL TABLES IN SCHEMA '||v_row.nspname||' TO '||v_readonly_role;
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF;
    EXECUTE v_sql;
END LOOP;

IF p_owner THEN
    -- Set database ownership
    v_dbname := current_database();
    v_sql := 'ALTER DATABASE '||v_dbname||' OWNER TO '||v_owner_role;
    IF p_debug THEN
        RAISE NOTICE 'command: %', v_sql;
    END IF; EXECUTE v_sql;

    -- Set schema ownership
    FOR v_row IN 
        SELECT nspname AS name FROM pg_catalog.pg_namespace 
        WHERE nspname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER SCHEMA '||v_row.name||' OWNER TO '||v_owner_role;
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set table ownership
    FOR v_row IN
        SELECT schemaname||'.'||tablename AS name FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER TABLE '||v_row.name||' OWNER TO '||v_owner_role;
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set function ownership
    FOR v_row IN 
        SELECT n.nspname||'.'||p.proname||'('||pg_catalog.pg_get_function_identity_arguments(p.oid)||')' AS name
        FROM pg_proc p, pg_namespace n WHERE p.pronamespace = n.oid AND n.nspname NOT IN ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER FUNCTION '||v_row.name||' OWNER TO '||v_owner_role;
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;

    -- Set sequence ownership
    FOR v_row IN
        SELECT n.nspname||'.'||c.relname AS name FROM pg_class c 
        JOIN pg_namespace n ON c.relnamespace = n.oid 
        WHERE relkind = 'S' and n.nspname not in ('pg_catalog', 'information_schema')
    LOOP
        v_sql := 'ALTER SEQUENCE '||v_row.name||' OWNER TO '||v_owner_role;
        IF p_debug THEN
            RAISE NOTICE 'command: %', v_sql;
        END IF; EXECUTE v_sql;
    END LOOP;


    -- TODO Deal with other objects that need ownership handled

END IF;

END
$$;
