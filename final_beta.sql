--
-- PostgreSQL database dump
--

-- Dumped from database version 16.0
-- Dumped by pg_dump version 16.0

-- Started on 2024-01-12 12:23:22

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 6 (class 2615 OID 30001)
-- Name: account; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA account;


ALTER SCHEMA account OWNER TO postgres;

--
-- TOC entry 7 (class 2615 OID 30002)
-- Name: delivery; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA delivery;


ALTER SCHEMA delivery OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 30003)
-- Name: product; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA product;


ALTER SCHEMA product OWNER TO postgres;

--
-- TOC entry 5208 (class 0 OID 0)
-- Dependencies: 8
-- Name: SCHEMA product; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA product IS 'standard public schema';


--
-- TOC entry 9 (class 2615 OID 30004)
-- Name: shopping; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA shopping;


ALTER SCHEMA shopping OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 30005)
-- Name: store; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA store;


ALTER SCHEMA store OWNER TO postgres;

--
-- TOC entry 11 (class 2615 OID 30006)
-- Name: timetable; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA timetable;


ALTER SCHEMA timetable OWNER TO postgres;

--
-- TOC entry 928 (class 1247 OID 30008)
-- Name: command_kind; Type: TYPE; Schema: timetable; Owner: postgres
--

CREATE TYPE timetable.command_kind AS ENUM (
    'SQL',
    'PROGRAM',
    'BUILTIN'
);


ALTER TYPE timetable.command_kind OWNER TO postgres;

--
-- TOC entry 277 (class 1255 OID 30015)
-- Name: cron_split_to_arrays(text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.cron_split_to_arrays(cron text, OUT mins integer[], OUT hours integer[], OUT days integer[], OUT months integer[], OUT dow integer[]) RETURNS record
    LANGUAGE plpgsql STRICT
    AS $_$
DECLARE
    a_element text[];
    i_index integer;
    a_tmp text[];
    tmp_item text;
    a_range int[];
    a_split text[];
    a_res integer[];
    max_val integer;
    min_val integer;
    dimensions constant text[] = '{"minutes", "hours", "days", "months", "days of week"}';
    allowed_ranges constant integer[][] = '{{0,59},{0,23},{1,31},{1,12},{0,7}}';
BEGIN
    a_element := regexp_split_to_array(cron, '\s+');
    FOR i_index IN 1..5 LOOP
        a_res := NULL;
        a_tmp := string_to_array(a_element[i_index],',');
        FOREACH  tmp_item IN ARRAY a_tmp LOOP
            IF tmp_item ~ '^[0-9]+$' THEN -- normal integer
                a_res := array_append(a_res, tmp_item::int);
            ELSIF tmp_item ~ '^[*]+$' THEN -- '*' any value
                a_range := array(select generate_series(allowed_ranges[i_index][1], allowed_ranges[i_index][2]));
                a_res := array_cat(a_res, a_range);
            ELSIF tmp_item ~ '^[0-9]+[-][0-9]+$' THEN -- '-' range of values
                a_range := regexp_split_to_array(tmp_item, '-');
                a_range := array(select generate_series(a_range[1], a_range[2]));
                a_res := array_cat(a_res, a_range);
            ELSIF tmp_item ~ '^[0-9]+[\/][0-9]+$' THEN -- '/' step values
                a_range := regexp_split_to_array(tmp_item, '/');
                a_range := array(select generate_series(a_range[1], allowed_ranges[i_index][2], a_range[2]));
                a_res := array_cat(a_res, a_range);
            ELSIF tmp_item ~ '^[0-9-]+[\/][0-9]+$' THEN -- '-' range of values and '/' step values
                a_split := regexp_split_to_array(tmp_item, '/');
                a_range := regexp_split_to_array(a_split[1], '-');
                a_range := array(select generate_series(a_range[1], a_range[2], a_split[2]::int));
                a_res := array_cat(a_res, a_range);
            ELSIF tmp_item ~ '^[*]+[\/][0-9]+$' THEN -- '*' any value and '/' step values
                a_split := regexp_split_to_array(tmp_item, '/');
                a_range := array(select generate_series(allowed_ranges[i_index][1], allowed_ranges[i_index][2], a_split[2]::int));
                a_res := array_cat(a_res, a_range);
            ELSE
                RAISE EXCEPTION 'Value ("%") not recognized', a_element[i_index]
                    USING HINT = 'fields separated by space or tab.'+
                       'Values allowed: numbers (value list with ","), '+
                    'any value with "*", range of value with "-" and step values with "/"!';
            END IF;
        END LOOP;
        SELECT
           ARRAY_AGG(x.val), MIN(x.val), MAX(x.val) INTO a_res, min_val, max_val
        FROM (
            SELECT DISTINCT UNNEST(a_res) AS val ORDER BY val) AS x;
        IF max_val > allowed_ranges[i_index][2] OR min_val < allowed_ranges[i_index][1] OR a_res IS NULL THEN
            RAISE EXCEPTION '% is out of range % for %', tmp_item, allowed_ranges[i_index:i_index][:], dimensions[i_index];
        END IF;
        CASE i_index
            WHEN 1 THEN mins := a_res;
            WHEN 2 THEN hours := a_res;
            WHEN 3 THEN days := a_res;
            WHEN 4 THEN months := a_res;
        ELSE
            dow := a_res;
        END CASE;
    END LOOP;
    RETURN;
END;
$_$;


ALTER FUNCTION timetable.cron_split_to_arrays(cron text, OUT mins integer[], OUT hours integer[], OUT days integer[], OUT months integer[], OUT dow integer[]) OWNER TO postgres;

--
-- TOC entry 931 (class 1247 OID 30017)
-- Name: cron; Type: DOMAIN; Schema: timetable; Owner: postgres
--

CREATE DOMAIN timetable.cron AS text
	CONSTRAINT cron_check CHECK (((VALUE = '@reboot'::text) OR ((substr(VALUE, 1, 6) = ANY (ARRAY['@every'::text, '@after'::text])) AND ((substr(VALUE, 7))::interval IS NOT NULL)) OR ((VALUE ~ '^(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) +){4}(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) ?)$'::text) AND (timetable.cron_split_to_arrays(VALUE) IS NOT NULL))));


ALTER DOMAIN timetable.cron OWNER TO postgres;

--
-- TOC entry 5209 (class 0 OID 0)
-- Dependencies: 931
-- Name: DOMAIN cron; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON DOMAIN timetable.cron IS 'Extended CRON-style notation with support of interval values';


--
-- TOC entry 935 (class 1247 OID 30020)
-- Name: log_type; Type: TYPE; Schema: timetable; Owner: postgres
--

CREATE TYPE timetable.log_type AS ENUM (
    'DEBUG',
    'NOTICE',
    'INFO',
    'ERROR',
    'PANIC',
    'USER'
);


ALTER TYPE timetable.log_type OWNER TO postgres;

--
-- TOC entry 278 (class 1255 OID 30033)
-- Name: autocreatedelimethod(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.autocreatedelimethod() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN 
    INSERT INTO store.delivery_method(store_id, price) VALUES(NEW.store_id, 3.00); 
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.autocreatedelimethod() OWNER TO postgres;

--
-- TOC entry 282 (class 1255 OID 30497)
-- Name: autocreateinv(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.autocreateinv() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO product.inventory(product_id) VALUES(NEW.product_id);
    RETURN NEW;
 END;
$$;


ALTER FUNCTION public.autocreateinv() OWNER TO postgres;

--
-- TOC entry 279 (class 1255 OID 30034)
-- Name: autocreaterole(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.autocreaterole() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN 
    INSERT INTO account.user_role(user_id, role_id) VALUES(NEW.user_id, 1); 
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.autocreaterole() OWNER TO postgres;

--
-- TOC entry 280 (class 1255 OID 30035)
-- Name: autoreupdaterole(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.autoreupdaterole() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    DELETE FROM account.user_role
    WHERE user_id = OLD.user_id AND role_id = 2;
	RETURN OLD;
END;
$$;


ALTER FUNCTION public.autoreupdaterole() OWNER TO postgres;

--
-- TOC entry 281 (class 1255 OID 30036)
-- Name: autoupdaterole(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.autoupdaterole() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	INSERT INTO account.user_role(user_id, role_id) VALUES(NEW.user_id, 2);
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.autoupdaterole() OWNER TO postgres;

--
-- TOC entry 283 (class 1255 OID 30037)
-- Name: update_active_product(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_active_product() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE product.product
    SET is_active = false
    WHERE 
        product_id IN (
            SELECT latest_order.product_id
            FROM (
                SELECT product_id, MAX(modified_at) AS last_modified
                FROM shopping.order_item
                GROUP BY product_id
            ) AS latest_order
            JOIN product.inventory inv ON latest_order.product_id = inv.product_id
            WHERE latest_order.last_modified + INTERVAL '30 days' < NOW()
            AND inv.quantity = 0
        );
END;
$$;


ALTER FUNCTION public.update_active_product() OWNER TO postgres;

--
-- TOC entry 298 (class 1255 OID 30038)
-- Name: update_and_delete_discount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_and_delete_discount() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Update the discount_id in product.product to NULL
    UPDATE product.product
    SET discount_id = NULL
    WHERE discount_id IN (
        SELECT discount_id FROM product.discount
        WHERE end_date = CURRENT_DATE
    );

    -- Delete the row in product.discount
    UPDATE product.discount
	SET is_active = false
    WHERE end_date = CURRENT_DATE;
END;
$$;


ALTER FUNCTION public.update_and_delete_discount() OWNER TO postgres;

--
-- TOC entry 284 (class 1255 OID 30039)
-- Name: update_condition_after_delay(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_condition_after_delay() RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE shopping.order_item
    SET condition = 'Pending Pickup'
    WHERE created_at <= NOW() - INTERVAL '1 minute'
    AND condition = 'Pending Confirmation';
END;
$$;


ALTER FUNCTION public.update_condition_after_delay() OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 30517)
-- Name: update_modified(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_modified() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	NEW.modified_at := now();
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_modified() OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 30052)
-- Name: _validate_json_schema_type(text, jsonb); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable._validate_json_schema_type(type text, data jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $$
BEGIN
  IF type = 'integer' THEN
    IF jsonb_typeof(data) != 'number' THEN
      RETURN false;
    END IF;
    IF trunc(data::text::numeric) != data::text::numeric THEN
      RETURN false;
    END IF;
  ELSE
    IF type != jsonb_typeof(data) THEN
      RETURN false;
    END IF;
  END IF;
  RETURN true;
END;
$$;


ALTER FUNCTION timetable._validate_json_schema_type(type text, data jsonb) OWNER TO postgres;

--
-- TOC entry 300 (class 1255 OID 30053)
-- Name: add_job(text, timetable.cron, text, jsonb, timetable.command_kind, text, integer, boolean, boolean, boolean, boolean, text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.add_job(job_name text, job_schedule timetable.cron, job_command text, job_parameters jsonb DEFAULT NULL::jsonb, job_kind timetable.command_kind DEFAULT 'SQL'::timetable.command_kind, job_client_name text DEFAULT NULL::text, job_max_instances integer DEFAULT NULL::integer, job_live boolean DEFAULT true, job_self_destruct boolean DEFAULT false, job_ignore_errors boolean DEFAULT true, job_exclusive boolean DEFAULT false, job_on_error text DEFAULT NULL::text) RETURNS bigint
    LANGUAGE sql
    AS $$
    WITH 
        cte_chain (v_chain_id) AS (
            INSERT INTO timetable.chain (chain_name, run_at, max_instances, live, self_destruct, client_name, exclusive_execution, on_error) 
            VALUES (job_name, job_schedule,job_max_instances, job_live, job_self_destruct, job_client_name, job_exclusive, job_on_error)
            RETURNING chain_id
        ),
        cte_task(v_task_id) AS (
            INSERT INTO timetable.task (chain_id, task_order, kind, command, ignore_error, autonomous)
            SELECT v_chain_id, 10, job_kind, job_command, job_ignore_errors, TRUE
            FROM cte_chain
            RETURNING task_id
        ),
        cte_param AS (
            INSERT INTO timetable.parameter (task_id, order_id, value)
            SELECT v_task_id, 1, job_parameters FROM cte_task, cte_chain
        )
        SELECT v_chain_id FROM cte_chain
$$;


ALTER FUNCTION timetable.add_job(job_name text, job_schedule timetable.cron, job_command text, job_parameters jsonb, job_kind timetable.command_kind, job_client_name text, job_max_instances integer, job_live boolean, job_self_destruct boolean, job_ignore_errors boolean, job_exclusive boolean, job_on_error text) OWNER TO postgres;

--
-- TOC entry 5210 (class 0 OID 0)
-- Dependencies: 300
-- Name: FUNCTION add_job(job_name text, job_schedule timetable.cron, job_command text, job_parameters jsonb, job_kind timetable.command_kind, job_client_name text, job_max_instances integer, job_live boolean, job_self_destruct boolean, job_ignore_errors boolean, job_exclusive boolean, job_on_error text); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.add_job(job_name text, job_schedule timetable.cron, job_command text, job_parameters jsonb, job_kind timetable.command_kind, job_client_name text, job_max_instances integer, job_live boolean, job_self_destruct boolean, job_ignore_errors boolean, job_exclusive boolean, job_on_error text) IS 'Add one-task chain (aka job) to the system';


--
-- TOC entry 301 (class 1255 OID 30054)
-- Name: add_task(timetable.command_kind, text, bigint, double precision); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.add_task(kind timetable.command_kind, command text, parent_id bigint, order_delta double precision DEFAULT 10) RETURNS bigint
    LANGUAGE sql
    AS $_$
    INSERT INTO timetable.task (chain_id, task_order, kind, command) 
	SELECT chain_id, task_order + $4, $1, $2 FROM timetable.task WHERE task_id = $3
	RETURNING task_id
$_$;


ALTER FUNCTION timetable.add_task(kind timetable.command_kind, command text, parent_id bigint, order_delta double precision) OWNER TO postgres;

--
-- TOC entry 5211 (class 0 OID 0)
-- Dependencies: 301
-- Name: FUNCTION add_task(kind timetable.command_kind, command text, parent_id bigint, order_delta double precision); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.add_task(kind timetable.command_kind, command text, parent_id bigint, order_delta double precision) IS 'Add a task to the same chain as the task with parent_id';


--
-- TOC entry 302 (class 1255 OID 30055)
-- Name: cron_days(timestamp with time zone, integer[], integer[], integer[]); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.cron_days(from_ts timestamp with time zone, allowed_months integer[], allowed_days integer[], allowed_week_days integer[]) RETURNS SETOF timestamp with time zone
    LANGUAGE sql STRICT
    AS $$
    WITH
    ad(ad) AS (SELECT UNNEST(allowed_days)),
    am(am) AS (SELECT * FROM timetable.cron_months(from_ts, allowed_months)),
    gend(ts) AS ( --generated days
        SELECT date_trunc('day', ts)
        FROM am,
            pg_catalog.generate_series(am.am, am.am + INTERVAL '1 month'
                - INTERVAL '1 day',  -- don't include the same day of the next month
                INTERVAL '1 day') g(ts)
    )
    SELECT ts
    FROM gend JOIN ad ON date_part('day', gend.ts) = ad.ad
    WHERE extract(dow from ts)=ANY(allowed_week_days)
$$;


ALTER FUNCTION timetable.cron_days(from_ts timestamp with time zone, allowed_months integer[], allowed_days integer[], allowed_week_days integer[]) OWNER TO postgres;

--
-- TOC entry 303 (class 1255 OID 30056)
-- Name: cron_months(timestamp with time zone, integer[]); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.cron_months(from_ts timestamp with time zone, allowed_months integer[]) RETURNS SETOF timestamp with time zone
    LANGUAGE sql STRICT
    AS $$
    WITH
    am(am) AS (SELECT UNNEST(allowed_months)),
    genm(ts) AS ( --generated months
        SELECT date_trunc('month', ts)
        FROM pg_catalog.generate_series(from_ts, from_ts + INTERVAL '1 year', INTERVAL '1 month') g(ts)
    )
    SELECT ts FROM genm JOIN am ON date_part('month', genm.ts) = am.am
$$;


ALTER FUNCTION timetable.cron_months(from_ts timestamp with time zone, allowed_months integer[]) OWNER TO postgres;

--
-- TOC entry 304 (class 1255 OID 30057)
-- Name: cron_runs(timestamp with time zone, text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.cron_runs(from_ts timestamp with time zone, cron text) RETURNS SETOF timestamp with time zone
    LANGUAGE sql STRICT
    AS $$
    SELECT cd + ct
    FROM
        timetable.cron_split_to_arrays(cron) a,
        timetable.cron_times(a.hours, a.mins) ct CROSS JOIN
        timetable.cron_days(from_ts, a.months, a.days, a.dow) cd
    WHERE cd + ct > from_ts
    ORDER BY 1 ASC;
$$;


ALTER FUNCTION timetable.cron_runs(from_ts timestamp with time zone, cron text) OWNER TO postgres;

--
-- TOC entry 305 (class 1255 OID 30058)
-- Name: cron_times(integer[], integer[]); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.cron_times(allowed_hours integer[], allowed_minutes integer[]) RETURNS SETOF time without time zone
    LANGUAGE sql STRICT
    AS $$
    WITH
    ah(ah) AS (SELECT UNNEST(allowed_hours)),
    am(am) AS (SELECT UNNEST(allowed_minutes))
    SELECT make_time(ah.ah, am.am, 0) FROM ah CROSS JOIN am
$$;


ALTER FUNCTION timetable.cron_times(allowed_hours integer[], allowed_minutes integer[]) OWNER TO postgres;

--
-- TOC entry 306 (class 1255 OID 30059)
-- Name: delete_job(text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.delete_job(job_name text) RETURNS boolean
    LANGUAGE sql
    AS $_$
    WITH del_chain AS (DELETE FROM timetable.chain WHERE chain.chain_name = $1 RETURNING chain_id)
    SELECT EXISTS(SELECT 1 FROM del_chain)
$_$;


ALTER FUNCTION timetable.delete_job(job_name text) OWNER TO postgres;

--
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 306
-- Name: FUNCTION delete_job(job_name text); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.delete_job(job_name text) IS 'Delete the chain and its tasks from the system';


--
-- TOC entry 307 (class 1255 OID 30060)
-- Name: delete_task(bigint); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.delete_task(task_id bigint) RETURNS boolean
    LANGUAGE sql
    AS $_$
    WITH del_task AS (DELETE FROM timetable.task WHERE task_id = $1 RETURNING task_id)
    SELECT EXISTS(SELECT 1 FROM del_task)
$_$;


ALTER FUNCTION timetable.delete_task(task_id bigint) OWNER TO postgres;

--
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 307
-- Name: FUNCTION delete_task(task_id bigint); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.delete_task(task_id bigint) IS 'Delete the task from a chain';


--
-- TOC entry 308 (class 1255 OID 30061)
-- Name: get_client_name(integer); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.get_client_name(integer) RETURNS text
    LANGUAGE sql
    AS $_$
    SELECT client_name FROM timetable.active_session WHERE server_pid = $1 LIMIT 1
$_$;


ALTER FUNCTION timetable.get_client_name(integer) OWNER TO postgres;

--
-- TOC entry 276 (class 1255 OID 30062)
-- Name: is_cron_in_time(timetable.cron, timestamp with time zone); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.is_cron_in_time(run_at timetable.cron, ts timestamp with time zone) RETURNS boolean
    LANGUAGE sql
    AS $$
    SELECT
    CASE WHEN run_at IS NULL THEN
        TRUE
    ELSE
        date_part('month', ts) = ANY(a.months)
        AND (date_part('dow', ts) = ANY(a.dow) OR date_part('isodow', ts) = ANY(a.dow))
        AND date_part('day', ts) = ANY(a.days)
        AND date_part('hour', ts) = ANY(a.hours)
        AND date_part('minute', ts) = ANY(a.mins)
    END
    FROM
        timetable.cron_split_to_arrays(run_at) a
$$;


ALTER FUNCTION timetable.is_cron_in_time(run_at timetable.cron, ts timestamp with time zone) OWNER TO postgres;

--
-- TOC entry 291 (class 1255 OID 30063)
-- Name: move_task_down(bigint); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.move_task_down(task_id bigint) RETURNS boolean
    LANGUAGE sql
    AS $_$
	WITH current_task (ct_chain_id, ct_id, ct_order) AS (
		SELECT chain_id, task_id, task_order FROM timetable.task WHERE task_id = $1
	),
	tasks(t_id, t_new_order) AS (
		SELECT task_id, COALESCE(LAG(task_order) OVER w, LEAD(task_order) OVER w)
		FROM timetable.task t, current_task ct
		WHERE chain_id = ct_chain_id AND (task_order > ct_order OR task_id = ct_id)
		WINDOW w AS (PARTITION BY chain_id ORDER BY ABS(task_order - ct_order))
		LIMIT 2
	),
	upd AS (
		UPDATE timetable.task t SET task_order = t_new_order
		FROM tasks WHERE tasks.t_id = t.task_id AND tasks.t_new_order IS NOT NULL
		RETURNING true
	)
	SELECT COUNT(*) > 0 FROM upd
$_$;


ALTER FUNCTION timetable.move_task_down(task_id bigint) OWNER TO postgres;

--
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 291
-- Name: FUNCTION move_task_down(task_id bigint); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.move_task_down(task_id bigint) IS 'Switch the order of the task execution with a following task within the chain';


--
-- TOC entry 309 (class 1255 OID 30064)
-- Name: move_task_up(bigint); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.move_task_up(task_id bigint) RETURNS boolean
    LANGUAGE sql
    AS $_$
	WITH current_task (ct_chain_id, ct_id, ct_order) AS (
		SELECT chain_id, task_id, task_order FROM timetable.task WHERE task_id = $1
	),
	tasks(t_id, t_new_order) AS (
		SELECT task_id, COALESCE(LAG(task_order) OVER w, LEAD(task_order) OVER w)
		FROM timetable.task t, current_task ct
		WHERE chain_id = ct_chain_id AND (task_order < ct_order OR task_id = ct_id)
		WINDOW w AS (PARTITION BY chain_id ORDER BY ABS(task_order - ct_order))
		LIMIT 2
	),
	upd AS (
		UPDATE timetable.task t SET task_order = t_new_order
		FROM tasks WHERE tasks.t_id = t.task_id AND tasks.t_new_order IS NOT NULL
		RETURNING true
	)
	SELECT COUNT(*) > 0 FROM upd
$_$;


ALTER FUNCTION timetable.move_task_up(task_id bigint) OWNER TO postgres;

--
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 309
-- Name: FUNCTION move_task_up(task_id bigint); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.move_task_up(task_id bigint) IS 'Switch the order of the task execution with a previous task within the chain';


--
-- TOC entry 310 (class 1255 OID 30065)
-- Name: next_run(timetable.cron); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.next_run(cron timetable.cron) RETURNS timestamp with time zone
    LANGUAGE sql STRICT
    AS $$
    SELECT * FROM timetable.cron_runs(now(), cron) LIMIT 1
$$;


ALTER FUNCTION timetable.next_run(cron timetable.cron) OWNER TO postgres;

--
-- TOC entry 311 (class 1255 OID 30066)
-- Name: notify_chain_start(bigint, text, interval); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.notify_chain_start(chain_id bigint, worker_name text, start_delay interval DEFAULT NULL::interval) RETURNS void
    LANGUAGE sql
    AS $$
    SELECT pg_notify(
        worker_name, 
        format('{"ConfigID": %s, "Command": "START", "Ts": %s, "Delay": %s}', 
            chain_id, 
            EXTRACT(epoch FROM clock_timestamp())::bigint,
            COALESCE(EXTRACT(epoch FROM start_delay)::bigint, 0)
        )
    )
$$;


ALTER FUNCTION timetable.notify_chain_start(chain_id bigint, worker_name text, start_delay interval) OWNER TO postgres;

--
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 311
-- Name: FUNCTION notify_chain_start(chain_id bigint, worker_name text, start_delay interval); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.notify_chain_start(chain_id bigint, worker_name text, start_delay interval) IS 'Send notification to the worker to start the chain';


--
-- TOC entry 312 (class 1255 OID 30067)
-- Name: notify_chain_stop(bigint, text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.notify_chain_stop(chain_id bigint, worker_name text) RETURNS void
    LANGUAGE sql
    AS $$ 
    SELECT pg_notify(
        worker_name, 
        format('{"ConfigID": %s, "Command": "STOP", "Ts": %s}', 
            chain_id, 
            EXTRACT(epoch FROM clock_timestamp())::bigint)
        )
$$;


ALTER FUNCTION timetable.notify_chain_stop(chain_id bigint, worker_name text) OWNER TO postgres;

--
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 312
-- Name: FUNCTION notify_chain_stop(chain_id bigint, worker_name text); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.notify_chain_stop(chain_id bigint, worker_name text) IS 'Send notification to the worker to stop the chain';


--
-- TOC entry 313 (class 1255 OID 30068)
-- Name: try_lock_client_name(bigint, text); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.try_lock_client_name(worker_pid bigint, worker_name text) RETURNS boolean
    LANGUAGE plpgsql STRICT
    AS $$
BEGIN
    IF pg_is_in_recovery() THEN
        RAISE NOTICE 'Cannot obtain lock on a replica. Please, use the primary node';
        RETURN FALSE;
    END IF;
    -- remove disconnected sessions
    DELETE
        FROM timetable.active_session
        WHERE server_pid NOT IN (
            SELECT pid
            FROM pg_catalog.pg_stat_activity
            WHERE application_name = 'pg_timetable'
        );
    DELETE 
        FROM timetable.active_chain 
        WHERE client_name NOT IN (
            SELECT client_name FROM timetable.active_session
        );
    -- check if there any active sessions with the client name but different client pid
    PERFORM 1
        FROM timetable.active_session s
        WHERE
            s.client_pid <> worker_pid
            AND s.client_name = worker_name
        LIMIT 1;
    IF FOUND THEN
        RAISE NOTICE 'Another client is already connected to server with name: %', worker_name;
        RETURN FALSE;
    END IF;
    -- insert current session information
    INSERT INTO timetable.active_session(client_pid, client_name, server_pid) VALUES (worker_pid, worker_name, pg_backend_pid());
    RETURN TRUE;
END;
$$;


ALTER FUNCTION timetable.try_lock_client_name(worker_pid bigint, worker_name text) OWNER TO postgres;

--
-- TOC entry 314 (class 1255 OID 30069)
-- Name: validate_json_schema(jsonb, jsonb, jsonb); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb DEFAULT NULL::jsonb) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE
    AS $_$
DECLARE
  prop text;
  item jsonb;
  path text[];
  types text[];
  pattern text;
  props text[];
BEGIN

  IF root_schema IS NULL THEN
    root_schema = schema;
  END IF;

  IF schema ? 'type' THEN
    IF jsonb_typeof(schema->'type') = 'array' THEN
      types = ARRAY(SELECT jsonb_array_elements_text(schema->'type'));
    ELSE
      types = ARRAY[schema->>'type'];
    END IF;
    IF (SELECT NOT bool_or(timetable._validate_json_schema_type(type, data)) FROM unnest(types) type) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'properties' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'properties') LOOP
      IF data ? prop AND NOT timetable.validate_json_schema(schema->'properties'->prop, data->prop, root_schema) THEN
        RETURN false;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'required' AND jsonb_typeof(data) = 'object' THEN
    IF NOT ARRAY(SELECT jsonb_object_keys(data)) @>
           ARRAY(SELECT jsonb_array_elements_text(schema->'required')) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'items' AND jsonb_typeof(data) = 'array' THEN
    IF jsonb_typeof(schema->'items') = 'object' THEN
      FOR item IN SELECT jsonb_array_elements(data) LOOP
        IF NOT timetable.validate_json_schema(schema->'items', item, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    ELSE
      IF NOT (
        SELECT bool_and(i > jsonb_array_length(schema->'items') OR timetable.validate_json_schema(schema->'items'->(i::int - 1), elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
      ) THEN
        RETURN false;
      END IF;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'boolean' and NOT (schema->'additionalItems')::text::boolean AND jsonb_typeof(schema->'items') = 'array' THEN
    IF jsonb_array_length(data) > jsonb_array_length(schema->'items') THEN
      RETURN false;
    END IF;
  END IF;

  IF jsonb_typeof(schema->'additionalItems') = 'object' THEN
    IF NOT (
        SELECT bool_and(timetable.validate_json_schema(schema->'additionalItems', elem, root_schema))
        FROM jsonb_array_elements(data) WITH ORDINALITY AS t(elem, i)
        WHERE i > jsonb_array_length(schema->'items')
      ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minimum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric < (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maximum' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric > (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMinimum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'minimum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'exclusiveMaximum')::text::bool, FALSE) THEN
    IF data::text::numeric = (schema->>'maximum')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'anyOf' THEN
    IF NOT (SELECT bool_or(timetable.validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'anyOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'allOf' THEN
    IF NOT (SELECT bool_and(timetable.validate_json_schema(sub_schema, data, root_schema)) FROM jsonb_array_elements(schema->'allOf') sub_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'oneOf' THEN
    IF 1 != (SELECT COUNT(*) FROM jsonb_array_elements(schema->'oneOf') sub_schema WHERE timetable.validate_json_schema(sub_schema, data, root_schema)) THEN
      RETURN false;
    END IF;
  END IF;

  IF COALESCE((schema->'uniqueItems')::text::boolean, false) THEN
    IF (SELECT COUNT(*) FROM jsonb_array_elements(data)) != (SELECT count(DISTINCT val) FROM jsonb_array_elements(data) val) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'additionalProperties' AND jsonb_typeof(data) = 'object' THEN
    props := ARRAY(
      SELECT key
      FROM jsonb_object_keys(data) key
      WHERE key NOT IN (SELECT jsonb_object_keys(schema->'properties'))
        AND NOT EXISTS (SELECT * FROM jsonb_object_keys(schema->'patternProperties') pat WHERE key ~ pat)
    );
    IF jsonb_typeof(schema->'additionalProperties') = 'boolean' THEN
      IF NOT (schema->'additionalProperties')::text::boolean AND jsonb_typeof(data) = 'object' AND NOT props <@ ARRAY(SELECT jsonb_object_keys(schema->'properties')) THEN
        RETURN false;
      END IF;
    ELSEIF NOT (
      SELECT bool_and(timetable.validate_json_schema(schema->'additionalProperties', data->key, root_schema))
      FROM unnest(props) key
    ) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? '$ref' THEN
    path := ARRAY(
      SELECT regexp_replace(regexp_replace(path_part, '~1', '/'), '~0', '~')
      FROM UNNEST(regexp_split_to_array(schema->>'$ref', '/')) path_part
    );
    -- ASSERT path[1] = '#', 'only refs anchored at the root are supported';
    IF NOT timetable.validate_json_schema(root_schema #> path[2:array_length(path, 1)], data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'enum' THEN
    IF NOT EXISTS (SELECT * FROM jsonb_array_elements(schema->'enum') val WHERE val = data) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') < (schema->>'minLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxLength' AND jsonb_typeof(data) = 'string' THEN
    IF char_length(data #>> '{}') > (schema->>'maxLength')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'not' THEN
    IF timetable.validate_json_schema(schema->'not', data, root_schema) THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) > (schema->>'maxProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minProperties' AND jsonb_typeof(data) = 'object' THEN
    IF (SELECT count(*) FROM jsonb_object_keys(data)) < (schema->>'minProperties')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'maxItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) > (schema->>'maxItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'minItems' AND jsonb_typeof(data) = 'array' THEN
    IF (SELECT count(*) FROM jsonb_array_elements(data)) < (schema->>'minItems')::numeric THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'dependencies' THEN
    FOR prop IN SELECT jsonb_object_keys(schema->'dependencies') LOOP
      IF data ? prop THEN
        IF jsonb_typeof(schema->'dependencies'->prop) = 'array' THEN
          IF NOT (SELECT bool_and(data ? dep) FROM jsonb_array_elements_text(schema->'dependencies'->prop) dep) THEN
            RETURN false;
          END IF;
        ELSE
          IF NOT timetable.validate_json_schema(schema->'dependencies'->prop, data, root_schema) THEN
            RETURN false;
          END IF;
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF schema ? 'pattern' AND jsonb_typeof(data) = 'string' THEN
    IF (data #>> '{}') !~ (schema->>'pattern') THEN
      RETURN false;
    END IF;
  END IF;

  IF schema ? 'patternProperties' AND jsonb_typeof(data) = 'object' THEN
    FOR prop IN SELECT jsonb_object_keys(data) LOOP
      FOR pattern IN SELECT jsonb_object_keys(schema->'patternProperties') LOOP
        RAISE NOTICE 'prop %s, pattern %, schema %', prop, pattern, schema->'patternProperties'->pattern;
        IF prop ~ pattern AND NOT timetable.validate_json_schema(schema->'patternProperties'->pattern, data->prop, root_schema) THEN
          RETURN false;
        END IF;
      END LOOP;
    END LOOP;
  END IF;

  IF schema ? 'multipleOf' AND jsonb_typeof(data) = 'number' THEN
    IF data::text::numeric % (schema->>'multipleOf')::numeric != 0 THEN
      RETURN false;
    END IF;
  END IF;

  RETURN true;
END;
$_$;


ALTER FUNCTION timetable.validate_json_schema(schema jsonb, data jsonb, root_schema jsonb) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 221 (class 1259 OID 30071)
-- Name: address; Type: TABLE; Schema: account; Owner: postgres
--

CREATE TABLE account.address (
    address_id integer NOT NULL,
    user_id integer NOT NULL,
    address character varying(50) NOT NULL,
    city character varying(20) NOT NULL,
    postal_code character varying(30) NOT NULL,
    country character varying(30) NOT NULL
);


ALTER TABLE account.address OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 30074)
-- Name: address_address_id_seq; Type: SEQUENCE; Schema: account; Owner: postgres
--

CREATE SEQUENCE account.address_address_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.address_address_id_seq OWNER TO postgres;

--
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 222
-- Name: address_address_id_seq; Type: SEQUENCE OWNED BY; Schema: account; Owner: postgres
--

ALTER SEQUENCE account.address_address_id_seq OWNED BY account.address.address_id;


--
-- TOC entry 223 (class 1259 OID 30075)
-- Name: address_user_id_seq; Type: SEQUENCE; Schema: account; Owner: postgres
--

CREATE SEQUENCE account.address_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.address_user_id_seq OWNER TO postgres;

--
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 223
-- Name: address_user_id_seq; Type: SEQUENCE OWNED BY; Schema: account; Owner: postgres
--

ALTER SEQUENCE account.address_user_id_seq OWNED BY account.address.user_id;


--
-- TOC entry 224 (class 1259 OID 30076)
-- Name: payment; Type: TABLE; Schema: account; Owner: postgres
--

CREATE TABLE account.payment (
    payment_id integer NOT NULL,
    user_id integer NOT NULL,
    payment_type character varying(30) DEFAULT 'Visa'::character varying NOT NULL,
    provider character varying(30),
    account_no character varying(20),
    expiry date,
    CONSTRAINT payment_check CHECK (((payment_type)::text = ANY (ARRAY[('Credit Card'::character varying)::text, ('Debit Card'::character varying)::text, ('Bank Account'::character varying)::text, ('Visa'::character varying)::text])))
);


ALTER TABLE account.payment OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 30080)
-- Name: payment_register_pay_id_seq; Type: SEQUENCE; Schema: account; Owner: postgres
--

CREATE SEQUENCE account.payment_register_pay_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.payment_register_pay_id_seq OWNER TO postgres;

--
-- TOC entry 5220 (class 0 OID 0)
-- Dependencies: 225
-- Name: payment_register_pay_id_seq; Type: SEQUENCE OWNED BY; Schema: account; Owner: postgres
--

ALTER SEQUENCE account.payment_register_pay_id_seq OWNED BY account.payment.payment_id;


--
-- TOC entry 226 (class 1259 OID 30081)
-- Name: payment_register_user_id_seq; Type: SEQUENCE; Schema: account; Owner: postgres
--

CREATE SEQUENCE account.payment_register_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.payment_register_user_id_seq OWNER TO postgres;

--
-- TOC entry 5221 (class 0 OID 0)
-- Dependencies: 226
-- Name: payment_register_user_id_seq; Type: SEQUENCE OWNED BY; Schema: account; Owner: postgres
--

ALTER SEQUENCE account.payment_register_user_id_seq OWNED BY account.payment.user_id;


--
-- TOC entry 227 (class 1259 OID 30082)
-- Name: role; Type: TABLE; Schema: account; Owner: postgres
--

CREATE TABLE account.role (
    role_id integer NOT NULL,
    name character varying(255)
);


ALTER TABLE account.role OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 30085)
-- Name: role_role_id_seq; Type: SEQUENCE; Schema: account; Owner: postgres
--

CREATE SEQUENCE account.role_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.role_role_id_seq OWNER TO postgres;

--
-- TOC entry 5222 (class 0 OID 0)
-- Dependencies: 228
-- Name: role_role_id_seq; Type: SEQUENCE OWNED BY; Schema: account; Owner: postgres
--

ALTER SEQUENCE account.role_role_id_seq OWNED BY account.role.role_id;


--
-- TOC entry 229 (class 1259 OID 30086)
-- Name: user; Type: TABLE; Schema: account; Owner: postgres
--

CREATE TABLE account."user" (
    user_id integer NOT NULL,
    username character varying(30) NOT NULL,
    password character varying(40) NOT NULL,
    first_name character varying(50) NOT NULL,
    last_name character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    telephone character varying(20) NOT NULL
);


ALTER TABLE account."user" OWNER TO postgres;

--
-- TOC entry 230 (class 1259 OID 30091)
-- Name: user_role; Type: TABLE; Schema: account; Owner: postgres
--

CREATE TABLE account.user_role (
    user_id integer NOT NULL,
    role_id integer NOT NULL
);


ALTER TABLE account.user_role OWNER TO postgres;

--
-- TOC entry 231 (class 1259 OID 30094)
-- Name: user_user_id_seq; Type: SEQUENCE; Schema: account; Owner: postgres
--

CREATE SEQUENCE account.user_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    MINVALUE 0
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.user_user_id_seq OWNER TO postgres;

--
-- TOC entry 5223 (class 0 OID 0)
-- Dependencies: 231
-- Name: user_user_id_seq; Type: SEQUENCE OWNED BY; Schema: account; Owner: postgres
--

ALTER SEQUENCE account.user_user_id_seq OWNED BY account."user".user_id;


--
-- TOC entry 232 (class 1259 OID 30095)
-- Name: delivery_provider; Type: TABLE; Schema: delivery; Owner: postgres
--

CREATE TABLE delivery.delivery_provider (
    delivery_provider_id integer NOT NULL,
    name character varying(50) NOT NULL,
    contact_email character varying(70) NOT NULL,
    contact_phone character varying(20) NOT NULL,
    website_url character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now()
);


ALTER TABLE delivery.delivery_provider OWNER TO postgres;

--
-- TOC entry 233 (class 1259 OID 30100)
-- Name: delivery_provider_delivery_provider_id_seq; Type: SEQUENCE; Schema: delivery; Owner: postgres
--

CREATE SEQUENCE delivery.delivery_provider_delivery_provider_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE delivery.delivery_provider_delivery_provider_id_seq OWNER TO postgres;

--
-- TOC entry 5224 (class 0 OID 0)
-- Dependencies: 233
-- Name: delivery_provider_delivery_provider_id_seq; Type: SEQUENCE OWNED BY; Schema: delivery; Owner: postgres
--

ALTER SEQUENCE delivery.delivery_provider_delivery_provider_id_seq OWNED BY delivery.delivery_provider.delivery_provider_id;


--
-- TOC entry 234 (class 1259 OID 30101)
-- Name: category; Type: TABLE; Schema: product; Owner: postgres
--

CREATE TABLE product.category (
    category_id integer NOT NULL,
    name character varying(30) NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now(),
    parent_id integer
);


ALTER TABLE product.category OWNER TO postgres;

--
-- TOC entry 235 (class 1259 OID 30109)
-- Name: category_category_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.category_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.category_category_id_seq OWNER TO postgres;

--
-- TOC entry 5225 (class 0 OID 0)
-- Dependencies: 235
-- Name: category_category_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.category_category_id_seq OWNED BY product.category.category_id;


--
-- TOC entry 236 (class 1259 OID 30110)
-- Name: category_parent_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.category_parent_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.category_parent_id_seq OWNER TO postgres;

--
-- TOC entry 5226 (class 0 OID 0)
-- Dependencies: 236
-- Name: category_parent_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.category_parent_id_seq OWNED BY product.category.parent_id;


--
-- TOC entry 237 (class 1259 OID 30111)
-- Name: discount; Type: TABLE; Schema: product; Owner: postgres
--

CREATE TABLE product.discount (
    discount_id integer NOT NULL,
    name character varying(40) NOT NULL,
    description text,
    discount_percent real NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    store_id integer NOT NULL,
    active boolean
);


ALTER TABLE product.discount OWNER TO postgres;

--
-- TOC entry 238 (class 1259 OID 30119)
-- Name: discount_discount_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.discount_discount_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.discount_discount_id_seq OWNER TO postgres;

--
-- TOC entry 5227 (class 0 OID 0)
-- Dependencies: 238
-- Name: discount_discount_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.discount_discount_id_seq OWNED BY product.discount.discount_id;


--
-- TOC entry 239 (class 1259 OID 30120)
-- Name: inventory; Type: TABLE; Schema: product; Owner: postgres
--

CREATE TABLE product.inventory (
    inventory_id integer NOT NULL,
    product_id integer,
    quantity integer DEFAULT 50 NOT NULL,
    minimum_stock integer DEFAULT 10 NOT NULL,
    status boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE product.inventory OWNER TO postgres;

--
-- TOC entry 240 (class 1259 OID 30127)
-- Name: inventory_inventory_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.inventory_inventory_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.inventory_inventory_id_seq OWNER TO postgres;

--
-- TOC entry 5228 (class 0 OID 0)
-- Dependencies: 240
-- Name: inventory_inventory_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.inventory_inventory_id_seq OWNED BY product.inventory.inventory_id;


--
-- TOC entry 241 (class 1259 OID 30128)
-- Name: inventory_product_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.inventory_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.inventory_product_id_seq OWNER TO postgres;

--
-- TOC entry 5229 (class 0 OID 0)
-- Dependencies: 241
-- Name: inventory_product_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.inventory_product_id_seq OWNED BY product.inventory.product_id;


--
-- TOC entry 242 (class 1259 OID 30129)
-- Name: product; Type: TABLE; Schema: product; Owner: postgres
--

CREATE TABLE product.product (
    product_id integer NOT NULL,
    name character varying(50) NOT NULL,
    image text,
    description text,
    sku character varying(30),
    category_id integer NOT NULL,
    price double precision NOT NULL,
    discount_id integer,
    store_id integer NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now()
);


ALTER TABLE product.product OWNER TO postgres;

--
-- TOC entry 243 (class 1259 OID 30137)
-- Name: prodinfo; Type: VIEW; Schema: product; Owner: postgres
--

CREATE VIEW product.prodinfo AS
 SELECT p.name,
    p.image AS picture,
    i.inventory_id,
    i.quantity
   FROM (product.product p
     JOIN product.inventory i USING (product_id));


ALTER VIEW product.prodinfo OWNER TO postgres;

--
-- TOC entry 244 (class 1259 OID 30141)
-- Name: product_category_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.product_category_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.product_category_id_seq OWNER TO postgres;

--
-- TOC entry 5230 (class 0 OID 0)
-- Dependencies: 244
-- Name: product_category_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.product_category_id_seq OWNED BY product.product.category_id;


--
-- TOC entry 245 (class 1259 OID 30142)
-- Name: product_discount_Id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product."product_discount_Id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product."product_discount_Id_seq" OWNER TO postgres;

--
-- TOC entry 5231 (class 0 OID 0)
-- Dependencies: 245
-- Name: product_discount_Id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product."product_discount_Id_seq" OWNED BY product.product.discount_id;


--
-- TOC entry 246 (class 1259 OID 30143)
-- Name: product_product_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.product_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.product_product_id_seq OWNER TO postgres;

--
-- TOC entry 5232 (class 0 OID 0)
-- Dependencies: 246
-- Name: product_product_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.product_product_id_seq OWNED BY product.product.product_id;


--
-- TOC entry 247 (class 1259 OID 30144)
-- Name: product_store_id_seq; Type: SEQUENCE; Schema: product; Owner: postgres
--

CREATE SEQUENCE product.product_store_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE product.product_store_id_seq OWNER TO postgres;

--
-- TOC entry 5233 (class 0 OID 0)
-- Dependencies: 247
-- Name: product_store_id_seq; Type: SEQUENCE OWNED BY; Schema: product; Owner: postgres
--

ALTER SEQUENCE product.product_store_id_seq OWNED BY product.product.store_id;


--
-- TOC entry 275 (class 1259 OID 30446)
-- Name: temp_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.temp_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.temp_seq OWNER TO postgres;

--
-- TOC entry 248 (class 1259 OID 30145)
-- Name: cart_item; Type: TABLE; Schema: shopping; Owner: postgres
--

CREATE TABLE shopping.cart_item (
    cart_item_id integer NOT NULL,
    user_id integer,
    product_id integer,
    quantity integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now()
);


ALTER TABLE shopping.cart_item OWNER TO postgres;

--
-- TOC entry 249 (class 1259 OID 30150)
-- Name: cart_item_cart_item_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.cart_item_cart_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.cart_item_cart_item_id_seq OWNER TO postgres;

--
-- TOC entry 5234 (class 0 OID 0)
-- Dependencies: 249
-- Name: cart_item_cart_item_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.cart_item_cart_item_id_seq OWNED BY shopping.cart_item.cart_item_id;


--
-- TOC entry 250 (class 1259 OID 30151)
-- Name: cart_item_product_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.cart_item_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.cart_item_product_id_seq OWNER TO postgres;

--
-- TOC entry 5235 (class 0 OID 0)
-- Dependencies: 250
-- Name: cart_item_product_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.cart_item_product_id_seq OWNED BY shopping.cart_item.product_id;


--
-- TOC entry 251 (class 1259 OID 30152)
-- Name: cart_item_session_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.cart_item_session_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.cart_item_session_id_seq OWNER TO postgres;

--
-- TOC entry 5236 (class 0 OID 0)
-- Dependencies: 251
-- Name: cart_item_session_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.cart_item_session_id_seq OWNED BY shopping.cart_item.user_id;


--
-- TOC entry 252 (class 1259 OID 30153)
-- Name: order_detail; Type: TABLE; Schema: shopping; Owner: postgres
--

CREATE TABLE shopping.order_detail (
    order_detail_id integer NOT NULL,
    user_id integer NOT NULL,
    total double precision DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    address_id integer NOT NULL,
    payment_id integer NOT NULL
);


ALTER TABLE shopping.order_detail OWNER TO postgres;

--
-- TOC entry 253 (class 1259 OID 30159)
-- Name: order_detail_order_detail_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.order_detail_order_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.order_detail_order_detail_id_seq OWNER TO postgres;

--
-- TOC entry 5237 (class 0 OID 0)
-- Dependencies: 253
-- Name: order_detail_order_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.order_detail_order_detail_id_seq OWNED BY shopping.order_detail.order_detail_id;


--
-- TOC entry 254 (class 1259 OID 30160)
-- Name: order_detail_user_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.order_detail_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.order_detail_user_id_seq OWNER TO postgres;

--
-- TOC entry 5238 (class 0 OID 0)
-- Dependencies: 254
-- Name: order_detail_user_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.order_detail_user_id_seq OWNED BY shopping.order_detail.user_id;


--
-- TOC entry 255 (class 1259 OID 30161)
-- Name: order_item; Type: TABLE; Schema: shopping; Owner: postgres
--

CREATE TABLE shopping.order_item (
    order_item_id integer NOT NULL,
    order_detail_id integer NOT NULL,
    product_id integer NOT NULL,
    quantity integer NOT NULL,
    condition character varying(40) DEFAULT 'Pending Confirmation'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now() NOT NULL,
    delivery_provider_id integer,
    delivery_method_id integer,
    delivery_method character varying(255),
    CONSTRAINT condition_check CHECK (((condition)::text = ANY ((ARRAY['Pending Confirmation'::character varying, 'Pending Pickup'::character varying, 'Complete Setup'::character varying, 'In transit'::character varying, 'Delivered'::character varying, 'Return Initiated'::character varying, 'Order Cancelled'::character varying])::text[])))
);


ALTER TABLE shopping.order_item OWNER TO postgres;

--
-- TOC entry 256 (class 1259 OID 30168)
-- Name: order_item_order_detail_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.order_item_order_detail_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.order_item_order_detail_id_seq OWNER TO postgres;

--
-- TOC entry 5239 (class 0 OID 0)
-- Dependencies: 256
-- Name: order_item_order_detail_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.order_item_order_detail_id_seq OWNED BY shopping.order_item.order_detail_id;


--
-- TOC entry 257 (class 1259 OID 30169)
-- Name: order_item_order_item_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.order_item_order_item_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.order_item_order_item_id_seq OWNER TO postgres;

--
-- TOC entry 5240 (class 0 OID 0)
-- Dependencies: 257
-- Name: order_item_order_item_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.order_item_order_item_id_seq OWNED BY shopping.order_item.order_item_id;


--
-- TOC entry 258 (class 1259 OID 30170)
-- Name: order_item_product_id_seq; Type: SEQUENCE; Schema: shopping; Owner: postgres
--

CREATE SEQUENCE shopping.order_item_product_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE shopping.order_item_product_id_seq OWNER TO postgres;

--
-- TOC entry 5241 (class 0 OID 0)
-- Dependencies: 258
-- Name: order_item_product_id_seq; Type: SEQUENCE OWNED BY; Schema: shopping; Owner: postgres
--

ALTER SEQUENCE shopping.order_item_product_id_seq OWNED BY shopping.order_item.product_id;


--
-- TOC entry 259 (class 1259 OID 30171)
-- Name: delivery_method; Type: TABLE; Schema: store; Owner: postgres
--

CREATE TABLE store.delivery_method (
    delivery_method_id integer NOT NULL,
    store_id integer NOT NULL,
    method_name character varying(30) DEFAULT 'business'::character varying NOT NULL,
    price double precision NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now(),
    CONSTRAINT method_name_check CHECK (((method_name)::text = ANY (ARRAY[('business'::character varying)::text, ('fast'::character varying)::text, ('express'::character varying)::text])))
);


ALTER TABLE store.delivery_method OWNER TO postgres;

--
-- TOC entry 260 (class 1259 OID 30179)
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE; Schema: store; Owner: postgres
--

CREATE SEQUENCE store.delivery_methods_delivery_method_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE store.delivery_methods_delivery_method_id_seq OWNER TO postgres;

--
-- TOC entry 5242 (class 0 OID 0)
-- Dependencies: 260
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE OWNED BY; Schema: store; Owner: postgres
--

ALTER SEQUENCE store.delivery_methods_delivery_method_id_seq OWNED BY store.delivery_method.delivery_method_id;


--
-- TOC entry 261 (class 1259 OID 30180)
-- Name: delivery_methods_store_id_seq; Type: SEQUENCE; Schema: store; Owner: postgres
--

CREATE SEQUENCE store.delivery_methods_store_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE store.delivery_methods_store_id_seq OWNER TO postgres;

--
-- TOC entry 5243 (class 0 OID 0)
-- Dependencies: 261
-- Name: delivery_methods_store_id_seq; Type: SEQUENCE OWNED BY; Schema: store; Owner: postgres
--

ALTER SEQUENCE store.delivery_methods_store_id_seq OWNED BY store.delivery_method.store_id;


--
-- TOC entry 262 (class 1259 OID 30181)
-- Name: store; Type: TABLE; Schema: store; Owner: postgres
--

CREATE TABLE store.store (
    store_id integer NOT NULL,
    user_id integer NOT NULL,
    name character varying(30) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now()
);


ALTER TABLE store.store OWNER TO postgres;

--
-- TOC entry 263 (class 1259 OID 30188)
-- Name: store_store_id_seq; Type: SEQUENCE; Schema: store; Owner: postgres
--

CREATE SEQUENCE store.store_store_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE store.store_store_id_seq OWNER TO postgres;

--
-- TOC entry 5244 (class 0 OID 0)
-- Dependencies: 263
-- Name: store_store_id_seq; Type: SEQUENCE OWNED BY; Schema: store; Owner: postgres
--

ALTER SEQUENCE store.store_store_id_seq OWNED BY store.store.store_id;


--
-- TOC entry 264 (class 1259 OID 30189)
-- Name: store_user_id_seq; Type: SEQUENCE; Schema: store; Owner: postgres
--

CREATE SEQUENCE store.store_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE store.store_user_id_seq OWNER TO postgres;

--
-- TOC entry 5245 (class 0 OID 0)
-- Dependencies: 264
-- Name: store_user_id_seq; Type: SEQUENCE OWNED BY; Schema: store; Owner: postgres
--

ALTER SEQUENCE store.store_user_id_seq OWNED BY store.store.user_id;


--
-- TOC entry 265 (class 1259 OID 30190)
-- Name: active_chain; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE UNLOGGED TABLE timetable.active_chain (
    chain_id bigint NOT NULL,
    client_name text NOT NULL,
    started_at timestamp with time zone DEFAULT now()
);


ALTER TABLE timetable.active_chain OWNER TO postgres;

--
-- TOC entry 5246 (class 0 OID 0)
-- Dependencies: 265
-- Name: TABLE active_chain; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.active_chain IS 'Stores information about active chains within session';


--
-- TOC entry 266 (class 1259 OID 30196)
-- Name: active_session; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE UNLOGGED TABLE timetable.active_session (
    client_pid bigint NOT NULL,
    server_pid bigint NOT NULL,
    client_name text NOT NULL,
    started_at timestamp with time zone DEFAULT now()
);


ALTER TABLE timetable.active_session OWNER TO postgres;

--
-- TOC entry 5247 (class 0 OID 0)
-- Dependencies: 266
-- Name: TABLE active_session; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.active_session IS 'Stores information about active sessions';


--
-- TOC entry 267 (class 1259 OID 30202)
-- Name: chain; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.chain (
    chain_id bigint NOT NULL,
    chain_name text NOT NULL,
    run_at timetable.cron,
    max_instances integer,
    timeout integer DEFAULT 0,
    live boolean DEFAULT false,
    self_destruct boolean DEFAULT false,
    exclusive_execution boolean DEFAULT false,
    client_name text,
    on_error text
);


ALTER TABLE timetable.chain OWNER TO postgres;

--
-- TOC entry 5248 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE chain; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.chain IS 'Stores information about chains schedule';


--
-- TOC entry 5249 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.run_at; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.run_at IS 'Extended CRON-style time notation the chain has to be run at';


--
-- TOC entry 5250 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.max_instances; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.max_instances IS 'Number of instances (clients) this chain can run in parallel';


--
-- TOC entry 5251 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.timeout; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.timeout IS 'Abort any chain that takes more than the specified number of milliseconds';


--
-- TOC entry 5252 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.live; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.live IS 'Indication that the chain is ready to run, set to FALSE to pause execution';


--
-- TOC entry 5253 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.self_destruct; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.self_destruct IS 'Indication that this chain will delete itself after successful run';


--
-- TOC entry 5254 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.exclusive_execution; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.exclusive_execution IS 'All parallel chains should be paused while executing this chain';


--
-- TOC entry 5255 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.client_name; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.client_name IS 'Only client with this name is allowed to run this chain, set to NULL to allow any client';


--
-- TOC entry 268 (class 1259 OID 30211)
-- Name: chain_chain_id_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.chain_chain_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE timetable.chain_chain_id_seq OWNER TO postgres;

--
-- TOC entry 5256 (class 0 OID 0)
-- Dependencies: 268
-- Name: chain_chain_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.chain_chain_id_seq OWNED BY timetable.chain.chain_id;


--
-- TOC entry 269 (class 1259 OID 30212)
-- Name: execution_log; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.execution_log (
    chain_id bigint,
    task_id bigint,
    txid bigint NOT NULL,
    last_run timestamp with time zone DEFAULT now(),
    finished timestamp with time zone,
    pid bigint,
    returncode integer,
    ignore_error boolean,
    kind timetable.command_kind,
    command text,
    output text,
    client_name text NOT NULL
);


ALTER TABLE timetable.execution_log OWNER TO postgres;

--
-- TOC entry 5257 (class 0 OID 0)
-- Dependencies: 269
-- Name: TABLE execution_log; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.execution_log IS 'Stores log entries of executed tasks and chains';


--
-- TOC entry 270 (class 1259 OID 30218)
-- Name: log; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.log (
    ts timestamp with time zone DEFAULT now(),
    pid integer NOT NULL,
    log_level timetable.log_type NOT NULL,
    client_name text DEFAULT timetable.get_client_name(pg_backend_pid()),
    message text,
    message_data jsonb
);


ALTER TABLE timetable.log OWNER TO postgres;

--
-- TOC entry 5258 (class 0 OID 0)
-- Dependencies: 270
-- Name: TABLE log; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.log IS 'Stores log entries of active sessions';


--
-- TOC entry 271 (class 1259 OID 30225)
-- Name: migration; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.migration (
    id bigint NOT NULL,
    version text NOT NULL
);


ALTER TABLE timetable.migration OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 30230)
-- Name: parameter; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.parameter (
    task_id bigint NOT NULL,
    order_id integer NOT NULL,
    value jsonb,
    CONSTRAINT parameter_order_id_check CHECK ((order_id > 0))
);


ALTER TABLE timetable.parameter OWNER TO postgres;

--
-- TOC entry 5259 (class 0 OID 0)
-- Dependencies: 272
-- Name: TABLE parameter; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.parameter IS 'Stores parameters passed as arguments to a chain task';


--
-- TOC entry 273 (class 1259 OID 30236)
-- Name: task; Type: TABLE; Schema: timetable; Owner: postgres
--

CREATE TABLE timetable.task (
    task_id bigint NOT NULL,
    chain_id bigint,
    task_order double precision NOT NULL,
    task_name text,
    kind timetable.command_kind DEFAULT 'SQL'::timetable.command_kind NOT NULL,
    command text NOT NULL,
    run_as text,
    database_connection text,
    ignore_error boolean DEFAULT false NOT NULL,
    autonomous boolean DEFAULT false NOT NULL,
    timeout integer DEFAULT 0
);


ALTER TABLE timetable.task OWNER TO postgres;

--
-- TOC entry 5260 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE task; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.task IS 'Holds information about chain elements aka tasks';


--
-- TOC entry 5261 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.chain_id; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.chain_id IS 'Link to the chain, if NULL task considered to be disabled';


--
-- TOC entry 5262 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.task_order; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.task_order IS 'Indicates the order of task within a chain';


--
-- TOC entry 5263 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.kind; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.kind IS 'Indicates whether "command" is SQL, built-in function or an external program';


--
-- TOC entry 5264 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.command; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.command IS 'Contains either an SQL command, or command string to be executed';


--
-- TOC entry 5265 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.run_as; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.run_as IS 'Role name to run task as. Uses SET ROLE for SQL commands';


--
-- TOC entry 5266 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.ignore_error; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.ignore_error IS 'Indicates whether a next task in a chain can be executed regardless of the success of the current one';


--
-- TOC entry 5267 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.timeout; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.timeout IS 'Abort any task within a chain that takes more than the specified number of milliseconds';


--
-- TOC entry 274 (class 1259 OID 30245)
-- Name: task_task_id_seq; Type: SEQUENCE; Schema: timetable; Owner: postgres
--

CREATE SEQUENCE timetable.task_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE timetable.task_task_id_seq OWNER TO postgres;

--
-- TOC entry 5268 (class 0 OID 0)
-- Dependencies: 274
-- Name: task_task_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.task_task_id_seq OWNED BY timetable.task.task_id;


--
-- TOC entry 4854 (class 2604 OID 30246)
-- Name: address address_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.address ALTER COLUMN address_id SET DEFAULT nextval('account.address_address_id_seq'::regclass);


--
-- TOC entry 4855 (class 2604 OID 30247)
-- Name: payment payment_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.payment ALTER COLUMN payment_id SET DEFAULT nextval('account.payment_register_pay_id_seq'::regclass);


--
-- TOC entry 4857 (class 2604 OID 30248)
-- Name: role role_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.role ALTER COLUMN role_id SET DEFAULT nextval('account.role_role_id_seq'::regclass);


--
-- TOC entry 4858 (class 2604 OID 30472)
-- Name: user user_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account."user" ALTER COLUMN user_id SET DEFAULT nextval('account.user_user_id_seq'::regclass);


--
-- TOC entry 4861 (class 2604 OID 30250)
-- Name: delivery_provider delivery_provider_id; Type: DEFAULT; Schema: delivery; Owner: postgres
--

ALTER TABLE ONLY delivery.delivery_provider ALTER COLUMN delivery_provider_id SET DEFAULT nextval('delivery.delivery_provider_delivery_provider_id_seq'::regclass);


--
-- TOC entry 4864 (class 2604 OID 30251)
-- Name: category category_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.category ALTER COLUMN category_id SET DEFAULT nextval('product.category_category_id_seq'::regclass);


--
-- TOC entry 4868 (class 2604 OID 30252)
-- Name: discount discount_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.discount ALTER COLUMN discount_id SET DEFAULT nextval('product.discount_discount_id_seq'::regclass);


--
-- TOC entry 4872 (class 2604 OID 30253)
-- Name: inventory inventory_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.inventory ALTER COLUMN inventory_id SET DEFAULT nextval('product.inventory_inventory_id_seq'::regclass);


--
-- TOC entry 4878 (class 2604 OID 30254)
-- Name: product product_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product ALTER COLUMN product_id SET DEFAULT nextval('product.product_product_id_seq'::regclass);


--
-- TOC entry 4882 (class 2604 OID 30255)
-- Name: cart_item cart_item_id; Type: DEFAULT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item ALTER COLUMN cart_item_id SET DEFAULT nextval('shopping.cart_item_cart_item_id_seq'::regclass);


--
-- TOC entry 4885 (class 2604 OID 30256)
-- Name: order_detail order_detail_id; Type: DEFAULT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail ALTER COLUMN order_detail_id SET DEFAULT nextval('shopping.order_detail_order_detail_id_seq'::regclass);


--
-- TOC entry 4889 (class 2604 OID 30257)
-- Name: order_item order_item_id; Type: DEFAULT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item ALTER COLUMN order_item_id SET DEFAULT nextval('shopping.order_item_order_item_id_seq'::regclass);


--
-- TOC entry 4893 (class 2604 OID 30258)
-- Name: delivery_method delivery_method_id; Type: DEFAULT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.delivery_method ALTER COLUMN delivery_method_id SET DEFAULT nextval('store.delivery_methods_delivery_method_id_seq'::regclass);


--
-- TOC entry 4898 (class 2604 OID 30259)
-- Name: store store_id; Type: DEFAULT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store ALTER COLUMN store_id SET DEFAULT nextval('store.store_store_id_seq'::regclass);


--
-- TOC entry 4903 (class 2604 OID 30260)
-- Name: chain chain_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain ALTER COLUMN chain_id SET DEFAULT nextval('timetable.chain_chain_id_seq'::regclass);


--
-- TOC entry 4911 (class 2604 OID 30261)
-- Name: task task_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task ALTER COLUMN task_id SET DEFAULT nextval('timetable.task_task_id_seq'::regclass);


--
-- TOC entry 5149 (class 0 OID 30071)
-- Dependencies: 221
-- Data for Name: address; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.address (address_id, user_id, address, city, postal_code, country) FROM stdin;
2	2	002 Owen Drive Apt. 909\nJohnborough, LA 86330	Lake Jeremy	27783	Slovenia
3	3	5550 Lisa Knolls\nLake Georgeburgh, MD 10813	North Patrickview	30332	Congo
4	4	8770 Victoria Burgs Suite 002\nNorth Charlene, PR 2	Port Derekside	91980	Gambia
5	5	43124 Clay Squares\nLake Caroline, NV 17277	Port Virginiamouth	97979	Malawi
6	6	61365 Richard Valleys Apt. 761\nEast Ericatown, MD 	Lake Benjamin	56171	Micronesia
7	7	974 Murphy Wells Suite 606\nPort Anthonyfort, AR 48	Geraldborough	64869	Jordan
8	8	4878 Hector Stravenue Apt. 208\nLewismouth, PW 8469	New Mary	09144	Armenia
9	9	1851 Mendoza Row\nWest Kristi, WV 77826	West Jamesmouth	84579	Haiti
10	10	Unit 3768 Box 7480\nDPO AA 78635	Joneshaven	46340	Peru
11	11	441 Cooper Overpass\nDavidport, SD 11806	Chelseahaven	74214	Georgia
12	12	462 Nichols Circle Suite 953\nNorth Anthony, ID 741	South Emilybury	67379	Comoros
13	13	60909 Sparks Heights\nErikahaven, WI 67853	South Grant	23140	Tokelau
14	14	2871 Garza Row Apt. 914\nElizabethfort, WA 22208	New Dorisside	30397	Israel
15	15	1380 Olivia Meadow Suite 908\nEast Aaron, KY 85740	Gomezmouth	50828	Germany
16	16	456 Jennifer Ville Apt. 679\nPort Brittanyburgh, MP	New Albert	93609	Zambia
17	17	475 Mike Track\nNorth Stacey, RI 65211	Gillespieview	04901	Dominican Republic
18	18	071 Travis Light\nNew Meganbury, NC 66266	Morrowmouth	11737	Luxembourg
19	19	42440 Stephanie Keys Apt. 272\nSouth Peterberg, DC 	Andrewport	09297	French Polynesia
20	20	25116 Heidi Junctions Suite 794\nLeonardtown, NY 50	Adamchester	91629	Saint Kitts and Nevis
21	21	787 Jackson Shoals\nNorth Ruben, OK 26831	Morganchester	96254	Fiji
22	22	754 Nguyen Canyon\nShannonmouth, KS 97874	New Lauren	35705	Cote d'Ivoire
23	23	2137 Juan Fort\nPerezside, NV 47370	North Kathleenview	88456	Sudan
24	24	32397 Jackie Walk\nNorth Amber, VI 69145	South Lisa	82209	Greenland
25	25	503 Kathy Villages\nSawyermouth, ME 39467	Wrightborough	38519	Slovakia (Slovak Republic)
26	26	649 Johnson Cove Apt. 593\nEast Elizabeth, NV 05863	Ellisshire	21629	Saint Helena
27	27	454 Jeremy Cove Suite 440\nHuffchester, NM 69732	South Joseph	71582	Japan
28	28	0341 Mcgee Bridge\nNorth Stacychester, FM 79899	Austinburgh	30647	Ireland
29	29	26419 Dalton Bridge Suite 362\nNorth Andrefurt, LA 	Rodriguezmouth	37875	Gambia
30	30	35216 Thompson Creek Suite 477\nJessicaborough, VT 	Debramouth	26733	Croatia
31	31	28217 Jordan Drive Apt. 853\nNew Johnport, PW 58459	East Jenniferborough	89620	Nigeria
32	32	09236 Ward Neck\nPort Erinfort, VI 06973	Peterbury	23043	Guadeloupe
33	33	4947 Elizabeth River\nNorth Heatherbury, CT 68488	North Kimberly	25651	Cameroon
34	34	56663 Michael Hills Apt. 783\nEast Brettport, SD 12	Reynoldsstad	98901	Montenegro
35	35	9147 Fitzpatrick Oval\nRonaldbury, MP 30810	Daltonbury	04517	Marshall Islands
36	36	48452 Lisa Gateway Suite 458\nSouth Jamie, NJ 31227	New Elizabeth	71271	Estonia
37	37	71625 Marc Hollow\nSamuelport, VT 46997	South Pamelaside	69131	Mali
38	38	332 Jerry Union\nSouth Tammyton, ME 23904	East Kellymouth	29593	Libyan Arab Jamahiriya
39	39	4079 Lindsay Dam\nGrahambury, OH 29799	West Crystal	64681	Bolivia
40	40	66411 Campbell Courts\nAndrewbury, NY 52469	Thomasbury	88392	Christmas Island
41	41	2091 Cooper Centers\nLake Matthewstad, WI 63624	Smithberg	88769	Cameroon
42	42	USCGC Conley\nFPO AP 21874	Port Jadeton	28363	United States Virgin Islands
43	43	USNV Stein\nFPO AA 19788	Port David	23603	Aruba
44	44	927 Daniels Radial\nLisamouth, DE 60385	North George	56873	Austria
45	45	466 Wise Mountains\nHarpershire, MP 14084	New Angela	94264	Slovenia
46	46	1565 Mcdaniel Court Apt. 910\nWest Ericaberg, WI 81	Clementsborough	19589	Cook Islands
47	47	8918 Aaron Passage\nJasonport, MO 64795	Jacksonside	61548	Anguilla
48	48	9280 Gamble Greens\nDavisport, TX 09844	Michaelberg	05588	Bouvet Island (Bouvetoya)
49	49	22438 Tanya Square Apt. 478\nPort Dawn, MN 51881	Floresshire	64077	Greenland
50	50	9859 Debbie Light Suite 303\nPort Robertfurt, WI 55	East Lindseyport	81181	French Guiana
51	51	210 Lin Row\nNorth Williamfort, PA 47035	East Michael	66630	Gambia
52	52	89840 Christopher Island\nMelvinport, NC 44100	Tonyastad	03967	Paraguay
53	53	003 Samuel Parkway Apt. 154\nLeehaven, SD 78820	Marissamouth	15495	United Kingdom
54	54	1467 Mckinney Orchard\nNorth Aaronland, CO 40116	Floresmouth	01408	Mongolia
55	55	403 Jones Islands Apt. 645\nEast Juliemouth, AL 701	North Micheleville	33916	Libyan Arab Jamahiriya
56	56	751 David Green\nWest Tamaraside, AS 20767	Simpsonbury	01459	Palestinian Territory
57	57	6426 Brandon Park Suite 479\nGomezberg, SC 35575	Jenkinsland	36280	Austria
58	58	7877 White Hills\nMartinezview, ND 39121	Davismouth	85295	Antarctica (the territory Sout
59	59	77116 Stephanie Path Apt. 948\nNorth Caitlin, KS 25	Nicholsview	76803	Jersey
60	60	Unit 3268 Box 7154\nDPO AP 60143	New Michellechester	93114	Moldova
61	61	2345 Anna Roads\nPaulshire, KS 95336	New Nathan	92475	Trinidad and Tobago
62	62	33673 Samuel Hollow Suite 528\nKimberlyborough, MI 	South Jared	57296	Trinidad and Tobago
63	63	Unit 9167 Box 4736\nDPO AE 83785	East Megan	86370	Romania
64	64	21874 Stephen Track\nZimmermanshire, FL 85482	Brownborough	08173	Iraq
65	65	3032 Mcpherson Key Suite 609\nLake Kenneth, LA 1444	Kimberlyton	91431	Uzbekistan
66	66	4346 Patterson Radial Apt. 616\nSouth Lisa, MP 3188	Davismouth	51325	Gambia
67	67	63050 Melissa Junction Suite 043\nLake Nicolemouth,	Staceymouth	47758	Portugal
68	68	308 Mallory Forest Apt. 712\nJanicebury, CO 93450	South Johnberg	63878	Brunei Darussalam
69	69	455 Jason Underpass\nRobinsonview, CA 66834	Ruizstad	08380	Yemen
70	70	Unit 2860 Box 6926\nDPO AP 75223	Lake Howard	80059	Colombia
71	71	432 Stacey Stravenue\nPort Cynthia, LA 24701	Williamsview	88718	Germany
72	72	466 Ray Union\nWest Tina, PR 84579	Colemouth	02345	Hong Kong
73	73	12492 Keith Ports\nWest Laura, NJ 15331	Meyertown	91826	Qatar
74	74	2072 Jeffrey Vista\nNorth Tracey, KY 15630	Adamshire	72478	Sri Lanka
75	75	0473 Anthony Burgs Apt. 715\nSteeleberg, KY 51643	East Tracey	30986	Saudi Arabia
76	76	3710 Michael Freeway Apt. 027\nParkermouth, WI 1186	Port Shannonstad	69140	Oman
77	77	882 Stephens Underpass Apt. 331\nWilsonfurt, KS 106	Mendezborough	75525	Yemen
78	78	2202 Johnson Parks\nNew Evanchester, GA 04676	Transtad	35760	Bermuda
79	79	9772 Jennifer Alley\nLake Leeton, NE 26617	Lake Robert	40501	Brunei Darussalam
80	80	Unit 0271 Box 0556\nDPO AA 68096	Fullerchester	52033	Svalbard & Jan Mayen Islands
81	81	744 Smith Underpass\nWest Herbertbury, IN 72140	Brianmouth	85909	Tuvalu
82	82	Unit 4024 Box 0047\nDPO AE 71433	Byrdview	71323	Liechtenstein
83	83	42100 Christian Centers\nPort Timothyborough, NH 52	Averystad	67702	Senegal
84	84	2524 Wang Valleys\nLake Michelle, OR 03954	Smithshire	35734	Bhutan
85	85	4985 Lyons Extensions Suite 595\nSouth Dylanville, 	South Charlesville	09405	Saint Lucia
86	86	0854 Bethany Expressway Apt. 726\nNorth Stevenbury,	South Maryshire	68459	Qatar
87	87	27046 Stein Islands Suite 280\nNorth Jessicaside, N	New Benjaminton	88980	Burkina Faso
88	88	8307 Heather Gateway\nJenniferchester, WA 62763	Maddenville	67725	Nicaragua
89	89	998 Robert Plains\nDeanville, AS 27925	Weaverport	11761	Philippines
90	90	Unit 9980 Box 5227\nDPO AE 27819	Brandibury	95639	Djibouti
91	91	0979 Cynthia Street Apt. 104\nPaigefurt, IN 68255	Lake Anthony	25558	Turkmenistan
92	92	8327 Orr Parkways Apt. 808\nLake Brandon, FM 23499	Walkertown	71306	Libyan Arab Jamahiriya
93	93	4649 Shepherd Roads\nLake William, NC 81019	Gordonstad	92900	Eritrea
94	94	743 Rachel Shoals\nNew Danielhaven, TX 85625	Reyesland	20560	French Polynesia
95	95	5172 Guerra Wall\nDanielleland, FL 60956	Port Kelseyton	23617	Fiji
96	96	Unit 6429 Box 3184\nDPO AA 39073	Lake Sheenabury	69777	Denmark
97	97	PSC 1137, Box 3466\nAPO AE 40019	Port Thomas	31116	Bangladesh
98	98	USNS Garcia\nFPO AP 85241	Clarkfurt	92161	Belize
99	99	67659 Mcintyre Glen\nNew Scottburgh, CT 92307	Myerstown	06051	Spain
100	100	91647 Mason Flats\nNew Amandamouth, ND 74819	Millerhaven	75605	Guernsey
101	101	USCGC Bowen\nFPO AE 09228	Hillmouth	37133	Saint Kitts and Nevis
102	102	7755 Lee Freeway Apt. 790\nRichardfort, GU 23237	West Erin	13066	Guam
103	103	795 Jackson Ford Apt. 729\nColemanshire, HI 09946	Christopherfort	66810	Guadeloupe
104	104	795 Schmidt Wells\nNew Sara, TN 42409	Kleinville	66677	New Caledonia
105	105	86176 Mckinney Coves Suite 548\nSouth Jenniferburgh	Thomaston	49654	Vietnam
106	106	91155 Nicholas Shore Suite 738\nAprilside, WY 99752	Claytonmouth	51148	Norway
107	107	4468 Martin Mountain Apt. 571\nWilliemouth, DE 0793	East Danielle	03340	Yemen
108	108	8367 Stephanie Mills Apt. 578\nNorth Kaylastad, TX 	West James	68842	Andorra
109	109	38166 Andrew Groves Apt. 705\nNorth Alex, IN 74156	West Jessica	02763	Marshall Islands
110	110	31631 Aguirre Ports Apt. 455\nNew Ronald, NM 31062	Ryanshire	08843	Reunion
111	111	149 Heath Turnpike Apt. 700\nLake Lynnborough, VT 0	East Thomasstad	15607	Nauru
112	112	195 Sanchez Drive\nKimberlystad, MH 79762	Youngtown	65593	Saint Vincent and the Grenadin
113	113	Unit 0062 Box 2095\nDPO AE 74906	South Andrew	22182	Ethiopia
114	114	USS Long\nFPO AP 54496	Pamland	48478	Finland
115	115	12791 Holland Crossroad\nWest Wayne, MS 39268	Rebeccafort	86543	Belize
116	116	2789 Sandra Prairie Apt. 402\nWest Rachel, MI 05173	East Melissahaven	65406	Ireland
117	117	3119 Travis Views Apt. 340\nLake Melissaborough, MT	Dennistown	66498	Israel
118	118	4099 Morgan Ways\nPort Jessicachester, KY 41724	Port Jennifermouth	65936	Ethiopia
119	119	5050 Dana Squares\nWest Ralph, CO 46059	North Dwayne	41150	Mayotte
120	120	2863 Salas Ridges\nSouth Kimberly, UT 86977	New Janetton	82174	Portugal
121	121	23114 Ryan Extensions\nRicestad, VA 18396	Crystalville	28403	Greenland
122	122	52494 Amanda Shores\nBrownmouth, MS 56111	New Peterborough	28471	Lithuania
123	123	1197 Bryan Grove Apt. 726\nNorth Christopher, IA 12	Rogersfurt	33415	Malawi
124	124	76420 Alexandria Harbor\nNorth Rhonda, GA 57004	Amymouth	79573	Australia
125	125	390 Jones Lights Suite 693\nNew Shawnmouth, MO 4333	Williamsview	98636	Central African Republic
126	126	4214 Durham Square\nLake Tara, NM 30169	Samuelfurt	09335	United Arab Emirates
127	127	26663 Benjamin Locks Apt. 899\nNew Justin, AS 99303	Johnsonville	54359	Kyrgyz Republic
128	128	47861 Brandy Road\nHeatherport, PA 07147	South Beverly	76669	Portugal
129	129	30613 Calhoun Hill\nPort Williamshire, OH 60767	Kellyport	23710	Guinea-Bissau
130	130	68174 Scott Wall\nPort Williamfurt, GA 43036	Patriciaton	93116	Finland
131	131	08787 Johnson Extension\nWilliamchester, ME 72415	Coleshire	66326	Christmas Island
132	132	7530 Hubbard Manor\nReginaldfort, ME 48109	Lake Mark	43286	Croatia
133	133	938 Jerry Throughway Suite 772\nPort Joshuaborough,	Shelbyside	28422	Holy See (Vatican City State)
134	134	611 Shane Trail\nChristinaland, NC 32217	South Christopher	13362	Bahrain
135	135	488 Herring Pass\nBrianchester, GU 13293	East Adamstad	49025	United States Virgin Islands
136	136	849 Stanton Falls\nSanchezburgh, OK 19250	Chenchester	26394	Turkmenistan
137	137	00122 Stephanie Trafficway\nWest Hector, NE 15806	South Sarahberg	93448	South Africa
138	138	392 Armstrong Tunnel Apt. 943\nLaurastad, PA 96860	Mcculloughside	85260	Burkina Faso
139	139	815 Drake Valleys Suite 552\nMichaelfort, MS 96750	North Jessicaville	05695	El Salvador
140	140	6691 Briggs Field\nMayoburgh, KS 88475	New Derrickmouth	67512	Iceland
141	141	4420 Ortiz Springs Suite 523\nPort Stephenfort, MD 	Nobleport	09161	Nigeria
142	142	77732 Ali Mills Suite 382\nNorth John, LA 69962	New Jamiestad	30864	Monaco
143	143	712 Susan Point\nNguyenville, NM 32118	Kimberlyton	65783	Honduras
144	144	PSC 1721, Box 0173\nAPO AA 96644	Taylorside	48495	Colombia
145	145	862 William Loaf Suite 698\nWest Jessestad, WA 8325	Laurenstad	50230	Malaysia
146	146	50556 Gina Mission\nEast Loriview, NM 93546	Gainesshire	50016	French Guiana
147	147	11572 Jennifer Meadow\nNorth Jamesfurt, MI 62915	Katietown	33829	Palestinian Territory
148	148	25692 Medina Orchard Suite 929\nNew Amber, UT 49887	Bradleyshire	31616	United States Minor Outlying I
149	149	4454 Hines Square\nClarenceborough, VT 63770	Smithview	86518	Mayotte
150	150	7105 David Village Suite 444\nNorth Troyberg, VA 56	South Michael	07365	Belgium
151	151	96072 Gary Dale Apt. 874\nPort Alex, AS 96653	South Joshuachester	66101	Andorra
152	152	9078 Peter Overpass\nThompsonview, NJ 51940	Lesliemouth	12032	New Caledonia
153	153	4962 Thomas Valley Suite 358\nLake Alicia, HI 39727	Bishopland	49734	Puerto Rico
154	154	10084 Kim Shore\nRoberttown, OH 34801	South Rebeccaburgh	98358	Brunei Darussalam
155	155	8936 Lutz Crescent\nKaufmanburgh, NE 62261	South Matthew	21959	Zambia
156	156	8748 Wiggins Underpass Apt. 157\nSanchezville, VT 9	Mooreberg	50564	Kuwait
157	157	6479 Matthew Highway\nCollinshaven, MT 69237	Deanchester	92248	Cocos (Keeling) Islands
158	158	5157 Karen Tunnel\nNorth Donnahaven, ME 98656	West Michaelborough	61353	French Polynesia
159	159	1365 Anthony Corner\nSouth Daniellehaven, IA 68729	West Joshuamouth	47533	Panama
160	160	593 Ryan Forges Suite 623\nNew Daniel, FL 21961	South Isaac	63328	Bouvet Island (Bouvetoya)
161	161	86911 Thomas Square Apt. 883\nPort Kyleborough, KS 	Lake Theresa	66540	Uzbekistan
162	162	82943 William Radial\nNorth Terriside, UT 12932	Jamestown	84277	Congo
163	163	546 Harrington Trace\nSouth Julian, ID 19981	Port Darrell	64411	Brunei Darussalam
164	164	PSC 9095, Box 7470\nAPO AP 82069	Santiagoborough	25313	Kenya
165	165	2994 Rodriguez Mills\nAaronland, PR 22148	Judyshire	09276	United Arab Emirates
166	166	110 Patel Underpass\nNguyenborough, KS 25709	Rhondamouth	64656	Netherlands Antilles
167	167	75478 Rhonda Lane Suite 455\nNorth Laurieside, PW 4	Lake Jamesfurt	28229	Hungary
168	168	6163 Reyes Viaduct\nNorth Laura, OK 52862	Villarrealfort	25496	Guam
169	169	59750 Chris Street\nChristyport, MS 94494	West Royside	19324	Estonia
170	170	75043 Thomas Square Suite 032\nNew Jamesside, FM 78	Port Roberto	33875	Luxembourg
171	171	7467 Price Courts\nJustinmouth, IA 95890	Lake Charlesview	27996	Liechtenstein
172	172	4913 Nancy Wells Suite 804\nHermanbury, NY 44288	Ethantown	33473	Finland
173	173	673 Johnson Passage\nWilkinsfort, VA 67142	Wallacemouth	92276	Bangladesh
174	174	0357 Rogers Place Suite 211\nSouth Samuelbury, DE 5	Murraychester	49268	Sweden
175	175	677 Greg Mountain\nLake Elizabeth, PR 33971	Andrewsfort	06696	Antigua and Barbuda
176	176	47586 Stevens Groves\nScottburgh, OH 99657	Evanberg	91499	Northern Mariana Islands
177	177	658 Bell Forge\nLake Williamburgh, WI 54531	Nicholasborough	87526	Italy
178	178	USS Mckay\nFPO AP 31144	New Eric	43914	Jersey
179	179	386 Friedman Courts\nLake Vincent, NM 99772	East Ryan	50850	Guernsey
180	180	184 Huang Creek Suite 865\nNorth Garrettchester, IA	South Megan	75432	Iceland
181	181	26441 Michelle Way\nHorneberg, HI 20059	North Paula	59104	Russian Federation
182	182	Unit 2088 Box 7741\nDPO AP 07394	East Jacob	41622	New Zealand
183	183	36369 Williams Village Apt. 824\nNorth Brianburgh, 	New Rosemouth	09692	Turks and Caicos Islands
184	184	496 Nicholas Shoals Apt. 048\nRobinsonborough, NV 0	Gilberttown	18218	Somalia
185	185	126 Baker Hills\nNorth Robinfort, VA 27994	Lisamouth	38792	Ukraine
186	186	033 Tucker Shoals\nCaitlinfurt, NE 75051	North Joseph	34650	Bosnia and Herzegovina
187	187	533 Cindy Mission Suite 601\nTinaview, DE 89445	East Lauramouth	68535	China
188	188	293 Ramos Crest\nTravisborough, MA 95701	East Jeffreymouth	07303	Singapore
189	189	42694 William Highway\nStevenburgh, AZ 68358	Porterfurt	18097	Peru
190	190	12119 Vaughan Prairie Apt. 008\nEast Ricardoview, N	Johnsonborough	54440	Tunisia
191	191	Unit 4157 Box 3328\nDPO AE 36756	New Kevinville	46589	Qatar
192	192	41155 Jeanette Square Apt. 466\nJenniferberg, ID 69	South Lisa	55690	Bangladesh
193	193	2266 Cameron Flats Suite 495\nWest Andrew, WA 28418	Danielhaven	97155	Mozambique
194	194	19148 Pope Viaduct Apt. 466\nNew Josephchester, IL 	West Dianeshire	82986	Cambodia
195	195	53231 Miller Crescent Suite 712\nEast Jeffreyland, 	North Michael	28005	Kenya
196	196	51541 Karen Glens\nStacyside, NJ 44942	South Erika	59265	Thailand
197	197	627 Hahn Turnpike Apt. 511\nLake Jeremy, LA 41648	South Angelafort	01717	Liberia
198	198	94050 Wilkinson Rapids\nNataliehaven, UT 30364	Kennedystad	34440	Egypt
199	199	72054 Shane Meadows\nEast Erin, VI 08729	South Angelahaven	09952	Romania
200	200	7726 Evans Underpass Suite 485\nFranklinport, VA 80	North Davidton	02398	Uzbekistan
201	201	57538 Wolfe Ridges\nWest Allen, IL 60188	Lake Jaredville	68989	Croatia
202	202	49351 Elizabeth Circle\nBarronchester, MO 61415	Michaelland	94408	Pitcairn Islands
203	203	546 Green Glen Apt. 236\nColemanburgh, AZ 88013	Anitaside	37466	Isle of Man
204	204	57254 Jacob Fork\nLake Clayton, FM 84041	Charlestown	30848	United Kingdom
205	205	19778 Ivan Rapid\nLake Mary, WI 23545	Kramerland	36040	Armenia
206	206	958 Jimenez Inlet\nPort Heatherstad, TN 00570	West Judithstad	37680	Guernsey
207	207	6806 Harold Corner\nWest Donald, AL 36979	Woodshaven	21059	Saint Barthelemy
208	208	30955 Scott Route Apt. 353\nPort Lisa, NM 41294	South Laura	78877	Trinidad and Tobago
209	209	16076 Jasmine Fords\nHendrixmouth, MN 94081	Jamestown	07237	Poland
210	210	388 Adams Corners Suite 040\nNew Debbie, FM 19179	North Ashley	65627	Malaysia
211	211	832 Porter Ramp\nPort April, LA 61136	Coleberg	57357	Guadeloupe
212	212	5094 John Court Suite 890\nPort Catherine, IA 08856	Hancockbury	80036	Greenland
213	213	367 Cunningham Wall\nNew Brianburgh, IN 69854	Youngchester	82150	Jordan
214	214	8494 Ryan Tunnel\nWellsfurt, MD 93597	West Teresa	54212	Canada
215	215	814 Peters Grove Apt. 754\nGregoryport, VA 72074	Meganhaven	49032	Heard Island and McDonald Isla
216	216	8447 Lisa Meadow Suite 473\nJacksonbury, IN 69516	Port Christinafort	89677	Tokelau
217	217	PSC 5611, Box 1363\nAPO AE 66793	Williamfort	49657	Algeria
218	218	952 Amy Island Apt. 038\nBeardtown, SC 26869	East Catherinecheste	89394	Turkey
219	219	095 Conner Lane\nBrianbury, WA 01754	West Franciscoboroug	28642	Sri Lanka
220	220	1659 Jessica Greens Apt. 611\nCarrillochester, MP 4	Alicehaven	83609	Sao Tome and Principe
221	221	00046 Mason Manors Suite 047\nEast Christyport, UT 	New Markchester	89588	Congo
222	222	87474 Roger Orchard Apt. 196\nTuckerland, WV 85121	Lake Davidborough	05177	Cyprus
223	223	7476 Deborah Locks\nNorth Richard, IA 34666	Williamton	07791	Heard Island and McDonald Isla
224	224	9701 Patricia Point\nEast Michael, OR 11076	New Jorgeberg	79184	Equatorial Guinea
225	225	06183 Brendan Villages\nAndrewmouth, PA 01235	North Craigmouth	03206	Algeria
226	226	3400 David Spur Suite 889\nKristenbury, CO 29078	New Jamesport	28023	Kiribati
227	227	0942 Wiley Ramp\nKellyborough, IL 53683	New Debraton	87287	New Zealand
228	228	151 Marc Brook\nLake Royfort, WV 02957	Whitetown	73139	Palestinian Territory
229	229	75537 Keith Prairie\nJenniferstad, CA 30044	New Deborahfurt	03035	Korea
230	230	11785 Wood Plaza Apt. 960\nSouth Laura, AL 93391	New Bonniestad	20218	Slovenia
231	231	8821 Sexton Islands\nSamanthachester, VT 86666	Laurenport	78880	Gibraltar
232	232	687 Parsons Expressway\nCynthiaberg, MI 87237	Rodriguezstad	62675	Afghanistan
233	233	837 Shawn Harbors\nJohnsonmouth, VT 56298	Samanthaville	27143	Jamaica
234	234	8914 Cook Stream Suite 812\nBuckleytown, AR 40578	Alexandramouth	43083	Israel
235	235	621 Owens Turnpike Suite 761\nPaynemouth, FM 29813	Cynthiahaven	15389	United Kingdom
236	236	4207 Monica Mall\nJeremyberg, KS 68475	Charlestown	03385	Iran
237	237	65079 Rivera Tunnel\nLake Suzanne, HI 03864	Christopherberg	86407	Jamaica
238	238	5471 Jones Pines\nWest Ashleytown, KY 93339	West Heatherberg	91984	French Polynesia
239	239	342 Bennett Viaduct Apt. 234\nMichaelland, PR 87294	East Kyle	61659	Estonia
240	240	809 Elliott Lodge\nAllenton, AL 13913	Livingstonfort	85839	Lesotho
241	241	800 Ralph Crossing Apt. 099\nPort Juliastad, MT 350	North Christophermou	02066	Puerto Rico
242	242	610 Sosa Well Suite 303\nPort Eric, ME 19919	Jessicabury	05374	Netherlands Antilles
243	243	0598 Brittany Spur Suite 669\nLoveton, AS 71381	North Lynnbury	93271	Finland
244	244	17728 Derek Springs\nPhelpsberg, PA 61362	West Sylvia	74766	Peru
245	245	60266 Dunlap Green\nWest Anna, SD 94555	Fernandezville	57653	Hungary
246	246	133 Griffith Islands Apt. 069\nEdwardsland, MD 7896	Ashleyville	65031	South Georgia and the South Sa
247	247	0097 Donald Flats Suite 358\nClarkstad, SD 70490	Denisefurt	28027	Saudi Arabia
248	248	13119 Brian Point\nNew Meaganstad, WA 33806	Kimberlyshire	08348	Nigeria
249	249	739 Ali Camp\nNew Charlene, OH 88535	Bautistaside	75662	Kuwait
250	250	102 Tina Drives Apt. 445\nKristinbury, NY 01535	Stevenland	65421	Saint Helena
251	251	80301 Wesley Squares\nPort Michael, WI 07167	Port Nicholas	07257	Jordan
252	252	799 Harper Extensions Apt. 524\nKelleyview, SC 9041	Lake Mark	98804	Guinea-Bissau
253	253	79938 Kramer Landing Suite 570\nJohnview, WY 05557	New Danielmouth	03650	Uzbekistan
254	254	23759 Allen Mountain\nLauramouth, IL 64997	New Marisa	94967	Algeria
255	255	621 Collins Point Suite 903\nAmandamouth, LA 55828	Robersonside	54213	Sweden
256	256	252 Christopher Summit Apt. 476\nDevontown, LA 3090	East Carl	28816	Pitcairn Islands
257	257	816 Cohen River Suite 038\nHodgeton, FL 31719	Jeffersonville	90119	French Polynesia
258	258	43735 Huynh Courts Apt. 916\nPort Katieton, OK 7036	North Lindsey	46163	Armenia
259	259	39501 Morgan Wells\nLake Stanley, OR 22606	North Raymondland	28518	Pitcairn Islands
260	260	93215 Laura Canyon\nPatriciaside, IL 94320	Lake Jessica	39714	Trinidad and Tobago
261	261	PSC 8692, Box 8883\nAPO AA 92971	East Jamesburgh	97455	Nigeria
262	262	68917 Ryan Port Suite 454\nWest Evelyn, OH 80571	Andrewland	14963	China
263	263	5442 Cassie Estates\nGarciafort, MI 78801	Bakertown	19568	Timor-Leste
264	264	674 Derrick Causeway Apt. 424\nDavidstad, FM 97086	West Evelyn	60483	Saint Kitts and Nevis
265	265	2214 Smith Mountains Apt. 589\nBrandonmouth, RI 450	Katiechester	70430	Japan
266	266	3117 Singh Expressway\nMichelleland, HI 22046	Rachelside	69937	Burundi
267	267	344 Jones Village\nJoelland, CA 01588	Port Johnberg	01097	Ghana
268	268	798 Lewis Garden\nHeatherside, NJ 75600	Nathanstad	90659	Bahrain
269	269	723 Christopher Shore Apt. 139\nWhitetown, AR 82646	Mcdonaldmouth	03486	Fiji
270	270	3953 James Cape\nWendyhaven, SC 35132	Codymouth	83352	Nicaragua
271	271	120 Kelly Mountains\nGarzachester, OR 91852	Lake Donnastad	69751	Guernsey
272	272	4055 Samantha Mountains\nWest Franklinborough, DE 4	Albertchester	37676	British Virgin Islands
273	273	66340 Oscar Union Suite 698\nPaulborough, AL 26800	Keyfurt	60127	Burundi
274	274	86118 Schneider Expressway\nChristinaberg, PA 72939	Jacksonchester	80307	Micronesia
275	275	74360 Carey Manors Apt. 983\nEmilymouth, GA 47236	New Ravenburgh	04498	Qatar
276	276	USS Moore\nFPO AP 34191	Port Jeffreyborough	46040	Tokelau
277	277	57114 Frank Cliff Apt. 286\nJennyside, MP 18263	Hughesmouth	11502	Hong Kong
278	278	652 Brian Well\nSmithfurt, HI 85312	New Raymondbury	77142	Albania
279	279	1276 Jonathan Fields\nPort Pamela, MO 23054	East Brandon	59379	Lebanon
280	280	705 Samantha Lakes Apt. 699\nHeatherfort, WA 91834	West Dana	45656	Japan
281	281	15161 Joseph Village\nEast Shawn, KY 93028	Desireeberg	28670	Malawi
282	282	07827 Michael Hills\nHansenport, FM 44849	South Brandon	18656	Uruguay
283	283	33766 Burke Plain\nSouth Alexandermouth, MS 41665	New Christinahaven	58790	Libyan Arab Jamahiriya
284	284	72279 James Port\nLeahchester, AS 57975	South Jeremy	49481	Hungary
285	285	64400 Linda Lakes Apt. 762\nCampbellmouth, PA 43398	Lake Zacharyhaven	56018	Luxembourg
286	286	8448 Thomas Well\nShawnberg, ME 65646	Ashleyberg	70684	Azerbaijan
287	287	85787 Robert Manor\nNorth Joshuaton, MS 07311	Lake Meredithport	46115	Tokelau
288	288	PSC 5035, Box 7569\nAPO AP 27558	Port David	96498	Comoros
289	289	5851 Bond Pine Apt. 448\nLake Normaport, IL 71321	Lake Jeffreyside	91701	Jordan
290	290	0941 Elizabeth Crescent Apt. 380\nPort Stephanie, C	Harrisburgh	62576	Suriname
291	291	4338 Kyle Expressway\nCliffordside, DC 87393	Port Walterhaven	16911	Austria
292	292	37835 Johnson Mission\nMillerbury, WA 58034	New Brandon	29179	Peru
293	293	5064 Lori Hollow\nLake Tommyborough, VA 31342	East Kyle	03043	Uganda
294	294	USS Frederick\nFPO AE 05844	Gravesfort	06446	Kyrgyz Republic
295	295	81281 Paula Islands Apt. 436\nSallytown, NH 15767	Anthonyland	16286	Latvia
296	296	51490 Perkins Crescent Suite 425\nEast Roberttown, 	Mooreshire	09746	Egypt
297	297	7859 Davidson Forges\nEast Kristine, IL 78580	South Cliffordport	38359	Sudan
298	298	Unit 9954 Box 7272\nDPO AE 47925	Port Wandaport	97771	Jersey
299	299	1795 Sharon Light Apt. 031\nBrookechester, RI 86258	Paynefurt	24050	Martinique
300	300	33623 Keith Way Apt. 726\nJuliefurt, HI 67308	North Erica	34499	Sao Tome and Principe
301	301	2103 Lopez Lodge\nEdwardberg, NC 01499	South Phyllis	87297	Bosnia and Herzegovina
302	302	254 Shawn Villages\nNorth James, OK 30982	East James	69901	Belarus
303	303	496 Montoya Orchard Suite 076\nSouth Denisemouth, A	Brownfort	58939	Georgia
304	304	842 Janet Court\nRileychester, PA 70044	Lake Robertborough	86756	Iraq
305	305	836 Guerrero Lock Suite 278\nSouth Garyberg, KS 093	Larsonmouth	44337	Honduras
306	306	53676 Little Drive Apt. 783\nLake Elizabethview, PW	Wallacechester	22011	Cambodia
307	307	45144 Smith Garden\nWest Matthewtown, NV 56997	South Matthew	65005	Barbados
308	308	22092 Brown Freeway\nDavidside, ID 53367	Port Mark	65920	Mali
309	309	697 Rhodes Inlet\nSouth Robertborough, MT 37861	South Hannah	30512	Pakistan
310	310	USS White\nFPO AP 54336	Lake Paul	11733	Gabon
311	311	PSC 2734, Box 4453\nAPO AP 18700	Moseshaven	81112	Portugal
312	312	Unit 9579 Box 8524\nDPO AE 67181	South Veronica	42671	Rwanda
313	313	28245 Laura Gateway Apt. 411\nEast Stephenmouth, SC	Nicoleburgh	92071	Slovenia
314	314	15046 Daniel Cliffs\nShellyton, UT 59061	Thomaschester	31585	Australia
315	315	6727 Jeremy Light\nConniestad, AR 42540	East Kirstenburgh	49780	Guam
316	316	9940 Craig Unions\nPetersonstad, MD 97852	Port Michelleborough	86908	Falkland Islands (Malvinas)
317	317	8773 William Estates Suite 655\nMcbrideville, UT 47	Joseborough	96000	Guyana
318	318	4671 Sandra Plaza\nPort Amy, MS 02052	New Danaville	32097	Central African Republic
319	319	67116 Michelle Greens Suite 890\nEast Meganborough,	Howardland	75794	New Zealand
320	320	99541 Kristina Garden\nNew Christophermouth, WI 463	Port Autumnfort	53929	United Kingdom
321	321	0856 Angela Estate Apt. 515\nChristinetown, MT 7141	Stephensport	47955	Botswana
322	322	71268 Michelle Mill Suite 428\nMorrisberg, NV 87182	Pittmanfurt	29136	Mozambique
323	323	Unit 2385 Box 2464\nDPO AE 68922	Lake Crystal	37652	Hungary
324	324	8283 Ray Mount Suite 597\nElizabethbury, KY 64497	Port Lisa	99815	Jersey
325	325	348 Harold Trail Apt. 871\nNew Elizabeth, TX 64531	New Andreabury	27028	Djibouti
326	326	61470 Jessica Run\nSouth Crystal, PR 02714	Lake Drew	90070	Indonesia
327	327	USNS Sanchez\nFPO AP 75014	West Paul	67451	Nigeria
328	328	369 Dylan Knolls\nSouth Jonathan, MT 77846	Johntown	30004	France
329	329	6545 Margaret Coves Apt. 119\nWest Randychester, SC	Hollyview	91630	Guinea
330	330	58007 Cody Stream\nNew Melindatown, MA 31150	West Jennymouth	01392	Saint Lucia
331	331	7738 Moore Mews\nSamanthafurt, IN 97072	Barryburgh	20370	Liberia
332	332	0737 Michael Courts Apt. 416\nTrevorbury, WY 60293	Lake Maryland	06670	Netherlands Antilles
333	333	399 Laura Mills\nClaytonchester, AZ 72317	Port Christineburgh	68297	Saint Vincent and the Grenadin
334	334	9886 Heather Brook\nSarahside, MH 78699	North Davidshire	08883	Heard Island and McDonald Isla
335	335	PSC 1908, Box 0410\nAPO AE 33297	South Jessica	18399	Jamaica
336	336	552 Roy Wall Suite 890\nLesliefort, GU 58608	Owensfurt	65706	Falkland Islands (Malvinas)
337	337	68214 Wood Inlet\nSheilaside, VT 44487	West Jorgebury	83943	Anguilla
338	338	PSC 4500, Box 0991\nAPO AP 03111	Lake Robert	29532	India
339	339	00905 Laurie Isle Suite 695\nSabrinaberg, OH 91326	Ryanville	61770	France
340	340	79650 Edwards Forges\nSouth Oliviafort, RI 88689	Smithfort	96593	Uzbekistan
341	341	120 Garrett Ferry Apt. 208\nKristenbury, IA 01549	Port Ronaldfort	31617	American Samoa
342	342	211 Brittany Knolls Apt. 500\nNew Josephchester, IN	East Kathleen	22817	United States of America
343	343	89060 Obrien Keys\nWest Cherylborough, MA 13447	South James	01600	Serbia
344	344	666 David Extension Apt. 168\nNorth Melissa, WI 206	East Meghan	25854	Rwanda
345	345	9029 Fox Orchard\nArielland, CO 91008	Jeromefort	71602	Northern Mariana Islands
346	346	PSC 5367, Box 0379\nAPO AA 73172	Malloryshire	21444	Mozambique
347	347	PSC 3053, Box 0751\nAPO AA 94409	New Mallory	64360	Mexico
348	348	91726 Forbes Roads Apt. 867\nEast Catherine, NH 621	New Amy	34420	Turkey
349	349	312 Dunn Rapids Apt. 844\nEast Saraside, FL 25829	Brownside	56725	Bolivia
350	350	5659 Cox Tunnel Suite 139\nKimberlychester, DE 7114	Margaretburgh	07161	Hong Kong
351	351	9412 Jimmy Ports\nPort Lisastad, MA 66994	New Andrew	60435	Tunisia
352	352	92873 Megan Terrace Apt. 504\nBriggsstad, NE 74855	Annastad	76215	Cocos (Keeling) Islands
353	353	93177 Taylor Cape\nWalshfort, MT 11580	Shannonmouth	53881	Kyrgyz Republic
354	354	471 Williams Causeway\nPort Scott, WV 13102	Johnsonside	34942	Czech Republic
355	355	535 Lawson Circles\nWest Laura, AK 35711	East Matthew	83877	Cook Islands
356	356	616 Peck Summit\nWest Garychester, MS 92331	Armstrongville	02756	Ethiopia
357	357	5519 Mayer Trace\nHansenview, IL 28832	Lake Christopher	69473	Malaysia
358	358	8973 Holland Cliffs Apt. 663\nEdwardfurt, WA 88082	East Brenda	61766	Belize
359	359	29956 Jones Route Suite 449\nNorth Matthewhaven, AL	Jacksonville	67494	Tuvalu
360	360	1506 Cynthia Manor Suite 145\nNew Larry, WY 34420	Josemouth	25923	Congo
361	361	90055 Katherine Squares\nNew Kevinborough, AZ 55802	Maciasfort	30689	Cuba
362	362	Unit 8629 Box 3603\nDPO AA 72377	South Frederickchest	08388	Burundi
363	363	9182 Matthew Mills Suite 706\nRuizport, AR 00518	Mathewbury	77835	Sudan
364	364	67158 Erica Trace Suite 623\nTinahaven, AL 71868	Port Cathybury	89043	United Kingdom
365	365	31258 Shelly Crest\nDanielchester, HI 48254	West Sean	71670	Mexico
366	366	844 John Forge\nMichaelview, CT 50989	Johnport	27892	Czech Republic
367	367	99363 Richard Route Suite 821\nNorth Aaronberg, FM 	West Cynthia	69152	Micronesia
368	368	53894 Jason Extension Suite 864\nWest Danielleton, 	Desireetown	49862	Mali
369	369	93731 Smith Curve\nPort Katelynfurt, HI 63199	Elizabethville	01107	Slovenia
370	370	8241 Barajas Forge\nJacksonport, IN 36887	Jasonhaven	70260	Brunei Darussalam
371	371	9029 Bush Knoll\nNorth Michaelberg, MH 04332	South Vanessa	17785	Kuwait
372	372	126 Smith Expressway Apt. 900\nPort Amanda, TX 0091	South Lauraland	30506	Turkmenistan
373	373	209 Clarke Groves Apt. 499\nErinview, NE 74332	Charlesstad	42811	Guatemala
374	374	Unit 5095 Box 8016\nDPO AE 28117	South Christopher	17719	Ireland
375	375	7210 Charles Crossing\nTuckerfurt, WA 71616	East Olivia	29606	Cyprus
376	376	91291 Maria Cliff Apt. 618\nEast Kelsey, KY 33102	Millershire	94384	Canada
377	377	6631 Carter Vista\nSouth Robert, MT 25138	Port Carloschester	39046	Antigua and Barbuda
378	378	8816 David Knolls Apt. 237\nLake Nathaniel, MT 9096	Hayston	68444	Saudi Arabia
379	379	PSC 3673, Box 6735\nAPO AA 41204	Hernandezside	84915	Lao People's Democratic Republ
380	380	38439 Church Bypass Suite 584\nLake Jaredberg, MI 4	Lake Jenniferport	63866	Ecuador
381	381	0527 Turner Centers\nAliciafort, MO 06396	North Susan	14351	Bulgaria
382	382	9368 Tyler Ramp Suite 814\nRossshire, MD 33596	North Margaret	95217	Peru
383	383	82191 Green Garden\nDavidsonside, AR 28095	Port Lisachester	61544	Reunion
384	384	2357 Bennett Courts\nKevinshire, NJ 29644	New Francisco	01769	Palestinian Territory
385	385	453 Victoria Camp\nEast Taylor, ND 92916	Bennettton	80561	Anguilla
386	386	399 Claudia Lodge Suite 775\nManningfurt, HI 88997	East Aaronland	77158	Egypt
387	387	225 Myers Walks\nPort Lindsey, AL 15052	Frederickport	00788	French Guiana
388	388	7797 Reginald View\nPaulview, IL 56070	West James	74809	Russian Federation
389	389	271 Hunt Village\nDownsmouth, HI 97311	Juliefort	82264	Kiribati
390	390	9556 Evans Summit\nWest Johnton, SD 20996	Careyfurt	33913	Oman
391	391	790 Mary Cliff\nLake Nicholasstad, PR 24152	South James	31522	Kenya
392	392	034 Alejandro Corners\nPort Robert, WI 77469	West Luis	10131	Mauritius
393	393	27895 Ryan Plaza Apt. 925\nEast Matthew, IA 79183	Anthonyfort	80144	Malaysia
394	631	31701 Garcia Ports\nNicholaschester, TN 02600	Lake Virginiaside	81654	Japan
395	394	88352 Diana Dam\nDwayneborough, PW 75512	Benjaminside	28544	Gambia
396	395	6640 Stephen Road\nNew Gregory, ME 11758	New Kevin	20278	Croatia
397	396	5383 Marissa Common\nNew Matthewburgh, WV 25945	Brandonbury	72214	New Zealand
398	397	8720 Coleman Ridge Suite 818\nNorth Jaime, TN 21623	Brownburgh	22513	American Samoa
399	398	83401 Joseph Hill Apt. 823\nMorrisontown, PA 32376	Jenniferburgh	81585	Mexico
400	399	97642 Gonzales Ranch Suite 128\nJeffreyberg, CO 108	East Sophia	79578	Reunion
401	400	90595 Cynthia Plaza\nEast Ethanfort, TX 80062	West Annemouth	90021	Mongolia
402	401	91335 David Isle Apt. 934\nKellybury, WY 64154	West Kaylee	10978	Nepal
403	402	14516 Lopez Camp Apt. 500\nLake Jasmineview, HI 421	Rogerville	73848	Israel
404	403	002 Grant Crest\nWest Racheltown, ID 85050	East Matthew	24164	Montenegro
405	404	672 Abigail Junction\nWest Cherylview, AR 03075	North Aprilhaven	46067	Mexico
406	405	54940 Kristina Trace\nGreerside, NV 66098	West Joseph	50071	Samoa
407	406	71380 Smith Village\nAbbotttown, SC 13997	Alyssamouth	18998	Japan
408	407	18483 Sherri Springs\nSouth Tylerbury, CT 59724	South Lanceville	51480	New Caledonia
409	408	0815 Teresa Corners\nNew Juan, MP 74491	New Lisafort	67705	Estonia
410	409	34238 Sean Stravenue\nDanielport, MN 77384	Schroederland	38991	Equatorial Guinea
411	410	265 Matthews Drives Apt. 112\nGlennmouth, UT 16020	Cruzberg	52954	Antarctica (the territory Sout
412	411	406 Jennifer Wall\nNew Christopherville, AS 66931	North Stephanie	20989	Turkmenistan
413	412	9330 Newman Landing\nMichaelfurt, ME 07865	Aaronchester	75618	Chile
414	413	0361 Heather Harbors\nBeasleytown, NJ 79068	East Danielle	65314	South Georgia and the South Sa
415	414	64073 Fowler Squares Suite 051\nCarpentertown, AK 7	Sandersmouth	57552	Spain
416	415	528 Kyle Radial Apt. 934\nJeanshire, WY 24528	North Phyllis	34800	Benin
417	416	7823 Rios Crossing\nEast Aprilbury, IA 79445	Marshburgh	78186	Hong Kong
418	417	60516 Lloyd Loaf Apt. 193\nCollinsville, KS 37253	New Brianshire	36613	Cambodia
419	418	0287 James Branch\nRangelfort, ID 88783	Lake Joseph	02937	Canada
420	419	0921 Anthony Junctions Apt. 511\nBensonport, AL 825	South Crystalville	37223	Sri Lanka
421	420	6870 Karen Loop\nEast Heatherfurt, NH 73843	New Kathryn	21483	Faroe Islands
422	421	847 Jonathan Junction\nNorth Adamside, IL 97332	Port Emilymouth	33029	Chile
423	422	0334 Solis Trafficway Suite 891\nLake Brandon, SC 8	Kathleenmouth	58673	Martinique
424	423	0858 Stephen Locks\nNorth Josephmouth, PR 50632	Lake Troy	15516	Romania
425	424	30727 Madison Springs\nMyersshire, WY 64186	Millerhaven	28773	United States Virgin Islands
426	425	04404 Lindsey Summit\nWest Cherylland, ME 51664	Lake Margaretburgh	77602	Montserrat
427	426	95434 Julie Turnpike\nSouth Bradleyville, AR 17386	Timothymouth	73650	Senegal
428	427	1161 Lopez Bypass\nEast Shawn, GU 52976	Dawsonfort	32899	Nauru
429	428	95306 Laura Plaza\nSouth Andres, HI 37929	Port Aprilside	31193	Antarctica (the territory Sout
430	429	8842 Graves Heights\nRamseyton, LA 91727	East Tracy	22049	Cape Verde
431	430	846 Heather Curve Apt. 727\nChurchborough, MO 88206	Katherineberg	21302	San Marino
432	431	39713 Jane Plains\nSimonhaven, FM 89356	South Monicatown	26073	Saint Lucia
433	432	90828 Alexandria Hollow\nPatriciafurt, DC 77249	Erinview	49435	Moldova
434	433	97259 Hoffman Path Suite 640\nChristinaview, WV 996	Melissaside	33440	Vanuatu
435	434	062 Williams Valleys\nWolfeburgh, OH 20401	East Timothy	20068	Malaysia
436	435	7894 Navarro Plains\nPort Kathleen, MH 37975	North Anthonyberg	29819	Saint Lucia
437	436	44030 Martin Valleys Apt. 864\nNew Paigeburgh, MN 8	East Garyville	16729	Madagascar
438	437	95976 Tyler Viaduct\nGeorgeborough, KS 05310	Christophermouth	86559	Solomon Islands
439	438	Unit 4465 Box 1312\nDPO AE 12016	South Tinaburgh	79086	India
440	439	USCGC Powers\nFPO AE 74114	Evanbury	33779	Aruba
441	440	556 Kevin Oval Apt. 076\nWest Antonio, ID 09815	North Elizabeth	11028	Guam
442	441	77202 Wendy Causeway Apt. 087\nBarrettberg, NY 0815	North Michaelstad	81595	Equatorial Guinea
443	442	3720 Marquez Port Apt. 883\nHernandezshire, VI 2632	Jasonbury	81280	United States of America
444	443	76543 Alicia Prairie Suite 726\nNorth Katieport, ID	Colleenland	81478	Italy
445	444	USNV White\nFPO AE 91555	Vanessachester	70314	Ecuador
446	445	670 Charles Tunnel Suite 852\nNorth Katie, WI 10431	Maldonadoton	14177	North Macedonia
447	446	667 Brown Falls\nKathrynton, WA 25546	New Jason	72767	British Virgin Islands
448	447	3112 Price Mission Suite 281\nMichaelburgh, NY 5545	New Kennethshire	43611	Brunei Darussalam
449	448	2144 Holland Square Apt. 131\nPort Heatherburgh, MN	North Nathanfurt	10950	Armenia
450	449	65694 Johnson Island Suite 335\nBryanberg, MA 52313	Whitakerville	14547	Zimbabwe
451	450	USNV Johnson\nFPO AE 49741	Jeffreyhaven	87532	Morocco
452	451	Unit 9552 Box 8627\nDPO AE 15373	North Amanda	65564	Seychelles
453	452	52296 Carlos Passage\nNorth Josephborough, WI 15969	Hoodchester	48518	Lesotho
454	453	5549 Kimberly Tunnel\nFloresstad, NC 60222	Farleyside	60345	Serbia
455	454	84064 Yvonne Mill Suite 382\nLake Kimberly, MI 7355	Port Stuart	52486	Morocco
456	455	407 Edward Greens Apt. 100\nWest Thomasstad, NM 369	East Kelly	01458	Mexico
457	456	2526 Ian Meadows Suite 458\nDanielmouth, CO 27651	Port Robert	60244	Faroe Islands
458	457	26680 Paul Orchard Apt. 232\nNorth Kendra, HI 80489	Lake Christopherburg	58475	Greece
459	458	2139 Smith Roads\nMeghanburgh, NJ 36248	Port Kennethchester	76548	Turkey
460	459	699 Powell Walk Suite 892\nSouth Stevenborough, ME 	Taramouth	98418	Belarus
461	460	9272 James Curve\nSouth Craig, PW 13932	Yorkchester	83312	Poland
462	461	37653 Makayla Parks Suite 957\nWest Sonyaburgh, NE 	Ramirezmouth	36695	Montenegro
463	462	08561 Stephanie Groves\nRossshire, PA 23000	New Debraberg	88797	Eritrea
464	463	68703 Stewart Roads Apt. 999\nPort Williammouth, NV	North Ashley	33503	Cuba
465	464	2065 Cain Oval Suite 567\nAlanview, VI 70824	New Maryport	53765	Turkmenistan
466	465	4487 Banks Springs\nCervanteston, OK 44147	New Michael	36192	Mayotte
467	466	7714 Dixon Trafficway Apt. 116\nRyanborough, VT 412	North Emily	48090	Moldova
468	467	1415 Thomas Mills\nAshleyhaven, MI 79152	Averyville	27319	Panama
469	468	60154 Lisa Walk\nEast Sethport, SD 14087	West Norman	39638	Nigeria
470	469	639 Chambers Center Apt. 758\nNew Lisa, ME 29317	Christensenside	53341	Lesotho
471	470	88069 Matthew Mission Apt. 779\nCaldwellville, NV 4	East Donaldborough	92792	Myanmar
472	471	Unit 9249 Box 2529\nDPO AE 22409	South Catherine	06416	Nepal
473	472	749 Kenneth Coves Apt. 009\nPort Coryburgh, MO 9917	East Daniel	43510	Ethiopia
474	473	Unit 5900 Box 9947\nDPO AA 87011	New Dennisfort	28200	Congo
475	474	92619 Curtis Flats\nDanielchester, MH 75971	Duranmouth	37162	British Indian Ocean Territory
476	475	71393 Maria Roads\nDuanefurt, SC 48304	Yeseniabury	74928	Costa Rica
477	476	4388 Jason Lights Suite 733\nPaulview, FM 10291	Hilltown	20050	Chile
478	477	33273 Victoria Mews\nJamestown, IN 22002	Amandafurt	26603	Jamaica
479	478	846 Williams Forges\nNorth Dennisberg, NC 94710	Theresaborough	96199	Saint Pierre and Miquelon
480	479	USNS Cooper\nFPO AE 04755	Armstrongmouth	58065	Liechtenstein
481	480	381 Lester Point Suite 769\nStevebury, NV 73464	South Patrickbury	77441	Aruba
482	481	000 Anderson River\nLake Steven, MO 42786	Durhamstad	73906	Austria
483	482	41442 Whitaker Pike Suite 056\nNicoleton, NV 39602	Walshfort	01527	Guatemala
484	483	PSC 6023, Box 2858\nAPO AP 24725	North Prestonhaven	53194	Montenegro
485	484	534 Moore Drives Suite 895\nSmithhaven, MH 81999	Rayshire	25528	Thailand
486	485	77875 Anderson Springs\nNorth Joefort, OK 61724	Bellburgh	92788	Zimbabwe
487	486	078 Rich Parkways Suite 920\nKylebury, MO 90439	West Angelastad	67740	Togo
488	487	3631 Anne Isle\nNew Beverly, LA 77513	East Jenniferberg	63840	Anguilla
489	488	87289 Nathan Points\nNorth Michael, AK 31709	Gonzalezhaven	55797	Saint Kitts and Nevis
490	489	87798 Dean Plains Apt. 408\nAnneburgh, MH 99074	Angelaburgh	57095	Chad
491	490	3383 Sandra Branch Apt. 548\nNew Susanside, CA 8308	South Maria	82769	Slovakia (Slovak Republic)
492	491	0539 Katherine Highway\nWest Benjamin, UT 44322	East Jennifer	98777	Cocos (Keeling) Islands
493	492	89733 Mooney Radial\nEast Carlosville, AK 38993	Herreraland	56717	San Marino
494	493	4995 Meadows Passage Apt. 960\nLake Kristenside, RI	Lisaborough	14136	Guinea-Bissau
495	494	58549 Kim Ferry Apt. 574\nJasonview, MP 04016	North Andrewburgh	56352	Bosnia and Herzegovina
496	495	93624 Roth Village\nLake Michaelchester, IL 05884	Crosbytown	38242	Pakistan
497	496	0334 Christensen Pass\nSharpshire, NJ 57458	West Spencer	00942	Germany
498	497	9915 Michael Station\nLake Stephanieburgh, PA 35494	North Allenstad	76388	Sudan
499	498	493 Moreno Track Apt. 706\nNew Michaelville, KS 970	South Howardport	10913	Kazakhstan
500	499	70651 Martinez Pine Apt. 604\nWalshside, DC 37068	Dianaton	83368	Kenya
501	500	683 Fry Forks\nQuinnbury, PW 38513	Jamesmouth	89787	Mali
502	501	PSC 9566, Box 8927\nAPO AE 73572	Port Marystad	30391	Ukraine
503	502	700 Maria Extensions\nJosehaven, NV 19857	Port Donaldborough	47083	Tunisia
504	503	58196 Conrad Stream Suite 351\nNew Thomas, OK 95718	Craighaven	50248	Luxembourg
505	504	5130 Holmes Roads\nFranklinmouth, NM 15810	Ortizfurt	77516	Montserrat
506	505	783 Howard Row\nDennismouth, OK 11219	Toddtown	05678	Samoa
507	506	1510 Hernandez Shore\nDanielside, HI 01887	Bryanborough	06295	Liberia
508	507	16888 Hunt Mountain\nPerezstad, VA 37696	Gardnerstad	17522	Cocos (Keeling) Islands
509	508	853 Smith Avenue Apt. 874\nPort Matthewfort, SD 491	North Ryan	97132	Mauritania
510	509	350 Richard Radial\nNew Frankborough, VT 35015	West Whitneyfort	97375	Malta
511	510	8062 Heather Gardens Apt. 295\nMurphyside, AL 10467	Lake Shannon	77739	Aruba
512	511	USNV Harper\nFPO AA 65131	Matthewborough	88011	Nauru
513	512	04130 Russell Plaza Apt. 074\nGeorgeville, GA 15584	East Dale	24202	Grenada
514	513	3631 Adams Extension Suite 495\nEast Holly, OK 7736	West Monica	30130	Mozambique
515	514	USNS Haas\nFPO AP 46010	Jenniferside	22557	Qatar
516	515	82795 Adams Roads\nSouth Tommyville, AK 49039	Ramirezmouth	13337	Canada
517	516	2248 Nathan Fields Suite 569\nKimberlyhaven, IA 476	South Keith	97858	Christmas Island
518	517	PSC 3541, Box 3726\nAPO AP 70881	Jamesshire	43229	Malta
519	518	49745 Daniel Parkways\nSouth Joseph, GA 26698	South Jessicahaven	68321	San Marino
520	519	30714 Julie Port\nDouglasport, MI 37280	North Katherine	48852	Aruba
521	520	9260 Aaron Parkways\nKimberlyfort, PW 05560	West William	29708	Maldives
522	521	71401 Kelly Gateway Apt. 795\nLeslieside, NC 08008	Brownmouth	46372	Burundi
523	522	73099 Brown Club Apt. 151\nTerryberg, OR 44467	New Charlesstad	53680	Iceland
524	523	844 Kristina Springs Apt. 834\nNew Nicholas, NV 029	New Marie	72683	Samoa
525	524	09452 Robert Corners Suite 312\nLake Tracey, MA 152	Andrewport	79231	Palestinian Territory
526	525	4454 Dennis Plaza Suite 508\nLake Cynthiastad, AZ 7	Port Samuel	12647	Armenia
527	526	03926 Christopher Extensions Suite 495\nKeithbury, 	Ramseychester	67962	Brazil
528	527	8369 Mary Via Suite 601\nBrucetown, SD 19575	West Charlene	46339	New Caledonia
529	528	141 Amanda Place\nNew Patricktown, TX 75028	Mckenziechester	81681	France
530	529	16393 Melissa Fords Apt. 027\nLewisview, NJ 37124	Kimberlyton	63431	Ukraine
531	530	PSC 9837, Box 2375\nAPO AA 85108	Kellerfurt	53692	Croatia
532	531	0313 Jordan Lakes\nGravesville, HI 38546	Victoriaburgh	91816	Belgium
533	532	99461 Kristine Greens\nAndreatown, NY 25768	Port Zachary	92895	Colombia
534	533	90841 Pena Field\nWest Donald, TX 39784	Tinaburgh	52882	South Africa
535	534	850 Allen Highway Suite 596\nColemanbury, SD 89234	East Loriland	99204	Svalbard & Jan Mayen Islands
536	535	01142 Garcia Crescent Apt. 331\nGregorychester, NM 	Gonzalezchester	64680	Greece
537	536	42100 Tara Island\nLake Max, DC 84320	East Steven	23858	San Marino
538	537	1001 Guerrero Parkway\nNew Michaelport, NM 01261	Port Laura	25712	Libyan Arab Jamahiriya
539	538	84246 Williams Station\nHarrishaven, FM 78596	Waltersborough	16616	Kyrgyz Republic
540	539	731 Ashley Views Suite 641\nSouth Lisaside, MH 7238	Brianborough	74385	Maldives
541	540	4490 Todd Island\nHarrismouth, OH 05284	West Johnton	59893	Saint Helena
542	541	5307 Christina Gateway Suite 102\nNorth Corey, KY 4	Lopezville	53430	Greece
543	542	1924 Alexander Junction\nNorth Ericmouth, WV 85041	West Edwardtown	93012	Ghana
544	543	2698 Benjamin Centers Apt. 528\nNorth Todd, AL 1019	Smithmouth	58909	Montserrat
545	544	Unit 3802 Box 7420\nDPO AA 03903	Walkerborough	68348	Bulgaria
546	545	Unit 4515 Box 8557\nDPO AE 50906	West Ethan	50544	Palestinian Territory
547	546	0091 Cannon Underpass\nPort Amy, CA 57891	Rodriguezmouth	89578	British Virgin Islands
548	547	08202 Larry Motorway\nMorenohaven, OR 09170	Cruzland	36430	Ecuador
549	548	3205 Jennifer Knolls Suite 166\nKarenchester, ID 02	North Sharon	75629	El Salvador
550	549	78324 Cortez Shoals\nNorth Davidberg, PW 79974	Daltonmouth	31236	Somalia
551	550	44507 Charles Lights\nLake April, LA 55639	East Steven	61342	Zimbabwe
552	551	028 Henry Falls\nPort Anthonymouth, MA 46821	Penningtonhaven	95819	Morocco
553	552	0425 Karen Plain\nEast Shannon, AS 67766	Samanthabury	33536	United States Virgin Islands
554	553	01970 Jim Way Suite 249\nLisahaven, SD 78992	North Kimberly	53842	Guadeloupe
555	554	9845 Blackburn Bypass\nEast John, FM 02563	West Nicholasfurt	55342	Latvia
556	555	217 Angelica Camp\nWatershaven, MP 81283	West Shelbyshire	59682	Bahrain
557	556	009 Melinda Ville Apt. 694\nSouth Charles, MI 66681	West Aaronshire	53441	Ghana
558	557	863 Horton Cape\nNorth Biancafort, VT 36692	Kellyside	45017	Guatemala
559	558	15822 Gonzalez Valley Apt. 176\nPort Danielfurt, CT	Christophermouth	64251	Sri Lanka
560	559	09388 Taylor Crossroad\nNorth Annefurt, AS 37536	Port Barbara	91843	Eritrea
561	560	2104 Derrick Shoals Suite 272\nAlexanderside, DE 47	East Ashley	82454	Cocos (Keeling) Islands
562	561	921 Dunn Ridges Suite 682\nCoffeyview, AR 12205	Moniqueberg	92154	Saint Vincent and the Grenadin
563	562	7522 Ricky Way\nNew Craig, IL 81056	Krystalberg	86200	Jordan
564	563	248 Kenneth Parkway Apt. 407\nEast Michelle, PR 839	Potterfort	93377	Palestinian Territory
565	564	855 Sanchez Falls\nLake Anne, SD 92312	East Williamberg	06539	Bouvet Island (Bouvetoya)
566	565	43550 Burns Throughway\nWrightberg, SD 35698	West Yolandastad	71334	Samoa
567	566	237 Alexa Meadow Suite 021\nTimothymouth, PR 60181	Watsonchester	69170	El Salvador
568	567	1318 James Rest\nKatherinemouth, OH 18101	Lake Jeffrey	76432	Switzerland
569	568	8455 David Stravenue Suite 782\nWest Andrew, MT 085	Millerside	57540	Holy See (Vatican City State)
570	569	PSC 4476, Box 5879\nAPO AP 77793	Lucasport	84236	Albania
571	570	1459 Kimberly Underpass\nBrowntown, AK 17485	Davischester	65648	Morocco
572	571	8617 Teresa Streets Apt. 016\nNew Joyce, MP 55090	Tarabury	64526	Monaco
573	572	04213 Long Garden Apt. 954\nNorth Erikamouth, DE 41	Millshaven	06438	Saint Vincent and the Grenadin
574	573	73522 Huang Passage\nEast Joseph, IA 23485	Martinhaven	56552	French Polynesia
575	574	77520 Thompson Key Apt. 448\nWest Meredithton, KS 7	North Angelatown	19585	Norway
576	575	35108 Chapman Throughway\nNorth Shawntown, PW 36811	West Kathryn	28766	Nicaragua
577	576	7769 Chelsea Plaza\nWest Carrie, NE 82323	South Rebeccafort	94916	Denmark
578	577	44430 Lee Plaza\nSouth Nataliechester, NC 26518	Smithhaven	26522	Antarctica (the territory Sout
579	578	9657 Andrew Villages\nDiazport, AK 81148	Adamchester	26757	Guinea-Bissau
580	579	044 Rachel Ridge\nNorth Deannaside, FL 79429	Port Stephenside	43467	Saudi Arabia
581	580	USCGC Dixon\nFPO AE 36460	Whitebury	98463	Tanzania
582	581	721 Jeffrey Cliffs Apt. 377\nSouth Robert, FL 41979	Port Adrianhaven	22718	Ghana
583	582	7906 Mays Passage Apt. 831\nPort Patriciamouth, SC 	Port Michael	39541	Sierra Leone
584	583	87272 Nicholas Forest\nHopkinsstad, LA 94290	Anthonyton	31855	Libyan Arab Jamahiriya
585	584	1305 Scott Isle\nSouth Patrickburgh, MH 67998	North Mitchell	76784	Haiti
586	585	107 David Terrace\nNew Ashley, OH 63356	East Jonathantown	30821	Solomon Islands
587	586	283 Michelle Light Apt. 928\nHallberg, NH 28716	South Coryburgh	27354	Niue
588	587	0527 Melissa Plaza\nWest Robert, CA 41648	North Melinda	65553	Latvia
589	588	29795 Jacqueline Land\nNew Johnstad, WV 15902	North Brentview	59989	Nicaragua
590	589	USS Stone\nFPO AP 30655	Markstown	19979	United States of America
591	590	7868 Jennifer Summit\nJameschester, RI 12741	Heatherburgh	62449	Cayman Islands
592	591	313 Brown Island Apt. 896\nWest Yolandamouth, NV 63	Lake Angela	53185	Russian Federation
593	592	7234 Wolf Prairie Suite 408\nPort Robert, CT 72435	Tommymouth	14575	Indonesia
594	593	4487 Simon Ridge Apt. 464\nNorth Jeffreyfurt, VA 01	Boydton	35845	Cyprus
595	594	020 Nunez Village Suite 737\nWest Kyle, SD 25519	East Calvinmouth	69797	Angola
596	595	PSC 1517, Box 3986\nAPO AP 76349	Dickersonstad	93845	Albania
597	596	45791 Day Land Suite 043\nNorth Tony, WV 40079	West David	92732	Burundi
598	597	792 Randall Spur\nMeganberg, SC 78725	South Deborah	03937	Angola
599	598	83999 Cooper Route Apt. 888\nLewisport, WV 20974	West Juliefort	70067	Mongolia
600	599	7735 Mark Ford Suite 409\nBarronmouth, GU 41286	Kristinafurt	21077	Armenia
601	600	91182 Kevin Row\nNew Bradleyside, MD 75081	North Cindyborough	23395	Saint Kitts and Nevis
602	601	25703 Lopez Valleys\nMelindafort, MN 69007	Woodmouth	73497	Togo
603	602	064 Meyers Stream Suite 195\nAngelamouth, CT 85425	Johnsontown	74662	Zimbabwe
604	603	602 Turner Highway Apt. 468\nNorth Monicahaven, CA 	East Paulborough	94963	Bahamas
605	604	6918 Mason Ways Suite 682\nFrancismouth, IA 97622	Lake Jaclyn	71952	Ireland
606	605	7140 Tami Circle\nSamanthamouth, IN 65430	Kellychester	65438	Afghanistan
607	606	174 Parker Stravenue\nEscobarchester, DE 54322	South Larryview	03372	Kiribati
608	607	6061 Case Grove Apt. 950\nRobertchester, NC 07041	Lake Paul	76166	Tajikistan
609	608	0908 Rodriguez Land Apt. 202\nSouth Samanthaburgh, 	South Christinafort	88812	Cambodia
610	609	25854 Susan Curve Apt. 315\nEast Donald, OH 77977	Shawnville	14313	Wallis and Futuna
611	610	9441 Marcus Mountains Suite 610\nLauriefurt, MA 450	Lake Walter	47860	Ecuador
612	611	222 Pedro Lodge Apt. 794\nEast Molly, VI 13856	Contrerasburgh	42892	United States Minor Outlying I
613	612	152 Sarah Passage\nAnthonymouth, MT 09583	Chavezfurt	25105	Gibraltar
614	613	4971 Anthony Groves\nDavidsonview, DE 10799	East Paula	02640	Bahamas
615	614	4861 Gregory Oval Suite 330\nNew Lauraborough, VI 9	Alexanderberg	31236	Panama
616	615	204 Holmes Ville\nWest Judychester, MT 21780	West Steve	34403	Tajikistan
617	616	3944 Carl Trail\nSouth Debra, MD 82827	South Collinstad	13520	Armenia
618	617	1130 Robert Trafficway Suite 793\nHawkinsfurt, MA 4	Robertfort	88169	Romania
619	618	756 Anderson Stream Apt. 097\nPort Erica, MI 14182	Mckenziefort	49258	Libyan Arab Jamahiriya
620	619	8092 Williams Ferry\nLake Debrastad, HI 34421	Clarkhaven	45276	Andorra
621	620	728 Lopez Ridge Apt. 692\nMikeshire, NE 85347	Thomaston	51879	Holy See (Vatican City State)
622	621	78388 Robin Loaf\nSouth Matthewfurt, NC 78544	East Anna	89131	Swaziland
623	622	11770 Hughes Camp Apt. 587\nNew Tonyland, NC 68748	West James	31552	Seychelles
624	623	786 Blair Trace Apt. 751\nTravisstad, VT 54876	Patriciabury	90250	Lebanon
625	624	339 Alyssa Groves\nLarryshire, UT 68428	Justinberg	72731	United States Virgin Islands
626	625	5900 Burton Ranch\nSouth Donna, WA 29643	Gonzalezfurt	97472	Oman
627	626	1870 Stephanie Radial Apt. 917\nEast Harold, AK 129	Johnsonland	10681	Papua New Guinea
628	627	162 Cassidy Shoal Suite 698\nEast Juliatown, FM 426	Jenniferfurt	85090	Estonia
629	628	0811 Lauren Trafficway\nJenniferborough, IN 34428	Lynchburgh	59270	Lithuania
630	629	233 Amy Lodge\nSwansonfurt, KS 01404	Port Philip	38496	Vanuatu
631	630	05323 Bridges Orchard\nCarolynton, KS 45213	Anthonybury	79166	United Kingdom
632	632	995 Melissa Springs Suite 715\nNew Edward, NY 15444	Stephenchester	95424	Puerto Rico
633	633	5075 Howard Forest Suite 904\nRebeccaville, AR 6582	Lindatown	94787	Svalbard & Jan Mayen Islands
634	634	388 Boyle Port\nPort Jillchester, RI 49195	North Trevorhaven	43024	Croatia
635	635	426 Gabrielle Rapids Apt. 615\nDillonchester, DE 69	Cooperside	89945	Ireland
636	636	186 George Shores Suite 431\nLake Annemouth, WI 958	Laurafort	38438	Montenegro
637	637	58556 Mark River Apt. 735\nLake Kyle, ME 88567	Boydview	95609	Luxembourg
638	638	78169 Mario Alley Suite 373\nStephenmouth, AR 46333	Rachelburgh	29125	United Arab Emirates
639	639	665 Peters Burgs Apt. 696\nEast Brandi, DC 83347	West Anthony	92707	Mexico
640	640	658 Tyler Points\nDevonland, CA 39746	Rodriguezchester	95527	Saint Martin
641	641	55052 Wells View Suite 063\nPearsonview, AR 94979	Cookport	77341	Kuwait
642	642	Unit 0973 Box 8907\nDPO AP 18330	North Emily	31444	Holy See (Vatican City State)
643	643	15751 Joseph Courts Apt. 905\nLittlefort, ID 19852	Timothyshire	33390	Wallis and Futuna
644	644	99045 Cook Pike\nPattersonchester, NV 57699	West Carol	56565	Bouvet Island (Bouvetoya)
645	645	92438 John Islands Suite 891\nLake Robertmouth, PR 	Robertbury	43187	Turks and Caicos Islands
646	646	168 Young Roads\nNew Lisamouth, NM 47295	South Kathrynville	05414	Greece
647	647	051 Andrews Port\nCarpenterbury, NM 62812	West Kevinfort	38395	Montserrat
648	648	2946 Johnson Mountains Suite 402\nEast Mark, NM 352	West Austinberg	49814	Pakistan
649	649	3311 Monroe Prairie\nEast Savannah, NY 64840	Stricklandtown	97191	Jersey
650	650	97050 Katherine Port\nLake Brandon, KS 98101	Lake Meganland	79943	Bangladesh
651	651	704 Morales Mountain\nPort Daniel, CO 74761	Lake Brittany	81770	Jordan
652	652	3842 Cynthia Spring Apt. 842\nLeemouth, PA 49754	Shaffermouth	36735	Indonesia
653	653	07193 Peters Tunnel Suite 396\nNew Annahaven, WY 74	Hernandezbury	45372	Indonesia
654	654	294 Shaw Wells Apt. 615\nWest James, NJ 67510	Dixonport	86435	Czech Republic
655	655	37522 Latoya Centers\nLongtown, SD 94172	South Tyroneside	21269	Czech Republic
656	656	014 Joshua Prairie Suite 616\nLeeton, SC 28806	New John	70472	Brazil
657	657	93531 Calvin Locks Apt. 706\nEast Shirley, IL 40817	Russellbury	99333	Samoa
658	658	54419 Nicole Passage\nWashingtontown, CO 43924	South Markview	85978	Marshall Islands
659	659	779 Warren Village Suite 751\nSouth Robert, IA 4766	Crystalborough	29437	Chad
660	660	772 John Divide Suite 998\nBooneview, KY 35684	Johnsonton	68675	Seychelles
661	661	20793 Daniel Meadows Suite 915\nPort Melissa, SC 67	East Jamesmouth	60355	Netherlands Antilles
662	662	0813 Brian Lakes\nNew Dustinport, GA 87571	New Randallland	72421	Croatia
663	663	24639 Peter Knoll\nChristineville, TN 32409	North Kevinville	09572	Turkey
664	664	404 Ricky Hill Apt. 462\nSmithhaven, SC 99115	Jaredburgh	69903	Hong Kong
665	665	65864 Morgan Circle\nEast Tinaborough, MI 07040	Jocelynview	07818	Barbados
666	666	552 Richards Center\nNew Jamesville, NY 15421	Tiffanyland	08634	Heard Island and McDonald Isla
667	667	2514 Carmen Creek\nBryantburgh, GA 20880	New David	54062	Seychelles
668	668	0074 Brandi Road\nCharlesmouth, AR 53951	Hudsontown	06039	Solomon Islands
669	669	288 Gordon Place\nSloanview, ND 69093	New Christophertown	65523	Samoa
670	670	Unit 6578 Box 6503\nDPO AP 81611	Gonzalesview	78575	Lebanon
671	671	452 Miller Haven\nEast Sharonfurt, MN 54487	Hermanfurt	69584	Korea
672	672	51465 Brian Fork\nSouth Haley, RI 80694	Lake John	11565	Anguilla
673	673	643 Ashley Pike\nHeidifurt, ME 27446	Michaelmouth	99477	Morocco
674	674	62550 Chris Parkways\nRickyport, AK 28669	Brandonview	69468	Aruba
675	675	Unit 4746 Box 2921\nDPO AP 40674	Monicabury	24607	Colombia
676	676	778 Nunez Causeway Suite 977\nNew Michele, MH 74032	North Dominiqueshire	10286	Somalia
677	677	24054 Stephen Row Suite 746\nPort Vickie, MP 62465	Bowenton	18531	Niger
678	678	5189 Olsen Gateway Apt. 707\nJeffersonton, LA 24148	Aaronfurt	80351	Senegal
679	679	48702 Katie Lodge Suite 091\nSouth Melissa, AK 4985	New Stephanie	33241	Zambia
680	680	81402 John Meadows\nNew Andrewberg, PW 27907	Patrickmouth	99269	France
681	681	3286 Andrew Isle Suite 621\nSouth Jamesfurt, TN 593	Jaredfurt	51269	Saint Barthelemy
682	682	41367 Calvin Branch\nMichaelborough, VI 65766	Kentmouth	86156	Saint Martin
683	683	91860 Contreras Pike\nNew Kyleside, VA 13612	Port Michele	55647	Eritrea
684	684	88125 Thomas Road Suite 883\nWest Elizabethville, P	Heatherfort	27980	Morocco
685	685	USS Jenkins\nFPO AP 85433	Peggyside	26155	New Caledonia
686	686	9612 Hughes Stravenue Suite 792\nWilliamsburgh, DC 	Amandafort	72430	Montserrat
687	687	750 Beth Spring\nNorth Alexanderland, GU 97526	North Laurashire	94461	Grenada
688	688	Unit 2204 Box 2208\nDPO AA 66628	South Jenny	49629	Greece
689	689	258 David Corner\nNew Shannonmouth, LA 70397	New Donald	72618	Madagascar
690	690	4288 Kristopher Squares Apt. 107\nBarrport, WY 2585	New Ryan	04447	Denmark
691	691	6506 Palmer Ports Apt. 787\nEast Kimberlytown, SD 1	East Angelafort	57157	Ireland
692	692	8210 Jones Mill\nJosephtown, NY 69044	West Jenna	47821	Bolivia
693	693	566 Kenneth Mill Suite 140\nRichardview, MH 40917	Sanchezhaven	75356	Pakistan
694	694	274 Schmidt Wall Suite 923\nLauraville, ID 56564	Brownbury	97919	Vietnam
695	695	249 Andrews Center Apt. 576\nHatfieldport, VT 60280	Nelsonstad	30962	Liechtenstein
696	696	296 Kelly Crest Suite 611\nEast Amanda, OR 53328	Stewarttown	66152	Maldives
697	697	4166 Jeremiah Brooks\nRobertborough, FM 71275	Amandabury	28307	Netherlands Antilles
698	698	518 Andrews Viaduct\nEast Ann, IA 51951	Browningberg	94654	Gabon
699	699	9091 Johnson Radial\nNew Leslie, OR 88541	South Elizabethville	10970	Romania
700	700	757 Green Expressway Suite 445\nBlakeland, AZ 54313	Turnerfort	52873	Portugal
701	701	51692 Valerie Lodge\nLake Jamesbury, CA 96059	Karaport	89053	India
702	702	8209 Harris Corners\nWilsonbury, GU 62814	Aaronbury	65732	Tokelau
703	703	180 Kurt Alley Suite 414\nLake Sharon, ID 43792	Mendezchester	45118	Poland
704	704	608 Jackson Summit Suite 922\nPort Staceyville, VA 	East Kelseybury	61558	Qatar
705	705	Unit 9076 Box 3380\nDPO AP 35926	Williamsbury	70958	Bouvet Island (Bouvetoya)
706	706	63978 Billy Center\nNicoleland, AL 89518	Michelleberg	01067	Nigeria
707	707	6437 Garcia Branch\nJohnnyberg, NM 84884	Lindsaychester	90077	Iraq
708	708	76564 Carla Curve\nHessmouth, VT 74843	South Michelle	23642	Togo
709	709	675 Katie Groves Apt. 398\nJoseview, KS 49487	East Amandafurt	83896	Italy
710	710	5646 Mckee View\nFordborough, VI 10546	Johnfort	81947	China
711	711	133 Daniel Dale\nGinastad, OR 24024	Sandramouth	00754	Madagascar
712	712	6144 Warren Key\nGalvanmouth, MS 24002	Bakerland	96483	Guinea-Bissau
713	713	357 Clayton Flats Apt. 463\nThomasland, VA 46670	East Lisa	10333	United Kingdom
714	714	56171 Bird Shoal Suite 830\nJameshaven, VT 63445	South Kevinbury	13238	Kazakhstan
715	715	32235 Robert Shores Apt. 846\nCollierport, AL 80064	West Diane	82865	Suriname
716	716	609 Rhodes Inlet Apt. 140\nWest Ian, KY 06583	Hendersonton	18685	Canada
717	717	44816 Smith Underpass\nThomasborough, IL 81416	Lake Alice	85832	Aruba
718	718	64632 Veronica Mills\nEast Sarah, WV 52615	West Chadview	09003	Iceland
719	719	Unit 5472 Box 0169\nDPO AA 82013	Hernandezland	60194	Zimbabwe
720	720	73576 Sean Place Suite 813\nWest Kevinmouth, SC 695	Jenniferhaven	76429	Tajikistan
721	721	4722 Logan Dam\nWest Crystal, NM 38142	Tammyville	79166	Cote d'Ivoire
722	722	7247 Barnett Fork\nRamosfort, TX 85513	Davistown	91612	Mali
723	723	0600 Kelly Shore\nAlexanderfort, WY 48620	West Marybury	70338	Guam
724	724	08859 Gomez Springs\nKaitlynchester, KS 14785	Davidchester	36610	Spain
725	725	USCGC Bell\nFPO AA 42737	Paulview	18874	Cambodia
726	726	759 Frederick Pass\nNew Thomasfort, CA 39406	New Yvonnestad	52949	Timor-Leste
727	727	1285 Todd Prairie\nSouth Douglas, NV 95319	North Jeremy	18043	Slovakia (Slovak Republic)
728	728	2915 Pratt Rapid Apt. 927\nSchaeferchester, OR 4952	Davidborough	41735	Cyprus
729	729	60137 Galloway Port Suite 783\nMartinton, UT 78564	Marcohaven	31810	Botswana
730	730	1093 Bishop Oval\nRebeccaberg, OK 60216	Lawsonmouth	53119	Russian Federation
731	731	055 Hayes Drives\nPort Steve, IN 47100	East Erintown	90741	Italy
732	732	02081 John Rapids Suite 646\nWellstown, AS 83131	North Lorraine	39875	Madagascar
733	733	27970 Massey Union\nPort Jenniferberg, OH 57323	Hallmouth	21870	Martinique
734	734	1567 Troy Square\nCarterton, WI 09893	Amyport	85101	Belgium
735	735	058 Jesus Via\nRonaldland, IL 39007	East Kelseymouth	51060	Heard Island and McDonald Isla
736	736	93451 Megan Junctions\nRobertfurt, MD 33109	Alextown	18652	Pitcairn Islands
737	737	USS Hopkins\nFPO AE 88019	Moonhaven	25757	Saint Helena
738	738	15675 Perez Light Suite 333\nDeborahburgh, CA 19422	Tateshire	22985	Belize
739	739	81839 Stevens Garden\nWest Ericchester, AK 79395	West Lisahaven	96898	Cook Islands
740	740	545 Brown Place\nMatthewchester, AL 91677	Adkinsview	52666	Sudan
741	741	6481 Griffith Island Apt. 103\nRodriguezview, RI 54	North Lesliefort	95819	Mali
742	742	5323 Jones Ranch\nJenniferfurt, CA 32004	North Robertview	36675	Poland
743	743	07527 Denise Glens\nLisaview, NJ 65248	North Jamesview	15007	Niue
744	744	273 Smith Crest Suite 135\nAllenhaven, NE 17370	South Kevin	08074	Malta
745	745	6251 Rodriguez Forks\nLake Lukefurt, MN 62060	Natalieland	63943	Morocco
746	746	05803 Ashley Forest Suite 373\nSouth Lori, FL 29297	Jeffreymouth	42714	Chile
747	747	7410 Perez Shoals\nLake Michaelfurt, IA 46596	Pamelastad	21136	Marshall Islands
748	748	USNV Harris\nFPO AA 99435	Maloneville	71107	Guinea
749	749	91632 Ryan Well\nHuntstad, AZ 08353	Lake Meganfurt	51699	Finland
750	750	795 Gates Extension Suite 635\nPort Dennis, WV 0690	Zacharyton	57042	French Guiana
751	751	70803 Coleman Trail\nLake Susan, AR 76498	Brianfurt	82213	Guadeloupe
752	752	6442 Rodriguez Cliffs\nHortonhaven, MH 09187	Paulfurt	87563	Central African Republic
753	753	PSC 7074, Box 4496\nAPO AA 42425	Jamesside	04447	Tokelau
754	754	34780 Chase Springs\nNew Christophershire, NV 29578	North Perryside	66060	Timor-Leste
755	755	95216 Rangel Valley\nSusanberg, ME 57644	Port Danielview	33630	Saint Pierre and Miquelon
756	756	USCGC Jones\nFPO AA 57723	South Jesseside	12589	Bulgaria
757	757	Unit 5978 Box 0319\nDPO AE 66725	East Natalie	22530	Guam
758	758	29252 Charles Wall Suite 510\nEast Tonya, VI 71145	Elizabethfurt	33367	Croatia
759	759	0280 Randall Station\nSouth Stephanie, FL 16254	Lake Edwinport	90327	Bhutan
760	760	974 Rachel Lake Suite 024\nHillberg, TX 06624	Chavezfurt	49423	Netherlands
761	761	0893 Singh Valley Suite 910\nWest Jessicaton, OK 78	West Veronica	80911	Philippines
762	762	186 Rachel Island Apt. 332\nCarrollland, VT 96072	Rodneyfort	96781	Martinique
763	763	18631 Smith Walks Apt. 214\nLevimouth, SC 05858	Port Nicolasmouth	01247	Guinea-Bissau
764	764	96980 Fitzpatrick Prairie Apt. 805\nLake William, I	Lake Gabriellecheste	25930	Slovakia (Slovak Republic)
765	765	530 John Summit\nLake Holly, FL 87587	Perryville	20047	Gibraltar
766	766	90794 Hansen Plain\nAlexandertown, ME 26908	East Amanda	04909	Puerto Rico
767	767	46914 Meghan Cove\nDicksonside, NV 37381	West Michaelland	66202	Spain
768	768	5370 Megan Skyway\nEast William, AR 09262	Fergusonland	16795	Serbia
769	769	8435 Weiss Knoll\nNorth Cheyenne, WY 97840	South Katieside	92432	Monaco
770	770	PSC 6723, Box 6683\nAPO AE 91809	Devonfort	36070	Guernsey
771	771	6928 Lewis Ports\nNorth Marymouth, CO 52603	Andrewchester	94290	Brazil
772	772	Unit 6739 Box 5879\nDPO AE 01429	Mossland	49500	Mexico
773	773	43117 Lindsey Common Apt. 015\nMaryport, MS 49911	Chenville	10019	Finland
774	774	05013 Jeffrey Cliff Apt. 004\nAshleyport, MP 11852	Lisaville	17403	Christmas Island
775	775	596 Hannah View Suite 600\nPort Alyssa, GU 36193	Danielmouth	32851	Timor-Leste
776	776	2374 Turner Drive\nWest Johnborough, MH 23819	Howardfurt	73926	Vietnam
777	777	4665 Christopher Centers Apt. 958\nFordchester, NY 	Christinamouth	40559	Togo
778	778	USNV Larsen\nFPO AE 20995	New Barbara	92821	Nauru
779	779	1750 Jones Common Apt. 884\nKylefort, MP 92459	East Jake	96004	French Polynesia
780	780	11320 James Union Suite 363\nNew Shawnfort, KS 7578	West Calvin	98723	Korea
781	781	634 Thomas Forge Suite 583\nLeslieton, WA 34763	South Anthony	15995	Macao
782	782	3534 Desiree Rue\nEspinozaland, UT 80967	East Wesleyville	45508	Martinique
783	783	3403 Adams Lakes\nNew Michael, NH 62262	New David	83489	Vanuatu
784	784	0501 Smith Row Suite 236\nLake Jennifermouth, PW 42	East Stephanie	05728	Bhutan
785	785	4233 Doyle Crossing Suite 647\nEast Kristinahaven, 	Mosesburgh	14883	Saint Pierre and Miquelon
786	786	197 Peterson Glen Suite 863\nDavisview, NY 76902	Obrienmouth	26724	South Georgia and the South Sa
787	787	12144 Crystal Gardens Apt. 664\nSouth John, MD 8627	Tinaborough	80879	Azerbaijan
788	788	1177 Stevenson Cliffs Suite 973\nLake Darrell, MO 8	South Karenland	11098	Faroe Islands
789	789	893 Jeffery Lake\nNathanview, NH 96611	East Joshua	82508	Norway
790	790	8829 Janet Inlet\nEdwardview, OH 29926	Jayfort	73712	Bhutan
791	791	10490 Jessica Knolls Suite 400\nWest Austinbury, ND	South Scottmouth	30007	Marshall Islands
792	792	3376 Logan Bypass\nNew Gerald, MH 73587	Mccannberg	90299	Moldova
793	793	10564 Robert Mission Apt. 238\nPort Michaelstad, NJ	Brendaland	41104	Northern Mariana Islands
794	794	5748 Curtis Trafficway\nMurphytown, NC 57187	North Jerryfort	06477	Syrian Arab Republic
795	795	7376 Smith Prairie\nPort Theresa, AR 97592	Ericstad	46543	Guam
796	796	3820 Mackenzie Inlet\nJosephport, MD 46622	Aaronburgh	41827	United Arab Emirates
797	797	833 Phillips Well Suite 146\nKathleenport, FL 76675	New Jaimemouth	74118	Malta
798	798	00488 Nash Expressway\nMillerton, ND 10260	Morrisbury	42583	Norway
799	799	2667 Kevin Forge Apt. 406\nSouth Christinaside, NJ 	Zavalaton	69199	Norfolk Island
800	800	Unit 9648 Box 4164\nDPO AP 80325	Christophertown	68762	New Zealand
801	801	01533 Lee Creek\nLake Christina, OR 22807	Patriciachester	61367	Qatar
802	802	370 Jeffery Fall\nNorth Annette, LA 37397	Sherryburgh	92865	Egypt
803	803	59437 Mercado Fields\nSouth George, CO 05413	New Michael	84388	Seychelles
804	804	0393 Martin Mountains\nLoriside, CA 69926	East Kimbury	22777	Mexico
805	805	80551 Marshall Knoll\nDawnport, AK 39221	Bradleyhaven	02637	Peru
806	806	623 Lopez Circles\nSouth Christopher, NM 37373	Jonestown	63704	Sweden
807	807	PSC 7082, Box 7549\nAPO AA 60960	Lake Conniestad	05508	Brazil
808	808	PSC 3213, Box 1733\nAPO AP 99208	Matthewtown	39536	Belize
809	809	5219 Roberts Lakes Apt. 533\nNew Wandashire, IA 925	Figueroatown	15557	Puerto Rico
810	810	23506 Kevin Heights Suite 865\nNorth Heather, LA 54	Lake Dianeburgh	96386	Nepal
811	811	07425 Farley Route Suite 865\nNorth Courtney, NM 59	Lake Robertmouth	57035	Niue
812	812	306 Amy Divide Apt. 125\nKevinview, FL 38307	Reynoldsmouth	69415	Algeria
813	813	735 Melissa Pine\nPort Anthony, FL 72205	East Martin	82529	Faroe Islands
814	814	3211 Shannon Place\nColleenborough, MT 12778	Lake Marymouth	84662	French Southern Territories
815	815	Unit 8014 Box 0518\nDPO AP 66419	North Ashley	69591	Slovenia
816	816	02761 Christopher Ridges\nArnoldhaven, KY 50595	Port Amberside	84201	Guinea
817	817	11200 Norma Terrace\nNew Keith, IL 03322	Lake Carla	67578	South Africa
818	818	493 Nicole Meadows\nNorth Caleb, MT 85715	Port Susanton	03556	Swaziland
819	819	9493 Martinez Trail\nJameshaven, AK 69239	East Katelyn	02783	Ireland
820	820	Unit 5107 Box 1950\nDPO AE 41980	Lake Stephanieton	78828	Madagascar
821	821	74636 Mikayla Mountains\nRuizfurt, CT 06527	Lake Darrellhaven	64271	Burundi
822	822	1931 Richard Dale Apt. 158\nJeffreychester, SC 9177	Lake James	49196	Cyprus
823	823	682 Guerrero Junctions\nEast Josephchester, NH 7045	Browningbury	15403	Estonia
824	824	2791 Shane Ville Suite 494\nPetersmouth, AK 67881	South Coreyshire	11283	Bulgaria
825	825	PSC 2877, Box 8194\nAPO AE 32118	Lake Elijahfurt	90389	Trinidad and Tobago
826	826	4241 Willis Rest\nSouth Rhondaburgh, ME 26838	Hallfort	36643	Anguilla
827	827	77839 Suarez Drives Apt. 558\nRyanland, MN 16806	West Deborahmouth	82320	Vietnam
828	828	PSC 5441, Box 4240\nAPO AA 84169	Brittanymouth	05463	Netherlands
829	829	6018 Miller Glens Apt. 792\nStephaniechester, AR 81	Lake Richard	81881	Cuba
830	830	645 Smith Mission Suite 735\nNew Kristentown, AS 64	Lake Codyland	59114	Madagascar
831	831	5565 Lori Burg\nNorth Justin, IN 44170	Scottburgh	96931	Syrian Arab Republic
832	832	3887 Teresa Loop Suite 163\nMarkfort, CO 51593	Port Brenda	30635	Moldova
833	833	1792 Collins Road\nWest Krystal, MO 65858	Lake Curtis	79044	Ukraine
834	834	730 Emily Corners Apt. 260\nTracyville, NC 35091	South Kaitlyn	55913	United States of America
835	835	087 Hudson Harbors\nScottberg, MS 07857	Curtismouth	56560	Luxembourg
836	836	97101 Paul Way\nSmithberg, VT 50288	Burnshaven	85228	Northern Mariana Islands
837	837	69269 Jessica Ports Suite 152\nColemanmouth, WA 492	North Alexchester	30473	Northern Mariana Islands
838	838	9840 Hull Parkways\nSouth Nicole, MT 53718	North Anthony	08594	Montenegro
839	839	5312 Matthew Summit Apt. 505\nBoltonfurt, MP 87237	Alvaradoville	43561	Italy
840	840	3757 Taylor Forest\nBarkershire, MH 99670	Lopezview	43999	India
841	841	130 Whitaker Plain Apt. 002\nStephanieside, MS 9926	North Rebecca	67172	Guyana
842	842	7685 Beck Track\nPort Michael, RI 60364	North Derrickberg	36734	Jersey
843	843	382 Carroll Village\nNorth Donnahaven, ID 44835	Port Rachelborough	70253	Taiwan
844	844	751 Watts Squares\nRodriguezville, VI 77561	East Michaelstad	65418	Sweden
845	845	PSC 4503, Box 3201\nAPO AA 28190	Port Andrew	99378	Albania
846	846	756 Oliver Valley\nNew Brandontown, AK 95290	West Chadshire	44875	Monaco
847	847	8496 Griffith Ports\nNorth Ryan, NC 80791	South Lori	24697	Bahrain
848	848	7972 Cook Trafficway Suite 185\nLake Shawn, MN 0685	Tonyahaven	80190	Palau
849	849	53832 Charles Prairie Apt. 346\nSalasfort, GU 98232	South Williamtown	58451	Guernsey
850	850	321 Berger Overpass Apt. 455\nPort Tony, VA 34528	Deleonborough	95061	Guyana
851	851	32881 Brandon Passage\nAarontown, CT 69516	West Stephen	20497	Lesotho
852	852	014 Cross Crossing Apt. 562\nZimmermanmouth, AZ 913	Petersstad	93414	Montserrat
853	853	1139 Richard Crossroad\nObrienberg, OR 36146	East Mariastad	49219	Western Sahara
854	854	927 Alicia Islands Suite 148\nNew Patricia, VI 8232	Johnborough	89729	Iran
855	855	500 Taylor Expressway\nJosefort, AK 56768	Port Timothyport	96032	Russian Federation
856	856	9736 Willis Field Suite 630\nEmilytown, DE 50640	West Lisa	77537	Belgium
998	998	327 Arias Views\nBarrside, TX 78123	Marksville	32321	Bhutan
857	857	Unit 1038 Box 3747\nDPO AA 58375	East Lisashire	31882	Guinea-Bissau
858	858	Unit 7882 Box 3595\nDPO AE 62857	Shauntown	72140	Sri Lanka
859	859	Unit 2815 Box 2853\nDPO AA 85200	Lisafort	22364	Belarus
860	860	0925 Graham Isle\nWest Keith, CO 08827	New Zachary	03540	Tajikistan
861	861	USNS Davis\nFPO AA 21834	South Rebeccaton	04039	Cocos (Keeling) Islands
862	862	53666 Simpson Corners Suite 794\nSmithstad, FM 4102	Robertside	59291	Wallis and Futuna
863	863	303 Brett Ways Apt. 886\nEast Linda, KS 38761	North Christopherbor	71934	Central African Republic
864	864	85053 Angela Port\nThomasside, VT 79909	South Bianca	99279	Jamaica
865	865	6912 Harrington Ranch\nNew Diana, KS 48357	Codytown	89076	Israel
866	866	161 Donald Overpass Apt. 811\nNew Trevorstad, NH 86	Schultzhaven	01596	Poland
867	867	Unit 6601 Box 0579\nDPO AP 84285	Johnmouth	79881	Falkland Islands (Malvinas)
868	868	Unit 3005 Box 4319\nDPO AE 68096	North Vincentshire	43604	United States Virgin Islands
869	869	31660 Michelle Summit Apt. 878\nRossville, FL 03092	Allisonmouth	53568	Iraq
870	870	0024 Miranda Hill\nPerryfurt, HI 26809	Owenfort	12819	Benin
871	871	8525 Pamela Plaza Apt. 640\nSouth Christopherside, 	South Tammy	52153	Falkland Islands (Malvinas)
872	872	68293 Brown Drive Apt. 023\nTaylorburgh, FL 61665	West Danielport	55280	Jordan
873	873	7385 Guerrero Keys Apt. 957\nWatsonburgh, PR 56236	Jenniferfort	43220	Cote d'Ivoire
874	874	815 Oliver Expressway Suite 180\nAlexanderstad, NH 	North Jessebury	64499	Bangladesh
875	875	430 Mack Flats\nMcdonaldshire, NC 87955	New Joelburgh	26851	Latvia
876	876	2443 Norton Crossroad Suite 064\nBenjaminbury, AL 8	Torresshire	17670	Brunei Darussalam
877	877	9841 Dean Springs\nLake Alyssa, ID 99928	East Justin	62619	Madagascar
878	878	02624 Michael Glen Apt. 946\nNorth Angelabury, HI 8	Stevebury	03674	Austria
879	879	6197 Hancock Field Suite 441\nPamelachester, GA 157	North James	86940	Tajikistan
880	880	PSC 5880, Box 1039\nAPO AP 03283	West Elizabeth	63150	Italy
881	881	33490 Mark Dale Suite 134\nFryehaven, NH 96226	Veronicashire	57496	Peru
882	882	PSC 1901, Box 2244\nAPO AP 58179	Wellsberg	57569	Philippines
883	883	8068 Spencer Keys\nMillsfurt, NV 02723	North Randy	38083	Bermuda
884	884	07273 Lopez Summit Suite 150\nNortonfort, VA 71770	North Rodney	53935	Honduras
885	885	91435 Cooper Crossroad Suite 662\nLake Jacqueline, 	Bellbury	44142	Libyan Arab Jamahiriya
886	886	81535 Teresa Burgs Suite 817\nJohnnyside, PA 77891	New Edward	98771	Luxembourg
887	887	24710 Hendrix Forge Suite 904\nLake Jeremy, NY 1286	Port Kelly	42289	Palau
888	888	28928 Jeffery Haven\nGrossmouth, ID 17387	Anthonyborough	01313	Anguilla
889	889	7046 Tyler Tunnel Suite 096\nMigueltown, WY 07821	Larryview	09233	Mauritius
890	890	78488 Edwards Plaza\nGeorgeview, PR 21883	Edwardsberg	35504	Belarus
891	891	378 Crawford Junction\nTurnerland, NH 99398	South Kyleborough	61389	North Macedonia
892	892	6444 Greer Drive Suite 335\nEast Michele, WY 01281	Emilymouth	69077	Macao
893	893	7339 Robert Fort Suite 669\nWest Peter, NJ 67208	Boyerport	08753	Palau
894	894	523 Owens Place Suite 045\nGonzalezstad, DC 83086	North Jefferyville	20957	Ghana
895	895	668 Isaac Square\nSouth Jamesville, WI 50189	Jamesburgh	53317	Jamaica
896	896	209 Blake Crossroad\nSouth Ericborough, PA 92681	New Dennis	97938	Jersey
897	897	886 Joshua Loaf\nNew Jennifer, IL 12685	Lake Johnfort	62588	Guadeloupe
898	898	4621 Irwin Radial\nPort Samuelfurt, MO 79118	Evelynview	13125	Turkey
899	899	PSC 7063, Box 5688\nAPO AA 79117	West Todd	85233	Zambia
900	900	2670 Jennifer Heights\nJaredview, NY 63087	Wallaceville	52180	French Southern Territories
901	901	74112 Austin Pass Apt. 369\nJasonland, NC 32344	East Cody	07193	Sudan
902	902	18256 Wright Streets\nWest Brendaside, IN 53059	Petersonfurt	47704	Moldova
903	903	34921 White Tunnel\nNorth Morgan, NC 35480	Susanbury	15581	Tanzania
904	904	121 Oliver Crossroad Suite 288\nTinamouth, CA 76896	Lake Juan	46273	United States of America
905	905	297 Herman Inlet Apt. 851\nMichelleborough, WV 6806	West Angelaborough	87634	Jersey
906	906	9384 Carr Hollow\nPort Rachel, MP 40570	West Kentfort	45458	Gabon
907	907	1394 King Valley\nSouth Brian, WV 14226	Romanstad	04732	United States Virgin Islands
908	908	929 Osborn Turnpike\nRogersside, GA 63627	East Shelbymouth	98469	Poland
909	909	1983 Jennifer Hollow Suite 964\nJasonmouth, TN 1833	West Tina	84081	Switzerland
910	910	5216 Patricia Isle\nPamelashire, PW 70374	Cynthiaville	21669	Montenegro
911	911	204 Wendy Brooks Apt. 732\nPamelabury, VA 93349	Port Jason	67286	Mayotte
912	912	807 Wagner Divide\nRebeccaville, MT 74320	Lake Kevin	42974	Fiji
913	913	PSC 9732, Box 8433\nAPO AE 79557	Matthewmouth	57321	Finland
914	914	362 Lawrence Mountain Apt. 105\nHalechester, PW 495	Robertmouth	44691	Tonga
915	915	USCGC Juarez\nFPO AE 94393	West Nathanielland	25710	Equatorial Guinea
916	916	15255 Christian Forge Suite 169\nMcclureside, VI 80	North Brandychester	38438	Heard Island and McDonald Isla
917	917	29607 Davis Isle Suite 629\nChristinaville, SD 6935	North Krista	17936	Zambia
918	918	375 Mendez Islands\nStewartburgh, NY 12290	West Michael	58222	Cape Verde
919	919	3456 Stephanie Corners Apt. 120\nNew Xaviershire, N	East Dennis	71607	Finland
920	920	PSC 5282, Box 8763\nAPO AE 52668	East Evelyn	81057	Togo
921	921	6104 Lori Mews\nWest Donnahaven, WV 25827	Port Elizabeth	11442	Antigua and Barbuda
922	922	3512 Patterson Fords\nEast Erin, IL 35556	East Amandashire	22644	El Salvador
923	923	59246 Cruz Forge Apt. 296\nNew Jeremy, WV 04927	New Andreaview	55487	Falkland Islands (Malvinas)
924	924	80992 Lee Centers Apt. 936\nPatrickshire, AL 53163	Victoriafurt	56019	Colombia
925	925	6894 Amanda Coves Suite 243\nJohntown, AZ 78641	South Jacksonmouth	32234	French Guiana
926	926	105 Christopher Rest Suite 914\nHowardburgh, WA 038	Jaimemouth	55495	Turks and Caicos Islands
927	927	USCGC Harvey\nFPO AA 79310	Lake Amyton	67326	Chile
928	928	5432 Jackson Land Apt. 945\nSouth Anthony, NE 72942	Jillshire	33319	Kenya
929	929	942 Bowman Knoll Apt. 052\nWest Bobby, AK 82192	Martinezshire	12714	Slovakia (Slovak Republic)
930	930	89925 Ross Brook Suite 499\nNorth Peter, VA 41776	East Kyleton	21719	United States of America
931	931	555 Barbara Terrace\nGordontown, NE 56431	Fullermouth	92300	United Arab Emirates
932	932	57291 Eric Fields\nEast Deannafort, ND 63510	South Deannahaven	42654	United Kingdom
933	933	7811 Joseph Ridge Apt. 221\nJohnsonville, ND 16638	Lake Shannonside	87526	Antarctica (the territory Sout
934	934	93152 Amanda Orchard Apt. 808\nPort Maryport, NY 39	Chavezstad	01019	Grenada
935	935	485 Ross Views\nHintonport, WY 07925	North Gabrielchester	47142	Saint Lucia
936	936	386 Cesar Route Apt. 503\nLake Anita, WY 92581	South Brittneyboroug	86519	Bulgaria
937	937	PSC 5462, Box 9978\nAPO AP 52539	Millerton	25649	Timor-Leste
938	938	199 Thomas Islands\nEast William, GU 97446	Lake Samanthastad	42206	Uganda
939	939	8141 Shari Ways Suite 848\nRobertmouth, MD 02495	North Jenniferview	69905	Cote d'Ivoire
940	940	Unit 2716 Box 5657\nDPO AA 21336	Adammouth	72915	Saint Kitts and Nevis
941	941	903 Jason Plaza\nSouth John, OK 59666	Port Brittanyburgh	53858	Cameroon
942	942	02026 Raymond Junction Apt. 213\nLake Samantha, AZ 	Woodsmouth	34997	Jamaica
943	943	4713 Rebecca Avenue\nPaceland, OK 73407	Davidland	53999	Tokelau
944	944	300 Whitney Underpass\nRyanberg, NY 45235	Wallaceville	74965	Lao People's Democratic Republ
945	945	392 Faulkner Land\nJasonfurt, AR 45593	Wrightfurt	93559	Bangladesh
946	946	975 Frank Stravenue Suite 697\nWest George, MP 1549	East Carla	80841	Romania
947	947	9505 James Crest\nEast Steven, AR 20145	East Juliehaven	36627	Zimbabwe
948	948	530 April Plain Apt. 359\nEast Travis, OK 47413	East Chadberg	47889	Togo
949	949	12897 Dean Springs Apt. 984\nJessicatown, OK 80277	New Tony	54519	French Polynesia
950	950	341 Sherman Row\nPetersenstad, TN 02258	West Marcus	28032	France
951	951	68345 Cody Mountain\nPattonport, TX 48428	Robinsonfort	68888	Cameroon
952	952	9960 Michael Mountain\nNorth Christy, UT 30758	North Annberg	11538	Mauritania
953	953	Unit 3862 Box 6238\nDPO AA 99455	Joshuaville	08248	Tunisia
954	954	50113 Mccormick Cape\nNorth Edwinborough, NH 00805	Brianport	09155	Rwanda
955	955	98185 Lawson Causeway Suite 633\nTamaraberg, MT 437	Richardsonview	02532	Togo
956	956	PSC 6738, Box 6645\nAPO AE 17973	South Benjaminbury	85576	Solomon Islands
957	957	442 Steven Skyway\nPort Howardmouth, MH 81287	South Richard	63399	Greenland
958	958	7495 Kelly Freeway Suite 920\nNorth Alexandria, ID 	Halefurt	73805	Qatar
959	959	619 Kennedy Motorway\nRoberttown, DC 78417	Thomastown	13640	Germany
960	960	5247 Marshall Meadow\nLake Matthewmouth, PR 71242	East Darrenfurt	47781	Zambia
961	961	9767 Thornton Rue Suite 884\nJoycefurt, LA 65423	Port Michaelberg	16140	Tunisia
962	962	34027 Timothy Square Suite 692\nSouth Adrienneburgh	North Michael	35290	Guatemala
963	963	PSC 7253, Box 8177\nAPO AA 46740	North Adrianfurt	24291	Timor-Leste
964	964	880 Davis Valleys Suite 302\nNew Brookeport, DC 275	South Williammouth	66671	Cote d'Ivoire
965	965	0394 Griffin Harbor\nSouth Jasonville, MH 76988	Christineside	34419	Bermuda
966	966	223 Karen Spur Suite 685\nWest Melissafurt, MI 9840	Moorehaven	19604	Micronesia
967	967	USCGC Carter\nFPO AE 79341	Ballardchester	26428	Germany
968	968	3837 Harris Causeway Apt. 263\nNorth Lisa, ID 78267	Travishaven	81251	Antarctica (the territory Sout
969	969	113 Hill Creek\nPort Joseph, ID 83453	South David	58620	Myanmar
970	970	64515 James Courts Apt. 256\nDavidland, WV 15618	Nicholasside	86602	South Georgia and the South Sa
971	971	697 Vargas Rue Apt. 705\nRachelfort, ND 71734	Rachelburgh	22229	Kuwait
972	972	2445 Bryan Corner\nPort Mark, PW 98629	South Jessica	84081	Iceland
973	973	09299 Moore Underpass Apt. 273\nSouth Scottmouth, T	South Samuel	21961	Germany
974	974	8189 Contreras Course\nFarleyview, MH 20535	North Timothyborough	31240	Cuba
975	975	2824 April Ramp\nNorth Mary, ID 51209	Sandersville	85588	Spain
976	976	86143 Harris Spurs Apt. 684\nTammyside, TX 13676	West Joseph	02268	Canada
977	977	24662 Davis Club\nAshleyville, NC 20958	Shannonview	23842	Philippines
978	978	86935 Davis Crest Apt. 692\nEast Jeffreyshire, MP 1	Lake Davidberg	80783	Bahamas
979	979	47770 Richard Island\nBrandontown, MP 34070	Arianaville	52659	Turkey
980	980	535 Rivers Locks\nWest Justinbury, AR 21327	Perezshire	06623	British Indian Ocean Territory
981	981	720 Howard Inlet Apt. 498\nWest Justinfort, SD 5035	Fordstad	45347	Trinidad and Tobago
982	982	Unit 9665 Box 3402\nDPO AE 88082	Lake Brittany	02643	Iraq
983	983	Unit 4596 Box 7126\nDPO AP 64690	Patriciabury	62525	South Africa
984	984	81722 Riley Harbors Apt. 808\nPort Stephen, OH 9378	North Brett	27731	Christmas Island
985	985	12583 Jeffrey Cove\nLake Katherinemouth, AS 09195	Randallfurt	98407	Turks and Caicos Islands
986	986	385 Hall Via\nMatthewshire, NY 13306	Barbaraton	44558	Moldova
987	987	927 Sanchez Ville Suite 724\nLake Thomaston, SD 972	Troyshire	30544	Luxembourg
988	988	196 Graham Manor Suite 609\nWest Heatherfurt, TN 40	Lake Daniellefort	51744	Antigua and Barbuda
989	989	842 Charles Mission Apt. 909\nMariashire, MD 74490	Donaldsonview	02760	Western Sahara
990	990	990 George Springs Suite 953\nWest Matthew, WV 3443	Port Aaronshire	61844	Tunisia
991	991	5144 Brian Ford\nNew Anthony, AK 87712	Lake Lorimouth	43545	Syrian Arab Republic
992	992	438 Jenny Ports Apt. 953\nKathyfurt, KS 44248	South Patrickmouth	90383	Sweden
993	993	16753 Travis Stravenue Suite 911\nPamelatown, DE 14	Lake Jennifer	43182	Belarus
994	994	96232 Jeanette Shores\nJohnmouth, KS 52411	Justinshire	10734	Puerto Rico
995	995	0639 Nguyen Forest\nEast Kimberlyfurt, ME 08358	Bryanland	62745	Mayotte
996	996	95210 Leon Valleys\nWest Haley, ND 72598	New Alanville	69742	Guyana
997	997	192 Moreno Skyway\nRyanville, OH 60472	Brittanyfurt	11620	Saint Martin
999	999	92935 Brown Street\nWest Chad, FM 36503	West Roger	99628	Heard Island and McDonald Isla
1000	1000	920 Jones Points\nNew Jeremiahland, KY 82660	Lake Christopherfort	60375	Antigua and Barbuda
1001	1001	7077 Church Divide\nAndersonfort, IA 68398	New Anthony	14757	Montserrat
1002	1002	USS Small\nFPO AA 67946	Diazmouth	20781	North Macedonia
1003	1003	33983 Carolyn Isle Apt. 391\nBlackwellview, MO 8926	Bryanfort	32310	Ghana
\.


--
-- TOC entry 5152 (class 0 OID 30076)
-- Dependencies: 224
-- Data for Name: payment; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.payment (payment_id, user_id, payment_type, provider, account_no, expiry) FROM stdin;
256	256	Bank Account	\N	\N	\N
257	257	Bank Account	\N	\N	\N
258	258	Bank Account	\N	\N	\N
259	259	Bank Account	\N	\N	\N
260	260	Bank Account	\N	\N	\N
400	399	Bank Account	\N	\N	\N
401	400	Bank Account	\N	\N	\N
583	582	Visa	\N	\N	\N
584	583	Visa	\N	\N	\N
585	584	Visa	\N	\N	\N
586	585	Visa	\N	\N	\N
587	586	Visa	\N	\N	\N
588	587	Visa	\N	\N	\N
589	588	Visa	\N	\N	\N
590	589	Visa	\N	\N	\N
591	590	Visa	\N	\N	\N
592	591	Visa	\N	\N	\N
593	592	Visa	\N	\N	\N
201	201	Bank Account	\N	\N	\N
202	202	Bank Account	\N	\N	\N
203	203	Bank Account	\N	\N	\N
204	204	Bank Account	\N	\N	\N
205	205	Bank Account	\N	\N	\N
206	206	Bank Account	\N	\N	\N
207	207	Bank Account	\N	\N	\N
208	208	Bank Account	\N	\N	\N
209	209	Bank Account	\N	\N	\N
210	210	Bank Account	\N	\N	\N
211	211	Bank Account	\N	\N	\N
261	261	Bank Account	\N	\N	\N
262	262	Bank Account	\N	\N	\N
263	263	Bank Account	\N	\N	\N
594	593	Visa	\N	\N	\N
595	594	Visa	\N	\N	\N
596	595	Visa	\N	\N	\N
597	596	Visa	\N	\N	\N
598	597	Visa	\N	\N	\N
599	598	Visa	\N	\N	\N
600	599	Visa	\N	\N	\N
601	600	Visa	\N	\N	\N
264	264	Bank Account	\N	\N	\N
265	265	Bank Account	\N	\N	\N
266	266	Bank Account	\N	\N	\N
267	267	Bank Account	\N	\N	\N
268	268	Bank Account	\N	\N	\N
269	269	Bank Account	\N	\N	\N
270	270	Bank Account	\N	\N	\N
271	271	Bank Account	\N	\N	\N
272	272	Bank Account	\N	\N	\N
273	273	Bank Account	\N	\N	\N
274	274	Bank Account	\N	\N	\N
275	275	Bank Account	\N	\N	\N
276	276	Bank Account	\N	\N	\N
277	277	Bank Account	\N	\N	\N
278	278	Bank Account	\N	\N	\N
279	279	Bank Account	\N	\N	\N
280	280	Bank Account	\N	\N	\N
281	281	Bank Account	\N	\N	\N
282	282	Bank Account	\N	\N	\N
283	283	Bank Account	\N	\N	\N
284	284	Bank Account	\N	\N	\N
285	285	Bank Account	\N	\N	\N
286	286	Bank Account	\N	\N	\N
287	287	Bank Account	\N	\N	\N
288	288	Bank Account	\N	\N	\N
101	101	Debit Card	\N	\N	\N
102	102	Debit Card	\N	\N	\N
103	103	Debit Card	\N	\N	\N
104	104	Debit Card	\N	\N	\N
105	105	Debit Card	\N	\N	\N
106	106	Debit Card	\N	\N	\N
107	107	Debit Card	\N	\N	\N
108	108	Debit Card	\N	\N	\N
109	109	Debit Card	\N	\N	\N
110	110	Debit Card	\N	\N	\N
111	111	Debit Card	\N	\N	\N
112	112	Debit Card	\N	\N	\N
113	113	Debit Card	\N	\N	\N
114	114	Debit Card	\N	\N	\N
115	115	Debit Card	\N	\N	\N
116	116	Debit Card	\N	\N	\N
117	117	Debit Card	\N	\N	\N
118	118	Debit Card	\N	\N	\N
119	119	Debit Card	\N	\N	\N
120	120	Debit Card	\N	\N	\N
121	121	Debit Card	\N	\N	\N
122	122	Debit Card	\N	\N	\N
123	123	Debit Card	\N	\N	\N
147	147	Debit Card	\N	\N	\N
148	148	Debit Card	\N	\N	\N
149	149	Debit Card	\N	\N	\N
150	150	Debit Card	\N	\N	\N
151	151	Debit Card	\N	\N	\N
152	152	Debit Card	\N	\N	\N
153	153	Debit Card	\N	\N	\N
154	154	Debit Card	\N	\N	\N
155	155	Debit Card	\N	\N	\N
156	156	Debit Card	\N	\N	\N
157	157	Debit Card	\N	\N	\N
158	158	Debit Card	\N	\N	\N
159	159	Debit Card	\N	\N	\N
160	160	Debit Card	\N	\N	\N
161	161	Debit Card	\N	\N	\N
162	162	Debit Card	\N	\N	\N
163	163	Debit Card	\N	\N	\N
164	164	Debit Card	\N	\N	\N
165	165	Debit Card	\N	\N	\N
166	166	Debit Card	\N	\N	\N
167	167	Debit Card	\N	\N	\N
168	168	Debit Card	\N	\N	\N
169	169	Debit Card	\N	\N	\N
170	170	Debit Card	\N	\N	\N
171	171	Debit Card	\N	\N	\N
172	172	Debit Card	\N	\N	\N
173	173	Debit Card	\N	\N	\N
174	174	Debit Card	\N	\N	\N
175	175	Debit Card	\N	\N	\N
701	701	Visa	\N	\N	\N
702	702	Visa	\N	\N	\N
703	703	Visa	\N	\N	\N
704	704	Visa	\N	\N	\N
705	705	Visa	\N	\N	\N
706	706	Visa	\N	\N	\N
707	707	Visa	\N	\N	\N
708	708	Visa	\N	\N	\N
709	709	Visa	\N	\N	\N
710	710	Visa	\N	\N	\N
711	711	Visa	\N	\N	\N
712	712	Visa	\N	\N	\N
713	713	Visa	\N	\N	\N
714	714	Visa	\N	\N	\N
715	715	Visa	\N	\N	\N
716	716	Visa	\N	\N	\N
717	717	Visa	\N	\N	\N
718	718	Visa	\N	\N	\N
719	719	Visa	\N	\N	\N
720	720	Visa	\N	\N	\N
721	721	Visa	\N	\N	\N
722	722	Visa	\N	\N	\N
723	723	Visa	\N	\N	\N
724	724	Visa	\N	\N	\N
725	725	Visa	\N	\N	\N
726	726	Visa	\N	\N	\N
727	727	Visa	\N	\N	\N
728	728	Visa	\N	\N	\N
729	729	Visa	\N	\N	\N
730	730	Visa	\N	\N	\N
731	731	Visa	\N	\N	\N
732	732	Visa	\N	\N	\N
733	733	Visa	\N	\N	\N
734	734	Visa	\N	\N	\N
735	735	Visa	\N	\N	\N
736	736	Visa	\N	\N	\N
737	737	Visa	\N	\N	\N
738	738	Visa	\N	\N	\N
739	739	Visa	\N	\N	\N
740	740	Visa	\N	\N	\N
741	741	Visa	\N	\N	\N
742	742	Visa	\N	\N	\N
743	743	Visa	\N	\N	\N
744	744	Visa	\N	\N	\N
745	745	Visa	\N	\N	\N
746	746	Visa	\N	\N	\N
747	747	Visa	\N	\N	\N
748	748	Visa	\N	\N	\N
749	749	Visa	\N	\N	\N
750	750	Visa	\N	\N	\N
751	751	Visa	\N	\N	\N
752	752	Visa	\N	\N	\N
753	753	Visa	\N	\N	\N
754	754	Visa	\N	\N	\N
755	755	Visa	\N	\N	\N
756	756	Visa	\N	\N	\N
757	757	Visa	\N	\N	\N
758	758	Visa	\N	\N	\N
759	759	Visa	\N	\N	\N
760	760	Visa	\N	\N	\N
761	761	Visa	\N	\N	\N
762	762	Visa	\N	\N	\N
763	763	Visa	\N	\N	\N
764	764	Visa	\N	\N	\N
765	765	Visa	\N	\N	\N
766	766	Visa	\N	\N	\N
767	767	Visa	\N	\N	\N
768	768	Visa	\N	\N	\N
769	769	Visa	\N	\N	\N
770	770	Visa	\N	\N	\N
771	771	Visa	\N	\N	\N
772	772	Visa	\N	\N	\N
773	773	Visa	\N	\N	\N
774	774	Visa	\N	\N	\N
775	775	Visa	\N	\N	\N
776	776	Visa	\N	\N	\N
777	777	Visa	\N	\N	\N
778	778	Visa	\N	\N	\N
779	779	Visa	\N	\N	\N
780	780	Visa	\N	\N	\N
781	781	Visa	\N	\N	\N
782	782	Visa	\N	\N	\N
783	783	Visa	\N	\N	\N
784	784	Visa	\N	\N	\N
785	785	Visa	\N	\N	\N
786	786	Visa	\N	\N	\N
787	787	Visa	\N	\N	\N
788	788	Visa	\N	\N	\N
789	789	Visa	\N	\N	\N
790	790	Visa	\N	\N	\N
791	791	Visa	\N	\N	\N
792	792	Visa	\N	\N	\N
793	793	Visa	\N	\N	\N
794	794	Visa	\N	\N	\N
795	795	Visa	\N	\N	\N
796	796	Visa	\N	\N	\N
797	797	Visa	\N	\N	\N
798	798	Visa	\N	\N	\N
799	799	Visa	\N	\N	\N
800	800	Visa	\N	\N	\N
801	801	Visa	\N	\N	\N
802	802	Visa	\N	\N	\N
803	803	Visa	\N	\N	\N
804	804	Visa	\N	\N	\N
805	805	Visa	\N	\N	\N
806	806	Visa	\N	\N	\N
807	807	Visa	\N	\N	\N
808	808	Visa	\N	\N	\N
809	809	Visa	\N	\N	\N
810	810	Visa	\N	\N	\N
811	811	Visa	\N	\N	\N
812	812	Visa	\N	\N	\N
813	813	Visa	\N	\N	\N
814	814	Visa	\N	\N	\N
815	815	Visa	\N	\N	\N
816	816	Visa	\N	\N	\N
817	817	Visa	\N	\N	\N
818	818	Visa	\N	\N	\N
819	819	Visa	\N	\N	\N
820	820	Visa	\N	\N	\N
821	821	Visa	\N	\N	\N
822	822	Visa	\N	\N	\N
823	823	Visa	\N	\N	\N
824	824	Visa	\N	\N	\N
825	825	Visa	\N	\N	\N
826	826	Visa	\N	\N	\N
827	827	Visa	\N	\N	\N
828	828	Visa	\N	\N	\N
829	829	Visa	\N	\N	\N
830	830	Visa	\N	\N	\N
831	831	Visa	\N	\N	\N
832	832	Visa	\N	\N	\N
833	833	Visa	\N	\N	\N
834	834	Visa	\N	\N	\N
835	835	Visa	\N	\N	\N
836	836	Visa	\N	\N	\N
837	837	Visa	\N	\N	\N
838	838	Visa	\N	\N	\N
839	839	Visa	\N	\N	\N
840	840	Visa	\N	\N	\N
841	841	Visa	\N	\N	\N
842	842	Visa	\N	\N	\N
843	843	Visa	\N	\N	\N
844	844	Visa	\N	\N	\N
845	845	Visa	\N	\N	\N
846	846	Visa	\N	\N	\N
847	847	Visa	\N	\N	\N
848	848	Visa	\N	\N	\N
849	849	Visa	\N	\N	\N
850	850	Visa	\N	\N	\N
851	851	Visa	\N	\N	\N
852	852	Visa	\N	\N	\N
853	853	Visa	\N	\N	\N
854	854	Visa	\N	\N	\N
855	855	Visa	\N	\N	\N
856	856	Visa	\N	\N	\N
857	857	Visa	\N	\N	\N
858	858	Visa	\N	\N	\N
859	859	Visa	\N	\N	\N
860	860	Visa	\N	\N	\N
861	861	Visa	\N	\N	\N
862	862	Visa	\N	\N	\N
863	863	Visa	\N	\N	\N
864	864	Visa	\N	\N	\N
865	865	Visa	\N	\N	\N
866	866	Visa	\N	\N	\N
867	867	Visa	\N	\N	\N
868	868	Visa	\N	\N	\N
869	869	Visa	\N	\N	\N
870	870	Visa	\N	\N	\N
871	871	Visa	\N	\N	\N
872	872	Visa	\N	\N	\N
873	873	Visa	\N	\N	\N
874	874	Visa	\N	\N	\N
875	875	Visa	\N	\N	\N
876	876	Visa	\N	\N	\N
877	877	Visa	\N	\N	\N
878	878	Visa	\N	\N	\N
879	879	Visa	\N	\N	\N
880	880	Visa	\N	\N	\N
881	881	Visa	\N	\N	\N
882	882	Visa	\N	\N	\N
883	883	Visa	\N	\N	\N
884	884	Visa	\N	\N	\N
885	885	Visa	\N	\N	\N
886	886	Visa	\N	\N	\N
887	887	Visa	\N	\N	\N
888	888	Visa	\N	\N	\N
889	889	Visa	\N	\N	\N
890	890	Visa	\N	\N	\N
891	891	Visa	\N	\N	\N
892	892	Visa	\N	\N	\N
893	893	Visa	\N	\N	\N
894	894	Visa	\N	\N	\N
895	895	Visa	\N	\N	\N
896	896	Visa	\N	\N	\N
897	897	Visa	\N	\N	\N
898	898	Visa	\N	\N	\N
899	899	Visa	\N	\N	\N
900	900	Visa	\N	\N	\N
901	901	Visa	\N	\N	\N
902	902	Visa	\N	\N	\N
903	903	Visa	\N	\N	\N
904	904	Visa	\N	\N	\N
905	905	Visa	\N	\N	\N
906	906	Visa	\N	\N	\N
907	907	Visa	\N	\N	\N
908	908	Visa	\N	\N	\N
909	909	Visa	\N	\N	\N
910	910	Visa	\N	\N	\N
911	911	Visa	\N	\N	\N
912	912	Visa	\N	\N	\N
913	913	Visa	\N	\N	\N
914	914	Visa	\N	\N	\N
915	915	Visa	\N	\N	\N
916	916	Visa	\N	\N	\N
917	917	Visa	\N	\N	\N
918	918	Visa	\N	\N	\N
919	919	Visa	\N	\N	\N
920	920	Visa	\N	\N	\N
921	921	Visa	\N	\N	\N
922	922	Visa	\N	\N	\N
923	923	Visa	\N	\N	\N
924	924	Visa	\N	\N	\N
925	925	Visa	\N	\N	\N
926	926	Visa	\N	\N	\N
927	927	Visa	\N	\N	\N
928	928	Visa	\N	\N	\N
929	929	Visa	\N	\N	\N
930	930	Visa	\N	\N	\N
931	931	Visa	\N	\N	\N
932	932	Visa	\N	\N	\N
933	933	Visa	\N	\N	\N
934	934	Visa	\N	\N	\N
935	935	Visa	\N	\N	\N
936	936	Visa	\N	\N	\N
937	937	Visa	\N	\N	\N
938	938	Visa	\N	\N	\N
939	939	Visa	\N	\N	\N
940	940	Visa	\N	\N	\N
941	941	Visa	\N	\N	\N
942	942	Visa	\N	\N	\N
943	943	Visa	\N	\N	\N
944	944	Visa	\N	\N	\N
945	945	Visa	\N	\N	\N
946	946	Visa	\N	\N	\N
947	947	Visa	\N	\N	\N
948	948	Visa	\N	\N	\N
949	949	Visa	\N	\N	\N
950	950	Visa	\N	\N	\N
951	951	Visa	\N	\N	\N
952	952	Visa	\N	\N	\N
953	953	Visa	\N	\N	\N
954	954	Visa	\N	\N	\N
955	955	Visa	\N	\N	\N
956	956	Visa	\N	\N	\N
957	957	Visa	\N	\N	\N
958	958	Visa	\N	\N	\N
959	959	Visa	\N	\N	\N
960	960	Visa	\N	\N	\N
961	961	Visa	\N	\N	\N
962	962	Visa	\N	\N	\N
963	963	Visa	\N	\N	\N
964	964	Visa	\N	\N	\N
965	965	Visa	\N	\N	\N
966	966	Visa	\N	\N	\N
967	967	Visa	\N	\N	\N
968	968	Visa	\N	\N	\N
969	969	Visa	\N	\N	\N
970	970	Visa	\N	\N	\N
971	971	Visa	\N	\N	\N
972	972	Visa	\N	\N	\N
973	973	Visa	\N	\N	\N
974	974	Visa	\N	\N	\N
975	975	Visa	\N	\N	\N
976	976	Visa	\N	\N	\N
977	977	Visa	\N	\N	\N
978	978	Visa	\N	\N	\N
979	979	Visa	\N	\N	\N
980	980	Visa	\N	\N	\N
981	981	Visa	\N	\N	\N
982	982	Visa	\N	\N	\N
983	983	Visa	\N	\N	\N
984	984	Visa	\N	\N	\N
985	985	Visa	\N	\N	\N
986	986	Visa	\N	\N	\N
987	987	Visa	\N	\N	\N
988	988	Visa	\N	\N	\N
989	989	Visa	\N	\N	\N
990	990	Visa	\N	\N	\N
991	991	Visa	\N	\N	\N
992	992	Visa	\N	\N	\N
993	993	Visa	\N	\N	\N
994	994	Visa	\N	\N	\N
995	995	Visa	\N	\N	\N
996	996	Visa	\N	\N	\N
997	997	Visa	\N	\N	\N
998	998	Visa	\N	\N	\N
999	999	Visa	\N	\N	\N
1000	1000	Visa	\N	\N	\N
1001	1001	Visa	\N	\N	\N
1002	1002	Visa	\N	\N	\N
1003	1003	Visa	\N	\N	\N
176	176	Debit Card	\N	\N	\N
177	177	Debit Card	\N	\N	\N
178	178	Debit Card	\N	\N	\N
179	179	Debit Card	\N	\N	\N
180	180	Debit Card	\N	\N	\N
181	181	Debit Card	\N	\N	\N
182	182	Debit Card	\N	\N	\N
183	183	Debit Card	\N	\N	\N
184	184	Debit Card	\N	\N	\N
185	185	Debit Card	\N	\N	\N
186	186	Debit Card	\N	\N	\N
187	187	Debit Card	\N	\N	\N
188	188	Debit Card	\N	\N	\N
189	189	Debit Card	\N	\N	\N
190	190	Debit Card	\N	\N	\N
191	191	Debit Card	\N	\N	\N
192	192	Debit Card	\N	\N	\N
193	193	Debit Card	\N	\N	\N
194	194	Debit Card	\N	\N	\N
195	195	Debit Card	\N	\N	\N
196	196	Debit Card	\N	\N	\N
197	197	Debit Card	\N	\N	\N
198	198	Debit Card	\N	\N	\N
199	199	Debit Card	\N	\N	\N
200	200	Debit Card	\N	\N	\N
426	425	Visa	\N	\N	\N
427	426	Visa	\N	\N	\N
428	427	Visa	\N	\N	\N
429	428	Visa	\N	\N	\N
430	429	Visa	\N	\N	\N
431	430	Visa	\N	\N	\N
432	431	Visa	\N	\N	\N
433	432	Visa	\N	\N	\N
434	433	Visa	\N	\N	\N
435	434	Visa	\N	\N	\N
436	435	Visa	\N	\N	\N
437	436	Visa	\N	\N	\N
373	373	Bank Account	\N	\N	\N
374	374	Bank Account	\N	\N	\N
375	375	Bank Account	\N	\N	\N
376	376	Bank Account	\N	\N	\N
377	377	Bank Account	\N	\N	\N
378	378	Bank Account	\N	\N	\N
379	379	Bank Account	\N	\N	\N
380	380	Bank Account	\N	\N	\N
381	381	Bank Account	\N	\N	\N
382	382	Bank Account	\N	\N	\N
383	383	Bank Account	\N	\N	\N
384	384	Bank Account	\N	\N	\N
385	385	Bank Account	\N	\N	\N
386	386	Bank Account	\N	\N	\N
387	387	Bank Account	\N	\N	\N
388	388	Bank Account	\N	\N	\N
389	389	Bank Account	\N	\N	\N
390	390	Bank Account	\N	\N	\N
391	391	Bank Account	\N	\N	\N
392	392	Bank Account	\N	\N	\N
393	393	Bank Account	\N	\N	\N
395	394	Bank Account	\N	\N	\N
396	395	Bank Account	\N	\N	\N
397	396	Bank Account	\N	\N	\N
398	397	Bank Account	\N	\N	\N
399	398	Bank Account	\N	\N	\N
212	212	Bank Account	\N	\N	\N
213	213	Bank Account	\N	\N	\N
214	214	Bank Account	\N	\N	\N
215	215	Bank Account	\N	\N	\N
216	216	Bank Account	\N	\N	\N
217	217	Bank Account	\N	\N	\N
218	218	Bank Account	\N	\N	\N
219	219	Bank Account	\N	\N	\N
220	220	Bank Account	\N	\N	\N
221	221	Bank Account	\N	\N	\N
222	222	Bank Account	\N	\N	\N
223	223	Bank Account	\N	\N	\N
224	224	Bank Account	\N	\N	\N
225	225	Bank Account	\N	\N	\N
226	226	Bank Account	\N	\N	\N
227	227	Bank Account	\N	\N	\N
228	228	Bank Account	\N	\N	\N
229	229	Bank Account	\N	\N	\N
230	230	Bank Account	\N	\N	\N
231	231	Bank Account	\N	\N	\N
232	232	Bank Account	\N	\N	\N
233	233	Bank Account	\N	\N	\N
234	234	Bank Account	\N	\N	\N
235	235	Bank Account	\N	\N	\N
236	236	Bank Account	\N	\N	\N
237	237	Bank Account	\N	\N	\N
238	238	Bank Account	\N	\N	\N
239	239	Bank Account	\N	\N	\N
240	240	Bank Account	\N	\N	\N
241	241	Bank Account	\N	\N	\N
242	242	Bank Account	\N	\N	\N
243	243	Bank Account	\N	\N	\N
244	244	Bank Account	\N	\N	\N
245	245	Bank Account	\N	\N	\N
246	246	Bank Account	\N	\N	\N
247	247	Bank Account	\N	\N	\N
248	248	Bank Account	\N	\N	\N
249	249	Bank Account	\N	\N	\N
250	250	Bank Account	\N	\N	\N
251	251	Bank Account	\N	\N	\N
252	252	Bank Account	\N	\N	\N
253	253	Bank Account	\N	\N	\N
65	65	Credit Card	\N	\N	\N
66	66	Credit Card	\N	\N	\N
67	67	Credit Card	\N	\N	\N
68	68	Credit Card	\N	\N	\N
69	69	Credit Card	\N	\N	\N
70	70	Credit Card	\N	\N	\N
71	71	Credit Card	\N	\N	\N
72	72	Credit Card	\N	\N	\N
73	73	Credit Card	\N	\N	\N
74	74	Credit Card	\N	\N	\N
75	75	Credit Card	\N	\N	\N
76	76	Credit Card	\N	\N	\N
77	77	Credit Card	\N	\N	\N
78	78	Credit Card	\N	\N	\N
79	79	Credit Card	\N	\N	\N
80	80	Credit Card	\N	\N	\N
81	81	Credit Card	\N	\N	\N
82	82	Credit Card	\N	\N	\N
83	83	Credit Card	\N	\N	\N
84	84	Credit Card	\N	\N	\N
85	85	Credit Card	\N	\N	\N
86	86	Credit Card	\N	\N	\N
87	87	Credit Card	\N	\N	\N
88	88	Credit Card	\N	\N	\N
89	89	Credit Card	\N	\N	\N
90	90	Credit Card	\N	\N	\N
91	91	Credit Card	\N	\N	\N
92	92	Credit Card	\N	\N	\N
93	93	Credit Card	\N	\N	\N
94	94	Credit Card	\N	\N	\N
95	95	Credit Card	\N	\N	\N
96	96	Credit Card	\N	\N	\N
97	97	Credit Card	\N	\N	\N
98	98	Credit Card	\N	\N	\N
99	99	Credit Card	\N	\N	\N
100	100	Credit Card	\N	\N	\N
438	437	Visa	\N	\N	\N
439	438	Visa	\N	\N	\N
440	439	Visa	\N	\N	\N
441	440	Visa	\N	\N	\N
442	441	Visa	\N	\N	\N
443	442	Visa	\N	\N	\N
444	443	Visa	\N	\N	\N
445	444	Visa	\N	\N	\N
446	445	Visa	\N	\N	\N
447	446	Visa	\N	\N	\N
448	447	Visa	\N	\N	\N
449	448	Visa	\N	\N	\N
450	449	Visa	\N	\N	\N
451	450	Visa	\N	\N	\N
452	451	Visa	\N	\N	\N
453	452	Visa	\N	\N	\N
454	453	Visa	\N	\N	\N
455	454	Visa	\N	\N	\N
456	455	Visa	\N	\N	\N
457	456	Visa	\N	\N	\N
458	457	Visa	\N	\N	\N
459	458	Visa	\N	\N	\N
460	459	Visa	\N	\N	\N
461	460	Visa	\N	\N	\N
462	461	Visa	\N	\N	\N
463	462	Visa	\N	\N	\N
464	463	Visa	\N	\N	\N
465	464	Visa	\N	\N	\N
466	465	Visa	\N	\N	\N
467	466	Visa	\N	\N	\N
468	467	Visa	\N	\N	\N
469	468	Visa	\N	\N	\N
470	469	Visa	\N	\N	\N
471	470	Visa	\N	\N	\N
472	471	Visa	\N	\N	\N
473	472	Visa	\N	\N	\N
474	473	Visa	\N	\N	\N
475	474	Visa	\N	\N	\N
476	475	Visa	\N	\N	\N
477	476	Visa	\N	\N	\N
478	477	Visa	\N	\N	\N
479	478	Visa	\N	\N	\N
480	479	Visa	\N	\N	\N
481	480	Visa	\N	\N	\N
482	481	Visa	\N	\N	\N
483	482	Visa	\N	\N	\N
484	483	Visa	\N	\N	\N
485	484	Visa	\N	\N	\N
486	485	Visa	\N	\N	\N
487	486	Visa	\N	\N	\N
488	487	Visa	\N	\N	\N
489	488	Visa	\N	\N	\N
490	489	Visa	\N	\N	\N
491	490	Visa	\N	\N	\N
492	491	Visa	\N	\N	\N
493	492	Visa	\N	\N	\N
494	493	Visa	\N	\N	\N
495	494	Visa	\N	\N	\N
496	495	Visa	\N	\N	\N
497	496	Visa	\N	\N	\N
498	497	Visa	\N	\N	\N
499	498	Visa	\N	\N	\N
500	499	Visa	\N	\N	\N
501	500	Visa	\N	\N	\N
502	501	Visa	\N	\N	\N
503	502	Visa	\N	\N	\N
504	503	Visa	\N	\N	\N
505	504	Visa	\N	\N	\N
506	505	Visa	\N	\N	\N
507	506	Visa	\N	\N	\N
508	507	Visa	\N	\N	\N
509	508	Visa	\N	\N	\N
510	509	Visa	\N	\N	\N
511	510	Visa	\N	\N	\N
512	511	Visa	\N	\N	\N
513	512	Visa	\N	\N	\N
514	513	Visa	\N	\N	\N
515	514	Visa	\N	\N	\N
516	515	Visa	\N	\N	\N
517	516	Visa	\N	\N	\N
518	517	Visa	\N	\N	\N
519	518	Visa	\N	\N	\N
520	519	Visa	\N	\N	\N
521	520	Visa	\N	\N	\N
522	521	Visa	\N	\N	\N
523	522	Visa	\N	\N	\N
524	523	Visa	\N	\N	\N
525	524	Visa	\N	\N	\N
526	525	Visa	\N	\N	\N
527	526	Visa	\N	\N	\N
528	527	Visa	\N	\N	\N
529	528	Visa	\N	\N	\N
530	529	Visa	\N	\N	\N
531	530	Visa	\N	\N	\N
532	531	Visa	\N	\N	\N
533	532	Visa	\N	\N	\N
534	533	Visa	\N	\N	\N
535	534	Visa	\N	\N	\N
536	535	Visa	\N	\N	\N
537	536	Visa	\N	\N	\N
538	537	Visa	\N	\N	\N
539	538	Visa	\N	\N	\N
540	539	Visa	\N	\N	\N
541	540	Visa	\N	\N	\N
542	541	Visa	\N	\N	\N
543	542	Visa	\N	\N	\N
544	543	Visa	\N	\N	\N
545	544	Visa	\N	\N	\N
546	545	Visa	\N	\N	\N
547	546	Visa	\N	\N	\N
548	547	Visa	\N	\N	\N
549	548	Visa	\N	\N	\N
550	549	Visa	\N	\N	\N
551	550	Visa	\N	\N	\N
552	551	Visa	\N	\N	\N
553	552	Visa	\N	\N	\N
554	553	Visa	\N	\N	\N
555	554	Visa	\N	\N	\N
556	555	Visa	\N	\N	\N
557	556	Visa	\N	\N	\N
558	557	Visa	\N	\N	\N
559	558	Visa	\N	\N	\N
560	559	Visa	\N	\N	\N
561	560	Visa	\N	\N	\N
562	561	Visa	\N	\N	\N
563	562	Visa	\N	\N	\N
564	563	Visa	\N	\N	\N
565	564	Visa	\N	\N	\N
566	565	Visa	\N	\N	\N
567	566	Visa	\N	\N	\N
568	567	Visa	\N	\N	\N
569	568	Visa	\N	\N	\N
570	569	Visa	\N	\N	\N
571	570	Visa	\N	\N	\N
572	571	Visa	\N	\N	\N
573	572	Visa	\N	\N	\N
574	573	Visa	\N	\N	\N
575	574	Visa	\N	\N	\N
576	575	Visa	\N	\N	\N
577	576	Visa	\N	\N	\N
578	577	Visa	\N	\N	\N
579	578	Visa	\N	\N	\N
580	579	Visa	\N	\N	\N
581	580	Visa	\N	\N	\N
582	581	Visa	\N	\N	\N
402	401	Visa	\N	\N	\N
403	402	Visa	\N	\N	\N
404	403	Visa	\N	\N	\N
405	404	Visa	\N	\N	\N
406	405	Visa	\N	\N	\N
407	406	Visa	\N	\N	\N
408	407	Visa	\N	\N	\N
409	408	Visa	\N	\N	\N
410	409	Visa	\N	\N	\N
411	410	Visa	\N	\N	\N
412	411	Visa	\N	\N	\N
413	412	Visa	\N	\N	\N
414	413	Visa	\N	\N	\N
415	414	Visa	\N	\N	\N
416	415	Visa	\N	\N	\N
417	416	Visa	\N	\N	\N
418	417	Visa	\N	\N	\N
419	418	Visa	\N	\N	\N
420	419	Visa	\N	\N	\N
421	420	Visa	\N	\N	\N
422	421	Visa	\N	\N	\N
423	422	Visa	\N	\N	\N
394	631	Visa	\N	\N	\N
424	423	Visa	\N	\N	\N
425	424	Visa	\N	\N	\N
602	601	Visa	\N	\N	\N
603	602	Visa	\N	\N	\N
604	603	Visa	\N	\N	\N
605	604	Visa	\N	\N	\N
606	605	Visa	\N	\N	\N
607	606	Visa	\N	\N	\N
608	607	Visa	\N	\N	\N
609	608	Visa	\N	\N	\N
610	609	Visa	\N	\N	\N
611	610	Visa	\N	\N	\N
612	611	Visa	\N	\N	\N
613	612	Visa	\N	\N	\N
614	613	Visa	\N	\N	\N
615	614	Visa	\N	\N	\N
616	615	Visa	\N	\N	\N
617	616	Visa	\N	\N	\N
618	617	Visa	\N	\N	\N
619	618	Visa	\N	\N	\N
620	619	Visa	\N	\N	\N
621	620	Visa	\N	\N	\N
622	621	Visa	\N	\N	\N
623	622	Visa	\N	\N	\N
624	623	Visa	\N	\N	\N
625	624	Visa	\N	\N	\N
626	625	Visa	\N	\N	\N
627	626	Visa	\N	\N	\N
628	627	Visa	\N	\N	\N
629	628	Visa	\N	\N	\N
630	629	Visa	\N	\N	\N
631	630	Visa	\N	\N	\N
632	632	Visa	\N	\N	\N
633	633	Visa	\N	\N	\N
634	634	Visa	\N	\N	\N
635	635	Visa	\N	\N	\N
636	636	Visa	\N	\N	\N
637	637	Visa	\N	\N	\N
638	638	Visa	\N	\N	\N
639	639	Visa	\N	\N	\N
640	640	Visa	\N	\N	\N
641	641	Visa	\N	\N	\N
642	642	Visa	\N	\N	\N
643	643	Visa	\N	\N	\N
644	644	Visa	\N	\N	\N
645	645	Visa	\N	\N	\N
646	646	Visa	\N	\N	\N
647	647	Visa	\N	\N	\N
648	648	Visa	\N	\N	\N
649	649	Visa	\N	\N	\N
650	650	Visa	\N	\N	\N
651	651	Visa	\N	\N	\N
652	652	Visa	\N	\N	\N
653	653	Visa	\N	\N	\N
654	654	Visa	\N	\N	\N
655	655	Visa	\N	\N	\N
656	656	Visa	\N	\N	\N
657	657	Visa	\N	\N	\N
658	658	Visa	\N	\N	\N
659	659	Visa	\N	\N	\N
660	660	Visa	\N	\N	\N
661	661	Visa	\N	\N	\N
662	662	Visa	\N	\N	\N
663	663	Visa	\N	\N	\N
664	664	Visa	\N	\N	\N
665	665	Visa	\N	\N	\N
666	666	Visa	\N	\N	\N
667	667	Visa	\N	\N	\N
668	668	Visa	\N	\N	\N
669	669	Visa	\N	\N	\N
670	670	Visa	\N	\N	\N
671	671	Visa	\N	\N	\N
672	672	Visa	\N	\N	\N
673	673	Visa	\N	\N	\N
674	674	Visa	\N	\N	\N
675	675	Visa	\N	\N	\N
676	676	Visa	\N	\N	\N
677	677	Visa	\N	\N	\N
678	678	Visa	\N	\N	\N
679	679	Visa	\N	\N	\N
680	680	Visa	\N	\N	\N
681	681	Visa	\N	\N	\N
682	682	Visa	\N	\N	\N
683	683	Visa	\N	\N	\N
684	684	Visa	\N	\N	\N
685	685	Visa	\N	\N	\N
686	686	Visa	\N	\N	\N
687	687	Visa	\N	\N	\N
688	688	Visa	\N	\N	\N
689	689	Visa	\N	\N	\N
690	690	Visa	\N	\N	\N
691	691	Visa	\N	\N	\N
692	692	Visa	\N	\N	\N
693	693	Visa	\N	\N	\N
694	694	Visa	\N	\N	\N
695	695	Visa	\N	\N	\N
696	696	Visa	\N	\N	\N
697	697	Visa	\N	\N	\N
698	698	Visa	\N	\N	\N
699	699	Visa	\N	\N	\N
700	700	Visa	\N	\N	\N
289	289	Bank Account	\N	\N	\N
290	290	Bank Account	\N	\N	\N
291	291	Bank Account	\N	\N	\N
292	292	Bank Account	\N	\N	\N
293	293	Bank Account	\N	\N	\N
294	294	Bank Account	\N	\N	\N
295	295	Bank Account	\N	\N	\N
296	296	Bank Account	\N	\N	\N
297	297	Bank Account	\N	\N	\N
298	298	Bank Account	\N	\N	\N
299	299	Bank Account	\N	\N	\N
300	300	Bank Account	\N	\N	\N
301	301	Bank Account	\N	\N	\N
302	302	Bank Account	\N	\N	\N
303	303	Bank Account	\N	\N	\N
304	304	Bank Account	\N	\N	\N
305	305	Bank Account	\N	\N	\N
306	306	Bank Account	\N	\N	\N
307	307	Bank Account	\N	\N	\N
308	308	Bank Account	\N	\N	\N
309	309	Bank Account	\N	\N	\N
310	310	Bank Account	\N	\N	\N
311	311	Bank Account	\N	\N	\N
312	312	Bank Account	\N	\N	\N
313	313	Bank Account	\N	\N	\N
314	314	Bank Account	\N	\N	\N
315	315	Bank Account	\N	\N	\N
316	316	Bank Account	\N	\N	\N
317	317	Bank Account	\N	\N	\N
318	318	Bank Account	\N	\N	\N
319	319	Bank Account	\N	\N	\N
320	320	Bank Account	\N	\N	\N
321	321	Bank Account	\N	\N	\N
322	322	Bank Account	\N	\N	\N
323	323	Bank Account	\N	\N	\N
324	324	Bank Account	\N	\N	\N
325	325	Bank Account	\N	\N	\N
326	326	Bank Account	\N	\N	\N
327	327	Bank Account	\N	\N	\N
328	328	Bank Account	\N	\N	\N
329	329	Bank Account	\N	\N	\N
330	330	Bank Account	\N	\N	\N
331	331	Bank Account	\N	\N	\N
332	332	Bank Account	\N	\N	\N
333	333	Bank Account	\N	\N	\N
334	334	Bank Account	\N	\N	\N
335	335	Bank Account	\N	\N	\N
336	336	Bank Account	\N	\N	\N
337	337	Bank Account	\N	\N	\N
338	338	Bank Account	\N	\N	\N
339	339	Bank Account	\N	\N	\N
340	340	Bank Account	\N	\N	\N
341	341	Bank Account	\N	\N	\N
342	342	Bank Account	\N	\N	\N
343	343	Bank Account	\N	\N	\N
344	344	Bank Account	\N	\N	\N
345	345	Bank Account	\N	\N	\N
346	346	Bank Account	\N	\N	\N
347	347	Bank Account	\N	\N	\N
348	348	Bank Account	\N	\N	\N
349	349	Bank Account	\N	\N	\N
350	350	Bank Account	\N	\N	\N
351	351	Bank Account	\N	\N	\N
352	352	Bank Account	\N	\N	\N
353	353	Bank Account	\N	\N	\N
354	354	Bank Account	\N	\N	\N
355	355	Bank Account	\N	\N	\N
356	356	Bank Account	\N	\N	\N
357	357	Bank Account	\N	\N	\N
358	358	Bank Account	\N	\N	\N
359	359	Bank Account	\N	\N	\N
360	360	Bank Account	\N	\N	\N
361	361	Bank Account	\N	\N	\N
362	362	Bank Account	\N	\N	\N
363	363	Bank Account	\N	\N	\N
364	364	Bank Account	\N	\N	\N
365	365	Bank Account	\N	\N	\N
366	366	Bank Account	\N	\N	\N
367	367	Bank Account	\N	\N	\N
368	368	Bank Account	\N	\N	\N
369	369	Bank Account	\N	\N	\N
370	370	Bank Account	\N	\N	\N
371	371	Bank Account	\N	\N	\N
372	372	Bank Account	\N	\N	\N
254	254	Bank Account	\N	\N	\N
255	255	Bank Account	\N	\N	\N
2	2	Credit Card	\N	\N	\N
3	3	Credit Card	\N	\N	\N
4	4	Credit Card	\N	\N	\N
5	5	Credit Card	\N	\N	\N
6	6	Credit Card	\N	\N	\N
7	7	Credit Card	\N	\N	\N
8	8	Credit Card	\N	\N	\N
9	9	Credit Card	\N	\N	\N
10	10	Credit Card	\N	\N	\N
11	11	Credit Card	\N	\N	\N
12	12	Credit Card	\N	\N	\N
13	13	Credit Card	\N	\N	\N
14	14	Credit Card	\N	\N	\N
15	15	Credit Card	\N	\N	\N
16	16	Credit Card	\N	\N	\N
17	17	Credit Card	\N	\N	\N
18	18	Credit Card	\N	\N	\N
19	19	Credit Card	\N	\N	\N
20	20	Credit Card	\N	\N	\N
21	21	Credit Card	\N	\N	\N
22	22	Credit Card	\N	\N	\N
23	23	Credit Card	\N	\N	\N
24	24	Credit Card	\N	\N	\N
25	25	Credit Card	\N	\N	\N
26	26	Credit Card	\N	\N	\N
27	27	Credit Card	\N	\N	\N
28	28	Credit Card	\N	\N	\N
29	29	Credit Card	\N	\N	\N
30	30	Credit Card	\N	\N	\N
31	31	Credit Card	\N	\N	\N
32	32	Credit Card	\N	\N	\N
33	33	Credit Card	\N	\N	\N
34	34	Credit Card	\N	\N	\N
35	35	Credit Card	\N	\N	\N
36	36	Credit Card	\N	\N	\N
37	37	Credit Card	\N	\N	\N
38	38	Credit Card	\N	\N	\N
39	39	Credit Card	\N	\N	\N
40	40	Credit Card	\N	\N	\N
41	41	Credit Card	\N	\N	\N
42	42	Credit Card	\N	\N	\N
43	43	Credit Card	\N	\N	\N
44	44	Credit Card	\N	\N	\N
45	45	Credit Card	\N	\N	\N
46	46	Credit Card	\N	\N	\N
47	47	Credit Card	\N	\N	\N
48	48	Credit Card	\N	\N	\N
49	49	Credit Card	\N	\N	\N
50	50	Credit Card	\N	\N	\N
51	51	Credit Card	\N	\N	\N
52	52	Credit Card	\N	\N	\N
53	53	Credit Card	\N	\N	\N
54	54	Credit Card	\N	\N	\N
55	55	Credit Card	\N	\N	\N
56	56	Credit Card	\N	\N	\N
124	124	Debit Card	\N	\N	\N
125	125	Debit Card	\N	\N	\N
126	126	Debit Card	\N	\N	\N
127	127	Debit Card	\N	\N	\N
128	128	Debit Card	\N	\N	\N
129	129	Debit Card	\N	\N	\N
130	130	Debit Card	\N	\N	\N
131	131	Debit Card	\N	\N	\N
132	132	Debit Card	\N	\N	\N
133	133	Debit Card	\N	\N	\N
134	134	Debit Card	\N	\N	\N
135	135	Debit Card	\N	\N	\N
136	136	Debit Card	\N	\N	\N
137	137	Debit Card	\N	\N	\N
138	138	Debit Card	\N	\N	\N
139	139	Debit Card	\N	\N	\N
140	140	Debit Card	\N	\N	\N
141	141	Debit Card	\N	\N	\N
142	142	Debit Card	\N	\N	\N
143	143	Debit Card	\N	\N	\N
144	144	Debit Card	\N	\N	\N
145	145	Debit Card	\N	\N	\N
146	146	Debit Card	\N	\N	\N
57	57	Credit Card	\N	\N	\N
58	58	Credit Card	\N	\N	\N
59	59	Credit Card	\N	\N	\N
60	60	Credit Card	\N	\N	\N
61	61	Credit Card	\N	\N	\N
62	62	Credit Card	\N	\N	\N
63	63	Credit Card	\N	\N	\N
64	64	Credit Card	\N	\N	\N
\.


--
-- TOC entry 5155 (class 0 OID 30082)
-- Dependencies: 227
-- Data for Name: role; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.role (role_id, name) FROM stdin;
1	CUSTOMER
2	SELLER
\.


--
-- TOC entry 5157 (class 0 OID 30086)
-- Dependencies: 229
-- Data for Name: user; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account."user" (user_id, username, password, first_name, last_name, created_at, modified_at, telephone) FROM stdin;
2	darkknight1	03092004	Nguyen	Ngoc Linh	2024-01-11 16:43:21.774515+07	2024-01-11 16:43:21.774515+07	0929239294
3	darkknight	03082004	Nguyen	Ngoc Ngan	2024-01-11 16:44:36.775436+07	2024-01-11 16:44:36.775436+07	0929239394
4	vroberts	00pN&bv$)j	Derek	Mendez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	663-959-00
5	daniellepage	5i&%2QcYVo	Amy	Figueroa	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-952-244
6	christopherallison	$&xp0EkNzW	Mark	Ramsey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	327-300-74
7	ryanjoshua	$8YCUi09sk	Jennifer	Wallace	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-552-320
8	jonathan54	u(i4HY5oab	Matthew	Mathis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	506.200.35
9	fedwards	3V5H^4Hm!Q	Peter	Newman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	951-264-77
10	pollardjames	^D36DZ%uB@	George	Moses	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(467)455-0
11	zoegarcia	_9@aSo03s!	Karen	Martinez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	356.924.96
12	fgregory	)b6T2UKjbj	Jenny	Castillo	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	316.582.78
13	omaxwell	)9&%%Ofrhs	Bryan	Parks	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-538-309
14	chavezanna	IS$TED+q^8	Robert	Alexander	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	352-943-17
15	matthew03	eVcrAUkg^1	Alexander	Mitchell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7234474453
16	danabeasley	M8Y3ZIemM)	Derek	Cook	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	613.831.50
17	iharris	3JzE_k@y&x	Rodney	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(683)420-0
18	brookemunoz	&l#g1NzNaX	William	Wells	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	740.230.51
19	fcrawford	Hnmg7Y*e&)	Daniel	Olson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	333.780.92
20	kyle80	#99nUr&rpx	Kylie	Moreno	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	410-888-92
21	bailey37	+6Vs9ZwcI&	Erika	Fuller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	298-997-35
22	davidjimenez	!s4b6UWp8Q	Joshua	Armstrong	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-400-57
23	holly09	I_&4LtokSL	Denise	Bray	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-849-299
24	alexis59	%jeQ3B)g&s	Jermaine	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(422)725-2
25	kcampbell	@))NrtI^4W	Jennifer	Herrera	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-351-235
26	andrew63	(AfWry^Js1	Cheryl	Hoffman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-213-77
27	ecooper	1G9KEMa6^c	Wendy	Wong	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-251-555
28	hallchristina	_b1D@Xy3jT	Gregory	Manning	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-422-454
29	jacksonjennifer	tCaXdFU6!5	Elizabeth	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8744048260
30	aclark	o2Iswzlf!Q	Joseph	Griffin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	773.327.81
31	jasonnavarro	*)3e1hJrWm	Darren	Stark	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4509146827
32	andrewdaniels	^1Oc5)pc!I	William	Hill	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-460-494
33	smithtimothy	3_#3XRYn2e	Andrew	King	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	784.206.06
34	robin21	GkG&9KvnWu	Judith	Hart	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-268-943
35	gabriel70	)flv9SDFE5	Jonathan	Shepard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7313991870
36	shawnblake	g9#Vlsv8_2	Roger	Kelly	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	275.226.12
37	charles59	@5z1uUnx(r	Deborah	Fuentes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-388-27
38	michelletaylor	+@203%CaJ8	Shelley	Dominguez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5763819649
39	elizabeth68	^4gVFmmIi7	Kenneth	Reyes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9855656849
40	tstafford	)YQ*3Esyas	April	Burgess	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-779-881
41	stanley84	76u4KX*l(*	Autumn	Tucker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-210-95
42	morannicole	jW_5@SjwR_	Ethan	Hughes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	225-799-36
43	brownchristopher	RwVxpPML_4	Lawrence	Pennington	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-985-207
44	nicholas16	!pTOqYn2^4	Lisa	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(377)896-2
45	nsanchez	^NY&70Ka+8	Alexander	Thomas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8343606420
46	christopher11	q7)VbEI2&f	Shannon	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	931-918-47
47	roberta92	z^6Kl_FI6o	Steven	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	539-964-23
48	emoreno	JgNz3NYk2@	Jasmin	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	745.380.34
49	ggray	%o3I7P#cS!	Allison	Larsen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	958.993.26
50	melissacollins	aCqdYKca&6	Alexander	Hunt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-289-413
51	william65	!1Da9sEmsm	Samuel	Griffin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	516-290-01
52	michaeledwards	Pu_9A%Tn_1	Ariel	Mercado	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(533)624-1
53	bray	k_8jOsReW*	Frank	Howard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	555-964-37
54	davidmary	&on1TV8rZ)	Brooke	Beasley	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4655532317
55	daviddavis	8^O5t&VQ_5	Timothy	Edwards	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8918633207
56	susanmclaughlin	@@6LSJMuyC	Megan	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(507)771-5
57	john71	+3Dkiv8HOX	John	Coffey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(927)375-9
58	melissabarron	sg$w7SeoXD	Michele	Ortiz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	240-270-58
59	cjohnson	^8WNK_lA9^	Marc	Ryan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	225-846-19
60	christina98	%fIy)6aFG2	Ryan	Moody	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5325825190
61	lauravazquez	V)kiW5zcjT	Sarah	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-415-535
62	hwallace	^6UnTVEv@7	David	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(895)302-0
63	shicks	@y2VYnLuUR	Justin	Greene	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(877)608-8
64	esalazar	_OPl7w_^n4	Nicole	Haas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-707-989
65	bakerdonna	Yj3ZyHRMN(	Nicole	Nicholson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(272)792-1
66	christopher50	2_6SMyWumM	Deborah	Rowe	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2405004017
67	jbuchanan	Mc9mSrEpU)	Darren	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-875-581
68	taylorsandra	7qiDf6Rf&3	Christine	Mcintyre	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-589-23
69	benjamincox	jx^x0DKjd+	Lauren	Salazar	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	236.721.69
70	sjones	kS1NRqih+w	Patrick	Mclaughlin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	907.579.76
71	cstevens	&3*+0_UyrA	Tabitha	Ochoa	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	232.675.44
72	bennettabigail	3mCoDFao)X	Elizabeth	Ross	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(962)491-8
73	burkeanthony	7IyQIT!o*B	Kenneth	Grant	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	968-581-37
74	randallconnie	@7GA9o_q52	Michael	Roy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-347-366
75	nlove	8#5SHIRrtM	Timothy	Warner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-706-604
76	sarathomas	@fvAy*m715	Patricia	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-379-32
77	diane20	_9NfXFckyN	Angela	Erickson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	915-559-49
78	xarias	6(6uZjOuon	Angela	Martin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	226-781-97
79	lisa93	C!9Z57eyP9	James	Short	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-610-369
80	sandra91	)C%7jMVor$	Bradley	Short	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-838-37
81	petersmario	oh1iNG9RN&	Amanda	Jordan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	659-541-85
82	johnsmith	n1y1boHj@)	William	Nichols	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(663)337-2
83	daniel79	p*n9YVGlSE	John	Warner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(237)422-1
84	bwalters	3a3WD(s%$r	Wendy	Collins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(791)425-1
85	bjensen	&#2TvuOoE9	Melanie	Hernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-786-93
86	vsmith	^GnF9@g@#7	Julie	Avery	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-304-232
87	vreyes	GIc7Qx(_7@	Nathan	Mendez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3154994931
88	harmonmatthew	MI1AF+Ip*2	James	Nguyen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	344.677.11
89	devin44	j5DMawQu(4	Jared	Holmes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(264)613-5
90	dennislarsen	p3UccQ6R_z	Matthew	Stephens	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-668-584
91	deleonpeter	_U3hBOSkzp	Albert	Vargas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	673.379.87
92	danapitts	%r^1%TtwYh	Chloe	Sanders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	744-621-35
93	phughes	&2ZW4Lpp_6	Victoria	Berry	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-497-714
94	lindsey46	!38XEa%W)C	Thomas	Obrien	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	594.842.27
95	rodgersteresa	_96yVGCl7%	Rebecca	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	804.525.62
96	melissa02	6iDTNEt!(0	Stephanie	Gutierrez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(458)599-6
97	bradleylindsey	@&0Q4!Km!9	Connie	Washington	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	582.387.08
98	ahowell	%lu#0MccK#	Kathryn	Richardson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-845-46
99	tiffany73	@gfIG_uy$9	Scott	Evans	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	373.384.24
100	johnthompson	%!S4w1)j+0	Monique	Long	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-328-935
101	kyle68	FTa68XiMo%	Christine	Fisher	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-561-73
102	icaldwell	B#43dVa0)#	Jim	Valenzuela	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(422)202-6
103	hooperjoseph	7+FFwSrd%o	Bryan	Simmons	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(277)781-1
104	williamgarcia	*5AUa%zJb4	Catherine	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-284-972
105	timothyhall	!wGNidcQu2	Ian	Hernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(697)714-4
106	solomonryan	23JX@uVz&j	Christopher	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-825-519
107	vnguyen	^3I_ML&stq	Brian	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	644.820.71
108	gayala	^36QTvvd9!	Karen	Weiss	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(471)224-9
109	zgreen	&w#O5(Fc5(	Craig	Mays	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(789)689-3
110	hollowayjoel	(wgBSda!)1	Jessica	Adams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-723-66
111	kklein	Y)2X_OpJQF	Briana	Woodward	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	209-499-16
112	simpsonlisa	xFX3XQFt&S	Donna	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	704-599-23
113	smccarty	(o6IYcexbX	Henry	Patel	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	974-509-35
114	heather76	oIUk3&fqL@	Tracy	Cuevas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5013806098
115	marilyn04	(9@^3AqjE9	Amanda	Hunt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(830)260-2
116	myersaustin	imxT_Sng(4	Mary	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-404-380
117	rgardner	QGRDakMA@3	Megan	Reyes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(232)634-7
118	ysalas	kH57KGy9$3	Cody	Wood	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(696)384-9
119	michaelhernandez	@2rYRKJgiR	Mike	Ramos	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(617)758-8
120	angelajohnson	L+7F@e+Q!)	Brandy	Chan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	290.269.18
121	timothygarcia	*4$VoZy*i5	Mark	Holmes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-606-71
122	derek31	c_OVWrYu^3	Kendra	Brewer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8009552888
123	dalebarnes	@8bObS2!s^	Troy	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(234)996-3
124	angela63	CC53VWr2_a	Andrea	Bennett	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-660-36
125	erin32	s3VRoxKt+F	Kevin	Rocha	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	550-272-51
126	jamesjohnson	4a4!Pt4UH@	Mark	Carroll	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-454-692
127	qsmith	b6b53nGk+E	Madison	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(786)642-5
128	othompson	Q00BfEq@+)	Brandon	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	390-604-42
129	qvaughn	AB7(nHn9*C	Kevin	Perez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(366)321-0
130	julie75	J17C^F&x^8	Sean	Ward	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(483)327-3
131	stephaniedavis	es$2wGimpa	Janet	Schultz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	940.355.46
132	lmiller	19G*f7GG*c	Jennifer	Lee	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	438.922.74
133	hwatson	)x(%4QMzr1	Edward	Romero	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	403.504.28
134	andrew76	Yo3ZP4Rs@d	James	Ferguson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	207-336-15
135	rodney67	MEtgG4TvO!	Stephanie	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	299.302.87
136	stevegraham	F3%BnRJu)p	Vicki	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(317)938-7
137	robertssandra	+rDJSEvs70	Jeffrey	Rivera	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4752848161
138	victoria83	7$6Erhb10s	Dylan	Becker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	376-226-20
139	ehickman	4BV_zCdF%m	Mark	Davies	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(405)701-2
140	edoyle	2f0Pfm@zQ*	Sara	Collier	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-287-228
141	wilsonmelissa	Vi(5#Yaib&	Stacy	Fuller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	521.719.80
142	floresjacob	*G2ap#gB3o	Michael	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(810)978-8
143	xharrington	Ln5l$Rcx4*	Chad	Leonard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-642-518
144	torresbrittney	*iqmW9Lqv+	Elizabeth	Robbins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5914929911
145	kelly90	@W$76FLkxi	Edward	Fuller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-928-693
146	michael82	nX0E(9Uu_8	Brian	Gonzalez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-657-62
147	bryansuzanne	%17CoOv^SB	Jocelyn	Freeman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	689-756-38
148	michael00	B4e(02Ppc(	Alexis	Clark	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-230-36
149	tyler04	^NzFOVUc3^	Bradley	Garrison	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	670.354.29
150	jaime13	_6BxaCeUL1	Billy	Hart	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	746-524-10
151	spencejeffrey	2hoLzl_()%	John	Diaz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4188964209
152	zbowers	!piMVOXv4l	Ruben	Oconnell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	569.901.92
153	laurieking	gd*j9Ek3V0	Darrell	Spence	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-699-654
154	carlsonshawn	%ZKQ8&QtCT	Brian	Henderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	974-847-35
155	harrisonmary	)H3)7KOb!U	Tiffany	Taylor	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	871-667-80
156	rebeccasimon	l*67A6tWkT	David	Pennington	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	613-579-81
157	haydenbrandon	jU%4cTm%FR	Micheal	Serrano	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-246-67
158	phammatthew	(CNHJoSU0l	Brian	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-747-43
159	mitchellrussell	6i2NLLg3u!	Rhonda	French	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-976-72
160	walterdawn	*Q3H!uz+)2	Rebecca	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5575854139
161	nicholaslopez	*3t#SfQezd	Melanie	Lowery	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	710-675-17
162	nathan99	&7J2MwJHdm	Steven	Young	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(212)717-2
163	webbstacy	Ro^5RPn_B#	Timothy	Wright	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	687-973-01
164	earmstrong	h!^I0YwyMz	Stephanie	Gomez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	472.493.24
165	jeremy95	)4A4TOz*&B	Laura	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2108168256
166	zavalarichard	^SNBiMdjp0	Wesley	Cohen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(791)359-7
167	crystal38	$2C!a+aS+L	Debbie	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-585-398
168	guerrerodavid	(AEJx6az71	Mary	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(962)748-0
169	michaelgibson	#6T9YjF&BE	Amy	Mccoy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-760-66
170	williamsroger	a20ObnoW+D	Nicole	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4564219483
171	jeffery43	2cQRPjv*)K	Zachary	Medina	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(930)621-9
172	thomasjennifer	(WHMq+!02C	Laura	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	673-440-79
173	dereksanders	@i1gG$&hI8	Natalie	Little	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(419)951-7
174	jbrown	+FVkp6Wklb	David	Freeman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2035978176
175	nmccoy	(_5Th8ci_O	Nicole	Gomez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-471-447
176	martinezkelly	7TOguVnx+b	Kenneth	Floyd	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(727)882-4
177	danielsdaniel	^51NwEAR5v	Donna	Castillo	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	997-710-41
178	erika53	R07AcUZda_	Michael	Lewis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	505-680-66
179	daniel74	*whv5Dv#Ek	Kimberly	Johnston	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(705)819-3
180	cody28	9)3EfW2reM	Maureen	Rivas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-640-315
181	alicia37	R$T0TtpgFo	April	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	421.338.90
182	mjohnson	!65HEQ1f!k	Eric	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(518)345-4
183	thomas95	)FW5+BEpp+	Loretta	Hoover	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6987846298
184	tbarr	&w$^BOYTR4	Steven	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	501-333-40
185	rebecca13	Y!9L%7)iCw	Sophia	Klein	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	546.782.52
186	kurtfrazier	4&5DvkdzjH	Corey	Dickerson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	608-446-41
187	lindsaynichols	sM+u5H&uCb	Jason	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-912-937
188	julia49	w2Boz*oE(_	James	Ballard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(423)972-5
189	nicholsheidi	8*1DvVlnZV	Eric	Hall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	464.448.21
190	cjones	6*RA1ECr0k	Tonya	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	287.467.50
191	chadwells	&s3UwMz$&N	Kaitlin	Klein	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(415)259-1
192	josephhawkins	m*6$Pu$!t*	David	Noble	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(911)973-5
193	bgarcia	z@AVM2mlQN	Sharon	Lawson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-592-31
194	melissagutierrez	_S7Oy)wg#q	Cristian	Pearson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	721-728-95
195	ronaldking	$g&)2SmT2k	Herbert	Wang	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-886-35
196	nicolesolis	&5CiCxuwWG	Jessica	Thompson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-840-60
197	idavis	B%r*6FMt#j	Kristie	Hunter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	790.736.89
198	hhunter	c2lP4P^d*^	Kathy	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-828-779
199	faith72	!lQsYKXc#9	Holly	Fowler	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	246-408-73
200	bosborne	W+YyAWhi_9	Erika	Richardson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(349)892-3
201	melissa76	(5bu48By3l	Paul	Jenkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-706-66
202	wpayne	!vvKFI*nM2	Joshua	Nash	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-640-867
203	jennifer81	+wChjwRj*5	James	Harrell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	224-441-60
204	robinsonnathan	#%9Rh$Blph	Derek	Solis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	483-225-39
205	swoodard	ko$uZ1EpS!	Ian	Navarro	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	736-919-98
206	andersonbryan	bFbsL#Ab(7	Timothy	Campbell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-714-94
207	stanleynancy	+cw)IFVh1t	Nicole	Schmidt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-796-273
208	mary88	)C4NYq53Se	Brian	Bowman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	881-647-67
209	daniel06	%8DJr2+XSV	Kathleen	Walter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	604.898.95
210	christine54	c6NNtPuN%M	Wanda	Hernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-274-600
211	mary82	+Ijh*DUv#0	Brandon	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	696.404.94
212	mitchelllisa	z8JymRYh^f	Rebecca	Byrd	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(342)929-2
213	silvamichael	^2lCEUyU$!	Renee	Garrison	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	876.554.90
214	poliver	%)6VS$jlz8	Jessica	Hall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(204)888-2
215	iwatson	4D5xO5oHl)	Benjamin	Bell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	696-677-20
216	xwright	1T7Vzytw#0	Christopher	Brewer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(539)238-9
217	brittanygonzales	*(wZ8c5vLR	Sherri	Washington	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(614)262-8
218	kaylacobb	d8$6Bl+wNp	Jill	Lee	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-875-386
219	omendoza	R)WXNThx(0	Trevor	Conner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-333-67
220	mhernandez	&8F(YbIOzr	Daniel	Allen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	884.983.03
221	khanrandy	#38Lzy0keh	Tricia	Chapman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(826)607-9
222	clarkmegan	y0@pp$H*)p	Lisa	Jenkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	518-329-72
223	cortezkaren	F3HI3kUG*q	Janice	Sparks	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	348-569-18
224	thall	I747!Czc_u	Danielle	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-787-85
225	longemily	#%WaMcngn4	Raymond	Pena	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	888-801-44
226	oreid	*!7X@Nwyfa	Nicholas	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	824-412-15
227	wendy17	+5GWBgMov3	David	Mack	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	296.506.75
228	luis61	#T5SrIibIc	Lisa	Meadows	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	391.271.65
229	robert66	_2F0q^$rTy	Sandra	Hayes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(349)217-9
230	cgarcia	%6Yp!Xj2Oa	Melinda	Nelson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	748-393-13
231	austinhorton	!!@18nEu8Z	Debbie	Herman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5189676474
232	slin	)2lM2hcMHu	Anthony	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	597-529-02
233	ronaldmiller	FM@5Hxa!IK	Brianna	Navarro	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(410)466-9
234	sanchezjohn	m9wF7Qs6+7	Hannah	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7319261747
235	vjones	DWW7iyXtJ_	Matthew	Schmidt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	502.999.49
236	sproctor	^vm0nMgxgl	Benjamin	Bates	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-804-41
237	teresarosales	&sY6RrHrgm	Kiara	Collins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(737)473-8
238	qday	2)IEU6ZmfF	Justin	Patterson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-569-81
239	davismichael	d(2p6OPf#L	Gerald	Yang	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(368)876-3
240	jane22	8%3HU&^w(u	Jeffrey	Webster	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-826-852
241	chaneyjennifer	4^3BzpTSp#	Thomas	Spencer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-820-629
242	qnelson	#b51MxYc26	Dylan	Mueller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	256-473-94
243	aortega	vy4WFox(%w	Richard	Lowe	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-761-66
244	jillgreen	($5HXTip_0	Julie	Blevins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-245-717
245	william85	#XY4DDqd_V	Jessica	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(888)930-1
246	jromero	N3DgGxP$)y	Rebecca	Howell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	666-874-87
247	barrymichael	SIxF8TEj)^	Michelle	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(938)904-5
248	jchambers	m%4B3R_zue	Eric	Manning	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(687)626-6
249	millerheather	T!+17PIrzp	Tommy	Stone	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-261-325
250	austingerald	nb0F$@j0A_	Tom	Benitez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-559-822
251	jritter	%2(iEbwy0j	Christine	Elliott	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-826-859
252	tylerrodriguez	T88STq6X_w	Larry	Morton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(972)254-1
253	becky09	!gK^o$MZA2	Jimmy	Gardner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-214-21
254	woodsbilly	#^7MLmslH_	Chelsea	Scott	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(676)813-2
255	umaynard	*vUBk2zip0	William	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-911-55
256	howard95	^ubY0Bsu)5	Sarah	Palmer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	207-696-95
257	mmcgee	!PLRfvlt$2	Joshua	Jenkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(274)892-8
258	wardmatthew	W(65MHi_#U	Julian	Vasquez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	232.523.41
259	lisagutierrez	byc3N_Ei4(	Andrew	Alvarez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(721)742-0
260	alison09	9#7oFJu8aL	Christina	Mitchell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-651-251
261	shannonschultz	f2cTI2K!!Y	Raymond	Dean	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-879-21
262	lisa33	vl+W9YGsRX	Melissa	Olson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	636-928-51
263	ddouglas	*vE1i*AOf8	Zachary	Lee	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	287.917.42
264	rhonda39	g%10tMT@kh	Marcus	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	206.202.71
265	gonzalezwilliam	p4+VbidV#!	Brandy	Moon	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	921-501-06
266	robertbryant	tC5ILewj+a	Shannon	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-361-260
267	james28	*20R&u0w$h	Jeffrey	Moore	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	537.508.20
268	meganhodges	&bJ8Y_Qpo@	Matthew	Higgins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4422905013
269	kevin89	aPuOp10pX_	Nicole	Gutierrez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	737-869-10
270	charlesvazquez	qQVO6LdE(F	Ashley	Webb	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(887)596-2
271	oclark	5jeXsJuP_K	Edwin	Burns	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-304-620
272	collinsmorgan	7w*1nKIfJX	Janice	Gray	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5947976118
273	matthew54	@pV^KXWNm9	Douglas	Becker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-377-57
274	tammy90	+5)T3x15)a	Laurie	Townsend	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3426083727
275	donnajenkins	k)_YU6hj(0	Debra	Marquez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	885.668.50
276	miguel38	+wQ#Qwcb38	Courtney	Villa	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-645-423
277	andrew52	nt46X6hrI%	Martha	Frederick	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-531-25
278	msmith	+4KMjfBAw6	Erica	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-985-719
279	mercercameron	Q7jr5GeB%h	Michael	Waters	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	776.648.61
280	martincamacho	!js#Srafo5	Pamela	Taylor	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	419-414-59
281	jesus03	Ho48mID@G@	Bruce	Hughes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-612-988
282	amyroberts	&La+1oQo#d	Robert	Martinez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-803-919
283	wwalton	&%E66aAflM	Jeremy	Gonzalez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-911-454
284	amandadelgado	(HIQ4CeD%2	Timothy	Rangel	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-410-239
285	sethbooth	5#8ZPSh5UN	Jennifer	Austin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	685.736.44
286	stevenjoseph	+7KxVQxx#e	Justin	Boyer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(206)849-8
287	kjones	H*w9JKHsnb	Allison	Livingston	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3722082486
288	reyesmelissa	2!@2cYnieQ	Edward	Bryant	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(500)497-7
289	rachel95	g8PdHHU5(u	Melissa	Freeman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	690.232.39
290	bruce15	yk8MQw1s&b	Bobby	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	544-519-54
291	collinssue	8*vbOHyp%V	Michael	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(802)384-4
292	robert02	1piX)@2q(+	Brandon	Cruz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-964-867
293	jamesgalloway	_Jb3hFonj0	Jon	Obrien	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	678-795-52
294	williamsheather	@#k1dnImE3	Hailey	Olson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-420-79
295	jorgerodriguez	Zt3f3BuA$0	Craig	Kline	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	829.453.73
296	bprice	dk#i8Z3aWg	Jason	Richardson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-343-282
297	michellesmith	hZ%84AiF!+	Valerie	Le	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	291-601-81
298	lwhite	@0RdNfvoH0	Robert	Stevens	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-812-52
299	jgriffin	aed0@0AkuE	Tiffany	Stout	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	678-747-87
300	lopezjoseph	wA!8JenIaP	Jeffrey	Edwards	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(850)574-7
301	elizabethbrown	0+5ZmztsAl	Stephanie	Rivera	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	503.576.03
302	ydavis	V*30C(m(gd	Jessica	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	888-761-24
303	belldonna	z9nIZSV+(5	Emily	Huang	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(504)245-8
304	paulmurray	+Fqq6Hko7V	Veronica	Cole	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5047633792
305	nmosley	BlEk#kHp@5	David	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-601-612
306	luis46	l3x0RqDa_8	Casey	Hill	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7423535172
307	lindaberry	AP_1Q5Ci66	Nicholas	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	359-264-94
308	taylorchristopher	+t9JjXVa2O	Jennifer	Black	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	935.709.26
309	tcarey	@44!Jk@ha#	Darren	Haley	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(964)391-1
310	lisashepherd	uGgFd3Id)B	Robert	Salinas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	547-303-67
311	shieldskathy	_I9Jz4twbf	Meghan	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-359-39
312	nicolehenry	#g3K7khqK8	Mark	Black	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-572-70
313	ashley87	K6sWmf*o*1	Stephanie	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-967-342
314	andersonamanda	n25_hSfi_!	Edward	Blankenship	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	599-202-53
315	scottdale	RUWo&8Lh@t	Cindy	Wallace	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-574-32
316	sandersmichelle	)7b^My6g)y	Kimberly	Fleming	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	257.607.06
317	albert75	fy6mP1gH)J	Connie	West	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	530-488-09
318	sgray	E!8$VfL1^5	Lisa	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(415)343-0
319	ybentley	(2ID7X*a_8	Jill	Joseph	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-899-353
320	kathleenmedina	!G5a2Bhr&H	Jeffrey	Guzman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-422-41
321	marvin04	y)8SHq(3A^	Stephanie	Graham	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(515)615-1
322	craig15	s^hP96Vo7(	Ashley	Wolfe	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	584-365-56
323	michellefrye	!Nq2DdVZ70	Christopher	Robinson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-757-38
324	johnperry	#ct7eTph56	Erica	Thomas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(895)869-3
325	zhamilton	7E16RmxUb#	Juan	Wilcox	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-972-735
326	john30	a9+@UXBI^t	Donald	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	820-255-69
327	brandongreer	!&Hxj0NiqO	Sarah	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	785-740-93
328	amycooper	Mw6n4Ql*A&	Beverly	Duran	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	920-582-84
329	frank01	!k0Mg+Gx4X	Lori	Haynes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-878-41
330	samantha45	I*SV3AvaLr	Lauren	Tran	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	764-854-89
331	brittany06	yV0QP8b$1(	Latoya	Hood	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-250-34
332	danielmeyer	uCWD@z3V(5	Michelle	Buckley	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7718816134
333	joshuamorgan	@09OFNjoam	Emily	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	858-482-18
334	gutierrezmary	#^7RmDDy*l	Dennis	Rodriguez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	634.981.60
335	nunezdavid	!HsKpfou36	Amanda	Good	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	324.894.50
336	bushmichael	$3QHmwsO8%	Lisa	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-941-50
337	charlesmelton	lMaD0Rlv7_	Margaret	Stephens	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(713)267-5
338	lisabaldwin	*z63S((qx1	Johnny	Webster	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4898143505
339	lgould	%7ztcLlsIp	Marissa	Horton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	277-939-91
340	mitchellalyssa	lI!SBCNp+6	Lauren	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	341.581.27
341	paul83	Ber4SYSuC#	Ashley	Larson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	629.683.82
342	michaelshelton	#LlM*5^r7E	Julia	Sandoval	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(728)261-2
343	vphillips	+6Gk6y5eGR	Taylor	Watkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	900.324.26
344	jchavez	@oX+UVMy68	Philip	Saunders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-697-65
345	john74	)f)RClv#9%	Jacob	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-931-662
346	kimberly58	!vHfA)O3@9	Norma	Cooper	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	986.745.76
347	codom	BwW4%TNz@T	Tommy	Bowen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(949)966-2
348	samanthafritz	)3y&JehBG#	Phillip	Richardson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-303-471
349	lsanchez	_OS5ZcI6R@	John	Morton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-782-62
350	michael12	haUVO#z*(1	Louis	Rosario	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-613-219
351	russell20	VP3sAkah&!	Kimberly	Fuller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	397-966-27
352	gholland	XZl2HsNfg#	Catherine	Ellis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	544-689-03
353	nchavez	$)9kSIeAZ$	Scott	Holt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	389.894.07
354	ldouglas	)84IZnlx$0	Jacob	Lee	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	701-301-22
355	marklang	B#riJ9EoE)	Kelly	Fernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-612-710
356	jonathanhenry	&z7EO4#_L4	Christina	Mccarty	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(692)468-1
357	gallegosnatasha	At9Zd7eZk!	Jennifer	Compton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-769-565
358	johnsonstephanie	U&E&xvC2)5	Rachel	Benson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	953-342-75
359	barryjohn	^lP%!mBb#5	Nicole	Stephenson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	346-741-09
360	mooneydouglas	U^S#0BtQa!	Michelle	Ayers	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-883-821
361	maciasjaime	7WC6TkKvy)	Amanda	Sanders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-998-412
362	gabriel78	6*_pVJkv!C	Kevin	Hoffman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-951-818
363	jimmydean	9z+61VwmA(	Felicia	Buchanan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-314-99
364	steven54	H9WSQjUq%D	Samuel	Baker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	959.527.63
365	christopher06	nRXWNOHS&8	Omar	Moore	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5138890158
366	annscott	0RL+1I4oC(	Katherine	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-578-569
367	llee	7B@9EWyh!k	Melissa	Lee	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	292-463-69
368	gcole	%6ZSE^vfD@	Lisa	Hurst	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-911-841
369	cortezholly	P5bPD3iu&y	Danielle	English	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-403-875
370	craig94	^R62XF%uK1	Anthony	Potter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(841)801-8
371	nicolecooper	XCX2T6zJ^&	Caitlin	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	447.414.44
372	william86	@+d$mAd8k8	Kelly	Barber	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	802.540.01
373	mroberts	$JPzJulz43	Bradley	Hughes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	261-549-11
374	lacosta	!9_O_WScUh	Chad	English	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-627-37
375	derekleonard	gzXw%1Bzh%	Jennifer	Leach	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(244)452-1
376	stevenjackson	NeL*6Maw45	Keith	Gibbs	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(305)945-7
377	sierra58	1+$u08Qb$o	Paul	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(657)285-0
378	youngnicole	8X6Zu4l$*1	Luis	Santana	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-727-51
379	hunterdavid	Q+8(9H1h!6	Ashley	Hall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-756-268
380	brian36	)_l&Stso_8	Robert	Wilcox	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	677.661.10
381	nschmidt	(JHBwk6FJ4	Mark	Marshall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	289.896.15
382	cervantesmichael	*4bMxaFhD2	Randy	Escobar	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-750-66
383	tonyasimmons	xjmLyHa4@7	Angela	Burke	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(308)479-6
384	wilsonscott	_7szFSYmfT	Angela	Carlson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-987-508
385	alyssarubio	Zb5DjZl^3!	Monica	Tucker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(923)284-0
386	michellerobles	cpH5LlP0)9	Laura	Evans	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-407-298
387	awhite	j!ORG9^i0G	Tanya	Hanson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(335)979-8
388	leedebra	(nV3PPgo94	Mary	Young	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5778716222
389	garciadavid	#6HdUrAI4B	David	Lewis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(627)607-2
390	stephen84	&m8zOZeu53	Cynthia	Villanueva	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	635.394.63
391	hmcmillan	_o4ZPEEtQ2	Nicholas	Martinez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(268)858-0
392	anthonymorales	*5XIiRE8_&	Dennis	Lynch	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	828.584.82
393	lmiles	3*In2DeyHp	Adam	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	545.357.38
631	joseph59	#3HdyIh#@8	Adam	Moran	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	782-835-14
394	gabriellegonzalez	5GxJ+dTD!L	Maria	Cisneros	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5829973474
395	smithmichael	xY#d64Vzu&	William	Griffin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5958811020
396	shermankristi	u5RC)0GcS*	Theresa	Diaz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(753)383-2
397	richard69	&Zs)K&0aW*	Sandra	Booth	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	519.348.14
398	dianavalentine	F0Lm5X9B(S	Renee	Patterson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2516749684
399	wrightgeorge	01WP6w9l*i	Daniel	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	694-472-66
400	randymora	5JHCQo(c&I	Matthew	Walker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-787-894
401	kellymaria	0_9Bulh*!s	Amanda	Graham	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	884-752-76
402	penny22	&L8EDf8pZ1	Cathy	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(314)610-1
403	lisa88	Nt$R%6GarT	Cindy	Fowler	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(923)494-7
404	rpadilla	G!IH0S4svq	Corey	Rice	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8914900519
405	jacksonjacqueline	!BBIc^Fg9C	Amy	Maldonado	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3569221416
406	evansrobin	5Xg&1_Ew^V	Melissa	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-292-20
407	havila	)7+B1CIr+@	Melissa	Flores	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	509.903.10
408	edward63	(@(7u+X+j4	Michelle	Rowe	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(849)743-6
409	flemingjoan	&BTKykI(4g	James	Hernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-230-50
410	cparrish	*6W4BXq*cO	Brenda	Taylor	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-444-616
411	daniel51	^6)OM8keuI	Brandon	Price	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-365-764
412	dianavang	#p4gMPttRV	Michelle	Ramos	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(726)464-8
413	raymond99	e&1G0Pbrwi	Jennifer	Chandler	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(419)466-0
414	pattersonallison	@6qSbbIs)b	Steve	Santana	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	315-814-70
415	dlynch	pm@8FE9z4t	Stephanie	Roberts	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(293)616-9
416	davidbruce	+&Q3_NSO^r	Jessica	Burke	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(478)612-8
417	stephanie74	YfAFBr$F^0	Jasmine	Gray	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	342-740-68
418	jenniferwagner	*(7cg8QlI_	Theresa	Kennedy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	205.607.33
419	ritterlaura	tC3DxCex$6	John	Bridges	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-525-70
420	jacqueline49	r*X(6xHj_p	Katherine	Floyd	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	545-997-29
421	ywolfe	_MY7iD4spU	Kathy	Harper	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-501-81
422	trevinoangela	CCH0p8QgY%	Michael	Hall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-919-406
423	fgarcia	2759XmaD+v	Carrie	Jordan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-233-260
424	wgillespie	k*36KWTANn	Rachel	Boyd	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(808)908-2
425	leblancsue	+7&As6QgwF	Lynn	Peterson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(310)271-1
426	pcox	a%7qtAkUdW	Karen	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-498-95
427	charles40	_OTQZh1d*1	Jason	Escobar	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(409)304-0
428	lisajohnson	+9q#N7dxQd	Cheryl	Lewis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-955-35
429	josedavidson	F!2Zt#laLF	Andrea	Barton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-834-94
430	steven87	$MNCo(Q(y5	Sheila	Waller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-425-33
431	robertstewart	QqV9T3xn(0	Tina	Lawson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-351-260
432	joshuaroy	*aTpUZVf1v	Kyle	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-988-37
433	erika48	m2VsoqrS+6	Pamela	Thomas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	648.910.24
434	ukeller	+HM8OMbP^+	Amber	Russell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3544396027
435	kmarshall	@7GpMH!G1Q	Margaret	Lam	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-467-66
436	isabellanelson	B*ob4KCcA&	Daniel	Roberts	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	464.249.71
437	rhodesandrew	Q_gf@K!j%0	Jacob	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3018863219
438	rachelblack	5uF0AO2b+_	Terri	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	715-798-47
439	ivaughan	m*15nBymY6	Kelly	Christian	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	275-456-71
440	tylernelson	K&Sa3Cvv*r	Jerry	Lambert	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-991-825
441	riverajonathan	Rri6Ypto^x	Tyler	Moon	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	371-930-55
442	davidpace	f_U12FzcRN	Brian	Guzman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	764.912.60
443	john04	aILZ&Xfw+0	Lisa	Skinner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	306-376-53
444	thomasrachel	p#p0Cv05Vj	Matthew	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(969)534-9
445	jeremymccormick	^y_92Gq$e0	Justin	Collins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	901-773-80
446	richardsanders	M7FeOfhA!T	Maxwell	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(419)871-9
447	adam82	xd5IwW(&_D	Cameron	Walters	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(586)264-4
448	jonescorey	CmVr2HZhT+	Richard	Ryan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(597)306-5
449	brady43	^uz1)G*rG4	Heather	Schwartz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3634054723
450	adamsmichelle	Ne5G4OBlt$	Angel	Graves	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	444.311.58
451	johnmoses	e%8sYX(6tt	Megan	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	736-211-31
452	hobbslance	VLHJ0D(y*4	James	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-590-68
453	justin17	o9hV4CuA$+	Tracy	Kemp	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	994.941.75
454	anthony22	rHlJD3xs@7	Michael	Walker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	607-499-72
455	acostastephen	mUg57kltK&	Jeffrey	Merritt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-292-98
456	theresa75	n8gN2drr#4	Jose	Freeman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(785)761-8
457	fitzgeraldjenna	tO^tV0Twwa	Sean	Melton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-904-438
458	brownkristin	!29g++Fe7i	Kurt	Campos	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-617-93
459	tinasims	#q3(5H%hwo	George	Heath	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(779)221-3
460	tinarubio	P$&2AJ7phh	Lauren	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-628-89
461	derekcuevas	@r!YIs^r3f	Selena	Sheppard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(570)939-3
462	jcollins	$r@(5F$aZl	Melissa	Cervantes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-429-26
463	daisywatson	YlV2CfEYr*	Randy	Alvarez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	455-525-35
464	juliarobinson	L44bLAhi)h	Jennifer	Burns	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	624.594.73
465	mclaughlinalicia	!8PL2dGVfz	Kimberly	David	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(599)958-1
466	erin20	^c7SRccg8G	Thomas	Davenport	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(518)425-4
467	jason78	(11zQ8erL5	Heather	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4069049640
468	sarah75	)8DGw@hudP	Lisa	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	971-469-53
469	josephalvarado	!%d*7mLpzj	Brittany	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-340-842
470	jacob48	mgL&6Vy@B^	Brandon	Castro	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	532.296.89
471	robertcruz	yd7m2YZTR_	Jeffery	Marquez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-755-76
472	moorekyle	^2CEklR4tm	Tonya	Marsh	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-564-337
473	brandoncooper	!tI(7*Py@$	Wesley	Wells	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	221-385-46
474	jamessmith	%2LS*z#f*O	Elizabeth	Brady	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5545400821
475	teresa85	Le^4R8b(%R	Thomas	Hernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(604)433-4
476	ronald04	!t)6X+6ya_	Mark	Hensley	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-958-802
477	sgraham	)9(LZtzhbw	Natalie	Vargas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(614)992-3
478	cookekelly	!!u63TQmIe	Daniel	Walker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-460-32
479	johnsonrandy	&6vLsb)Xx)	Melissa	Flores	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-724-38
480	beardsteven	!2J!uOmX$I	Dennis	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	368.495.21
481	cfrank	V4V08VzfW%	Kendra	Shaw	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	842.267.96
482	diana70	(&WPg0Fip!	Susan	Molina	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	544.791.20
483	wdaugherty	%#30MmBX+H	Ashlee	Barker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	225-678-30
484	floydmeredith	@_LOJ5Gh9h	Jaclyn	Wallace	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	391.450.13
485	shirley27	+VR_gFagn3	Edward	Wallace	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5765698046
486	angel38	fh%IHret$6	William	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(681)503-6
487	lpeterson	G$53P^ki)6	Ashley	Patrick	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-431-380
488	wwilson	v&c4+DVsug	Michael	George	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(708)484-8
489	willisdiana	I0gcCIQp&r	Andrew	Willis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(918)444-0
490	stephengarcia	3%2xBudx%Z	Gerald	Woods	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-547-54
491	travis96	T(9OcpEess	Brandon	Humphrey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-839-21
492	alewis	^2GvWIrdmL	Johnny	Salazar	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	867-396-08
493	eroberts	)UwLnIgp9o	Renee	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(398)952-2
494	anthonyjones	#7kRTia%n5	Eric	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(247)214-7
495	ewells	7&%6HJjKnV	Lisa	Snyder	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-634-82
496	morganrobinson	^5Oh1lWjzB	Karen	Thompson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-359-80
497	sabrina68	Pz&*OKwp(9	Joshua	Stewart	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(899)564-9
498	shaneadams	ArIRmVyv)5	Teresa	Fernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(740)703-8
499	zchen	(p4jO%dqw8	Elizabeth	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	724.477.28
500	mcintyretimothy	F$9P&rQrol	Kimberly	Butler	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	275-408-49
501	kimberly42	GxP$GEn2@1	Eric	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(997)851-1
502	lisadavis	$3OL$uo#3x	Lance	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-893-780
503	jameslong	#1a4kQWjla	Tina	Evans	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-869-683
504	parkbryan	!y3U7Zzm55	Julie	Mayer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	759-482-05
505	ysoto	8E8WPljM_X	Amanda	James	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	954.452.30
506	raymond45	y&n@H1Ma)v	Denise	Mitchell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-842-39
507	tortega	1KN0FqQg+w	Crystal	Potter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	571-356-70
508	sue78	NQ&1@Guqa*	Roger	Gray	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	944.996.76
509	zlozano	#2M$5SWe%W	Sarah	Long	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	959.768.66
510	douglaschristine	S)7YzJOwr7	Lorraine	Obrien	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-556-93
511	hardybryan	&YB^4KMz(!	Andrew	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(938)597-8
512	lisa31	^ES&T&a0%4	Dylan	Foster	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	513.246.50
513	thomasmichael	E(6HEuFs67	Sandra	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-281-511
514	hwilkerson	^7CAgvanyi	Diane	Saunders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	278.531.55
515	kendra93	@*wBh3O11l	Luis	Santos	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-415-92
516	harriskevin	u9XJ2n(s#a	James	Bowen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	209.286.63
517	zoemorris	7@^8Zddz1G	Rachel	Fuentes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-947-892
518	lori91	tU8Vw1RE#n	Larry	Thompson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-253-452
519	cathy94	0ZUUWQcJ^H	Austin	Reese	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	574.580.07
520	wcarlson	b93WmqO(+A	Daniel	Robertson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	947.392.94
521	jtorres	_w2p0ETm)7	Jessica	Hinton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6552077434
522	larsenallison	)74YKsc_wK	Troy	Taylor	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	241.653.37
523	romangary	+1vJhl)p!R	Amanda	Kaufman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	202.755.32
524	nsmith	_cBrf*Na+3	Justin	Moreno	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	872.232.09
525	nferrell	BWD$9@AkUK	Donna	Gutierrez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	566.665.19
526	hannah86	(5QC@_ni@R	Charles	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(720)716-1
527	amy45	S)83ExYJ#z	Lisa	Swanson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	469-212-10
528	theresa91	d3cC4ZZkY)	Michael	Barton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	694.807.17
529	dianezavala	be6kLkdN&4	Julie	Hardin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(747)267-5
530	kyle83	44INY^AQ&d	Kristina	Taylor	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-499-87
531	nathanroberts	%wFO4A&gj@	Craig	Sanders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(526)228-4
532	amiller	p+31LdSBM$	Jennifer	Barnes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8118676325
533	grodriguez	mF1qo%Uq(%	Cheryl	Miles	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-715-81
534	alivingston	GmFfHVtr(9	Joan	Wright	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-479-32
535	april75	(1u57(Rt)G	Michael	Perez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-417-739
536	diane49	5zVOgYgE(8	Brian	Richardson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-228-43
537	christopherdodson	$X6ZVlIwH!	Bill	Maxwell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(879)800-0
538	wallsapril	Ga7X2N$h$g	David	Aguilar	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5305538384
539	howellpatricia	OfE16dOn^P	Donald	Hernandez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(717)254-0
540	bradley05	zCc2A8xk(&	Melissa	Duran	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	616-344-65
541	mary17	^)V95O2o^%	Jeremy	Webb	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-514-70
542	kimberlycarrillo	J9%7tiCx$#	Charles	Gonzales	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(274)746-6
543	dreyes	C@@z8B8vfI	Charles	Patel	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(509)350-4
544	jeremiahgibson	pz5T(Xdz#r	Randy	Richards	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	260-727-31
545	fuenteslinda	&z5JlI7^Xr	Brian	Bailey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(788)362-5
546	george77	*@3P0Jbar8	Keith	Ewing	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	908-732-29
547	jessicabrown	j_Q9Gc84M%	Heather	Vasquez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-600-82
548	ymosley	7od_4Gpmd%	Joy	Wade	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	986.580.68
549	bakermary	OKL9Ehw$!S	Donald	Walker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-251-268
550	stephenstammy	Cj6Y!vZl&C	Matthew	Chase	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(696)713-9
551	lowerichard	)q7f@zBsx^	Eddie	Lewis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	477-843-22
552	danielcarrillo	&4I_fx08ke	Christian	Wood	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-582-235
553	meredith76	_@2PdA7XIn	Joseph	Hess	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	775-916-77
554	angela79	_vG+qJp&Y6	Jamie	Barry	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-383-805
555	amy54	_^2WRRyp7F	Michael	Saunders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	668-928-21
556	mhunter	aW^9&A5v9d	Kristy	Spencer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	824.925.86
557	wfuller	CoF8GmRi(M	Amy	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	610-538-67
558	ucampbell	Q$6qDEo4d#	Roberto	Marshall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	726-825-93
559	guerreronicole	J9KMC#Oe!w	Jackson	Fields	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6647248585
560	simpsonandrew	MTptG9Ym*L	Donald	Skinner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	247-704-00
561	michael74	*oV4D)ZqK0	John	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(494)765-6
562	ajennings	7T6Q^fU$%g	Darrell	Calhoun	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-480-863
563	baldwinjason	u^su8GfY#K	Shannon	Allen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-550-468
564	kellymarshall	__t*5DPhqx	Joseph	Holmes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-665-60
565	srichardson	*5Tjgibn5#	Eric	Alvarez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	419-333-89
566	jgill	M6Cl(PWi$&	Erica	Wiggins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	695-945-80
567	lharris	9o4OGFrK8@	Savannah	Peterson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(561)814-6
568	christymclean	QhIXaUjX(2	Kaitlyn	Sharp	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(701)488-8
569	mckaysteven	@a!nIrtG0C	James	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	492-400-38
570	zlove	!c8Jme%z#s	Anthony	Noble	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	475-450-06
571	cruzmichael	LwH1C#Cn8$	John	Ramsey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(505)488-0
572	turnersuzanne	w*D0fM0n3%	Terry	Kemp	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-246-955
573	paul31	^33Los!jic	Jeremy	Eaton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(555)514-4
574	williamkim	Su!Fquu*@2	Andrew	Valdez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-335-47
575	klinemark	0BcvCDMe%T	Heather	Howard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(929)949-0
576	michaelburke	*RN6pEs(nx	Kayla	Rasmussen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	368-207-56
577	brian83	y!5SKJqLps	Jasmine	Mitchell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(788)358-5
578	nataliebowman	14R4dggW^)	David	Aguilar	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(374)606-0
579	nicholas00	oPd6UHHv(*	Jeremy	Mccormick	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-319-29
580	johnsonleonard	^0m^#eEkOa	Brandon	Collins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(961)953-8
581	rebecca02	*1z15Go$86	Katrina	Yates	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9896551658
582	mannjacob	)3VRH9bPn_	Tina	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-558-330
583	okeller	)^8V@@u^Rh	Jason	Alvarez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(849)916-8
584	patty01	$0bKu@zr3D	Jessica	Hughes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-901-38
585	xsmith	7@2Y*OCG!t	Jason	Velez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2288618886
586	bnovak	j0ZqpjDb&_	Melissa	Campbell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-873-41
587	harriskenneth	7XW&2OJimK	Jennifer	Herring	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-718-758
588	michaelkrause	E+n0VJ&aHT	William	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-850-810
589	juanhughes	%(E5FrzBY&	Melissa	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	290-346-02
590	smithchristopher	#4XfsN_gFt	Denise	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	280-656-21
591	andrew71	!7Q2My(_d^	Monica	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9232732984
592	qgreene	j4V1bUCg(2	Timothy	Alvarado	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(274)938-7
593	vmyers	#eRK2GBpg&	Patrick	Middleton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-458-565
594	johnadams	9V6EsXDz^e	Michele	Boyd	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	637.804.26
595	hamiltonlisa	%aZNVS!mh3	Daniel	Macdonald	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3395032677
596	huntbenjamin	SnP9BuVd^d	Christopher	Mcdonald	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-925-919
597	jonesscott	VQP45p*fS#	Terri	Allen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	309.379.28
598	malonedaniel	M@0$jVeU(E	Andrea	Lara	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6503739091
599	rmoore	&8Q0WQdc@S	Marie	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(612)207-0
600	dale63	GB+7Zovomq	Karen	Miles	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	689.393.88
601	seannelson	uIYDLUee%3	David	Woods	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	370.559.62
602	patrick47	U5Pt%y+G_R	Jared	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	608.266.52
603	qgilmore	sfNSufjz%8	James	Herrera	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	913.501.52
604	paul64	+C1VEvltOK	Douglas	Olsen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	517-548-88
605	herrerajennifer	YuTTX#nB%9	Drew	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	908.971.11
606	lthompson	^9HjrY9gk@	Paul	Nelson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-718-55
607	tannererin	_9SO+zsdLL	Taylor	Hoover	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-885-29
608	ana93	3piO@qmX$7	Mary	Campos	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	397.881.81
609	jesusadams	Q73Nz0hg^U	Kenneth	Hayes	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-625-821
610	aaron57	#mY_XAqV69	Timothy	Ashley	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-315-246
611	tgarrett	!V1tuvTyk5	Christopher	Adams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-447-70
612	melissa12	@0149Wre)M	Jason	Bell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	821.279.95
613	zbrown	X^xqn5gi)G	Charles	Porter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	498.445.90
614	newmansandra	8^D^r7Vj4x	Joseph	Eaton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-624-42
615	tferguson	*2DxwBB#XS	Christine	Bartlett	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-436-58
616	nicholasmendoza	fv1AMhC1@4	James	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	246-982-25
617	bsteele	$&l8iQIlaH	Kristie	Perry	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	954-466-23
618	crawfordkevin	m6mHB@Ls&E	Brett	Alexander	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-832-529
619	hayesbarbara	Fc8AQ6v2$g	Justin	Marks	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	442-514-44
620	megan64	)r4gBGHj4B	Ashley	Kaiser	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-612-805
621	lmyers	#&2IfJ^LAu	Sandra	Harrison	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	412-900-11
622	dylan74	*l3SUzA*QN	James	Golden	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(267)855-5
623	vtrujillo	Q13Ui47&8*	Michael	Mcdonald	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-820-342
624	rcohen	%HXh9OKho2	Shirley	Morgan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-775-75
625	kscott	2n0ZbBAi&a	Adam	Kennedy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	598.343.24
626	hernandezjames	x5H%t@yR$2	Jessica	Reed	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	781-362-38
627	imoore	Zj7vW(eU_4	Jared	Travis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	758-707-39
628	byrdjasmine	L(9ae@Va7f	Wayne	Rocha	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9757905037
629	dnguyen	9(H^i4K7^c	Raymond	Alvarez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-459-991
630	stevenfoley	&hIk8HyY5y	Ashley	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	852.720.30
632	ashleycastaneda	M2WrsayD!s	Stephanie	Villarreal	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	834.558.46
633	susanjacobs	^xAfrnbgr9	Jon	Mcintosh	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(523)375-4
634	heidi29	&0Rba)z6%b	William	Young	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2319520192
635	steven99	*mpQwH(sk6	Matthew	Gray	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(680)790-3
636	richardgordon	%yqB16PyQa	Alec	James	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5266074554
637	johnray	&1zq%P8hZO	Michele	Esparza	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	944.241.46
638	iho	9wv)dWMj+Y	Laura	Fitzgerald	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2409904559
639	spotts	_cZ2mwXn+Y	Robert	Morrow	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9427225821
640	scottharvey	_DJ9Nsu@Q0	Melissa	Cuevas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-553-606
641	caleb33	*Y2#KbtlK!	Sarah	Bass	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	267-855-99
642	gaineswilliam	n*^#3Lc44X	Patrick	Hubbard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	721.475.80
643	peterfreeman	%R1NDCqT@v	Richard	Mills	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3102300873
644	angela30	m#)7+DrrXP	Wendy	Wyatt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	676.362.47
645	melissagibbs	)5JSBXCp*#	Holly	Hawkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	363-673-95
646	justinward	#1Sbz9Fnhe	Debbie	Guzman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	342.317.06
647	ohuber	%6BbQ%pabP	Andrew	Carlson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7955908372
648	margaret27	)SSGXCdpi6	Albert	Gilbert	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-474-95
649	wchavez	@*Ix0^f!+3	Melanie	Ramsey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	459.751.86
650	brownjeffrey	f)&3a^WxGk	David	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	235-742-20
651	hannahturner	h19XdBQW(q	Steven	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	894-314-61
652	christopherhamilton	^K86zlYf4_	Monica	Choi	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-955-28
653	brian05	yWC041th7%	Sandra	Daniel	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	271-966-22
654	eric91	_(s5FYsjAt	Scott	Vincent	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	252.549.97
655	richardlowery	3#dq3OEhN_	Sonya	Jensen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	909.919.62
656	leeshelley	m*15PjgdNt	Joseph	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-220-73
657	franciscojones	^K0GMkv6$A	Wyatt	Rodriguez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(826)789-9
658	zjones	Z+26MeDicO	Jennifer	Lucas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2942803225
659	frankprice	$MAGGy0t%1	Matthew	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	834.356.25
660	gonzalesbrittany	ue0m&V2i$e	Richard	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-844-89
661	salazarmark	_ybTWDw@r9	Julie	Wells	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	777.474.70
662	dawnnolan	84McX##9!7	Samantha	Buchanan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6773971646
663	robertberg	uXLP+#w4#1	Adam	Ruiz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	637.591.64
664	harriswendy	^N0OHJCz!F	Tracy	Green	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4913483218
665	curryamber	*x8EWqtLI6	Christopher	Norman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-688-92
666	david18	sMV3r0Mc$B	Kevin	Marshall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	418.871.21
667	charles86	_U6sC*&jo)	Benjamin	Bryan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-360-40
668	calebbaker	!*4H3Woioe	Timothy	Schmidt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	632.959.00
669	rberry	X84N!XYt)I	Ryan	Newman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-265-30
670	ybrown	^2VK#Vu^az	Jeremy	Gonzales	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6706620298
671	cgonzales	qT@*8Jd+$7	Heather	Morris	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	320-654-39
672	brandyclay	yv6H+Kmtp$	Nicholas	Swanson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-394-91
673	kingcaitlin	hBIqXx3%$6	Robert	Harvey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-944-54
674	elizabethwright	W5(k5Few0+	Jamie	Mcbride	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	299-505-55
675	patricia00	k6WJDNKx)Q	Teresa	Patel	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(983)215-0
676	evansantonio	+K3g+AKn%+	Bradley	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(931)605-0
677	benjamin99	$ZPLj()c(3	Elizabeth	Vincent	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-656-23
678	obrienmichelle	Oc4foNXe#h	Maria	Mitchell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(979)520-6
679	jrowe	W!7ZCpUl2y	Mark	Meyers	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6399923348
680	amy34	(5PO0Gji*B	Brandon	Bennett	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-892-640
681	zrobinson	@2PhHOd51*	Mary	Houston	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(967)342-9
682	ahouse	t^9cA#yn)s	Richard	Gonzalez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8302417717
683	jenniferhampton	)5N$ulv9(m	Diane	Roberts	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(316)962-5
684	rodney47	+0LR+olY(U	Robert	Black	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(488)899-6
685	lisa40	$@pIe0*E!7	Matthew	Malone	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(893)537-6
686	torresphillip	(%$11SixF4	Samantha	Anthony	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8362422492
687	teresadavis	0$0BgYCU$a	William	Wilkinson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(742)368-3
688	qmiller	d+i1AiOyt7	Joseph	Benson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(405)630-6
689	freemanluke	)bQNS1Ow)1	Douglas	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	424-511-37
690	bondwhitney	%W20Plng^L	Veronica	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	734.490.07
691	obrienmonica	+^O5Sohl(J	Elizabeth	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(613)640-4
692	justinbender	F4DaQg(F%3	Laura	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(768)623-4
693	amy49	39zHd^(a_X	Carrie	Barr	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	785-271-19
694	lhaas	(y35VucEbD	Shannon	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	458.566.96
695	barry10	Q^59Iv5vOW	Natasha	Edwards	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-572-721
696	danielle20	^LWWv+C11q	Natalie	Chung	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(589)747-6
697	hglover	+1)v9Ek_FJ	Christine	Willis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-582-994
698	lisa17	!3IOro8U(G	Kimberly	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	958-279-24
699	gcunningham	__Kyfyk9I3	Kathryn	Evans	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(531)730-5
700	pmiller	Kd7687ZMy%	Anthony	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	724.382.75
701	jonesemily	mm&Y3Gdc+4	Kelly	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	344.736.75
702	bruce36	#2DYMd0SRi	Sara	Larson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-677-85
703	rspencer	mMc6Pa0J)#	Julie	Myers	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	520-693-63
704	tuckerkatherine	o&570EB*mk	Danny	Sanders	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-347-36
705	qfloyd	)acGC#j38r	Carlos	Baker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-679-38
706	ymiles	#^REt4yZ8)	Virginia	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(806)292-3
707	rebeccalawrence	@zfQ6_Br$7	Jon	Hall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-825-220
708	sandersyvonne	*HBV7nEz+5	Mark	Estrada	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(574)982-3
709	lpowers	T8qTN%a+^l	James	Hicks	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	729.896.53
710	william69	C!7ohC)e6r	Joseph	Hart	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6627775929
711	edwardslaurie	%4A0K6_vNx	Audrey	Dennis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(864)834-5
712	zhansen	ycxYAcVw_8	Nancy	Benson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-263-958
713	mirandakyle	(JqUcJ4P5f	Christopher	Dixon	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(946)822-2
714	gkramer	_wT@7U8z&2	Jennifer	Simpson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	998-839-52
715	nlong	2@Ziw2xF)3	Steven	Liu	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-916-856
716	brian96	4I49L2aS#J	Jeffrey	Richard	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	377-322-56
717	sprice	#(1P8M+Nbp	Daisy	Gonzalez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(295)240-5
718	john99	Eo0ShMv(_3	Benjamin	Diaz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	500-805-70
719	johntyler	z5@JL(nd)X	Patricia	Rosales	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	931.340.10
720	lacey22	_1BPktE9K6	Brianna	Figueroa	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	241-263-28
721	tbernard	%mSknOfC$0	Jessica	Bender	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4732709489
722	corymartin	Y!x3Gx+O3k	Adam	Cannon	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(965)951-3
723	rodrigueztodd	gw@@)3DpRl	Destiny	Schwartz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-746-776
724	nleonard	6xq5nFsan&	Carlos	Sherman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	425-709-73
725	candice08	)8NWxDs4jJ	Vanessa	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	562.816.00
726	ramirezkimberly	$6ZlDY8Z6m	Jessica	Wright	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	626.608.34
727	mfox	&18BUb6%aI	Victoria	Ayala	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(826)545-1
728	biancasmith	7F7Zpu_I%X	Sarah	Richardson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(928)248-0
729	kathleenpeterson	_cQbzQFp65	Barbara	Berg	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	649-574-28
730	heidi17	(7gSm!LmeW	Monica	Walton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-386-605
731	scott10	_bBTx5*j5b	Nicole	Harris	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	644-363-37
732	ydavila	lq1mGhmT^7	Briana	Wilkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	973-694-92
733	wvazquez	$jsyIXq2#4	Jill	Ferguson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-805-275
734	daviskevin	D#VX4wJik_	Erin	Padilla	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(912)338-8
735	sean46	@WCdIMku67	Ryan	Donovan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	604.976.25
736	jennyvincent	M3Idr9)N(R	Jeremy	Harmon	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	582.557.06
737	garcianancy	^fVjw!xvO7	Gary	Fitzpatrick	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(355)667-7
738	rachelcox	_G9Bh0Og5V	Suzanne	Reilly	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8803248540
739	lisabrock	)qH4pQc+0k	Lori	Newman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-847-51
740	jordan88	SwYvVNcn%7	Wendy	Cook	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	852.827.93
741	palmerjo	&4PM#(CzAl	Marcus	Sanchez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-214-755
742	barbara35	JljBbpRr%2	Michael	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	775-341-32
743	tanyamurphy	6MG2+LYq%3	Jamie	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(513)361-9
744	meghan39	AWY*8Co&Wd	Linda	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	931-412-75
745	albert62	q0O&VYzr!k	Michael	Arnold	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-772-98
746	carlos52	w8Fbby6d&V	Kelly	Atkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-535-482
747	douglasdaniel	PR3WT65h_(	Logan	Martin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(368)646-3
748	james25	^9H1YokHPa	Kevin	Rodriguez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	650-694-63
749	vickie95	6oC4KJxg@7	Crystal	Lawson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	834-211-60
750	wevans	!bSf!GD9^1	Samuel	Scott	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-950-57
751	leesusan	@7zTcrYLJP	Sarah	Cruz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-864-80
752	watsonkimberly	*4LK1GPnu#	Joel	Torres	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-679-418
753	savannahhopkins	MlsNXFr^_5	Nicholas	Russell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-601-24
754	angela51	M&6Vdrvw+V	Sabrina	Graham	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3063333039
755	geoffrey31	#46RqQzk^L	David	Mitchell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-637-43
756	lowejames	#2VGtQju(r	Jennifer	Campbell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	934-416-95
757	stewartlauren	%W7J)Fc3A#	Gary	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6734000776
758	teresa10	_2wFO6JzRC	Victor	Gomez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	719-408-66
759	riverasara	$)6VBkWpJa	Destiny	Hall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-376-34
760	carolreed	TLb1XCnm#@	Michael	Gonzales	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-825-351
761	sosborne	$9QIuSv(r7	Kurt	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	885.412.00
762	bromero	iz89aQ3LA!	Alan	Salinas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	235.971.22
763	weberchristopher	Cp5u7UUp^9	Joshua	Graves	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	851.534.90
764	davidbowen	1NDaE0q8#9	Nicholas	Logan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-852-586
765	thancock	$2iAAHQm&_	Toni	Fitzgerald	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	609-781-13
766	ericmoore	H0qFRtPG((	Amanda	Avila	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	841.934.78
767	benjaminlittle	CeF(1Ho_8h	Sarah	Berry	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(399)709-0
768	coxamber	Mf)2_HOs$3	Kelly	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8083973956
769	keithhenderson	_N8M1m#f)s	Elizabeth	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9323404175
770	gmorgan	_5_(@Gicx6	Elizabeth	Stanley	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	213.883.38
771	johnny50	TtE!i6Bo)$	Renee	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(696)967-6
772	bernardmichelle	yA6iN_Hd&1	Kimberly	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	535-615-58
773	znelson	Y+&R_3Lgf7	Melissa	Vaughn	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	645-836-17
774	nshelton	*2Bb6hMvW8	Joseph	Morris	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2275515070
775	pachecoscott	(^VfGcnHk5	Sharon	Bush	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	382-425-11
776	flee	TC8*7LDeq^	Bradley	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	367.878.09
777	karen01	mSJ@6KexBo	Matthew	Gillespie	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	772-794-73
778	sarahgreer	Rn8YqlXk_f	Jerry	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(603)700-6
779	stephanie32	+BbV!P!sv9	Jessica	Patrick	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-425-248
780	dhuang	&9F_iGo^BS	Lisa	Blankenship	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-604-279
781	bryan38	*5JFsf*pch	Sierra	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(270)991-7
782	walkersarah	1oRiyvPy+J	Christopher	Russell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-286-639
783	burtonrobert	&I4EJAcpN3	Kyle	Chen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	560-382-96
784	destinygibson	@feRP0ky4S	Christopher	Bauer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	661.791.21
785	jcervantes	(wz2JIWgDi	Jerry	Nelson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	9918958141
786	richard35	J%R8Wv@h5@	Troy	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-833-77
787	haleybryant	1p!)1Gng(K	Lisa	Petersen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-374-866
788	blarson	*7MmP2^po6	Shawn	Butler	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	379.945.92
789	coreyallen	7&k+4MmAmU	Emily	Nicholson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-309-384
790	garciadwayne	K3zQA5mW(h	Sandra	Mason	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-226-934
791	yhull	LU+&6VBpoN	Adam	Sims	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-878-53
792	woodsthomas	iHKS8Bsu$%	Holly	Murphy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(994)569-9
793	markmoreno	Lr&0FN4z$%	Thomas	Wade	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-229-78
794	fordyvonne	(2PRWaHp1t	Thomas	Jordan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-652-564
795	hcook	f4X&XLku%@	Sean	Reid	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(234)449-6
796	ynielsen	#u0EoLRr*6	Michael	Bowman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	206.376.83
797	collinsphillip	$V$C2XvOZ2	Sarah	Mayer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	805-513-72
798	zford	B9!!cQy&&6	Gary	Jordan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	728-686-03
799	susan20	&$0CtYfgIw	Madeline	Medina	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	521-583-61
800	thomasdyer	!%+5)BWkhg	Mary	Dunlap	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(223)879-4
801	rodriguezjoseph	L#%400JUCp	Nicholas	Tucker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(330)987-2
802	xharvey	!vTh65bt9@	Christina	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	675-413-11
803	nicholasconley	mJ$I7Bta^3	Dustin	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-884-347
804	corey18	$n_Cu&nKj2	Carlos	Stewart	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-735-753
805	jonpreston	+7hWWCHZpe	Glen	Randall	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	833.346.76
806	currymorgan	EXk4P#Av%U	Denise	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-473-84
807	scottramirez	%TC*k8CfA^	Jonathan	Martinez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-762-49
808	kingmichael	SHD#7Lqxw(	Suzanne	Young	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	298-321-26
809	ctravis	$!5LrIa)hK	Danielle	James	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	244.888.25
810	jhale	w)F80HC$!e	Deborah	Graham	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-671-313
811	daniellerowe	dZVIZlcy!0	Michelle	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(901)844-9
812	anthony70	_a1_iUyXEs	Maurice	Gonzalez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-531-723
813	danieljones	4aN$trl%(3	Seth	Thornton	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	485.914.85
814	iwhite	+m3uELFbAZ	Diamond	Spencer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(757)471-4
815	jerryrice	(j6Mi5du9B	Laura	Jennings	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-450-57
816	ejennings	I_2UTLvT(x	Karen	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-752-55
817	boydkristy	@8DwN1qjSw	Mary	Gibson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(696)651-1
818	meghan96	N^8UkfIzSt	Dawn	Gross	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-905-87
819	wwatson	aF@13Tyr$F	David	Welch	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	909-426-22
820	jerome41	^uyiLT_xZ6	Diane	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	601-632-18
821	tmccall	p$78UD!i_l	Morgan	Davenport	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	427.235.76
822	brian68	*6@pSQc%pn	Samuel	Jensen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-312-42
823	brownmichael	_fZHI#bg2o	Daniel	Carpenter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5986434306
824	leslie02	^tCkrLuj)7	Amanda	Barajas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-954-803
825	jaustin	UoXV#leE%4	Katrina	Nelson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-864-32
826	salazarbrandi	S)6yKZCmYF	Rebecca	Green	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-477-234
827	bcherry	!lbBlYls6f	Billy	Mckay	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(544)632-5
828	amyorozco	w&3^XHLxJ*	Jessica	Larson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(338)347-0
829	vhunter	(W3SCyDz0%	Emily	Allen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	5574123584
830	emilymacdonald	%YfM5Buz0@	Barbara	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6664606505
831	teresareed	i1B4XB%d_v	Charles	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	798.461.08
832	ekeith	!4R!8NLn5W	Jennifer	Wiggins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(533)610-5
833	arthur60	m4SBETl)#A	Erin	Wilson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(451)383-2
834	sonia16	eEQh)3AJ&6	Kristin	Harrison	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4067559085
835	cporter	*GTccs3rl8	Christina	Allen	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-440-998
836	agarcia	&s!04Qi$IF	Sean	Higgins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(372)941-3
837	kenneth45	*L7GMt8QCx	Samantha	Villegas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-916-36
838	michaeldesiree	DS%k0)Vr)l	Joshua	Dougherty	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-733-509
839	kelly31	#b4KhR#ND1	Brenda	Stevens	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3892577031
840	william20	In89SoYXs!	Stephanie	Young	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	652.788.71
841	benjaminmorales	x6Dh3W&A_d	Kimberly	Wells	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	967-474-17
842	fcruz	_@D98U$pY(	Samantha	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	229-879-28
843	dsimmons	RM_#9Z(vUl	Randall	Ramirez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	596-252-06
844	bobby36	)@S9xgMnn2	Cameron	Morgan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	668-550-76
845	karisandoval	N+8QOeDvz%	Juan	Barron	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-256-51
846	jonesdiana	2c5DzU44_O	Jason	Wells	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	359-276-14
847	kcraig	#Mo0XHha0*	Kelli	Diaz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-352-46
848	owenaustin	_RklBPpZA6	Sarah	Kim	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	895-981-83
849	ashley27	)u8SgVeENx	Amy	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	678-716-49
850	nmartinez	3hCkehgV$i	Keith	Curtis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(306)595-3
851	goodmiguel	aP0BpD$N(E	Joseph	Bass	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	350.986.94
852	robertjones	3y6QLZZUm*	Levi	Gross	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	750.260.21
853	robertskeith	^0QVnFgb(I	Brian	Meadows	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(909)387-4
854	scottlisa	(F8HoBlr)S	Adam	Patel	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-383-740
855	crawfordbenjamin	Sfgo6Yyd_7	David	Robinson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6893693351
856	timothy58	Ko9ExhCHO!	Jennifer	Thomas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(334)538-8
857	rodneymaldonado	tz6ylFKeF$	Yolanda	Morris	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	772.815.22
858	ablake	GVS+0iUorn	Brandon	Kim	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7579378470
859	gkelley	!HXqbcF*X6	Robert	Kaufman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	935.707.99
860	corey68	E#p6Zy1REh	Melissa	Turner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	643.439.79
861	stewartsteven	E(SEkwih^2	Joseph	Delgado	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	257.267.11
862	lewisjoshua	+aT!7NaiF9	Kelli	Smith	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(456)403-8
863	rebecca94	$1pLB40b(E	Edward	Sanchez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6902924805
864	simsnicholas	U100N$mq*F	David	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	308-609-59
865	lopezhector	O!(71RpgG4	Kelly	Bonilla	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	425-896-95
866	robinsondavid	Ys7E5!!xU*	Brandy	Moore	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	376.406.42
867	rachel10	&5tZlR!kXc	Michelle	Stevenson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-214-40
868	jeanne73	)8_Bc0j%8u	Michael	Powell	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-637-86
869	thomas72	bf*+3ZwgH@	Shawn	Robertson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(302)877-1
870	christopher67	e(8_C_sn_^	Thomas	Martin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-603-337
871	kevin81	#8_xqQZ8Tf	Patrick	Grant	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	4439415406
872	lwolf	$6#ZE2n*Up	Jennifer	Frazier	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	277.771.86
873	nicholashamilton	1SAZtEEc#7	Ryan	Hodges	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-335-89
874	corymorris	_*tBCJTQ9e	Nancy	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	943.524.94
875	tamarasilva	amq3F3ah(*	David	Boyle	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-597-64
876	wallmegan	%vB9BvGCrk	Frank	Gray	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	744-348-27
877	sanfordrandy	*6XdSvgRqB	Jill	Schwartz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(369)372-1
878	nchurch	IjokFzQ3!0	Jamie	Moore	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	878.206.13
879	higginscorey	4tgUCTsI(t	Brandon	Chandler	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-377-86
880	simmonsjoseph	Ro_c1hGq)d	Gary	Fox	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	211-827-48
881	emoore	4NP%sl%g$S	Danny	Little	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	711.975.29
882	fburke	t32*Be$A+a	Douglas	Hill	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-898-68
883	flowersclinton	N!sCd_ShZ9	Sarah	Mccarthy	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	328.599.72
884	alyssa56	@BMKZSz43K	Phillip	Rice	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-645-42
885	gray	%4&Pbp$Jss	Lynn	Chavez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-447-348
886	odavidson	*Et@x0Wo!)	Wayne	Dunn	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	485-396-22
887	alopez	(aFjakNt44	Bryan	Ramos	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	240.675.90
888	sbrown	jcFSCL#M!7	Andrea	Jenkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	986-925-48
889	matthewmcdonald	@u8Z^%Q$13	Thomas	Mayer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	734-749-86
890	ktaylor	vk8UYG&rs$	Janet	Lee	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	860-779-45
891	williamschristopher	G8VFjTr!&l	Joseph	Castillo	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	3332986694
892	mckenziealexis	k3Xujh0x@3	Elijah	Freeman	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	547-351-48
893	andrewcalhoun	x4CqLi#B+E	Darin	Mcbride	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(782)362-9
894	jamesrogers	!)Q5k_Lw&D	Karen	Trevino	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	442-720-22
895	feliciawise	&*fNmI@bT8	Kevin	Hill	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	232.752.70
896	joycegarcia	1mA!$Um2*4	Anthony	Clark	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(316)767-0
897	stephanie25	%SGWJbLbU1	Stephen	Martin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-207-54
898	david93	$NHVIZs#S8	Matthew	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	561-403-41
899	braunamy	B@4qFUawu@	Teresa	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-213-682
900	kennethschroeder	QrQuQT8n_3	Victoria	Roberts	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	318.249.17
901	mark59	Z*0+Z$jWB0	Mary	Castro	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	783.834.34
902	hollandnancy	&4NJTbdc3)	Austin	Porter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	451.759.45
903	cblack	+9KHkfnUo2	Scott	Morris	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	347-404-02
904	rhiggins	_(04_Xam&^	Thomas	Holloway	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-223-697
905	gmaxwell	_(1b6GunXS	Melinda	Henry	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	993-509-25
906	susan89	De9XVyuHv(	Mary	Valenzuela	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	945-968-66
907	coffeydavid	D^V1VyGbuw	Daniel	Barry	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	678-491-55
908	gwilliams	@6rEzyADy)	Monica	Jones	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	638-472-25
909	john68	lS)@sybi(9	Marc	Rowland	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7847797172
910	carolynterrell	4Z03FMUq_5	Joseph	Turner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	966.450.56
911	harry45	*@+eLDhoM4	David	Keller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7529099585
912	millerjason	JPYi59vS#8	Maria	Rowland	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-344-55
913	vtucker	78V%cQUp)$	Sydney	Richards	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(458)968-5
914	pscott	LNS3RuSh_C	Michele	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	656-278-65
915	perezrobert	*wGNTO1fV2	Mary	Pacheco	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	434-679-45
916	marie52	b87J*eP_)*	Luis	Moore	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(531)932-2
917	robert12	XO!7H_JyRx	Susan	Robinson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(653)383-8
918	efitzpatrick	!cGe02gBQ8	Adam	Hendricks	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(770)389-9
919	lisareyes	Jd#Jf3DwzR	Cameron	Allison	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	732-684-15
920	josephdixon	S8WzJ6k5%s	Chad	Harvey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-390-823
921	phuerta	q1+zLpmf_0	Melissa	Williams	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-972-77
922	arielmejia	2iib_3mt)Q	Jennifer	Parks	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-557-904
923	gonzalezterri	)fQE4wByn0	William	Weber	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-416-92
924	barbarawilson	^&i8_PRiYT	John	Garcia	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(574)656-2
925	youngcharles	M_7^DA)m7W	Sarah	Carroll	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-798-829
926	jennifer04	+L%2*BLr7P	Kimberly	Rivas	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	971-464-87
927	reedregina	e#J1EZzhL^	William	Carter	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	613-266-02
928	gdixon	b_B#9YfSkU	George	Bryant	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-769-556
929	shaun07	&i^fWZyD0z	Jennifer	Hutchinson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(453)505-4
930	jameshunter	D39!7LqN_(	William	Casey	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	919-450-38
931	edwardsbryan	%6wS4N6Fkv	Jared	Werner	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-766-58
932	hholden	%2Djt9GbaQ	Eric	Curtis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	521-443-94
933	alicia43	J!Ls9mtEAE	Joshua	West	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-380-95
934	jacob38	%M68Qp6L%*	Paul	Villanueva	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	811-905-88
935	jessica93	N(2wVtdR#v	Kaitlyn	Jarvis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	508-447-23
936	ohudson	$!6ZUB$l4C	Julie	Robinson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-785-98
937	terri78	taOws!fl^0	Chloe	Love	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6217925200
938	mariahill	o^9SCoP4b@	Erin	Rodriguez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	689-702-28
939	andreaherrera	9a2cVlHY&f	Matthew	Holloway	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	622.946.41
940	heather81	*hJMI6wq5a	Martin	Price	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(445)323-6
941	kevin57	7eN53Vm6&H	Jared	Acosta	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-226-463
942	lauren01	WF8^xSZoj#	Janet	Clay	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	777.878.88
943	belindadavid	_2V4b6P0ST	Jacqueline	Bartlett	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	589.877.04
944	bettysolis	(O5AwXRya6	Robert	Miller	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(278)313-8
945	swang	U$$Ji7cj#B	Clayton	Parker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-286-71
946	alyssaperez	5*wyMnrq)b	Kathleen	Krueger	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(363)753-0
947	ysanford	@4^+Mdbx3c	Derek	Henderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	529-302-94
948	nicholaswilkerson	oqSB0pMa(F	Ashley	Higgins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(583)842-5
949	gloria10	GqFuU5$B%7	Lauren	Morales	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	910.218.65
950	amy95	r5vNfy5R*&	Brandon	Davis	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	452.934.15
951	shall	*5Ah1GmdpE	Joseph	Schroeder	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	944-236-81
952	angela91	O0XHh4w1!@	Brett	Matthews	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(976)227-2
953	umills	h#%35G(kLO	Meredith	Simpson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	862-434-91
954	smithmeredith	*JqS12aiZ4	Cody	Matthews	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-944-860
955	angela76	zT25C&fc%l	Maurice	Logan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-689-676
956	kathryn21	O2p2#CeY_5	Brett	Schultz	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-315-77
957	maddoxkenneth	Jj_1qFWg5&	Mary	Carlson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(551)325-8
958	karen07	_2FZTCDqhF	Charles	Schmidt	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-678-83
959	jhaas	_4SEwrJIlP	Tanya	Stephens	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-867-615
960	joshuajohnson	9e*5MLzud$	Sean	King	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-508-25
961	asullivan	V896FAsv&u	Amy	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	917.990.24
962	alexandrayork	_f6Z3rpk!i	Christopher	Mendoza	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-951-43
963	tracy06	%6Rr6hwKtg	Tammy	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	489.871.90
964	sandra43	_bc4oJ^fNS	Stephanie	Collins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-542-37
965	olivia34	V1JHpwtx&z	Regina	Lin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-554-77
966	qandersen	a)HYX6EyU0	Kyle	Gilbert	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	644.237.62
967	fwatkins	25GV^E%p!9	Stephanie	Foster	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-906-90
968	nathaniel04	%6JYwl95TZ	Jason	Townsend	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	447-316-83
969	cmason	o$3E0@qzYd	Theodore	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	913.285.41
970	johnmcdonald	80i_NQCo$v	Jennifer	Knapp	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-853-755
971	fletchermary	*8DE^X7bZc	James	King	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	355-370-28
972	phillip62	YY9NCXjpA)	Nicholas	Donovan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(731)465-0
973	xperkins	(iKSx+19u9	Nicole	Martin	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-442-26
974	riverajulie	P50u4h5m)T	Raymond	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-988-410
975	xflores	#pBOU6Qk((	Erin	Wilcox	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6588970044
976	nichole13	^nRwO0Lm0x	Anne	Maldonado	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-561-30
977	rachelcunningham	0s$m4Rlg%*	Bianca	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-454-79
978	crangel	C40KXylT^x	Erica	Morgan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	7598591220
979	josephbrown	TMXhZ9*kQ&	Robert	Paul	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-209-87
980	brittany53	dT7zOhOq#b	Erin	Price	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-519-25
981	charlesgray	t5uZ$S$r%g	Jose	Taylor	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	962-984-58
982	christopherhill	h00NJIp)*z	Joseph	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	697.775.89
983	tammyhall	#qAIPS2d9N	Jessica	Swanson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-787-375
984	wbaker	^!7E6Kb7wp	Michael	Berger	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(284)751-9
985	vpatton	0C4P*!Gr)I	Breanna	Brown	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	623-346-71
986	tiffany79	+zKBzMXta5	Nancy	Schaefer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	8039746278
987	lyang	c$H8TNCu5!	Cheryl	Collins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	(240)310-1
988	qmoreno	)C2Mi9x3z_	Brian	Evans	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-681-393
989	brittanyanderson	&3KZfrdc#P	Heather	Clay	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-996-30
990	amyrobinson	lI!1YdwZ9c	Duane	White	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-688-59
991	lewisjames	fJUSoZhP@0	Robin	Dyer	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	591-974-44
992	ewhite	S_2d8IUrD@	Lucas	Lopez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-457-66
993	jamesglenn	%3oLi#_Wb0	Edward	Tucker	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-691-856
994	petersfrank	p8qPklU@_*	Duane	Kemp	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	6807004994
995	danielle63	^&o02xAnkK	Amanda	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	832-335-29
996	richard41	!6fG1GjZIw	Brenda	Phillips	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	474.371.83
997	ayalacheryl	6vkiGpYP*5	Thomas	Nolan	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	2175824259
998	cristina68	&Pz3IFc1Zk	Becky	Johnson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	464.521.64
999	kellygreene	f+s8ZZVxEJ	Jim	Jackson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-740-861
1000	theodore58	^5&DbqmZU(	Dana	Castro	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	+1-641-850
1001	edwardsmichael	@+76Q9Jnkq	Richard	Jenkins	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	001-210-25
1002	scottwagner	%3F@f4$pQw	Katrina	Gonzalez	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	562-762-81
1003	pwhitaker	4(4bUKuA#(	Bruce	Anderson	2024-01-11 16:47:18.738517+07	2024-01-11 16:47:18.738517+07	644.965.83
1007	umryeuem	hirotaqua	Nguyen	Tra My	2024-01-12 10:33:32.743041+07	2024-01-12 11:04:57.072914+07	0228282822
\.


--
-- TOC entry 5158 (class 0 OID 30091)
-- Dependencies: 230
-- Data for Name: user_role; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.user_role (user_id, role_id) FROM stdin;
2	1
3	1
4	1
5	1
6	1
7	1
8	1
9	1
10	1
11	1
12	1
13	1
14	1
15	1
16	1
17	1
18	1
19	1
20	1
21	1
22	1
23	1
24	1
25	1
26	1
27	1
28	1
29	1
30	1
31	1
32	1
33	1
34	1
35	1
36	1
37	1
38	1
39	1
40	1
41	1
42	1
43	1
44	1
45	1
46	1
47	1
48	1
49	1
50	1
51	1
52	1
53	1
54	1
55	1
56	1
57	1
58	1
59	1
60	1
61	1
62	1
63	1
64	1
65	1
66	1
67	1
68	1
69	1
70	1
71	1
72	1
73	1
74	1
75	1
76	1
77	1
78	1
79	1
80	1
81	1
82	1
83	1
84	1
85	1
86	1
87	1
88	1
89	1
90	1
91	1
92	1
93	1
94	1
95	1
96	1
97	1
98	1
99	1
100	1
101	1
102	1
103	1
104	1
105	1
106	1
107	1
108	1
109	1
110	1
111	1
112	1
113	1
114	1
115	1
116	1
117	1
118	1
119	1
120	1
121	1
122	1
123	1
124	1
125	1
126	1
127	1
128	1
129	1
130	1
131	1
132	1
133	1
134	1
135	1
136	1
137	1
138	1
139	1
140	1
141	1
142	1
143	1
144	1
145	1
146	1
147	1
148	1
149	1
150	1
151	1
152	1
153	1
154	1
155	1
156	1
157	1
158	1
159	1
160	1
161	1
162	1
163	1
164	1
165	1
166	1
167	1
168	1
169	1
170	1
171	1
172	1
173	1
174	1
175	1
176	1
177	1
178	1
179	1
180	1
181	1
182	1
183	1
184	1
185	1
186	1
187	1
188	1
189	1
190	1
191	1
192	1
193	1
194	1
195	1
196	1
197	1
198	1
199	1
200	1
201	1
202	1
203	1
204	1
205	1
206	1
207	1
208	1
209	1
210	1
211	1
212	1
213	1
214	1
215	1
216	1
217	1
218	1
219	1
220	1
221	1
222	1
223	1
224	1
225	1
226	1
227	1
228	1
229	1
230	1
231	1
232	1
233	1
234	1
235	1
236	1
237	1
238	1
239	1
240	1
241	1
242	1
243	1
244	1
245	1
246	1
247	1
248	1
249	1
250	1
251	1
252	1
253	1
254	1
255	1
256	1
257	1
258	1
259	1
260	1
261	1
262	1
263	1
264	1
265	1
266	1
267	1
268	1
269	1
270	1
271	1
272	1
273	1
274	1
275	1
276	1
277	1
278	1
279	1
280	1
281	1
282	1
283	1
284	1
285	1
286	1
287	1
288	1
289	1
290	1
291	1
292	1
293	1
294	1
295	1
296	1
297	1
298	1
299	1
300	1
301	1
302	1
303	1
304	1
305	1
306	1
307	1
308	1
309	1
310	1
311	1
312	1
313	1
314	1
315	1
316	1
317	1
318	1
319	1
320	1
321	1
322	1
323	1
324	1
325	1
326	1
327	1
328	1
329	1
330	1
331	1
332	1
333	1
334	1
335	1
336	1
337	1
338	1
339	1
340	1
341	1
342	1
343	1
344	1
345	1
346	1
347	1
348	1
349	1
350	1
351	1
352	1
353	1
354	1
355	1
356	1
357	1
358	1
359	1
360	1
361	1
362	1
363	1
364	1
365	1
366	1
367	1
368	1
369	1
370	1
371	1
372	1
373	1
374	1
375	1
376	1
377	1
378	1
379	1
380	1
381	1
382	1
383	1
384	1
385	1
386	1
387	1
388	1
389	1
390	1
391	1
392	1
393	1
394	1
395	1
396	1
397	1
398	1
399	1
400	1
401	1
402	1
403	1
404	1
405	1
406	1
407	1
408	1
409	1
410	1
411	1
412	1
413	1
414	1
415	1
416	1
417	1
418	1
419	1
420	1
421	1
422	1
423	1
424	1
425	1
426	1
427	1
428	1
429	1
430	1
431	1
432	1
433	1
434	1
435	1
436	1
437	1
438	1
439	1
440	1
441	1
442	1
443	1
444	1
445	1
446	1
447	1
448	1
449	1
450	1
451	1
452	1
453	1
454	1
455	1
456	1
457	1
458	1
459	1
460	1
461	1
462	1
463	1
464	1
465	1
466	1
467	1
468	1
469	1
470	1
471	1
472	1
473	1
474	1
475	1
476	1
477	1
478	1
479	1
480	1
481	1
482	1
483	1
484	1
485	1
486	1
487	1
488	1
489	1
490	1
491	1
492	1
493	1
494	1
495	1
496	1
497	1
498	1
499	1
500	1
501	1
502	1
503	1
504	1
505	1
506	1
507	1
508	1
509	1
510	1
511	1
512	1
513	1
514	1
515	1
516	1
517	1
518	1
519	1
520	1
521	1
522	1
523	1
524	1
525	1
526	1
527	1
528	1
529	1
530	1
531	1
532	1
533	1
534	1
535	1
536	1
537	1
538	1
539	1
540	1
541	1
542	1
543	1
544	1
545	1
546	1
547	1
548	1
549	1
550	1
551	1
552	1
553	1
554	1
555	1
556	1
557	1
558	1
559	1
560	1
561	1
562	1
563	1
564	1
565	1
566	1
567	1
568	1
569	1
570	1
571	1
572	1
573	1
574	1
575	1
576	1
577	1
578	1
579	1
580	1
581	1
582	1
583	1
584	1
585	1
586	1
587	1
588	1
589	1
590	1
591	1
592	1
593	1
594	1
595	1
596	1
597	1
598	1
599	1
600	1
601	1
602	1
603	1
604	1
605	1
606	1
607	1
608	1
609	1
610	1
611	1
612	1
613	1
614	1
615	1
616	1
617	1
618	1
619	1
620	1
621	1
622	1
623	1
624	1
625	1
626	1
627	1
628	1
629	1
630	1
631	1
632	1
633	1
634	1
635	1
636	1
637	1
638	1
639	1
640	1
641	1
642	1
643	1
644	1
645	1
646	1
647	1
648	1
649	1
650	1
651	1
652	1
653	1
654	1
655	1
656	1
657	1
658	1
659	1
660	1
661	1
662	1
663	1
664	1
665	1
666	1
667	1
668	1
669	1
670	1
671	1
672	1
673	1
674	1
675	1
676	1
677	1
678	1
679	1
680	1
681	1
682	1
683	1
684	1
685	1
686	1
687	1
688	1
689	1
690	1
691	1
692	1
693	1
694	1
695	1
696	1
697	1
698	1
699	1
700	1
701	1
702	1
703	1
704	1
705	1
706	1
707	1
708	1
709	1
710	1
711	1
712	1
713	1
714	1
715	1
716	1
717	1
718	1
719	1
720	1
721	1
722	1
723	1
724	1
725	1
726	1
727	1
728	1
729	1
730	1
731	1
732	1
733	1
734	1
735	1
736	1
737	1
738	1
739	1
740	1
741	1
742	1
743	1
744	1
745	1
746	1
747	1
748	1
749	1
750	1
751	1
752	1
753	1
754	1
755	1
756	1
757	1
758	1
759	1
760	1
761	1
762	1
763	1
764	1
765	1
766	1
767	1
768	1
769	1
770	1
771	1
772	1
773	1
774	1
775	1
776	1
777	1
778	1
779	1
780	1
781	1
782	1
783	1
784	1
785	1
786	1
787	1
788	1
789	1
790	1
791	1
792	1
793	1
794	1
795	1
796	1
797	1
798	1
799	1
800	1
801	1
802	1
803	1
804	1
805	1
806	1
807	1
808	1
809	1
810	1
811	1
812	1
813	1
814	1
815	1
816	1
817	1
818	1
819	1
820	1
821	1
822	1
823	1
824	1
825	1
826	1
827	1
828	1
829	1
830	1
831	1
832	1
833	1
834	1
835	1
836	1
837	1
838	1
839	1
840	1
841	1
842	1
843	1
844	1
845	1
846	1
847	1
848	1
849	1
850	1
851	1
852	1
853	1
854	1
855	1
856	1
857	1
858	1
859	1
860	1
861	1
862	1
863	1
864	1
865	1
866	1
867	1
868	1
869	1
870	1
871	1
872	1
873	1
874	1
875	1
876	1
877	1
878	1
879	1
880	1
881	1
882	1
883	1
884	1
885	1
886	1
887	1
888	1
889	1
890	1
891	1
892	1
893	1
894	1
895	1
896	1
897	1
898	1
899	1
900	1
901	1
902	1
903	1
904	1
905	1
906	1
907	1
908	1
909	1
910	1
911	1
912	1
913	1
914	1
915	1
916	1
917	1
918	1
919	1
920	1
921	1
922	1
923	1
924	1
925	1
926	1
927	1
928	1
929	1
930	1
931	1
932	1
933	1
934	1
935	1
936	1
937	1
938	1
939	1
940	1
941	1
942	1
943	1
944	1
945	1
946	1
947	1
948	1
949	1
950	1
951	1
952	1
953	1
954	1
955	1
956	1
957	1
958	1
959	1
960	1
961	1
962	1
963	1
964	1
965	1
966	1
967	1
968	1
969	1
970	1
971	1
972	1
973	1
974	1
975	1
976	1
977	1
978	1
979	1
980	1
981	1
982	1
983	1
984	1
985	1
986	1
987	1
988	1
989	1
990	1
991	1
992	1
993	1
994	1
995	1
996	1
997	1
998	1
999	1
1000	1
1001	1
1002	1
1003	1
1007	1
365	2
695	2
375	2
391	2
140	2
234	2
130	2
906	2
100	2
792	2
398	2
52	2
124	2
35	2
540	2
688	2
948	2
775	2
439	2
998	2
137	2
492	2
713	2
759	2
599	2
\.


--
-- TOC entry 5160 (class 0 OID 30095)
-- Dependencies: 232
-- Data for Name: delivery_provider; Type: TABLE DATA; Schema: delivery; Owner: postgres
--

COPY delivery.delivery_provider (delivery_provider_id, name, contact_email, contact_phone, website_url, created_at, modified_at) FROM stdin;
1	Shoppee Express	 shoppeexpress@gmail.com	+84535345345	\N	2024-01-04 22:54:36.19165+07	2024-01-04 22:54:36.19165+07
2	UPS	ups@example.com	+1-800-742-5877	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
3	FedEx	fedex@example.com	+1-800-463-3339	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
4	DHL Express	dhl@example.com	+1-800-225-5345	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
5	USPS	usps@example.com	+1-800-275-8777	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
6	Amazon Logistics	amazonlogistics@example.com	+1-888-280-4331	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
7	Royal Mail	royalmail@example.com	+44 345 774 0740	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
8	Australia Post	auspost@example.com	+61 3 8847 9045	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
9	Canada Post	canadapost@example.com	+1-866-607-6301	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
10	Japan Post	japanpost@example.com	+81 0570-046-111	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
11	China Post	chinapost@example.com	+86 20 11185	\N	2024-01-04 22:55:20.453512+07	2024-01-04 22:55:20.453512+07
12	La Poste (France)	laposte@example.com	+33 3631	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
13	Correos (Spain)	correos@example.com	+34 902 197 197	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
14	India Post	indiapost@example.com	+91 1800 11 2011	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
15	Deutsche Post DHL (Germany)	deutschepost@example.com	+49 228 4333112	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
16	SingPost (Singapore)	singpost@example.com	+65 6841 2000	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
17	Swiss Post	swisspost@example.com	+41 848 888 888	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
18	Poste Italiane (Italy)	posteitaliane@example.com	+39 803 160	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
19	Royal Mail (UK)	royalmail@example.com	+44 345 774 0740	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
20	Russia Post	russiapost@example.com	+7 800 2005-255	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
21	Pos Malaysia	posmalaysia@example.com	+60 1-300-300-300	\N	2024-01-04 22:55:53.071669+07	2024-01-04 22:55:53.071669+07
22	PostNord (Sweden)	postnord@example.com	+46 771 33 33 10	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
23	Korea Post	koreapost@example.com	+82 2-2195-1114	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
24	Pos Indonesia	posindonesia@example.com	+62 21 161	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
25	Mexico Post	mexicopost@example.com	+52 55 5340 3300	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
26	Pos Thailand	posthailand@example.com	+66 2356 1111	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
27	Saudi Post	saudipost@example.com	+966 9200 05700	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
28	Aramex (UAE)	aramex@example.com	+971 600 544000	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
29	Brazil Post	brazilpost@example.com	+55 3003 0100	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
30	New Zealand Post	nzpost@example.com	+64 9-367 9710	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
31	Turkey Post	turkeypost@example.com	+90 444 1 888	\N	2024-01-04 22:56:30.77272+07	2024-01-04 22:56:30.77272+07
32	Swiss Post (Switzerland)	swisspost@example.com	+41 848 888 888	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
33	Japan Post	japanpost@example.com	+81 0570-046-111	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
34	Hongkong Post	hongkongpost@example.com	+852 2921 2222	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
35	PostNL (Netherlands)	postnl@example.com	+31 88 22 55 555	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
36	Australia Post	auspost@example.com	+61 3 8847 9045	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
37	Canada Post	canadapost@example.com	+1-866-607-6301	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
38	China Post	chinapost@example.com	+86 20 11185	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
39	SingPost (Singapore)	singpost@example.com	+65 6841 2000	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
40	Pos Malaysia	posmalaysia@example.com	+60 1-300-300-300	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
41	Deutsche Post DHL (Germany)	deutschepost@example.com	+49 228 4333112	\N	2024-01-04 22:56:50.474211+07	2024-01-04 22:56:50.474211+07
42	La Poste (France)	laposte@example.com	+33 3631	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
43	Correos (Spain)	correos@example.com	+34 902 197 197	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
44	India Post	indiapost@example.com	+91 1800 11 2011	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
45	Poste Italiane (Italy)	posteitaliane@example.com	+39 803 160	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
46	Royal Mail (UK)	royalmail@example.com	+44 345 774 0740	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
47	PostNord (Sweden)	postnord@example.com	+46 771 33 33 10	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
48	Pos Indonesia	posindonesia@example.com	+62 21 161	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
49	Saudi Post	saudipost@example.com	+966 9200 05700	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
50	Brazil Post	brazilpost@example.com	+55 3003 0100	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
51	Pos Malaysia	posmalaysia@example.com	+60 1-300-300-300	\N	2024-01-04 22:57:10.792464+07	2024-01-04 22:57:10.792464+07
52	Korea Post	koreapost@example.com	+82 2-2195-1114	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
53	Pos Indonesia	posindonesia@example.com	+62 21 161	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
54	Mexico Post	mexicopost@example.com	+52 55 5340 3300	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
55	Pos Thailand	posthailand@example.com	+66 2356 1111	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
56	Saudi Post	saudipost@example.com	+966 9200 05700	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
57	Aramex (UAE)	aramex@example.com	+971 600 544000	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
58	Brazil Post	brazilpost@example.com	+55 3003 0100	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
59	New Zealand Post	nzpost@example.com	+64 9-367 9710	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
60	Turkey Post	turkeypost@example.com	+90 444 1 888	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
61	Swiss Post (Switzerland)	swisspost@example.com	+41 848 888 888	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
62	Japan Post	japanpost@example.com	+81 0570-046-111	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
63	Hongkong Post	hongkongpost@example.com	+852 2921 2222	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
64	PostNL (Netherlands)	postnl@example.com	+31 88 22 55 555	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
65	Australia Post	auspost@example.com	+61 3 8847 9045	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
66	Canada Post	canadapost@example.com	+1-866-607-6301	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
67	China Post	chinapost@example.com	+86 20 11185	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
68	SingPost (Singapore)	singpost@example.com	+65 6841 2000	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
69	Pos Malaysia	posmalaysia@example.com	+60 1-300-300-300	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
70	Deutsche Post DHL (Germany)	deutschepost@example.com	+49 228 4333112	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
71	UPS	ups@example.com	+1-800-742-5877	\N	2024-01-04 22:57:36.972252+07	2024-01-04 22:57:36.972252+07
72	FedEx	fedex@example.com	+1-800-463-3339	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
73	DHL Express	dhl@example.com	+1-800-225-5345	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
74	USPS	usps@example.com	+1-800-275-8777	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
75	Amazon Logistics	amazonlogistics@example.com	+1-888-280-4331	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
76	Royal Mail	royalmail@example.com	+44 345 774 0740	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
77	Australia Post	auspost@example.com	+61 3 8847 9045	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
78	Canada Post	canadapost@example.com	+1-866-607-6301	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
79	China Post	chinapost@example.com	+86 20 11185	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
80	SingPost (Singapore)	singpost@example.com	+65 6841 2000	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
81	Pos Malaysia	posmalaysia@example.com	+60 1-300-300-300	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
82	La Poste (France)	laposte@example.com	+33 3631	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
83	Correos (Spain)	correos@example.com	+34 902 197 197	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
84	India Post	indiapost@example.com	+91 1800 11 2011	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
85	Deutsche Post DHL (Germany)	deutschepost@example.com	+49 228 4333112	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
86	Poste Italiane (Italy)	posteitaliane@example.com	+39 803 160	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
87	Royal Mail (UK)	royalmail@example.com	+44 345 774 0740	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
88	PostNord (Sweden)	postnord@example.com	+46 771 33 33 10	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
89	Pos Indonesia	posindonesia@example.com	+62 21 161	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
90	Saudi Post	saudipost@example.com	+966 9200 05700	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
91	Brazil Post	brazilpost@example.com	+55 3003 0100	\N	2024-01-04 22:58:07.781677+07	2024-01-04 22:58:07.781677+07
92	Poste Maroc	postemaroc@example.com	+212 5 37 71 20 05	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
93	An Post (Ireland)	anpost@example.com	+353 1 705 7600	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
94	PosTürkiye	posturkiye@example.com	+90 444 1 888	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
95	Pos Laju (Malaysia)	poslaju@example.com	+60 1-300-300-300	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
96	Post Danmark (Denmark)	postdanmark@example.com	+45 70 70 70 30	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
97	Österreichische Post (Austria)	austrianpost@example.com	+43 577 67 67	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
98	Eesti Post (Estonia)	eestipost@example.com	+372 661 6616	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
99	India Post	indiapost@example.com	+91 1800 11 2011	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
100	Posta Română (Romania)	postaromana@example.com	+40 021 9393	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
101	Israel Post	israelpost@example.com	+972 2-629-0691	\N	2024-01-04 22:58:38.533135+07	2024-01-04 22:58:38.533135+07
\.


--
-- TOC entry 5162 (class 0 OID 30101)
-- Dependencies: 234
-- Data for Name: category; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.category (category_id, name, description, is_active, created_at, modified_at, parent_id) FROM stdin;
2	Apparel	Explore a wide range of clothing, accessories, and footwear for both men and women.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
3	Electronics	Discover the latest in technology with smartphones, laptops, audio devices, and gadgets.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
4	Health and Wellness	Prioritize your well-being with vitamins, personal care products, and fitness equipment.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
5	Home and Decor	Transform your living space with furniture, decorative accessories, and lighting options.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
6	Luxury Items	Indulge in luxury with premium watches, designer clothing, and high-end accessories.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
7	Outdoor and Sports	Stay active with athletic apparel, sports footwear, and fitness accessories.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
8	Tech and Gadgets	Embrace innovation with electronic gadgets, smart home devices, and tech accessories.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
9	Timepieces	Keep track of time in style with luxury, classic, and modern watches.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
10	Toys and Collectibles	Bring joy to your collection with anime figures, collectible statues, and plush toys.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
11	Kitchen and Cookware	Enhance your culinary skills with cookware sets, utensils, and coffee essentials.	t	2024-01-11 21:04:57.502137+07	2024-01-11 21:04:57.502137+07	\N
12	Men's Clothing	Discover the latest trends in men's fashion.	t	2024-01-11 21:10:59.849882+07	2024-01-11 21:10:59.849882+07	2
13	Women's Clothing	Elevate your style with our collection of women's fashion.	t	2024-01-11 21:10:59.849882+07	2024-01-11 21:10:59.849882+07	2
14	Men's Shoes	Step out in style with our collection of men's footwear.	t	2024-01-11 21:10:59.849882+07	2024-01-11 21:10:59.849882+07	2
15	Women's Shoes	Find the perfect pair of women's shoes for any occasion.	t	2024-01-11 21:10:59.849882+07	2024-01-11 21:10:59.849882+07	2
16	Smartphones	Stay connected with the latest smartphones and accessories.	t	2024-01-11 21:13:14.257541+07	2024-01-11 21:13:14.257541+07	3
17	Laptops and Computers	Explore powerful computing devices for work and entertainment.	t	2024-01-11 21:13:14.257541+07	2024-01-11 21:13:14.257541+07	3
18	Audio and Headphones	Immerse yourself in high-quality audio with headphones and audio devices.	t	2024-01-11 21:13:14.257541+07	2024-01-11 21:13:14.257541+07	3
19	Gadgets and Accessories	Discover innovative gadgets and accessories to enhance your tech experience.	t	2024-01-11 21:13:14.257541+07	2024-01-11 21:13:14.257541+07	3
21	Sports Footwear	Step into the right footwear for various sports and activities.	t	2024-01-11 21:15:00.450954+07	2024-01-11 21:15:00.450954+07	7
22	Fitness Accessories	Enhance your workouts with a variety of fitness accessories.	t	2024-01-11 21:15:00.450954+07	2024-01-11 21:15:00.450954+07	7
23	Sports Equipment	Equip yourself with high-quality sports equipment for your favorite activities.	t	2024-01-11 21:15:00.450954+07	2024-01-11 21:15:00.450954+07	7
24	Luxury Watches	Indulge in exquisite timepieces that redefine elegance.	t	2024-01-11 21:22:03.726425+07	2024-01-11 21:22:03.726425+07	6
25	Designer Clothing	Discover high-end fashion with clothing from renowned designers.	t	2024-01-11 21:22:03.726425+07	2024-01-11 21:22:03.726425+07	6
26	High-end Accessories	Elevate your style with luxurious accessories.	t	2024-01-11 21:22:03.726425+07	2024-01-11 21:22:03.726425+07	6
27	Premium Handbags	Find the perfect handbag crafted with precision and style.	t	2024-01-11 21:22:03.726425+07	2024-01-11 21:22:03.726425+07	6
20	Healthcare	Find performance-driven athletic wear for your active lifestyle.	t	2024-01-11 21:15:00.450954+07	2024-01-12 00:08:53.5345+07	7
\.


--
-- TOC entry 5165 (class 0 OID 30111)
-- Dependencies: 237
-- Data for Name: discount; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.discount (discount_id, name, description, discount_percent, start_date, end_date, is_active, created_at, modified_at, store_id, active) FROM stdin;
\.


--
-- TOC entry 5167 (class 0 OID 30120)
-- Dependencies: 239
-- Data for Name: inventory; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.inventory (inventory_id, product_id, quantity, minimum_stock, status, created_at, modified_at) FROM stdin;
3	3	50	10	t	2024-01-11 22:02:32.026788+07	2024-01-11 22:02:32.026788+07
5	5	50	10	t	2024-01-11 22:02:32.026788+07	2024-01-11 22:02:32.026788+07
6	6	50	10	t	2024-01-11 22:06:20.983669+07	2024-01-11 22:06:20.983669+07
7	7	50	10	t	2024-01-11 22:06:20.983669+07	2024-01-11 22:06:20.983669+07
8	8	50	10	t	2024-01-11 22:06:20.983669+07	2024-01-11 22:06:20.983669+07
9	9	50	10	t	2024-01-11 22:06:20.983669+07	2024-01-11 22:06:20.983669+07
10	10	50	10	t	2024-01-11 22:15:33.949268+07	2024-01-11 22:15:33.949268+07
11	11	50	10	t	2024-01-11 22:15:33.949268+07	2024-01-11 22:15:33.949268+07
12	12	50	10	t	2024-01-11 22:15:33.949268+07	2024-01-11 22:15:33.949268+07
13	13	50	10	t	2024-01-11 22:15:33.949268+07	2024-01-11 22:15:33.949268+07
14	14	50	10	t	2024-01-11 22:20:48.195094+07	2024-01-11 22:20:48.195094+07
15	15	50	10	t	2024-01-11 22:20:48.195094+07	2024-01-11 22:20:48.195094+07
16	16	50	10	t	2024-01-11 22:20:48.195094+07	2024-01-11 22:20:48.195094+07
17	17	50	10	t	2024-01-11 22:20:48.195094+07	2024-01-11 22:20:48.195094+07
18	18	50	10	t	2024-01-11 22:25:06.583065+07	2024-01-11 22:25:06.583065+07
19	19	50	10	t	2024-01-11 22:25:06.583065+07	2024-01-11 22:25:06.583065+07
20	20	50	10	t	2024-01-11 22:25:06.583065+07	2024-01-11 22:25:06.583065+07
21	21	50	10	t	2024-01-11 22:25:06.583065+07	2024-01-11 22:25:06.583065+07
22	22	50	10	t	2024-01-11 22:39:59.092997+07	2024-01-11 22:39:59.092997+07
23	23	50	10	t	2024-01-11 22:39:59.092997+07	2024-01-11 22:39:59.092997+07
24	24	50	10	t	2024-01-11 22:39:59.092997+07	2024-01-11 22:39:59.092997+07
25	25	50	10	t	2024-01-11 22:39:59.092997+07	2024-01-11 22:39:59.092997+07
26	26	50	10	t	2024-01-11 23:05:31.46191+07	2024-01-11 23:05:31.46191+07
27	27	50	10	t	2024-01-11 23:05:31.46191+07	2024-01-11 23:05:31.46191+07
28	28	50	10	t	2024-01-11 23:05:31.46191+07	2024-01-11 23:05:31.46191+07
29	29	50	10	t	2024-01-11 23:05:31.46191+07	2024-01-11 23:05:31.46191+07
30	30	50	10	t	2024-01-11 23:11:51.757892+07	2024-01-11 23:11:51.757892+07
31	31	50	10	t	2024-01-11 23:11:51.757892+07	2024-01-11 23:11:51.757892+07
32	32	50	10	t	2024-01-11 23:11:51.757892+07	2024-01-11 23:11:51.757892+07
33	34	50	10	t	2024-01-11 23:16:33.113553+07	2024-01-11 23:16:33.113553+07
34	35	50	10	t	2024-01-11 23:16:33.113553+07	2024-01-11 23:16:33.113553+07
35	36	50	10	t	2024-01-11 23:31:25.668482+07	2024-01-11 23:31:25.668482+07
36	37	50	10	t	2024-01-11 23:31:25.668482+07	2024-01-11 23:31:25.668482+07
37	38	50	10	t	2024-01-11 23:42:14.791481+07	2024-01-11 23:42:14.791481+07
38	39	50	10	t	2024-01-11 23:42:14.791481+07	2024-01-11 23:42:14.791481+07
39	40	50	10	t	2024-01-11 23:45:49.976991+07	2024-01-11 23:45:49.976991+07
40	41	50	10	t	2024-01-11 23:45:49.976991+07	2024-01-11 23:45:49.976991+07
41	42	50	10	t	2024-01-11 23:47:11.001951+07	2024-01-11 23:47:11.001951+07
42	43	50	10	t	2024-01-11 23:47:11.001951+07	2024-01-11 23:47:11.001951+07
43	44	50	10	t	2024-01-11 23:53:42.699604+07	2024-01-11 23:53:42.699604+07
44	45	50	10	t	2024-01-11 23:53:42.699604+07	2024-01-11 23:53:42.699604+07
45	46	50	10	t	2024-01-11 23:53:42.699604+07	2024-01-11 23:53:42.699604+07
46	47	50	10	t	2024-01-11 23:53:42.699604+07	2024-01-11 23:53:42.699604+07
47	48	50	10	t	2024-01-11 23:53:42.699604+07	2024-01-11 23:53:42.699604+07
48	49	50	10	t	2024-01-11 23:53:42.699604+07	2024-01-11 23:53:42.699604+07
49	50	50	10	t	2024-01-12 00:11:54.794403+07	2024-01-12 00:11:54.794403+07
50	51	50	10	t	2024-01-12 00:11:54.794403+07	2024-01-12 00:11:54.794403+07
51	52	50	10	t	2024-01-12 00:11:54.794403+07	2024-01-12 00:11:54.794403+07
52	53	50	10	t	2024-01-12 00:11:54.794403+07	2024-01-12 00:11:54.794403+07
53	54	50	10	t	2024-01-12 00:11:54.794403+07	2024-01-12 00:11:54.794403+07
54	55	50	10	t	2024-01-12 00:11:54.794403+07	2024-01-12 00:11:54.794403+07
55	56	50	10	t	2024-01-12 00:29:48.122025+07	2024-01-12 00:29:48.122025+07
56	57	50	10	t	2024-01-12 00:29:48.122025+07	2024-01-12 00:29:48.122025+07
57	58	50	10	t	2024-01-12 00:29:48.122025+07	2024-01-12 00:29:48.122025+07
58	59	50	10	t	2024-01-12 00:29:48.122025+07	2024-01-12 00:29:48.122025+07
59	60	50	10	t	2024-01-12 00:30:07.142309+07	2024-01-12 00:30:07.142309+07
60	61	50	10	t	2024-01-12 00:30:07.142309+07	2024-01-12 00:30:07.142309+07
61	62	50	10	t	2024-01-12 00:30:07.142309+07	2024-01-12 00:30:07.142309+07
62	63	50	10	t	2024-01-12 00:30:07.142309+07	2024-01-12 00:30:07.142309+07
63	64	50	10	t	2024-01-12 00:42:13.039261+07	2024-01-12 00:42:13.039261+07
64	65	50	10	t	2024-01-12 00:42:13.039261+07	2024-01-12 00:42:13.039261+07
65	66	50	10	t	2024-01-12 00:42:13.039261+07	2024-01-12 00:42:13.039261+07
66	67	50	10	t	2024-01-12 00:42:29.439807+07	2024-01-12 00:42:29.439807+07
67	68	50	10	t	2024-01-12 00:42:29.439807+07	2024-01-12 00:42:29.439807+07
68	69	50	10	t	2024-01-12 00:42:29.439807+07	2024-01-12 00:42:29.439807+07
69	70	50	10	t	2024-01-12 00:43:37.272241+07	2024-01-12 00:43:37.272241+07
70	71	50	10	t	2024-01-12 00:43:37.272241+07	2024-01-12 00:43:37.272241+07
71	72	50	10	t	2024-01-12 00:43:37.272241+07	2024-01-12 00:43:37.272241+07
72	73	50	10	t	2024-01-12 00:43:56.811991+07	2024-01-12 00:43:56.811991+07
73	74	50	10	t	2024-01-12 00:43:56.811991+07	2024-01-12 00:43:56.811991+07
74	75	50	10	t	2024-01-12 00:43:56.811991+07	2024-01-12 00:43:56.811991+07
75	76	50	10	t	2024-01-12 01:01:07.406776+07	2024-01-12 01:01:07.406776+07
77	78	50	10	t	2024-01-12 01:01:07.406776+07	2024-01-12 01:01:07.406776+07
79	80	50	10	t	2024-01-12 01:01:26.441705+07	2024-01-12 01:01:26.441705+07
80	81	50	10	t	2024-01-12 01:01:26.441705+07	2024-01-12 01:01:26.441705+07
2	2	49	10	t	2024-01-11 22:02:32.026788+07	2024-01-12 11:32:45.822832+07
78	79	47	10	t	2024-01-12 01:01:26.441705+07	2024-01-12 12:15:31.858117+07
76	77	43	10	t	2024-01-12 01:01:07.406776+07	2024-01-12 12:19:02.386011+07
4	4	48	10	t	2024-01-11 22:02:32.026788+07	2024-01-12 12:20:34.518831+07
\.


--
-- TOC entry 5170 (class 0 OID 30129)
-- Dependencies: 242
-- Data for Name: product; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.product (product_id, name, image, description, sku, category_id, price, discount_id, store_id, is_active, created_at, modified_at) FROM stdin;
76	Blender	https://www.ariete.net/media/images/product/main/ariete-power-blender-frullatore-283c7d9fb871111cfda50b38d8908629.jpg	Experience convenience with our Blender. Perfect for all your blending needs.	BL-001	11	49.99	\N	62	t	2024-01-12 01:01:07.406776+07	2024-01-12 01:05:57.19985+07
77	Toaster	https://www.krupsusa.com/medias/?context=bWFzdGVyfGltYWdlc3wyNTY2NTF8aW1hZ2UvanBlZ3xpbWFnZXMvaDJhL2hmNC8xNDIzMjAwMTI4MjA3OC5qcGd8MTIxOTJlZTg3ZTFjZjg3YThhYzQ1MmQzYThkMmMxY2M2ZTkyNDU5NTA2MTliNTk2OWQzOTVlMWE2MjNlNmNlZA	Our Toaster offers a classic look with a modern design. It is perfect for everyday use.	TO-001	11	29.99	\N	62	t	2024-01-12 01:01:07.406776+07	2024-01-12 01:05:57.19985+07
78	Coffee Maker	https://cdn-amz.woka.io/images/I/71uLuTiXQlL.jpg	Stay refreshed with our Coffee Maker. It is designed for comfort and durability.	CM-001	11	39.99	\N	62	t	2024-01-12 01:01:07.406776+07	2024-01-12 01:05:57.19985+07
79	Microwave Oven	https://www.abenson.com/media/catalog/product/1/7/177657_2022.jpg	Experience convenience with our Microwave Oven. Perfect for all your cooking needs.	MO-001	11	99.99	\N	63	t	2024-01-12 01:01:26.441705+07	2024-01-12 01:05:57.19985+07
80	Dishwasher	https://media3.bosch-home.com/Images/400x225/MCIM01798536_DW_FSD_Carousel_60_526x310.jpg	Our Dishwasher offers a classic look with a modern design. It is perfect for everyday use.	DW-001	11	499.99	\N	63	t	2024-01-12 01:01:26.441705+07	2024-01-12 01:05:57.19985+07
81	Refrigerator	https://images.samsung.com/is/image/samsung/p6pim/ph/feature/163993107/ph-feature-ref-rs5000-familyhub-535438411?$FB_TYPE_C_JPG$	Stay refreshed with our Refrigerator. It is designed for comfort and durability.	RF-001	11	599.99	\N	63	t	2024-01-12 01:01:26.441705+07	2024-01-12 01:05:57.19985+07
2	Samsung Galaxy S23+	https://mobileworld.com.vn/uploads/product/02_2023/DSC04144_processed.jpg	Upgrade to the Samsung Galaxy S23+ for a larger display and enhanced features. Experience outstanding performance and style.	SSG21P-001	16	1199.99	\N	2	t	2024-01-11 22:02:32.026788+07	2024-01-12 01:06:48.071933+07
3	Samsung Galaxy S23 Ultra	https://cdn.viettelstore.vn/Images/Product/ProductImage/642246378.jpeg	Unleash the ultimate power with the Samsung Galaxy S23 Ultra. Its advanced camera system, stunning display, and exceptional performance redefine what a smartphone can do.	SSG21U-001	16	1399.99	\N	2	t	2024-01-11 22:02:32.026788+07	2024-01-12 01:06:48.071933+07
4	Samsung Galaxy S20 FE	https://cdn.tgdd.vn/Products/Images/42/224859/samsung-galaxy-s20-fan-edition-xanh-la-thumbnew-600x600.jpeg	Get the best of Samsung features at an affordable price with the Galaxy S20 FE. Experience flagship performance and innovation without the premium cost.	SSG20FE-001	16	699.99	\N	2	t	2024-01-11 22:02:32.026788+07	2024-01-12 01:06:48.071933+07
5	Samsung Galaxy Note20 Ultra	https://cdn2.cellphones.com.vn/insecure/rs:fill:0:358/q:80/plain/https://cellphones.com.vn/media/catalog/product/s/m/sm-n985_986_galaxynote20ultra_front_pen_mysticwhite_200529.jpg	Elevate your productivity and creativity with the Samsung Galaxy Note20 Ultra. Its powerful performance, intelligent S Pen, and stunning display redefine work and play.	SSN20U-001	16	1299.99	\N	2	t	2024-01-11 22:02:32.026788+07	2024-01-12 01:06:48.071933+07
10	HP Pavilion	https://www.bhphotovideo.com/images/images2500x2500/hp_5yh29ua_aba_pavilion_laptop_15_cs2010nr_core_1473122.jpg	Experience reliable performance and outstanding value with the HP Pavilion. It is perfect for work, play, and everything in between.	HPP-001	17	599.99	\N	8	t	2024-01-11 22:15:33.949268+07	2024-01-12 01:07:15.519866+07
11	HP Envy	https://th.bing.com/th/id/OIP.oDK8uL5pewQYzZWhkBoenAHaGE?rs=1&pid=ImgDetMain	Elevate your productivity with the HP Envy. Its sleek design, powerful performance, and enhanced features make it a top choice for professionals.	HPE-001	17	899.99	\N	8	t	2024-01-11 22:15:33.949268+07	2024-01-12 01:07:15.519866+07
12	HP Spectre	https://th.bing.com/th/id/R.79723aa31835a4c663a760ada825e052?rik=dIxqm%2fSf%2boWCHQ&pid=ImgRaw&r=0	Experience the pinnacle of innovation with the HP Spectre. Its stunning design, exceptional performance, and advanced features redefine what a laptop can do.	HPS-001	17	1199.99	\N	8	t	2024-01-11 22:15:33.949268+07	2024-01-12 01:07:15.519866+07
13	HP Omen	https://www.bhphotovideo.com/images/images2500x2500/hp_j9k19ua_aba_ci7_4710hq_t_omen_8gb_256gb_ssd_15_6_1094586.jpg	Unleash your gaming potential with the HP Omen. Its powerful performance, high-refresh-rate display, and advanced gaming features take your gaming experience to the next level.	HPO-001	17	1299.99	\N	8	t	2024-01-11 22:15:33.949268+07	2024-01-12 01:07:15.519866+07
14	Dell Inspiron	https://th.bing.com/th/id/OIP.hfRQ9IRJDZRGj6lfs18ShwHaGk?rs=1&pid=ImgDetMain	Experience reliable performance and outstanding value with the Dell Inspiron. It is perfect for work, play, and everything in between.	DEI-001	17	499.99	\N	7	t	2024-01-11 22:20:48.195094+07	2024-01-12 01:07:15.519866+07
15	Dell XPS	https://th.bing.com/th/id/OIP.ADjoUOy8GMryL7mgRCfvnwHaE3?rs=1&pid=ImgDetMain	Elevate your productivity with the Dell XPS. Its sleek design, powerful performance, and enhanced features make it a top choice for professionals.	DEX-001	17	999.99	\N	7	t	2024-01-11 22:20:48.195094+07	2024-01-12 01:07:15.519866+07
16	Dell Alienware	https://th.bing.com/th/id/OIP.TZ0GbIN0ttZYT6yiEKiZbgHaHa?rs=1&pid=ImgDetMain	Unleash your gaming potential with the Dell Alienware. Its powerful performance, high-refresh-rate display, and advanced gaming features take your gaming experience to the next level.	DEA-001	17	1499.99	\N	7	t	2024-01-11 22:20:48.195094+07	2024-01-12 01:07:15.519866+07
17	Dell G Series	https://www.notebookcheck.net/fileadmin/Notebooks/News/_nc3/g1555.jpg	Get the best of Dell gaming features at an affordable price with the Dell G Series. Experience flagship performance and innovation without the premium cost.	DEG-001	17	799.99	\N	7	t	2024-01-11 22:20:48.195094+07	2024-01-12 01:07:15.519866+07
18	Lenovo IdeaPad	https://th.bing.com/th/id/OIP.UFoh8ypOb5pyW0LJQPstXwHaFj?rs=1&pid=ImgDetMain	Experience reliable performance and outstanding value with the Lenovo IdeaPad. It is perfect for work, play, and everything in between.	LEI-001	17	499.99	\N	6	t	2024-01-11 22:25:06.583065+07	2024-01-12 01:07:15.519866+07
19	Lenovo ThinkPad	https://th.bing.com/th/id/R.5a5667ce3801eeed4e575cf0ba613634?rik=skBdi5HSPBwtXw&pid=ImgRaw&r=0	Elevate your productivity with the Lenovo ThinkPad. Its sleek design, powerful performance, and enhanced features make it a top choice for professionals.	LET-001	17	899.99	\N	6	t	2024-01-11 22:25:06.583065+07	2024-01-12 01:07:15.519866+07
20	Lenovo Legion	https://th.bing.com/th/id/OIP.5uD3bWRcnltH5u2rwymOBgHaF7?rs=1&pid=ImgDetMain	Unleash your gaming potential with the Lenovo Legion. Its powerful performance, high-refresh-rate display, and advanced gaming features take your gaming experience to the next level.	LEL-001	17	1199.99	\N	6	t	2024-01-11 22:25:06.583065+07	2024-01-12 01:07:15.519866+07
21	Lenovo Yoga	https://farm4.staticflickr.com/3952/15713610281_eb3a89ee66_o.jpg	Experience the flexibility of the Lenovo Yoga. Its 2-in-1 design, vibrant display, and long battery life make it a great choice for those on the go.	LEY-001	17	799.99	\N	6	t	2024-01-11 22:25:06.583065+07	2024-01-12 01:07:15.519866+07
48	Demon Slayer Mug	https://www.wtt.biz/Files/108580/Img/07/621MAN007x1200.jpg	Experience the world of Demon Slayer with our Demon Slayer Mug. Perfect for all Otaku.	DSM-001	10	14.99	\N	30	t	2024-01-11 23:53:42.699604+07	2024-01-12 01:19:43.084488+07
49	Jujutsu Kaisen Keychain	https://th.bing.com/th/id/OIP.ipW2rM5IxMX-1ITZ_inw5QHaHa?rs=1&pid=ImgDetMain	Our Jujutsu Kaisen Keychain offers a classic look with a modern design. It is perfect for everyday use.	JJK-001	10	4.99	\N	30	t	2024-01-11 23:53:42.699604+07	2024-01-12 01:19:43.084488+07
40	Adidas Men's Shoes	https://th.bing.com/th/id/R.aadcd05efc669beb969ba7050957c4fa?rik=lyGl7Gwg%2fYLtrQ&riu=http%3a%2f%2fwww.tennisnuts.com%2fimages%2fproduct%2ffull%2fD66785_F_beauty_B2C.jpg&ehk=Rbgr0rIL4KFtLsoQ0QeCY1bTROC%2f6%2fn1FC0s8SjagOs%3d&risl=&pid=ImgRaw&r=0	Experience comfort and style with our Adidas Men's Shoes. Perfect for all occasions.	AMS-001	14	89.99	\N	19	t	2024-01-11 23:45:49.976991+07	2024-01-12 01:10:28.410629+07
43	Puma Men's Shoes	https://th.bing.com/th/id/OIP.1FP6I_tOOc8oc2Bh6GmfDgHaHa?rs=1&pid=ImgDetMain	Our Puma Men's Shoes offer a classic look with a modern design. They are perfect for everyday use.	PMS-001	14	89.99	\N	20	t	2024-01-11 23:47:11.001951+07	2024-01-12 01:10:28.410629+07
42	Adidas Women's Shoes	https://th.bing.com/th/id/R.680b934ebffe452998776e115e1149e9?rik=R3YrDeIb39akMg&riu=http%3a%2f%2fwww.tennisnuts.com%2fimages%2fproduct%2ffull%2fD66239_F_beauty_B2C.jpg&ehk=jUOlzk0xgXQy%2fysar7iiXZb9T2VL5%2bNoeXVfbiurwoI%3d&risl=&pid=ImgRaw&r=0	Experience comfort and style with our Adidas Women's Shoes. Perfect for all occasions.	AWS-001	15	79.99	\N	19	t	2024-01-11 23:47:11.001951+07	2024-01-12 01:17:03.32295+07
44	Naruto Action Figure	https://th.bing.com/th/id/R.a352a89c1a20246d286b548b2bafe93b?rik=2PJjRYXeM1BZDQ&pid=ImgRaw&r=0	Experience the world of Naruto with our Naruto Action Figure. Perfect for all Otaku.	OAF-001	10	29.99	\N	29	t	2024-01-11 23:53:42.699604+07	2024-01-12 01:19:43.084488+07
60	Converse Chuck Taylor All-Star	https://product.hstatic.net/200000265619/product/121186-1_d83cf53a24ef440ea44f5c28778298a0.jpg	Experience comfort and style with our Converse Chuck Taylor All-Star. Perfect for all occasions.	CTAS-001	21	49.99	\N	53	t	2024-01-12 00:30:07.142309+07	2024-01-12 01:22:15.526148+07
71	IWC Schaffhausen Portugieser	https://24kara.com/files/sanpham/19932/1/jpg/dong-ho-iwc-portugieser-chronograph-classic-iw390302.jpg	Our IWC Schaffhausen Portugieser offers a classic look with a modern design. It is perfect for everyday use.	ISP-001	24	6999.99	\N	55	t	2024-01-12 00:43:37.272241+07	2024-01-12 01:23:20.326866+07
72	Panerai Luminor	https://cdn.luxshopping.vn/Thumnails/Uploads/News/panerai-luminor-marina-1950-3-days-pam00392-42mm.png.webp	Stay stylish with our Panerai Luminor. It is designed for comfort and durability.	PL-001	24	5999.99	\N	55	t	2024-01-12 00:43:37.272241+07	2024-01-12 01:23:20.326866+07
73	Cartier Tank	https://cdn.luxshopping.vn/Thumnails/Uploads/News/cartier-w5200027-tank-solo-xl-automatic-watch-31-x-41-mm.jpg.webp	Experience elegance and precision with our Cartier Tank. Perfect for all occasions.	CT-001	24	2999.99	\N	56	t	2024-01-12 00:43:56.811991+07	2024-01-12 01:23:20.326866+07
74	Breguet Classique	https://product.hstatic.net/200000254009/product/68201-1_4b95118d801842afab5122a839591585_master.jpg	Our Breguet Classique offers a classic look with a modern design. It is perfect for everyday use.	BC-001	24	8999.99	\N	56	t	2024-01-12 00:43:56.811991+07	2024-01-12 01:23:20.326866+07
6	iPhone 13	https://www.cdrokc.com/wp-content/uploads/2022/06/Iphone-13.jpg	Experience the next level of innovation with the iPhone 13. Enjoy a vibrant display, capture stunning photos, and stay connected with advanced features.	IP13-001	16	799.99	\N	3	t	2024-01-11 22:06:20.983669+07	2024-01-12 01:06:48.071933+07
7	iPhone 13 Pro	https://cdn.shopify.com/s/files/1/0183/5769/products/Proper-web-images-2021-_0002s_0003s_0000_13Pro-Silver_c9e0f6b6-b63b-4058-a752-4f28fa959535.png?v=1631857457	Unleash the power of Pro with the iPhone 13 Pro. Its advanced camera system, stunning ProMotion display, and exceptional performance redefine what a smartphone can do.	IP13P-001	16	999.99	\N	3	t	2024-01-11 22:06:20.983669+07	2024-01-12 01:06:48.071933+07
8	iPhone 13 Pro Max	https://static.digitecgalaxus.ch/Files/5/9/5/1/2/7/3/9/iPhone_13_Pro_Max_Green_PDP_Image_Position-1A__WWEN.jpg	Experience the ultimate iPhone with the iPhone 13 Pro Max. Its advanced camera system, stunning ProMotion display, and exceptional performance take smartphone capabilities to new heights.	IP13PM-001	16	1099.99	\N	3	t	2024-01-11 22:06:20.983669+07	2024-01-12 01:06:48.071933+07
9	iPhone 13 Mini	https://media.extra.com/s/aurora/100291774_800/Apple-iPhone-13-MINI-5G-128GB-Blue?locale=en-GB,en-*,*	Get the best of iPhone in a compact form with the iPhone 13 Mini. Experience advanced features and innovation without the premium cost.	IP13M-001	16	699.99	\N	3	t	2024-01-11 22:06:20.983669+07	2024-01-12 01:06:48.071933+07
65	Omega Seamaster	https://luxewatch.vn/wp-content/uploads/2022/11/1275bb10562b9075c93a19.jpg	Our Omega Seamaster offers a classic look with a modern design. It is perfect for everyday use.	OS-001	24	4999.99	\N	52	t	2024-01-12 00:42:13.039261+07	2024-01-12 01:23:20.326866+07
66	TAG Heuer Carrera	https://cdn.luxshopping.vn/Thumnails/Uploads/News/tag-heuer-carrera-cbs2212-fc6535-watch-39mm.jpg.webp	Stay stylish with our TAG Heuer Carrera. It is designed for comfort and durability.	THC-001	24	3199.99	\N	52	t	2024-01-12 00:42:13.039261+07	2024-01-12 01:23:20.326866+07
67	Patek Philippe Calatrava	https://www.thehourglass.com/vn/wp-content/uploads/sites/22/2023/04/Patek-Philippe-Calatrava_5227R-001.jpg	Experience elegance and precision with our Patek Philippe Calatrava. Perfect for all occasions.	PPC-001	24	18999.99	\N	54	t	2024-01-12 00:42:29.439807+07	2024-01-12 01:23:20.326866+07
68	Audemars Piguet Royal Oak	https://bossluxurywatch.vn/uploads/san-pham/audemars-piguet/royal-oak/1/thumbs/645x0/audemars-piguet-royal-oak-selfwinding-chronograph-38mm-26715st-oo-1356st-01.png	Our Audemars Piguet Royal Oak offers a classic look with a modern design. It is perfect for everyday use.	APRO-001	24	24999.99	\N	54	t	2024-01-12 00:42:29.439807+07	2024-01-12 01:23:20.326866+07
69	Vacheron Constantin Patrimony	https://cdn.luxshopping.vn/Thumnails/Uploads/News/patrimony-1110u-000r-b085-manual-wind-42mm.png.webp	Stay stylish with our Vacheron Constantin Patrimony. It is designed for comfort and durability.	VCP-001	24	20999.99	\N	54	t	2024-01-12 00:42:29.439807+07	2024-01-12 01:23:20.326866+07
70	Breitling Navitimer	https://mrwatch.vn/product_images/dong-ho-navitimer-b01-chronograph-46-ab0137211c1a1-chinh-hang-16578.png	Experience elegance and precision with our Breitling Navitimer. Perfect for all occasions.	BN-001	24	4999.99	\N	55	t	2024-01-12 00:43:37.272241+07	2024-01-12 01:23:20.326866+07
51	Protein Powder	https://www.optimumnutritionsea.com/frontend/images/products/whey_bottele.png	Our Protein Powder offers a high-quality protein source for muscle recovery and growth. It is perfect for post-workout nutrition.	PP-001	4	29.99	\N	40	t	2024-01-12 00:11:54.794403+07	2024-01-12 01:00:39.645704+07
22	Channel Men's Shirt	https://images-na.ssl-images-amazon.com/images/I/61DzSMfKqKL._AC_UX679_.jpg	Experience comfort and style with our Men's Shirt. Perfect for casual and formal occasions.	MCS-001	12	49.99	\N	9	t	2024-01-11 22:39:59.092997+07	2024-01-12 01:08:16.639786+07
23	Channel Men's Jeans	https://th.bing.com/th/id/R.387118410c8ba47bca3f9530266ccd1e?rik=kOm%2b%2bXgM%2bk88Tg&pid=ImgRaw&r=0	Our Men's Jeans offer a classic look with a modern fit. They're perfect for everyday wear.	MCJ-001	12	79.99	\N	9	t	2024-01-11 22:39:59.092997+07	2024-01-12 01:08:58.411662+07
24	Channel Men's Jacket	https://th.bing.com/th/id/OIP.qtMQRtX2qUunW2_6mKPGogHaJQ?rs=1&pid=ImgDetMain	Stay warm and stylish with our Men's Jacket. It's designed for comfort and durability.	MCJK-001	12	99.99	\N	9	t	2024-01-11 22:39:59.092997+07	2024-01-12 01:08:58.411662+07
25	Channel Men's Shoes	https://th.bing.com/th/id/R.a023032dc662881cc5bea413b76924fd?rik=pBz3jYEEVKbamg&pid=ImgRaw&r=0	Step into comfort with our Men's Shoes. They're designed for style and long-lasting comfort.	MCSH-001	14	69.99	\N	9	t	2024-01-11 22:39:59.092997+07	2024-01-12 01:10:28.410629+07
26	Louis Vuitton Bag	https://th.bing.com/th/id/OIP.U33MPbXUa6Tf5-4Wcm3J9QHaHa?rs=1&pid=ImgDetMain	Experience luxury and style with our Louis Vuitton Bag. Perfect for all occasions.	LVB-001	6	1499.99	\N	10	t	2024-01-11 23:05:31.46191+07	2024-01-12 01:11:55.990147+07
27	Louis Vuitton Wallet	https://th.bing.com/th/id/OIP.tgSLphr1zXTd5eYjuuU1igHaHa?rs=1&pid=ImgDetMain	Our Louis Vuitton Wallet offers a classic look with a modern design. It is perfect for everyday use.	LVW-001	6	499.99	\N	10	t	2024-01-11 23:05:31.46191+07	2024-01-12 01:11:55.990147+07
28	Louis Vuitton Belt	https://th.bing.com/th/id/R.bdfd528985daaebbf248d2ca682a89c9?rik=e4CEwY3Ij%2bo%2fOQ&pid=ImgRaw&r=0	Stay stylish with our Louis Vuitton Belt. It is designed for comfort and durability.	LVBELT-001	6	299.99	\N	10	t	2024-01-11 23:05:31.46191+07	2024-01-12 01:11:55.990147+07
29	Louis Vuitton Shoes	https://th.bing.com/th/id/OIP.u_nQIhxWkcT84agNgq-_-gHaHa?rs=1&pid=ImgDetMain	Step into comfort with our Louis Vuitton Shoes. They are designed for style and long-lasting comfort.	LVSH-001	6	699.99	\N	10	t	2024-01-11 23:05:31.46191+07	2024-01-12 01:11:55.990147+07
30	Dior Bag	https://th.bing.com/th/id/OIP.An6wNpyE1IH6HuT32mu3AgHaJx?rs=1&pid=ImgDetMain	Experience luxury and style with our Dior Bag. Perfect for all occasions.	DB-001	6	1499.99	\N	4	t	2024-01-11 23:11:51.757892+07	2024-01-12 01:11:55.990147+07
31	Dior Wallet	https://th.bing.com/th/id/R.6a1ef792039405224127c0e8bc48c974?rik=LuSc0i1iciz%2f%2fQ&pid=ImgRaw&r=0	Our Dior Wallet offers a classic look with a modern design. It is perfect for everyday use.	DW-001	6	499.99	\N	4	t	2024-01-11 23:11:51.757892+07	2024-01-12 01:11:55.990147+07
32	Dior Belt	https://th.bing.com/th/id/OIP.qi-AIBWWSWMShLo4CqZd9gHaHa?rs=1&pid=ImgDetMain	Stay stylish with our Dior Belt. It is designed for comfort and durability.	DBELT-001	6	299.99	\N	4	t	2024-01-11 23:11:51.757892+07	2024-01-12 01:11:55.990147+07
34	Gucci Bag	https://th.bing.com/th/id/R.1cc1d9a8afe5802035c0f248b4952dba?rik=5sdba%2byQNdpU4g&pid=ImgRaw&r=0	Experience luxury and style with our Gucci Bag. Perfect for all occasions.	GB-001	27	1599.99	\N	5	t	2024-01-11 23:16:33.113553+07	2024-01-12 01:13:18.324927+07
35	Gucci Shoes	https://th.bing.com/th/id/R.5ddb34c69fcbd49f3e9dedec52f2c355?rik=pe%2bZynpiUlT4Xg&pid=ImgRaw&r=0	Step into comfort with our Gucci Shoes. They are designed for style and long-lasting comfort.	GSH-001	15	799.99	\N	5	t	2024-01-11 23:16:33.113553+07	2024-01-12 01:18:46.274098+07
36	H&M Men's T-Shirt	https://lp2.hm.com/hmgoepprod?set=quality[79]%2Csource[%2F96%2Fff%2F96ff51865c7fa3d337cb5a9058051e6bc66b3f29.jpg]%2Corigin[dam]%2Ccategory[men_tshirtstanks_shortsleeve]%2Ctype[DESCRIPTIVESTILLLIFE]%2Cres[m]%2Chmver[1]&call=url[file:/product/main]	Experience comfort and style with our H&M Men's T-Shirt. Perfect for casual occasions.	HMMT-001	12	19.99	\N	17	t	2024-01-11 23:31:25.668482+07	2024-01-12 01:08:16.639786+07
38	Nike Men's Shoes	https://th.bing.com/th/id/OIP.TkUqG3LhW3a65Sa5ZTx6ZAHaE8?rs=1&pid=ImgDetMain	Step into comfort with our Men's Shoes. They're designed for style and long-lasting comfort.	NMS-001	14	69.99	\N	9	t	2024-01-11 23:42:14.791481+07	2024-01-12 01:10:28.410629+07
37	H&M Women's Dress	https://www.fashiongonerogue.com/wp-content/uploads/2016/06/HM-Beaded-Dress.jpg	Our H&M Women's Dress offers a classic look with a modern design. It is perfect for special occasions.	HMWD-001	13	49.99	\N	17	t	2024-01-11 23:31:25.668482+07	2024-01-12 01:15:22.614481+07
41	Puma Women's Shoes	https://cdnd.lystit.com/photos/puma/24b08306/puma-Puma-Black-Spiced-Coral-Riaze-Prowl-Womens-Running-Shoes.jpeg	Our Puma Women's Shoes offer a classic look with a modern design. They are perfect for everyday use.	PWS-001	15	79.99	\N	20	t	2024-01-11 23:45:49.976991+07	2024-01-12 01:17:03.32295+07
39	Nike Women's Shoes	https://th.bing.com/th/id/OIP.7GKjovh7YjSB86COsZxbVgHaEO?rs=1&pid=ImgDetMain	Our Nike Women's Shoes offer a classic look with a modern design. They are perfect for everyday use.	NWS-001	15	99.99	\N	18	t	2024-01-11 23:42:14.791481+07	2024-01-12 01:18:46.274098+07
50	Vitamin C Supplement	https://cdn-amz.woka.io/images/I/71GV-HLgI3L.jpg	Boost your immune system with our Vitamin C Supplement. Perfect for maintaining good health.	VCS-001	4	19.99	\N	40	t	2024-01-12 00:11:54.794403+07	2024-01-12 01:00:39.645704+07
45	One Piece Poster	https://th.bing.com/th/id/R.8cc7c03434b4c015f93a0baaa4aeccac?rik=EgfmISoSTiGhiA&riu=http%3a%2f%2fstatic.minitokyo.net%2fdownloads%2f04%2f48%2f727404.jpg&ehk=5OssVXPYFoHwY4x0MUBULVkS3ekQn8GiBuhtQFyqF7k%3d&risl=&pid=ImgRaw&r=0	Our One Piece Poster offers a classic look with a modern design. It is perfect for everyday use.	OPP-001	10	9.99	\N	29	t	2024-01-11 23:53:42.699604+07	2024-01-12 01:19:43.084488+07
46	Attack on Titan T-Shirt	https://th.bing.com/th/id/R.d43865ddb229f3145931d2dbbb49629d?rik=r4hLeGKcPLObug&pid=ImgRaw&r=0	Stay stylish with our Attack on Titan T-Shirt. It is designed for comfort and durability.	AOTT-001	10	19.99	\N	29	t	2024-01-11 23:53:42.699604+07	2024-01-12 01:19:43.084488+07
47	My Hero Academia Hoodie	https://th.bing.com/th/id/OIP.7QifgP4OMXgcjxoMn_yoBAHaIw?rs=1&pid=ImgDetMain	Step into comfort with our My Hero Academia Hoodie. They are designed for style and long-lasting comfort.	MHAH-001	10	39.99	\N	30	t	2024-01-11 23:53:42.699604+07	2024-01-12 01:19:43.084488+07
56	Air Jordan 1 Retro	https://cdn.authentic-shoes.com/wp-content/uploads/2023/04/stage-haze-jordan-1-555088-108-5_38b2c966cd044ce9ab217f47473efcce.jpg	Experience comfort and style with our Air Jordan 1 Retro. Perfect for all occasions.	AJ1R-001	22	139.99	\N	51	t	2024-01-12 00:29:48.122025+07	2024-01-12 01:21:29.214336+07
57	Nike Air Force 1	https://static.nike.com/a/images/t_PDP_1280_v1/f_auto,q_auto:eco/2eff461f-f3ac-4285-9c6a-2f22173aac42/custom-nike-air-force-1-low-by-you.png	Our Nike Air Force 1 offers a classic look with a modern design. It is perfect for everyday use.	NAF1-001	22	89.99	\N	51	t	2024-01-12 00:29:48.122025+07	2024-01-12 01:21:29.214336+07
58	Adidas Yeezy Boost 350	https://cdn-images.farfetch-contents.com/21/28/57/99/21285799_51225739_600.jpg	Stay stylish with our Adidas Yeezy Boost 350. It is designed for comfort and durability.	AYB350-001	22	219.99	\N	51	t	2024-01-12 00:29:48.122025+07	2024-01-12 01:21:29.214336+07
59	Puma Suede Classic	https://product.hstatic.net/1000284478/product/01_374915_1_b622d15c43ee4f2e85180cbb5b850fd3.jpg	Step into comfort with our Puma Suede Classic. They are designed for style and long-lasting comfort.	PSC-001	22	59.99	\N	51	t	2024-01-12 00:29:48.122025+07	2024-01-12 01:21:29.214336+07
62	Reebok Classic Leather	https://sneaker.com.vn/uploads/product/02_2023/reebokclassicleather.jpg	Stay stylish with our Reebok Classic Leather. It is designed for comfort and durability.	RCL-001	21	69.99	\N	53	t	2024-01-12 00:30:07.142309+07	2024-01-12 01:22:15.526148+07
63	Vans Old Skool	https://sneaker.com.vn/uploads/product/02_2023/vansoldskool.jpg	Step into comfort with our Vans Old Skool. They are designed for style and long-lasting comfort.	VOS-001	21	59.99	\N	53	t	2024-01-12 00:30:07.142309+07	2024-01-12 01:22:15.526148+07
61	New Balance 574	https://supersports.com.vn/cdn/shop/products/U574LGNW-1.jpg?v=1700569343	Our New Balance 574 offers a classic look with a modern design. It is perfect for everyday use.	NB574-001	21	79.99	\N	53	t	2024-01-12 00:30:07.142309+07	2024-01-12 01:22:15.526148+07
64	Rolex Submariner	https://watch.com.vn/uploads/product/02_2023/rolexsubmariner.jpg	Experience elegance and precision with our Rolex Submariner. Perfect for all occasions.	RS-001	24	7999.99	\N	52	t	2024-01-12 00:42:13.039261+07	2024-01-12 01:23:20.326866+07
75	Jaeger-LeCoultre Reverso	https://bizweb.dktcdn.net/100/175/988/products/q397848j.jpg?v=1662691570727	Stay stylish with our Jaeger-LeCoultre Reverso. It is designed for comfort and durability.	JLR-001	24	7999.99	\N	56	t	2024-01-12 00:43:56.811991+07	2024-01-12 01:23:20.326866+07
52	Fish Oil Capsules	https://bizweb.dktcdn.net/thumb/grande/100/063/010/products/imageservice-1-jpeg-0c0e3394-ccd0-4fea-8b97-353307fc53db.jpg?v=1678891350553	Stay healthy with our Fish Oil Capsules. They are designed to support heart and brain health.	FOC-001	4	39.99	\N	40	t	2024-01-12 00:11:54.794403+07	2024-01-12 01:00:39.645704+07
53	Multivitamin	https://bizweb.dktcdn.net/thumb/grande/100/011/344/products/muscletech-platinum-multivitamin-gymstore.jpg?v=1641198668027	Support your overall health with our Multivitamin. It is designed to fill nutritional gaps in your diet.	MV-001	4	19.99	\N	41	t	2024-01-12 00:11:54.794403+07	2024-01-12 01:00:39.645704+07
54	Probiotic Supplement	https://m.media-amazon.com/images/W/MEDIAX_792452-T2/images/I/81JstIWS+FL.jpg	Support your gut health with our Probiotic Supplement. It is designed to promote a healthy digestive system.	PS-001	4	29.99	\N	41	t	2024-01-12 00:11:54.794403+07	2024-01-12 01:00:39.645704+07
55	Green Tea Extract	https://baconmeo.com/wp-content/uploads/2019/01/IMG_3775-scaled.jpg	Boost your metabolism with our Green Tea Extract. It is designed to support weight management and antioxidant protection.	GTE-001	4	39.99	\N	41	t	2024-01-12 00:11:54.794403+07	2024-01-12 01:00:39.645704+07
\.


--
-- TOC entry 5175 (class 0 OID 30145)
-- Dependencies: 248
-- Data for Name: cart_item; Type: TABLE DATA; Schema: shopping; Owner: postgres
--

COPY shopping.cart_item (cart_item_id, user_id, product_id, quantity, created_at, modified_at) FROM stdin;
\.


--
-- TOC entry 5179 (class 0 OID 30153)
-- Dependencies: 252
-- Data for Name: order_detail; Type: TABLE DATA; Schema: shopping; Owner: postgres
--

COPY shopping.order_detail (order_detail_id, user_id, total, created_at, modified_at, address_id, payment_id) FROM stdin;
3	906	1199.99	2024-01-12 11:32:45.787023+07	2024-01-12 11:32:45.787023+07	906	906
4	906	0	2024-01-12 11:32:47.197383+07	2024-01-12 11:32:47.197383+07	906	906
5	906	0	2024-01-12 11:32:48.194857+07	2024-01-12 11:32:48.194857+07	906	906
6	906	0	2024-01-12 11:32:48.334933+07	2024-01-12 11:32:48.334933+07	906	906
7	906	0	2024-01-12 11:32:48.477049+07	2024-01-12 11:32:48.477049+07	906	906
8	906	0	2024-01-12 11:32:48.732726+07	2024-01-12 11:32:48.732726+07	906	906
9	906	0	2024-01-12 11:33:03.024122+07	2024-01-12 11:33:03.024122+07	906	906
10	906	0	2024-01-12 11:33:03.29413+07	2024-01-12 11:33:03.29413+07	906	906
11	906	0	2024-01-12 11:33:04.15783+07	2024-01-12 11:33:04.15783+07	906	906
12	906	119.96	2024-01-12 12:14:12.986518+07	2024-01-12 12:14:12.986518+07	906	906
13	906	299.96999999999997	2024-01-12 12:15:31.840584+07	2024-01-12 12:15:31.840584+07	906	906
14	906	0	2024-01-12 12:15:33.193064+07	2024-01-12 12:15:33.193064+07	906	906
15	906	0	2024-01-12 12:15:34.098352+07	2024-01-12 12:15:34.098352+07	906	906
16	906	0	2024-01-12 12:15:34.240764+07	2024-01-12 12:15:34.240764+07	906	906
17	906	0	2024-01-12 12:15:34.490277+07	2024-01-12 12:15:34.490277+07	906	906
18	906	0	2024-01-12 12:15:39.247844+07	2024-01-12 12:15:39.247844+07	906	906
19	2	89.97	2024-01-12 12:19:02.354923+07	2024-01-12 12:19:02.354923+07	2	2
20	2	0	2024-01-12 12:19:05.677798+07	2024-01-12 12:19:05.677798+07	2	2
21	2	1399.98	2024-01-12 12:20:34.503699+07	2024-01-12 12:20:34.503699+07	2	2
\.


--
-- TOC entry 5182 (class 0 OID 30161)
-- Dependencies: 255
-- Data for Name: order_item; Type: TABLE DATA; Schema: shopping; Owner: postgres
--

COPY shopping.order_item (order_item_id, order_detail_id, product_id, quantity, condition, created_at, modified_at, delivery_provider_id, delivery_method_id, delivery_method) FROM stdin;
15	3	2	1	Pending Confirmation	2024-01-12 11:32:45.836303+07	2024-01-12 11:32:45.834592+07	\N	\N	business
16	12	77	4	Pending Confirmation	2024-01-12 12:14:13.055464+07	2024-01-12 12:14:13.045217+07	\N	\N	fast
17	13	79	3	Pending Confirmation	2024-01-12 12:15:31.861673+07	2024-01-12 12:15:31.860299+07	\N	\N	business
18	19	77	3	Pending Confirmation	2024-01-12 12:19:02.388855+07	2024-01-12 12:19:02.378236+07	\N	\N	business
19	21	4	2	Pending Confirmation	2024-01-12 12:20:34.522771+07	2024-01-12 12:20:34.519268+07	\N	\N	business
\.


--
-- TOC entry 5186 (class 0 OID 30171)
-- Dependencies: 259
-- Data for Name: delivery_method; Type: TABLE DATA; Schema: store; Owner: postgres
--

COPY store.delivery_method (delivery_method_id, store_id, method_name, price, is_active, created_at, modified_at) FROM stdin;
355	2	business	3	t	2024-01-11 20:19:51.399722+07	2024-01-11 20:19:51.399722+07
356	3	business	3	t	2024-01-11 20:21:35.120295+07	2024-01-11 20:21:35.120295+07
357	4	business	3	t	2024-01-11 20:22:44.23414+07	2024-01-11 20:22:44.23414+07
358	5	business	3	t	2024-01-11 20:22:57.639927+07	2024-01-11 20:22:57.639927+07
359	6	business	3	t	2024-01-11 20:26:40.632605+07	2024-01-11 20:26:40.632605+07
360	7	business	3	t	2024-01-11 20:26:54.835273+07	2024-01-11 20:26:54.835273+07
361	8	business	3	t	2024-01-11 20:27:24.25328+07	2024-01-11 20:27:24.25328+07
362	9	business	3	t	2024-01-11 20:29:14.412791+07	2024-01-11 20:29:14.412791+07
363	10	business	3	t	2024-01-11 20:29:35.749153+07	2024-01-11 20:29:35.749153+07
370	17	business	3	t	2024-01-11 20:33:47.81467+07	2024-01-11 20:33:47.81467+07
371	18	business	3	t	2024-01-11 20:35:05.977943+07	2024-01-11 20:35:05.977943+07
372	19	business	3	t	2024-01-11 20:38:21.536386+07	2024-01-11 20:38:21.536386+07
373	20	business	3	t	2024-01-11 20:38:21.536386+07	2024-01-11 20:38:21.536386+07
381	29	business	3	t	2024-01-11 20:41:45.262595+07	2024-01-11 20:41:45.262595+07
382	30	business	3	t	2024-01-11 20:41:45.262595+07	2024-01-11 20:41:45.262595+07
392	40	business	3	t	2024-01-11 20:49:10.045977+07	2024-01-11 20:49:10.045977+07
393	41	business	3	t	2024-01-11 20:49:10.045977+07	2024-01-11 20:49:10.045977+07
403	51	business	3	t	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
404	52	business	3	t	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
405	53	business	3	t	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
406	54	business	3	t	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
407	55	business	3	t	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
408	56	business	3	t	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
413	62	business	3	t	2024-01-11 20:54:24.720337+07	2024-01-11 20:54:24.720337+07
414	63	business	3	t	2024-01-11 20:54:24.720337+07	2024-01-11 20:54:24.720337+07
\.


--
-- TOC entry 5189 (class 0 OID 30181)
-- Dependencies: 262
-- Data for Name: store; Type: TABLE DATA; Schema: store; Owner: postgres
--

COPY store.store (store_id, user_id, name, description, created_at, modified_at) FROM stdin;
2	365	SamStore	A lead technology store with powerful devices that change your life	2024-01-11 20:19:51.399722+07	2024-01-11 20:19:51.399722+07
3	695	Apple Store	A best digital store in the world, provide the greatese ecosystem that lighten your life	2024-01-11 20:21:35.120295+07	2024-01-11 20:21:35.120295+07
4	375	Dior Boutique	Indulge in luxury at the Dior Boutique. Immerse yourself in the world of haute couture and timeless elegance.	2024-01-11 20:22:44.23414+07	2024-01-11 20:22:44.23414+07
5	391	Gucci Boutique	Step into the world of fashion excellence at Gucci Boutique. Discover iconic designs that define sophistication and style.	2024-01-11 20:22:57.639927+07	2024-01-11 20:22:57.639927+07
6	140	Lenovo Laptop Hub	Elevate your computing experience at Lenovo Laptop Hub. Explore sleek and powerful laptops designed for modern lifestyles.	2024-01-11 20:26:40.632605+07	2024-01-11 20:26:40.632605+07
7	234	Dell Laptop Center	Unleash the possibilities with Dell Laptop Center. Experience top-notch quality and reliability in every laptop we offer.	2024-01-11 20:26:54.835273+07	2024-01-11 20:26:54.835273+07
8	130	HP Laptop Store	Discover the power of performance at HP Laptop Store. Explore a wide range of laptops designed for productivity and innovation.	2024-01-11 20:27:24.25328+07	2024-01-11 20:27:24.25328+07
9	906	Chanel Boutique	Experience timeless elegance at Chanel Boutique. Immerse yourself in the world of luxury fashion and iconic designs.	2024-01-11 20:29:14.412791+07	2024-01-11 20:29:14.412791+07
10	100	Louis Vuitton Store	Indulge in luxury at Louis Vuitton Store. Explore exquisite craftsmanship and sophistication in our collection of fashion and accessories.	2024-01-11 20:29:35.749153+07	2024-01-11 20:29:35.749153+07
17	792	H&M Fashion Outlet	Revamp your style at H&M Fashion Outlet. Discover trendy and affordable fashion that keeps you on the cutting edge of the latest trends.	2024-01-11 20:33:47.81467+07	2024-01-11 20:33:47.81467+07
18	398	Nike Sportswear Store	Unleash the athlete in you at Nike Sportswear Store. Discover cutting-edge sports apparel and footwear designed for performance and style.	2024-01-11 20:35:05.977943+07	2024-01-11 20:35:05.977943+07
19	52	Adidas Performance Hub	Elevate your game with Adidas Performance Hub. Explore a range of high-performance sportswear and footwear designed for champions.	2024-01-11 20:38:21.536386+07	2024-01-11 20:38:21.536386+07
20	124	Puma Athletic Outlet	Step into the world of agility at Puma Athletic Outlet. Explore stylish and functional athletic wear and footwear that enhances your performance.	2024-01-11 20:38:21.536386+07	2024-01-11 20:38:21.536386+07
29	35	Otaku Paradise	Dive into the world of anime and manga at Otaku Paradise. Explore a vast collection of figures, merchandise, and exclusive items from your favorite series.	2024-01-11 20:41:45.262595+07	2024-01-11 20:41:45.262595+07
30	540	Manga Marvels	Embark on a journey through Manga Marvels. Discover a treasure trove of manga, anime figures, and collectibles that celebrate the essence of Japanese pop culture.	2024-01-11 20:41:45.262595+07	2024-01-11 20:41:45.262595+07
40	688	Holistic Health Hub	Nurture your body and mind at Holistic Health Hub. Discover a comprehensive selection of health care solutions, natural remedies, and holistic wellness products.	2024-01-11 20:49:10.045977+07	2024-01-11 20:49:10.045977+07
41	948	Vitality Emporium	Energize your life at Vitality Emporium. Explore a curated collection of health care essentials, vitamins, and supplements to enhance your overall vitality.	2024-01-11 20:49:10.045977+07	2024-01-11 20:49:10.045977+07
51	775	Footwear Finesse	Elevate your step at Footwear Finesse. Explore a curated selection of stylish shoes that blend trendsetting designs with comfort.	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
52	439	Chrono Boutique	Dive into the world of precision at Chrono Boutique. Find watches that transcend time, embodying craftsmanship and innovation.	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
53	998	Sneaker Street	Discover urban style at Sneaker Street. Explore a diverse collection of sneakers that showcase the latest trends and streetwear fashion.	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
54	137	Watch Wardrobe	Cultivate your watch collection at Watch Wardrobe. Find timepieces that suit every occasion, from classic designs to modern marvels.	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
55	492	Strut & Tick	Strut in style at Strut & Tick. Discover a fusion of watches and shoes that embody contemporary fashion and timeless elegance.	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
56	713	Solely Time	Balance fashion and function at Solely Time. Find watches and shoes that complement your lifestyle, ensuring you make a statement with every step.	2024-01-11 20:50:48.327961+07	2024-01-11 20:50:48.327961+07
62	759	Culinary Corner	Equip your kitchen at Culinary Corner. Explore a comprehensive range of kitchen items, utensils, and gadgets to enhance your cooking experience.	2024-01-11 20:54:24.720337+07	2024-01-11 20:54:24.720337+07
63	599	Kitchen Essentials Emporium	Discover the heart of your home at Kitchen Essentials Emporium. Find a diverse collection of kitchen items and tools that make meal preparation a breeze.	2024-01-11 20:54:24.720337+07	2024-01-11 20:54:24.720337+07
\.


--
-- TOC entry 5192 (class 0 OID 30190)
-- Dependencies: 265
-- Data for Name: active_chain; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.active_chain (chain_id, client_name, started_at) FROM stdin;
\.


--
-- TOC entry 5193 (class 0 OID 30196)
-- Dependencies: 266
-- Data for Name: active_session; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.active_session (client_pid, server_pid, client_name, started_at) FROM stdin;
\.


--
-- TOC entry 5194 (class 0 OID 30202)
-- Dependencies: 267
-- Data for Name: chain; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.chain (chain_id, chain_name, run_at, max_instances, timeout, live, self_destruct, exclusive_execution, client_name, on_error) FROM stdin;
9	execute-func	@every 1 minute	\N	0	t	f	f	\N	\N
10	updatedeletedis	@every 1 minute	\N	0	t	f	f	\N	\N
\.


--
-- TOC entry 5196 (class 0 OID 30212)
-- Dependencies: 269
-- Data for Name: execution_log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.execution_log (chain_id, task_id, txid, last_run, finished, pid, returncode, ignore_error, kind, command, output, client_name) FROM stdin;
\.


--
-- TOC entry 5197 (class 0 OID 30218)
-- Dependencies: 270
-- Data for Name: log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.log (ts, pid, log_level, client_name, message, message_data) FROM stdin;
\.


--
-- TOC entry 5198 (class 0 OID 30225)
-- Dependencies: 271
-- Data for Name: migration; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.migration (id, version) FROM stdin;
0	00259 Restart migrations for v4
1	00305 Fix timetable.is_cron_in_time
2	00323 Append timetable.delete_job function
3	00329 Migration required for some new added functions
4	00334 Refactor timetable.task as plain schema without tree-like dependencies
5	00381 Rewrite active chain handling
6	00394 Add started_at column to active_session and active_chain tables
7	00417 Rename LOG database log level to INFO
8	00436 Add txid column to timetable.execution_log
9	00534 Use cron_split_to_arrays() in cron domain check
10	00560 Alter txid column to bigint
11	00573 Add ability to start a chain with delay
12	00575 Add on_error handling
13	00629 Add ignore_error column to timetable.execution_log
\.


--
-- TOC entry 5199 (class 0 OID 30230)
-- Dependencies: 272
-- Data for Name: parameter; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.parameter (task_id, order_id, value) FROM stdin;
7	1	\N
8	1	\N
\.


--
-- TOC entry 5200 (class 0 OID 30236)
-- Dependencies: 273
-- Data for Name: task; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.task (task_id, chain_id, task_order, task_name, kind, command, run_as, database_connection, ignore_error, autonomous, timeout) FROM stdin;
7	9	10	\N	SQL	SELECT public.update_condition_after_delay()	\N	\N	t	t	0
8	10	10	\N	SQL	SELECT update_and_delete_discount()	\N	\N	t	t	0
\.


--
-- TOC entry 5269 (class 0 OID 0)
-- Dependencies: 222
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.address_address_id_seq', 1003, true);


--
-- TOC entry 5270 (class 0 OID 0)
-- Dependencies: 223
-- Name: address_user_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.address_user_id_seq', 1, false);


--
-- TOC entry 5271 (class 0 OID 0)
-- Dependencies: 225
-- Name: payment_register_pay_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.payment_register_pay_id_seq', 1003, true);


--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 226
-- Name: payment_register_user_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.payment_register_user_id_seq', 1, false);


--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 228
-- Name: role_role_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.role_role_id_seq', 2, true);


--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 231
-- Name: user_user_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.user_user_id_seq', 1007, true);


--
-- TOC entry 5275 (class 0 OID 0)
-- Dependencies: 233
-- Name: delivery_provider_delivery_provider_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: postgres
--

SELECT pg_catalog.setval('delivery.delivery_provider_delivery_provider_id_seq', 101, true);


--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 235
-- Name: category_category_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.category_category_id_seq', 27, true);


--
-- TOC entry 5277 (class 0 OID 0)
-- Dependencies: 236
-- Name: category_parent_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.category_parent_id_seq', 6, true);


--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 238
-- Name: discount_discount_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.discount_discount_id_seq', 2, true);


--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 240
-- Name: inventory_inventory_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.inventory_inventory_id_seq', 80, true);


--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 241
-- Name: inventory_product_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.inventory_product_id_seq', 1, false);


--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 244
-- Name: product_category_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.product_category_id_seq', 1, false);


--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 245
-- Name: product_discount_Id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product."product_discount_Id_seq"', 2, true);


--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 246
-- Name: product_product_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.product_product_id_seq', 81, true);


--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 247
-- Name: product_store_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.product_store_id_seq', 1, false);


--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 275
-- Name: temp_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.temp_seq', 1, false);


--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 249
-- Name: cart_item_cart_item_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.cart_item_cart_item_id_seq', 62, true);


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 250
-- Name: cart_item_product_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.cart_item_product_id_seq', 1, false);


--
-- TOC entry 5288 (class 0 OID 0)
-- Dependencies: 251
-- Name: cart_item_session_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.cart_item_session_id_seq', 1, false);


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 253
-- Name: order_detail_order_detail_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_detail_order_detail_id_seq', 21, true);


--
-- TOC entry 5290 (class 0 OID 0)
-- Dependencies: 254
-- Name: order_detail_user_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_detail_user_id_seq', 1, false);


--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 256
-- Name: order_item_order_detail_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_item_order_detail_id_seq', 1, false);


--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 257
-- Name: order_item_order_item_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_item_order_item_id_seq', 19, true);


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 258
-- Name: order_item_product_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_item_product_id_seq', 1, false);


--
-- TOC entry 5294 (class 0 OID 0)
-- Dependencies: 260
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.delivery_methods_delivery_method_id_seq', 420, true);


--
-- TOC entry 5295 (class 0 OID 0)
-- Dependencies: 261
-- Name: delivery_methods_store_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.delivery_methods_store_id_seq', 1, false);


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 263
-- Name: store_store_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.store_store_id_seq', 69, true);


--
-- TOC entry 5297 (class 0 OID 0)
-- Dependencies: 264
-- Name: store_user_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.store_user_id_seq', 1, false);


--
-- TOC entry 5298 (class 0 OID 0)
-- Dependencies: 268
-- Name: chain_chain_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.chain_chain_id_seq', 11, true);


--
-- TOC entry 5299 (class 0 OID 0)
-- Dependencies: 274
-- Name: task_task_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.task_task_id_seq', 9, true);


--
-- TOC entry 4921 (class 2606 OID 30263)
-- Name: address address_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- TOC entry 4923 (class 2606 OID 30265)
-- Name: payment payment_register_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.payment
    ADD CONSTRAINT payment_register_pkey PRIMARY KEY (payment_id);


--
-- TOC entry 4925 (class 2606 OID 30267)
-- Name: role role_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (role_id);


--
-- TOC entry 4927 (class 2606 OID 30474)
-- Name: user user_name; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account."user"
    ADD CONSTRAINT user_name UNIQUE (username);


--
-- TOC entry 4929 (class 2606 OID 30269)
-- Name: user user_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4931 (class 2606 OID 30271)
-- Name: delivery_provider delivery_provider_pkey; Type: CONSTRAINT; Schema: delivery; Owner: postgres
--

ALTER TABLE ONLY delivery.delivery_provider
    ADD CONSTRAINT delivery_provider_pkey PRIMARY KEY (delivery_provider_id);


--
-- TOC entry 4933 (class 2606 OID 30273)
-- Name: category category_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4935 (class 2606 OID 30275)
-- Name: discount discount_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.discount
    ADD CONSTRAINT discount_pkey PRIMARY KEY (discount_id);


--
-- TOC entry 4937 (class 2606 OID 30277)
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- TOC entry 4939 (class 2606 OID 30468)
-- Name: product name; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT name UNIQUE (name);


--
-- TOC entry 4941 (class 2606 OID 30279)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- TOC entry 4943 (class 2606 OID 30281)
-- Name: cart_item cart_item_pkey; Type: CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item
    ADD CONSTRAINT cart_item_pkey PRIMARY KEY (cart_item_id);


--
-- TOC entry 4945 (class 2606 OID 30283)
-- Name: order_detail order_detail_pkey; Type: CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT order_detail_pkey PRIMARY KEY (order_detail_id);


--
-- TOC entry 4947 (class 2606 OID 30285)
-- Name: order_item order_item_pkey; Type: CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (order_item_id);


--
-- TOC entry 4949 (class 2606 OID 30287)
-- Name: delivery_method delivery_methods_pkey; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.delivery_method
    ADD CONSTRAINT delivery_methods_pkey PRIMARY KEY (delivery_method_id);


--
-- TOC entry 4951 (class 2606 OID 30458)
-- Name: store name; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT name UNIQUE (name);


--
-- TOC entry 4953 (class 2606 OID 30289)
-- Name: store store_pkey; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);


--
-- TOC entry 4955 (class 2606 OID 30491)
-- Name: store user; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT "user" UNIQUE (user_id);


--
-- TOC entry 4957 (class 2606 OID 30291)
-- Name: chain chain_chain_name_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain
    ADD CONSTRAINT chain_chain_name_key UNIQUE (chain_name);


--
-- TOC entry 4959 (class 2606 OID 30293)
-- Name: chain chain_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain
    ADD CONSTRAINT chain_pkey PRIMARY KEY (chain_id);


--
-- TOC entry 4961 (class 2606 OID 30295)
-- Name: migration migration_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.migration
    ADD CONSTRAINT migration_pkey PRIMARY KEY (id);


--
-- TOC entry 4963 (class 2606 OID 30297)
-- Name: parameter parameter_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.parameter
    ADD CONSTRAINT parameter_pkey PRIMARY KEY (task_id, order_id);


--
-- TOC entry 4965 (class 2606 OID 30299)
-- Name: task task_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (task_id);


--
-- TOC entry 4989 (class 2620 OID 30300)
-- Name: user auto_create_role; Type: TRIGGER; Schema: account; Owner: postgres
--

CREATE TRIGGER auto_create_role AFTER INSERT ON account."user" FOR EACH ROW EXECUTE FUNCTION public.autocreaterole();


--
-- TOC entry 4990 (class 2620 OID 30513)
-- Name: user update_user; Type: TRIGGER; Schema: account; Owner: postgres
--

CREATE TRIGGER update_user BEFORE UPDATE ON account."user" FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4991 (class 2620 OID 30302)
-- Name: delivery_provider update_delivery_provider; Type: TRIGGER; Schema: delivery; Owner: postgres
--

CREATE TRIGGER update_delivery_provider BEFORE UPDATE ON delivery.delivery_provider FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4995 (class 2620 OID 30498)
-- Name: product auto_create_inv; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER auto_create_inv AFTER INSERT ON product.product FOR EACH ROW EXECUTE FUNCTION public.autocreateinv();


--
-- TOC entry 4992 (class 2620 OID 30303)
-- Name: category update_category; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_category BEFORE UPDATE ON product.category FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4993 (class 2620 OID 30304)
-- Name: discount update_discount; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_discount BEFORE UPDATE ON product.discount FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4994 (class 2620 OID 30305)
-- Name: inventory update_inventory; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_inventory BEFORE UPDATE ON product.inventory FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4996 (class 2620 OID 30306)
-- Name: product update_product; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_product BEFORE UPDATE ON product.product FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4997 (class 2620 OID 30307)
-- Name: cart_item update_cart_item; Type: TRIGGER; Schema: shopping; Owner: postgres
--

CREATE TRIGGER update_cart_item BEFORE UPDATE ON shopping.cart_item FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4998 (class 2620 OID 30308)
-- Name: order_detail update_order_detail; Type: TRIGGER; Schema: shopping; Owner: postgres
--

CREATE TRIGGER update_order_detail BEFORE UPDATE ON shopping.order_detail FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4999 (class 2620 OID 30309)
-- Name: order_item update_order_item; Type: TRIGGER; Schema: shopping; Owner: postgres
--

CREATE TRIGGER update_order_item BEFORE UPDATE ON shopping.order_item FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 5001 (class 2620 OID 30310)
-- Name: store auto_create_deli_method; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER auto_create_deli_method AFTER INSERT ON store.store FOR EACH ROW EXECUTE FUNCTION public.autocreatedelimethod();


--
-- TOC entry 5002 (class 2620 OID 30311)
-- Name: store auto_reupdate_role; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER auto_reupdate_role AFTER DELETE ON store.store FOR EACH ROW EXECUTE FUNCTION public.autoreupdaterole();


--
-- TOC entry 5003 (class 2620 OID 30312)
-- Name: store auto_update_role; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER auto_update_role AFTER INSERT ON store.store FOR EACH ROW EXECUTE FUNCTION public.autoupdaterole();


--
-- TOC entry 5000 (class 2620 OID 30313)
-- Name: delivery_method update_delimethod; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER update_delimethod BEFORE UPDATE ON store.delivery_method FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 5004 (class 2620 OID 30314)
-- Name: store update_store; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER update_store BEFORE UPDATE ON store.store FOR EACH ROW EXECUTE FUNCTION public.update_modified();


--
-- TOC entry 4968 (class 2606 OID 30315)
-- Name: user_role role_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.user_role
    ADD CONSTRAINT role_fk FOREIGN KEY (role_id) REFERENCES account.role(role_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4967 (class 2606 OID 30320)
-- Name: payment user_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.payment
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4969 (class 2606 OID 30325)
-- Name: user_role user_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.user_role
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4966 (class 2606 OID 30330)
-- Name: address user_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.address
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4970 (class 2606 OID 30335)
-- Name: category cate_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.category
    ADD CONSTRAINT cate_fk FOREIGN KEY (parent_id) REFERENCES product.category(category_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4973 (class 2606 OID 30340)
-- Name: product cate_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT cate_fk FOREIGN KEY (category_id) REFERENCES product.category(category_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4974 (class 2606 OID 30345)
-- Name: product dis_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT dis_fk FOREIGN KEY (discount_id) REFERENCES product.discount(discount_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4972 (class 2606 OID 30350)
-- Name: inventory prod_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.inventory
    ADD CONSTRAINT prod_fk FOREIGN KEY (product_id) REFERENCES product.product(product_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4975 (class 2606 OID 30355)
-- Name: product store_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT store_fk FOREIGN KEY (store_id) REFERENCES store.store(store_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4971 (class 2606 OID 30483)
-- Name: discount store_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.discount
    ADD CONSTRAINT store_fk FOREIGN KEY (store_id) REFERENCES store.store(store_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4978 (class 2606 OID 30360)
-- Name: order_detail add_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT add_fk FOREIGN KEY (address_id) REFERENCES account.address(address_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4981 (class 2606 OID 30365)
-- Name: order_item deli_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT deli_fk FOREIGN KEY (delivery_provider_id) REFERENCES delivery.delivery_provider(delivery_provider_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4982 (class 2606 OID 30501)
-- Name: order_item deli_method; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT deli_method FOREIGN KEY (delivery_method_id) REFERENCES store.delivery_method(delivery_method_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4983 (class 2606 OID 30370)
-- Name: order_item detail_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT detail_fk FOREIGN KEY (order_detail_id) REFERENCES shopping.order_detail(order_detail_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4979 (class 2606 OID 30375)
-- Name: order_detail pay_id; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT pay_id FOREIGN KEY (payment_id) REFERENCES account.payment(payment_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4976 (class 2606 OID 30380)
-- Name: cart_item prod_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item
    ADD CONSTRAINT prod_fk FOREIGN KEY (product_id) REFERENCES product.product(product_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4984 (class 2606 OID 30385)
-- Name: order_item prod_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT prod_fk FOREIGN KEY (product_id) REFERENCES product.product(product_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4977 (class 2606 OID 30390)
-- Name: cart_item user_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4980 (class 2606 OID 30395)
-- Name: order_detail user_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4985 (class 2606 OID 30400)
-- Name: delivery_method deli_fk; Type: FK CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.delivery_method
    ADD CONSTRAINT deli_fk FOREIGN KEY (store_id) REFERENCES store.store(store_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4986 (class 2606 OID 30405)
-- Name: store user_fk; Type: FK CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4987 (class 2606 OID 30410)
-- Name: parameter parameter_task_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.parameter
    ADD CONSTRAINT parameter_task_id_fkey FOREIGN KEY (task_id) REFERENCES timetable.task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4988 (class 2606 OID 30415)
-- Name: task task_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task
    ADD CONSTRAINT task_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


-- Completed on 2024-01-12 12:23:22

--
-- PostgreSQL database dump complete
--

