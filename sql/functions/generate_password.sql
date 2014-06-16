CREATE FUNCTION generate_password(int) RETURNS text
    LANGUAGE sql
    AS $$
    SELECT ARRAY_TO_STRING(ARRAY_AGG(SUBSTR(A.chars, (RANDOM()*1000)::int%(LENGTH(A.chars))+1, 1)), '')
    FROM (SELECT 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'::varchar AS chars) A,
    (SELECT generate_series(1, $1, 1) AS line) B;
$$;
