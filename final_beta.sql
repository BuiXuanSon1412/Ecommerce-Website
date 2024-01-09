--
-- PostgreSQL database dump
--

-- Dumped from database version 16.0
-- Dumped by pg_dump version 16.0

-- Started on 2024-01-09 09:11:15

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
-- TOC entry 5210 (class 0 OID 0)
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
-- TOC entry 938 (class 1247 OID 30008)
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
-- TOC entry 941 (class 1247 OID 30017)
-- Name: cron; Type: DOMAIN; Schema: timetable; Owner: postgres
--

CREATE DOMAIN timetable.cron AS text
	CONSTRAINT cron_check CHECK (((VALUE = '@reboot'::text) OR ((substr(VALUE, 1, 6) = ANY (ARRAY['@every'::text, '@after'::text])) AND ((substr(VALUE, 7))::interval IS NOT NULL)) OR ((VALUE ~ '^(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) +){4}(((\d+,)+\d+|(\d+(\/|-)\d+)|(\*(\/|-)\d+)|\d+|\*) ?)$'::text) AND (timetable.cron_split_to_arrays(VALUE) IS NOT NULL))));


ALTER DOMAIN timetable.cron OWNER TO postgres;

--
-- TOC entry 5211 (class 0 OID 0)
-- Dependencies: 941
-- Name: DOMAIN cron; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON DOMAIN timetable.cron IS 'Extended CRON-style notation with support of interval values';


--
-- TOC entry 945 (class 1247 OID 30020)
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
-- TOC entry 282 (class 1255 OID 30037)
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
-- TOC entry 308 (class 1255 OID 30038)
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
-- TOC entry 283 (class 1255 OID 30039)
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
-- TOC entry 284 (class 1255 OID 30040)
-- Name: updatecartitem(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatecartitem() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatecartitem() OWNER TO postgres;

--
-- TOC entry 285 (class 1255 OID 30041)
-- Name: updatecategory(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatecategory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatecategory() OWNER TO postgres;

--
-- TOC entry 286 (class 1255 OID 30042)
-- Name: updatedelimethod(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatedelimethod() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatedelimethod() OWNER TO postgres;

--
-- TOC entry 287 (class 1255 OID 30043)
-- Name: updatedeliveryprovider(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatedeliveryprovider() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatedeliveryprovider() OWNER TO postgres;

--
-- TOC entry 288 (class 1255 OID 30044)
-- Name: updatediscount(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatediscount() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatediscount() OWNER TO postgres;

--
-- TOC entry 289 (class 1255 OID 30045)
-- Name: updateinventory(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateinventory() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updateinventory() OWNER TO postgres;

--
-- TOC entry 290 (class 1255 OID 30046)
-- Name: updateorderdetail(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateorderdetail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updateorderdetail() OWNER TO postgres;

--
-- TOC entry 291 (class 1255 OID 30047)
-- Name: updateorderitem(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateorderitem() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updateorderitem() OWNER TO postgres;

--
-- TOC entry 292 (class 1255 OID 30048)
-- Name: updatepaymentdetail(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatepaymentdetail() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatepaymentdetail() OWNER TO postgres;

--
-- TOC entry 293 (class 1255 OID 30049)
-- Name: updateproduct(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateproduct() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updateproduct() OWNER TO postgres;

--
-- TOC entry 294 (class 1255 OID 30050)
-- Name: updatestore(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updatestore() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updatestore() OWNER TO postgres;

--
-- TOC entry 295 (class 1255 OID 30051)
-- Name: updateuser(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.updateuser() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.modified_at := now();
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.updateuser() OWNER TO postgres;

--
-- TOC entry 296 (class 1255 OID 30052)
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
-- TOC entry 310 (class 1255 OID 30053)
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
-- TOC entry 5212 (class 0 OID 0)
-- Dependencies: 310
-- Name: FUNCTION add_job(job_name text, job_schedule timetable.cron, job_command text, job_parameters jsonb, job_kind timetable.command_kind, job_client_name text, job_max_instances integer, job_live boolean, job_self_destruct boolean, job_ignore_errors boolean, job_exclusive boolean, job_on_error text); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.add_job(job_name text, job_schedule timetable.cron, job_command text, job_parameters jsonb, job_kind timetable.command_kind, job_client_name text, job_max_instances integer, job_live boolean, job_self_destruct boolean, job_ignore_errors boolean, job_exclusive boolean, job_on_error text) IS 'Add one-task chain (aka job) to the system';


--
-- TOC entry 311 (class 1255 OID 30054)
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
-- TOC entry 5213 (class 0 OID 0)
-- Dependencies: 311
-- Name: FUNCTION add_task(kind timetable.command_kind, command text, parent_id bigint, order_delta double precision); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.add_task(kind timetable.command_kind, command text, parent_id bigint, order_delta double precision) IS 'Add a task to the same chain as the task with parent_id';


--
-- TOC entry 312 (class 1255 OID 30055)
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
-- TOC entry 313 (class 1255 OID 30056)
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
-- TOC entry 314 (class 1255 OID 30057)
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
-- TOC entry 315 (class 1255 OID 30058)
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
-- TOC entry 316 (class 1255 OID 30059)
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
-- TOC entry 5214 (class 0 OID 0)
-- Dependencies: 316
-- Name: FUNCTION delete_job(job_name text); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.delete_job(job_name text) IS 'Delete the chain and its tasks from the system';


--
-- TOC entry 317 (class 1255 OID 30060)
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
-- TOC entry 5215 (class 0 OID 0)
-- Dependencies: 317
-- Name: FUNCTION delete_task(task_id bigint); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.delete_task(task_id bigint) IS 'Delete the task from a chain';


--
-- TOC entry 318 (class 1255 OID 30061)
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
-- TOC entry 301 (class 1255 OID 30063)
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
-- TOC entry 5216 (class 0 OID 0)
-- Dependencies: 301
-- Name: FUNCTION move_task_down(task_id bigint); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.move_task_down(task_id bigint) IS 'Switch the order of the task execution with a following task within the chain';


--
-- TOC entry 319 (class 1255 OID 30064)
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
-- TOC entry 5217 (class 0 OID 0)
-- Dependencies: 319
-- Name: FUNCTION move_task_up(task_id bigint); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.move_task_up(task_id bigint) IS 'Switch the order of the task execution with a previous task within the chain';


--
-- TOC entry 320 (class 1255 OID 30065)
-- Name: next_run(timetable.cron); Type: FUNCTION; Schema: timetable; Owner: postgres
--

CREATE FUNCTION timetable.next_run(cron timetable.cron) RETURNS timestamp with time zone
    LANGUAGE sql STRICT
    AS $$
    SELECT * FROM timetable.cron_runs(now(), cron) LIMIT 1
$$;


ALTER FUNCTION timetable.next_run(cron timetable.cron) OWNER TO postgres;

--
-- TOC entry 321 (class 1255 OID 30066)
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
-- TOC entry 5218 (class 0 OID 0)
-- Dependencies: 321
-- Name: FUNCTION notify_chain_start(chain_id bigint, worker_name text, start_delay interval); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.notify_chain_start(chain_id bigint, worker_name text, start_delay interval) IS 'Send notification to the worker to start the chain';


--
-- TOC entry 322 (class 1255 OID 30067)
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
-- TOC entry 5219 (class 0 OID 0)
-- Dependencies: 322
-- Name: FUNCTION notify_chain_stop(chain_id bigint, worker_name text); Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON FUNCTION timetable.notify_chain_stop(chain_id bigint, worker_name text) IS 'Send notification to the worker to stop the chain';


--
-- TOC entry 323 (class 1255 OID 30068)
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
-- TOC entry 324 (class 1255 OID 30069)
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
-- TOC entry 5220 (class 0 OID 0)
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
-- TOC entry 5221 (class 0 OID 0)
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
    payment_type character varying(30) NOT NULL,
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
-- TOC entry 5222 (class 0 OID 0)
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
-- TOC entry 5223 (class 0 OID 0)
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
-- TOC entry 5224 (class 0 OID 0)
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
    username character varying(15) NOT NULL,
    password character varying(20) NOT NULL,
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
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE account.user_user_id_seq OWNER TO postgres;

--
-- TOC entry 5225 (class 0 OID 0)
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
-- TOC entry 5226 (class 0 OID 0)
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
-- TOC entry 5227 (class 0 OID 0)
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
-- TOC entry 5228 (class 0 OID 0)
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
    modified_at timestamp with time zone DEFAULT now() NOT NULL
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
-- TOC entry 5229 (class 0 OID 0)
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
    quantity integer NOT NULL,
    minimum_stock integer DEFAULT 0,
    status boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    modified_at timestamp with time zone DEFAULT now()
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
-- TOC entry 5230 (class 0 OID 0)
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
-- TOC entry 5231 (class 0 OID 0)
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
    price numeric NOT NULL,
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
-- TOC entry 5232 (class 0 OID 0)
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
-- TOC entry 5233 (class 0 OID 0)
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
-- TOC entry 5234 (class 0 OID 0)
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
-- TOC entry 5235 (class 0 OID 0)
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
    user_id integer NOT NULL,
    product_id integer NOT NULL,
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
-- TOC entry 5236 (class 0 OID 0)
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
-- TOC entry 5237 (class 0 OID 0)
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
-- TOC entry 5238 (class 0 OID 0)
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
    total money DEFAULT 0 NOT NULL,
    delivery_method character varying(40),
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
-- TOC entry 5239 (class 0 OID 0)
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
-- TOC entry 5240 (class 0 OID 0)
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
    modified_at timestamp with time zone DEFAULT now(),
    delivery_provider_id integer NOT NULL,
    CONSTRAINT condition_check CHECK (((condition)::text = ANY (ARRAY[('Pending Confirmation'::character varying)::text, ('Pending Pickup'::character varying)::text, ('In transit'::character varying)::text, ('Delivered'::character varying)::text, ('Return Initiated'::character varying)::text, ('Order Cancelled'::character varying)::text])))
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
-- TOC entry 5241 (class 0 OID 0)
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
-- TOC entry 5242 (class 0 OID 0)
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
-- TOC entry 5243 (class 0 OID 0)
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
    price numeric NOT NULL,
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
-- TOC entry 5244 (class 0 OID 0)
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
-- TOC entry 5245 (class 0 OID 0)
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
-- TOC entry 5246 (class 0 OID 0)
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
-- TOC entry 5247 (class 0 OID 0)
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
-- TOC entry 5248 (class 0 OID 0)
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
-- TOC entry 5249 (class 0 OID 0)
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
-- TOC entry 5250 (class 0 OID 0)
-- Dependencies: 267
-- Name: TABLE chain; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.chain IS 'Stores information about chains schedule';


--
-- TOC entry 5251 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.run_at; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.run_at IS 'Extended CRON-style time notation the chain has to be run at';


--
-- TOC entry 5252 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.max_instances; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.max_instances IS 'Number of instances (clients) this chain can run in parallel';


--
-- TOC entry 5253 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.timeout; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.timeout IS 'Abort any chain that takes more than the specified number of milliseconds';


--
-- TOC entry 5254 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.live; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.live IS 'Indication that the chain is ready to run, set to FALSE to pause execution';


--
-- TOC entry 5255 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.self_destruct; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.self_destruct IS 'Indication that this chain will delete itself after successful run';


--
-- TOC entry 5256 (class 0 OID 0)
-- Dependencies: 267
-- Name: COLUMN chain.exclusive_execution; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.chain.exclusive_execution IS 'All parallel chains should be paused while executing this chain';


--
-- TOC entry 5257 (class 0 OID 0)
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
-- TOC entry 5258 (class 0 OID 0)
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
-- TOC entry 5259 (class 0 OID 0)
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
-- TOC entry 5260 (class 0 OID 0)
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
-- TOC entry 5261 (class 0 OID 0)
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
-- TOC entry 5262 (class 0 OID 0)
-- Dependencies: 273
-- Name: TABLE task; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON TABLE timetable.task IS 'Holds information about chain elements aka tasks';


--
-- TOC entry 5263 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.chain_id; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.chain_id IS 'Link to the chain, if NULL task considered to be disabled';


--
-- TOC entry 5264 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.task_order; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.task_order IS 'Indicates the order of task within a chain';


--
-- TOC entry 5265 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.kind; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.kind IS 'Indicates whether "command" is SQL, built-in function or an external program';


--
-- TOC entry 5266 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.command; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.command IS 'Contains either an SQL command, or command string to be executed';


--
-- TOC entry 5267 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.run_as; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.run_as IS 'Role name to run task as. Uses SET ROLE for SQL commands';


--
-- TOC entry 5268 (class 0 OID 0)
-- Dependencies: 273
-- Name: COLUMN task.ignore_error; Type: COMMENT; Schema: timetable; Owner: postgres
--

COMMENT ON COLUMN timetable.task.ignore_error IS 'Indicates whether a next task in a chain can be executed regardless of the success of the current one';


--
-- TOC entry 5269 (class 0 OID 0)
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
-- TOC entry 5270 (class 0 OID 0)
-- Dependencies: 274
-- Name: task_task_id_seq; Type: SEQUENCE OWNED BY; Schema: timetable; Owner: postgres
--

ALTER SEQUENCE timetable.task_task_id_seq OWNED BY timetable.task.task_id;


--
-- TOC entry 4864 (class 2604 OID 30246)
-- Name: address address_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.address ALTER COLUMN address_id SET DEFAULT nextval('account.address_address_id_seq'::regclass);


--
-- TOC entry 4865 (class 2604 OID 30247)
-- Name: payment payment_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.payment ALTER COLUMN payment_id SET DEFAULT nextval('account.payment_register_pay_id_seq'::regclass);


--
-- TOC entry 4866 (class 2604 OID 30248)
-- Name: role role_id; Type: DEFAULT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.role ALTER COLUMN role_id SET DEFAULT nextval('account.role_role_id_seq'::regclass);


--
-- TOC entry 4869 (class 2604 OID 30250)
-- Name: delivery_provider delivery_provider_id; Type: DEFAULT; Schema: delivery; Owner: postgres
--

ALTER TABLE ONLY delivery.delivery_provider ALTER COLUMN delivery_provider_id SET DEFAULT nextval('delivery.delivery_provider_delivery_provider_id_seq'::regclass);


--
-- TOC entry 4872 (class 2604 OID 30251)
-- Name: category category_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.category ALTER COLUMN category_id SET DEFAULT nextval('product.category_category_id_seq'::regclass);


--
-- TOC entry 4876 (class 2604 OID 30252)
-- Name: discount discount_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.discount ALTER COLUMN discount_id SET DEFAULT nextval('product.discount_discount_id_seq'::regclass);


--
-- TOC entry 4880 (class 2604 OID 30253)
-- Name: inventory inventory_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.inventory ALTER COLUMN inventory_id SET DEFAULT nextval('product.inventory_inventory_id_seq'::regclass);


--
-- TOC entry 4885 (class 2604 OID 30254)
-- Name: product product_id; Type: DEFAULT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product ALTER COLUMN product_id SET DEFAULT nextval('product.product_product_id_seq'::regclass);


--
-- TOC entry 4889 (class 2604 OID 30255)
-- Name: cart_item cart_item_id; Type: DEFAULT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item ALTER COLUMN cart_item_id SET DEFAULT nextval('shopping.cart_item_cart_item_id_seq'::regclass);


--
-- TOC entry 4892 (class 2604 OID 30256)
-- Name: order_detail order_detail_id; Type: DEFAULT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail ALTER COLUMN order_detail_id SET DEFAULT nextval('shopping.order_detail_order_detail_id_seq'::regclass);


--
-- TOC entry 4896 (class 2604 OID 30257)
-- Name: order_item order_item_id; Type: DEFAULT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item ALTER COLUMN order_item_id SET DEFAULT nextval('shopping.order_item_order_item_id_seq'::regclass);


--
-- TOC entry 4900 (class 2604 OID 30258)
-- Name: delivery_method delivery_method_id; Type: DEFAULT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.delivery_method ALTER COLUMN delivery_method_id SET DEFAULT nextval('store.delivery_methods_delivery_method_id_seq'::regclass);


--
-- TOC entry 4905 (class 2604 OID 30259)
-- Name: store store_id; Type: DEFAULT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store ALTER COLUMN store_id SET DEFAULT nextval('store.store_store_id_seq'::regclass);


--
-- TOC entry 4910 (class 2604 OID 30260)
-- Name: chain chain_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain ALTER COLUMN chain_id SET DEFAULT nextval('timetable.chain_chain_id_seq'::regclass);


--
-- TOC entry 4918 (class 2604 OID 30261)
-- Name: task task_id; Type: DEFAULT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task ALTER COLUMN task_id SET DEFAULT nextval('timetable.task_task_id_seq'::regclass);


--
-- TOC entry 5151 (class 0 OID 30071)
-- Dependencies: 221
-- Data for Name: address; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.address (address_id, user_id, address, city, postal_code, country) FROM stdin;
1	1	35 Vong Street	Ha Noi	0001	Viet Nam
2	2	123 Main St	New York	10001	USA
3	3	456 Elm St	Los Angeles	90001	USA
4	4	789 Oak St	Chicago	60601	USA
5	5	321 Pine St	London	SW1A 1AA	UK
6	6	654 Birch St	Sydney	2000	Australia
7	7	987 Cedar St	Paris	75001	France
8	8	210 Oakwood Ave	Toronto	M4C 1M7	Canada
9	9	555 Maple St	Berlin	10115	Germany
10	10	888 Walnut St	Tokyo	100-0001	Japan
11	11	111 Willow St	Madrid	28001	Spain
12	12	222 Cedar St	Rome	00184	Italy
13	13	333 Oak St	Moscow	101000	Russia
14	14	444 Maple St	Beijing	100000	China
15	15	555 Elm St	Cape Town	8001	South Africa
16	16	666 Pine St	Rio de Janeiro	20040	Brazil
17	17	777 Birch St	Dubai	12345	UAE
18	18	888 Oakwood Ave	Mumbai	400001	India
19	19	999 Walnut St	Sydney	2000	Australia
20	20	1010 Cedar St	Seoul	04524	South Korea
21	21	1111 Willow St	Berlin	10117	Germany
22	22	2222 Cedar St	Tokyo	100-0004	Japan
23	23	3333 Oak St	Paris	75009	France
24	24	4444 Maple St	New York	10007	USA
25	25	5555 Elm St	Sydney	2000	Australia
26	26	6666 Pine St	Mexico City	01000	Mexico
27	27	7777 Birch St	Moscow	101000	Russia
28	28	8888 Oakwood Ave	Cape Town	8001	South Africa
29	29	9999 Walnut St	Seoul	04532	South Korea
30	30	10101 Cedar St	Beijing	100000	China
31	31	11111 Willow St	London	SW1A 1AA	UK
32	32	22222 Cedar St	Berlin	10115	Germany
34	34	44444 Maple St	New York	10013	USA
35	35	55555 Elm St	Sydney	2000	Australia
36	36	66666 Pine St	Mexico City	01000	Mexico
37	37	77777 Birch St	Moscow	101000	Russia
38	38	88888 Oakwood Ave	Cape Town	8001	South Africa
39	39	99999 Walnut St	Seoul	04534	South Korea
40	40	101010 Cedar St	Beijing	100000	China
41	41	111111 Willow St	Paris	75001	France
42	42	222222 Cedar St	London	SW1A 1AA	UK
44	44	444444 Maple St	Tokyo	100-0004	Japan
47	47	777777 Birch St	Mexico City	01000	Mexico
48	48	888888 Oakwood Ave	Moscow	101000	Russia
50	50	101010 Cedar St	Seoul	04534	South Korea
51	51	789 Long Street	Beijing	100000	China
52	52	221 Rue de la Paix	Paris	75001	France
53	53	15 Oxford Street	London	SW1A 1AA	UK
54	54	12 Brandenburg Gate	Berlin	10117	Germany
55	55	7 Ginza Avenue	Tokyo	100-0004	Japan
56	56	456 Park Avenue	New York	10007	USA
57	57	123 Bondi Beach Road	Sydney	2000	Australia
58	58	10 Zvenigorodskoye Shosse	Moscow	123456	Russia
59	59	99 Table Mountain Blvd	Cape Town	8001	South Africa
60	60	321 Gangnam-daero	Seoul	04534	South Korea
63	63	30 Leicester Square	London	WC2H 7LA	UK
64	64	40 Unter den Linden	Berlin	10117	Germany
66	66	350 Fifth Avenue	New York	10118	USA
68	68	1 Red Square	Moscow	109012	Russia
69	69	Table Mountain National Park	Cape Town	8001	South Africa
70	70	513 Yeongdong-daero	Seoul	06164	South Korea
71	71	456 Nanjing Road	Shanghai	200001	China
72	72	27 Via della Conciliazione	Rome	00193	Italy
74	74	50 Elgin Street	Ottawa	K1P 5K8	Canada
76	76	2 Rue des Rosiers	Paris	75004	France
77	77	Kurfürstendamm 231	Berlin	10719	Germany
78	78	10 Downing Street	London	SW1A 2AA	UK
79	79	1 Mannerheimintie	Helsinki	00100	Finland
80	80	Plaza de la Constitución	Mexico City	06066	Mexico
82	82	1 Alexanderplatz	Berlin	10178	Germany
84	84	Champs de Mars, 5 Avenue Anatole	Paris	75007	France
85	85	1 Harbourfront Ave	Toronto	M5V 3K2	Canada
86	86	9 de Julio Avenue	Buenos Aires	C1073ABA	Argentina
87	87	Kaivokatu 1	Helsinki	00101	Finland
88	88	123 Paseo de la Reforma	Mexico City	06500	Mexico
90	90	1 OConnell Street	Sydney	2000	Australia
91	91	Strada Stavropoleos 3	Bucharest	030081	Romania
92	92	Ulitsa Tverskaya 1	Moscow	125009	Russia
93	93	Piazza del Duomo	Milan	20121	Italy
94	94	Kapellestraße 5	Vienna	1010	Austria
95	95	Avenida Diagonal 605	Barcelona	08028	Spain
96	96	Kungsträdgården 1	Stockholm	111 47	Sweden
97	97	Friedrichstraße 101	Berlin	10117	Germany
98	98	Rua Augusta 175	São Paulo	01305-000	Brazil
99	99	Via della Conciliazione 5	Vatican City	00193	Vatican City
100	100	Princes Street Gardens	Edinburgh	EH2 2HG	UK
\.


--
-- TOC entry 5154 (class 0 OID 30076)
-- Dependencies: 224
-- Data for Name: payment; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.payment (payment_id, user_id, payment_type, provider, account_no, expiry) FROM stdin;
4	1	Credit Card	\N	\N	\N
5	2	Credit Card	\N	\N	\N
6	3	Credit Card	\N	\N	\N
7	4	Credit Card	\N	\N	\N
8	5	Credit Card	\N	\N	\N
9	6	Credit Card	\N	\N	\N
10	7	Credit Card	\N	\N	\N
11	8	Credit Card	\N	\N	\N
12	9	Credit Card	\N	\N	\N
13	10	Credit Card	\N	\N	\N
14	11	Credit Card	\N	\N	\N
15	12	Credit Card	\N	\N	\N
16	13	Credit Card	\N	\N	\N
17	14	Credit Card	\N	\N	\N
18	15	Credit Card	\N	\N	\N
19	16	Credit Card	\N	\N	\N
20	17	Credit Card	\N	\N	\N
21	18	Credit Card	\N	\N	\N
22	19	Credit Card	\N	\N	\N
23	20	Credit Card	\N	\N	\N
24	21	Credit Card	\N	\N	\N
25	22	Credit Card	\N	\N	\N
26	23	Credit Card	\N	\N	\N
27	24	Credit Card	\N	\N	\N
28	25	Credit Card	\N	\N	\N
29	26	Credit Card	\N	\N	\N
30	27	Credit Card	\N	\N	\N
31	28	Credit Card	\N	\N	\N
32	29	Credit Card	\N	\N	\N
33	30	Credit Card	\N	\N	\N
34	31	Credit Card	\N	\N	\N
35	32	Credit Card	\N	\N	\N
37	34	Credit Card	\N	\N	\N
38	35	Credit Card	\N	\N	\N
39	36	Credit Card	\N	\N	\N
40	37	Credit Card	\N	\N	\N
41	38	Credit Card	\N	\N	\N
42	39	Credit Card	\N	\N	\N
43	40	Credit Card	\N	\N	\N
44	41	Credit Card	\N	\N	\N
45	42	Credit Card	\N	\N	\N
47	44	Credit Card	\N	\N	\N
50	47	Credit Card	\N	\N	\N
51	48	Credit Card	\N	\N	\N
53	50	Credit Card	\N	\N	\N
54	51	Credit Card	\N	\N	\N
55	52	Credit Card	\N	\N	\N
56	53	Credit Card	\N	\N	\N
57	54	Credit Card	\N	\N	\N
58	55	Credit Card	\N	\N	\N
59	56	Credit Card	\N	\N	\N
60	57	Credit Card	\N	\N	\N
61	58	Credit Card	\N	\N	\N
62	59	Credit Card	\N	\N	\N
63	60	Credit Card	\N	\N	\N
66	63	Credit Card	\N	\N	\N
67	64	Credit Card	\N	\N	\N
69	66	Credit Card	\N	\N	\N
71	68	Credit Card	\N	\N	\N
72	69	Credit Card	\N	\N	\N
73	70	Credit Card	\N	\N	\N
74	71	Credit Card	\N	\N	\N
75	72	Credit Card	\N	\N	\N
77	74	Credit Card	\N	\N	\N
79	76	Credit Card	\N	\N	\N
80	77	Credit Card	\N	\N	\N
81	78	Credit Card	\N	\N	\N
82	79	Credit Card	\N	\N	\N
83	80	Credit Card	\N	\N	\N
85	82	Credit Card	\N	\N	\N
87	84	Credit Card	\N	\N	\N
88	85	Credit Card	\N	\N	\N
89	86	Credit Card	\N	\N	\N
90	87	Credit Card	\N	\N	\N
91	88	Credit Card	\N	\N	\N
93	90	Credit Card	\N	\N	\N
94	91	Credit Card	\N	\N	\N
95	92	Credit Card	\N	\N	\N
96	93	Credit Card	\N	\N	\N
97	94	Credit Card	\N	\N	\N
98	95	Credit Card	\N	\N	\N
99	96	Credit Card	\N	\N	\N
100	97	Credit Card	\N	\N	\N
101	98	Credit Card	\N	\N	\N
102	99	Credit Card	\N	\N	\N
103	100	Credit Card	\N	\N	\N
\.


--
-- TOC entry 5157 (class 0 OID 30082)
-- Dependencies: 227
-- Data for Name: role; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.role (role_id, name) FROM stdin;
1	CUSTOMER
2	SELLER
\.


--
-- TOC entry 5159 (class 0 OID 30086)
-- Dependencies: 229
-- Data for Name: user; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account."user" (user_id, username, password, first_name, last_name, created_at, modified_at, telephone) FROM stdin;
8	davidmartin	Dav!dM	David	Martin	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	5554443333
9	olivialee88	Oliv!aLee	Olivia	Lee	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	4445556666
10	williamdavis	W1ll!amD	William	Davis	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	6667778888
11	sophiawilson	S0ph!aW	Sophia	Wilson	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+34 123 456 789
12	charlesgarcia	Ch@rlie456	Charles	Garcia	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+39 333 444 555
13	elizabethlopez	El!z@bethL	Elizabeth	Lopez	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+7 999 888 7777
14	jacobrodriguez	J@c0bR	Jacob	Rodriguez	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+86 10 1234 5678
15	avafernandez	Av@F3rn	Ava	Fernandez	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+27 21 987 6543
16	ethanjackson	3th@nJ	Ethan	Jackson	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+55 21 3456 7890
17	miahill	M!aHill	Mia	Hill	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+971 50 678 1234
18	alexandermurphy	Al3x@nd3rM	Alexander	Murphy	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+91 98765 43210
19	gracegreen	Gr@ceG	Grace	Green	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+61 2 3456 7890
20	danielcarter	D@ni3lC	Daniel	Carter	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+82 2 9876 5432
21	chloewright	Chl03W	Chloe	Wright	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+49 30 1234567
22	madisonnguyen	M@dyNg	Madison	Nguyen	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+81 3 9876 5432
23	lucasrivera	Luk@Riv	Lucas	Rivera	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+33 1 2345 6789
24	victoriaharris	V1ct0ri@H	Victoria	Harris	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+1 212-345-6789
25	gabrielturner	G@bi3lT	Gabriel	Turner	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+61 2 8765 4321
26	ameliasmith	Am3liaS	Amelia	Smith	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+52 55 1234 5678
27	nathanmartinez	N@thanM	Nathan	Martinez	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+7 495 678 90 12
28	ellaevans	3ll@E	Ella	Evans	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+27 21 876 5432
29	samueljohnson	S@mJ	Samuel	Johnson	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+82 2 3456 7890
30	aubreyroberts	Aubr3yR	Aubrey	Roberts	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	+86 10 9876 5432
31	williamlove	L0veW1l	William	Smith	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+44 20 1234 5678
32	sarahheart	H3artS@	Sarah	Johnson	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+49 30 9876 5432
34	oliviaromance	Rom@nc3O	Olivia	Jones	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+1 212-345-6789
35	charlesamour	Am0urCh@	Charles	Wang	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+61 2 9876 5432
36	emilysweet	Sw33tEmi	Emily	Miller	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+52 55 9876 5432
37	michaelkiss	K!ssMic@	Michael	Martin	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+7 495 123 45 67
38	jacobvalentine	V@l3nt!n	Jacob	Lee	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+27 21 987 6543
39	ellalover	L0v3r3ll	Ella	Davis	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+82 2 8765 4321
40	victoriadream	Dr3amV1c	Victoria	Wilson	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+86 10 1234 5678
41	gracepassionate	P@ss!on	Grace	Garcia	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+33 1 2345 6789
42	ethanromantic	R0m@nt!c	Ethan	Lopez	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+44 20 8765 4321
44	nathanheartfelt	H3@rtf3l	Nathan	Fernandez	2023-12-29 00:32:15.279887+07	2024-01-05 12:34:41.093652+07	+81 3 1234 5678
47	willowlove	L0veWill	Willow	Smith	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+52 55 1234 5678
48	gracieheart	H3artG@	Gracie	Johnson	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+7 495 123 45 67
50	oliviajoy	J0yOl!v	Olivia	Jones	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+82 2 1234 5678
51	charlieamour	Am0urChl	Charlie	Wang	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+86 10 1234 5678
52	emilyspirit	Sp!ritEm	Emily	Miller	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+33 1 2345 6789
53	michaelathlete	Athl3teM	Michael	Martin	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+44 20 8765 4321
54	jacobsoccer	S0cc3rJ@	Jacob	Lee	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+49 30 1234567
55	ellabasket	Bask3tEl	Ella	Davis	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+81 3 1234 5678
56	vickytennis	T3nn!sV	Vicky	Wilson	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+1 212-345-6789
57	gracelight	L!ghtGr@	Grace	Garcia	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+61 2 9876 5432
58	ethanamore	Am0r3Eth	Ethan	Lopez	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+7 495 123 45 67
59	madcheering	Che3rM@d	Madison	Rodriguez	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+27 21 123 4567
60	nathanrun	RunN@th	Nathan	Fernandez	2023-12-29 00:33:28.839537+07	2024-01-05 12:34:41.093652+07	+82 2 1234 5678
63	willowsport	Sp0rtWil	Willow	Smith	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+44 20 1234 5678
64	gracefullove	L0veGr@	Graceful	Johnson	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+49 30 9876543
66	oliviaactive	Act!vOl	Olivia	Jones	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+1 212-555-1234
68	emilysoccer	S0cc3rEm	Emily	Miller	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+7 495 678 90 12
69	michaelrunner	Runn3rM!	Michael	Martin	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+27 21 234 5678
70	jacobpassion	P@ss!nJ	Jacob	Lee	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+82 2 3456 7890
71	ellagym	GymEll@	Ella	Davis	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+86 21 9876 5432
72	vickyball	B@llV!c	Vicky	Wilson	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+39 06 1234 5678
74	ethanjoy	J0yEth@	Ethan	Lopez	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+1 613-234-5678
76	nathanrunner	Runn3rN	Nathan	Fernandez	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+33 1 2345 6789
77	ameliarunner	Runn3rAm	Amelia	Jackson	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+49 30 1234567
78	lucasactive	Act!vLu	Lucas	Roberts	2023-12-29 00:34:32.398514+07	2024-01-05 12:34:41.093652+07	+44 20 8765 4321
79	willowsports	SportWil	Willow	Smith	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+358 9 87654321
80	gracelovely	Lov3lyGr	Grace	Johnson	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+52 55 1234 5678
82	oliviaball	B@llOli	Olivia	Jones	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+49 30 987654321
84	emilyactive	Activ3Em	Emily	Miller	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+33 1 2345 6789
85	michaelplayer	Pl@yerMi	Michael	Martin	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+1 416-890-1234
1	buiminh3344	supersss	Bui Minh	Nam	2023-12-29 00:26:04.864141+07	2024-01-05 12:34:41.093652+07	0834342234
2	johndoe123	Pas$wordJohn	John	Smith	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	1234567890
3	janedoe456	Ja@nePass	Jane	Johnson	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	0987654321
4	robertbrown	R0bert&456	Robert	Brown	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	1112223333
5	emilyjones	EmilyJ*nes	Emily	Jones	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	9998887777
6	michaelwang	Mich@elW	Michael	Wang	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	3332221111
7	sarahmiller	S@rahM123	Sarah	Miller	2023-12-29 00:30:25.788091+07	2024-01-05 12:34:41.093652+07	7778889999
86	jacobpassionate	P@ssionJ	Jacob	Lee	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+54 11 8765-4321
87	ellagame	Gam3Ella	Ella	Davis	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+358 9 87654321
88	vickyactive	Act!veV	Vicky	Wilson	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+52 55 1234 5678
90	ethanjoyful	J0yfulE	Ethan	Lopez	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+61 2 1234 5678
91	madisonrunner	Runn3rM	Madison	Rodriguez	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+40 21 123 4567
92	nathanactive	Act!v3N	Nathan	Fernandez	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+7 495 987 6543
93	ameliarun	RunAmel	Amelia	Jackson	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+39 02 8765 4321
94	lucasathletic	Athl3tic	Lucas	Roberts	2023-12-29 00:35:01.966202+07	2024-01-05 12:34:41.093652+07	+43 1 2345678
95	willowrun	RunWil1	Willow	Smith	2023-12-29 00:35:36.01193+07	2024-01-05 12:34:41.093652+07	+34 93 123 45 67
96	gracefulplay	Pl@yfulG	Graceful	Johnson	2023-12-29 00:35:36.01193+07	2024-01-05 12:34:41.093652+07	+46 8 765 4321
97	davidsport	Sp0rtD@	David	Brown	2023-12-29 00:35:36.01193+07	2024-01-05 12:34:41.093652+07	+49 30 23456789
98	oliviakick	K!ckOli	Olivia	Jones	2023-12-29 00:35:36.01193+07	2024-01-05 12:34:41.093652+07	+55 11 8765 4321
99	charliefit	F!tCh@r	Charlie	Wang	2023-12-29 00:35:36.01193+07	2024-01-05 12:34:41.093652+07	+379 1234 5678
100	emilyball	B@llEmi	Emily	Miller	2023-12-29 00:35:36.01193+07	2024-01-05 12:34:41.093652+07	+44 131 123 4567
\.


--
-- TOC entry 5160 (class 0 OID 30091)
-- Dependencies: 230
-- Data for Name: user_role; Type: TABLE DATA; Schema: account; Owner: postgres
--

COPY account.user_role (user_id, role_id) FROM stdin;
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
34	1
35	1
36	1
37	1
38	1
39	1
40	1
41	1
42	1
44	1
47	1
48	1
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
63	1
64	1
66	1
68	1
69	1
70	1
71	1
72	1
74	1
76	1
77	1
78	1
79	1
80	1
82	1
84	1
85	1
1	1
2	1
3	1
4	1
5	1
6	1
7	1
86	1
87	1
88	1
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
10	2
11	2
12	2
13	2
15	2
16	2
17	2
18	2
19	2
20	2
21	2
22	2
24	2
25	2
26	2
27	2
28	2
29	2
30	2
31	2
32	2
34	2
35	2
36	2
37	2
38	2
39	2
41	2
48	2
52	2
54	2
55	2
58	2
60	2
63	2
64	2
66	2
68	2
70	2
71	2
72	2
74	2
76	2
77	2
78	2
79	2
82	2
84	2
85	2
1	2
86	2
87	2
88	2
90	2
91	2
\.


--
-- TOC entry 5162 (class 0 OID 30095)
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
-- TOC entry 5164 (class 0 OID 30101)
-- Dependencies: 234
-- Data for Name: category; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.category (category_id, name, description, is_active, created_at, modified_at, parent_id) FROM stdin;
45	Eletronics	\N	t	2024-01-04 23:03:27.229551+07	2024-01-04 23:03:27.229551+07	\N
46	Clothing & Accessories	\N	t	2024-01-04 23:03:41.853469+07	2024-01-04 23:03:41.853469+07	\N
47	Home & Garden	\N	t	2024-01-04 23:03:52.166167+07	2024-01-04 23:03:52.166167+07	\N
48	Sports & Outdoors	\N	t	2024-01-04 23:04:08.807493+07	2024-01-04 23:04:08.807493+07	\N
49	Beauty & Health	\N	t	2024-01-04 23:04:22.275206+07	2024-01-04 23:04:22.275206+07	\N
50	Toys & Games	\N	t	2024-01-04 23:04:31.100383+07	2024-01-04 23:04:31.100383+07	\N
51	Books & Media	\N	t	2024-01-04 23:04:46.241557+07	2024-01-04 23:04:46.241557+07	\N
52	Automotive	\N	t	2024-01-04 23:04:54.054076+07	2024-01-04 23:04:54.054076+07	\N
53	Food & Beverages	\N	t	2024-01-04 23:05:03.933678+07	2024-01-04 23:05:03.933678+07	\N
54	Office Suplies	\N	t	2024-01-04 23:05:16.358229+07	2024-01-04 23:05:16.358229+07	\N
55	Computers & Laptops	\N	t	2024-01-04 23:06:47.93458+07	2024-01-04 23:06:47.93458+07	45
56	Smartphones & Tablets	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
57	TVs & Home Entertainment	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
58	Cameras & Photography	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
59	Audio & Headphones	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
60	Gaming Consoles & Accessories	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
61	Computers & Laptops	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
62	Wearable Technology	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
63	Home Appliances	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
64	Office Electronics	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
65	Supporter	\N	t	2024-01-04 23:07:49.33291+07	2024-01-04 23:07:49.33291+07	45
66	Men Clothing	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
67	Women Clothing	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
68	Kids Clothing	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
69	Shoes	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
70	Bags & Backpacks	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
71	Accessories	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
72	Jewelry	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
73	Watches	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
74	Sunglasses	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
75	Intimate Apparel	\N	t	2024-01-04 23:09:37.189647+07	2024-01-04 23:09:37.189647+07	46
76	Furniture	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
77	Kitchen & Dining	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
78	Home Décor	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
79	Bedding & Bath	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
80	Gardening & Lawn Care	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
81	Home Improvement	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
82	Patio, Lawn & Garden	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
83	Appliances	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
84	Pet Supplies	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
85	Storage & Organization	\N	t	2024-01-04 23:10:13.967789+07	2024-01-04 23:10:13.967789+07	47
86	Outdoor Recreation	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
87	Fitness & Exercise	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
88	Camping & Hiking	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
89	Team Sports	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
90	Cycling	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
91	Water Sports	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
92	Winter Sports	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
93	Hunting & Fishing	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
94	Athletic Shoes	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
95	Fan Shop	\N	t	2024-01-04 23:11:04.076916+07	2024-01-04 23:11:04.076916+07	48
96	Skincare	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
97	Makeup	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
98	Hair Care	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
99	Bath & Body	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
100	Fragrances	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
101	Personal Care	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
102	Health & Wellness	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
103	Men\\s Grooming	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
104	Supplements	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
105	Beauty Accessories	\N	t	2024-01-04 23:11:43.360546+07	2024-01-04 23:11:43.360546+07	49
106	Action Figures	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
107	Dolls & Accessories	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
108	Building Toys	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
109	Board Games	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
110	Puzzles	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
111	Outdoor Toys	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
112	Educational Toys	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
113	Toy Vehicles	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
114	Video Games	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
115	Arts & Crafts	\N	t	2024-01-04 23:12:25.486786+07	2024-01-04 23:12:25.486786+07	50
116	Books	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
117	E-books	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
118	Magazines	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
119	Movies	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
120	Music	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
121	Podcasts	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
122	TV Shows	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
123	Video Streaming	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
124	Audiobooks	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
125	Digital Downloads	\N	t	2024-01-04 23:12:55.32481+07	2024-01-04 23:12:55.32481+07	51
126	Car Parts	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
127	Car Accessories	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
128	Car Electronics	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
129	Tools & Equipment	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
130	Motorcycle Parts	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
131	Truck Accessories	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
132	Oil & Fluids	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
133	Performance Parts	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
134	Tires & Wheels	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
135	Exterior Accessories	\N	t	2024-01-04 23:13:29.401714+07	2024-01-04 23:13:29.401714+07	52
136	Snacks & Sweets	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
137	Beverages	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
138	Baking & Cooking Ingredients	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
139	Dairy & Eggs	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
140	Frozen Foods	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
141	Canned Goods	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
142	Organic & Health Foods	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
143	Alcoholic Beverages	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
144	Coffee & Tea	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
145	Meat & Seafood	\N	t	2024-01-04 23:14:04.868975+07	2024-01-04 23:14:04.868975+07	53
146	Writing Instruments	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
147	Paper Products	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
148	Desk Organization	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
149	Office Furniture	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
150	Calendars & Planners	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
151	Presentation Supplies	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
152	Office Electronics	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
153	Shipping & Packing	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
154	Office Basics	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
155	School Supplies	\N	t	2024-01-04 23:14:43.995767+07	2024-01-04 23:14:43.995767+07	54
156	Laptops	\N	t	2024-01-04 23:17:46.370825+07	2024-01-04 23:17:46.370825+07	56
\.


--
-- TOC entry 5167 (class 0 OID 30111)
-- Dependencies: 237
-- Data for Name: discount; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.discount (discount_id, name, description, discount_percent, start_date, end_date, is_active, created_at, modified_at) FROM stdin;
\.


--
-- TOC entry 5169 (class 0 OID 30120)
-- Dependencies: 239
-- Data for Name: inventory; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.inventory (inventory_id, product_id, quantity, minimum_stock, status, created_at, modified_at) FROM stdin;
1	10	30	5	t	2024-01-04 23:52:25.533385+07	2024-01-04 23:52:25.533385+07
2	11	25	4	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
3	12	40	6	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
4	13	15	3	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
5	14	20	5	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
6	15	35	7	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
7	16	50	8	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
8	17	10	2	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
9	18	60	10	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
10	19	45	9	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
11	20	28	6	t	2024-01-04 23:53:44.719816+07	2024-01-04 23:53:44.719816+07
12	21	30	5	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
13	22	40	8	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
14	23	15	3	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
15	24	20	4	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
16	25	35	6	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
17	26	50	9	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
18	27	10	2	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
19	28	60	12	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
20	29	45	7	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
21	30	28	5	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
22	31	33	6	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
23	32	18	4	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
24	33	25	5	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
25	34	36	7	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
26	35	42	8	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
27	36	13	3	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
28	37	48	10	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
29	38	22	5	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
30	39	29	6	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
31	40	39	8	t	2024-01-04 23:54:07.278245+07	2024-01-04 23:54:07.278245+07
32	41	30	6	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
33	42	40	7	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
34	43	15	4	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
35	44	20	5	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
36	45	35	9	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
37	46	50	10	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
38	47	10	3	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
39	48	60	11	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
40	49	45	8	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
41	50	28	6	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
44	53	25	6	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
45	54	36	8	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
46	55	42	9	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
47	56	13	3	t	2024-01-04 23:54:25.968274+07	2024-01-04 23:54:25.968274+07
55	64	20	5	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
56	65	35	9	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
57	66	50	10	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
58	67	10	3	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
59	68	60	11	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
60	69	45	8	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
61	70	28	6	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
62	71	33	7	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
63	72	18	4	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
64	73	25	6	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
65	74	36	8	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
66	75	42	9	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
67	76	13	3	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
68	77	48	11	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
69	78	22	5	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
70	79	29	7	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
71	80	39	9	t	2024-01-04 23:54:45.597735+07	2024-01-04 23:54:45.597735+07
72	81	30	6	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
73	82	40	7	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
74	83	15	4	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
75	84	20	5	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
76	85	35	9	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
77	86	50	10	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
78	87	10	3	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
79	88	60	11	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
80	89	45	8	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
81	90	28	6	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
82	91	33	7	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
83	92	18	4	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
84	93	25	6	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
85	94	36	8	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
86	95	42	9	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
87	96	13	3	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
88	97	48	11	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
89	98	22	5	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
90	99	29	7	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
91	100	39	9	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
92	101	37	8	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
93	102	31	6	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
94	103	27	5	t	2024-01-04 23:55:23.444603+07	2024-01-04 23:55:23.444603+07
42	\N	33	7	t	2024-01-04 23:54:25.968274+07	2024-01-09 09:03:33.29252+07
43	\N	18	4	t	2024-01-04 23:54:25.968274+07	2024-01-09 09:03:33.29252+07
48	\N	48	11	t	2024-01-04 23:54:25.968274+07	2024-01-09 09:03:33.29252+07
49	\N	22	5	t	2024-01-04 23:54:25.968274+07	2024-01-09 09:03:33.29252+07
50	\N	29	7	t	2024-01-04 23:54:25.968274+07	2024-01-09 09:03:33.29252+07
51	\N	39	9	t	2024-01-04 23:54:25.968274+07	2024-01-09 09:03:33.29252+07
52	\N	30	6	t	2024-01-04 23:54:45.597735+07	2024-01-09 09:03:33.29252+07
53	\N	40	7	t	2024-01-04 23:54:45.597735+07	2024-01-09 09:03:33.29252+07
54	\N	15	4	t	2024-01-04 23:54:45.597735+07	2024-01-09 09:03:33.29252+07
\.


--
-- TOC entry 5172 (class 0 OID 30129)
-- Dependencies: 242
-- Data for Name: product; Type: TABLE DATA; Schema: product; Owner: postgres
--

COPY product.product (product_id, name, image, description, sku, category_id, price, discount_id, store_id, is_active, created_at, modified_at) FROM stdin;
10	Lenovo Victus	https://st4.tkcomputer.vn/uploads/lenovo_x1_carbon_gen5_1676547617_480.jpg	The ThinkPad X1 Carbon, part of the iconic ThinkPad series, embodies a perfect blend of portability, performance, and durability. Known for its sleek and lightweight design, this laptop features a carbon fiber chassis, making it exceptionally sturdy yet incredibly lightweight. The X1 Carbon boasts a vibrant and crisp display, providing an immersive viewing experience for work or entertainment. Equipped with powerful Intel processors, ample RAM, and fast SSD storage, it ensures swift multitasking and smooth performance. Moreover, its robust security features, such as the built-in fingerprint scanner and robust encryption, prioritize data security and privacy. Additionally, the X1 Carbons exceptional battery life and versatile connectivity options make it an ideal choice for professionals seeking a premium, high-performance laptop for business or personal use.	\N	156	100.00	\N	70	t	2024-01-04 23:23:23.353724+07	2024-01-04 23:25:52.19708+07
11	IBM ThinkPad T480	https://p1-ofp.static.pub/medias/bWFzdGVyfHJvb3R8MzQxOTQ4fGltYWdlL3BuZ3xoZmEvaDA4LzE0MzMyNjkwMTM3MTE4LnBuZ3xjMjJjNmIyOGQxNTVkYzRiYThiNDVkNTViMGFiZmY3MDNjYzFkMzIzM2QyYTRhM2U4YTBiMDJmMjQ1NWNlOTVk/lenovo-laptop-thinkpad-t480-hero.png	The IBM ThinkPad T480 offers robust performance and durability for business needs. With a sleek design, powerful Intel processors, and exceptional battery life, it\\s an ideal companion for professionals seeking reliability in their computing devices.	\N	156	899.99	\N	70	t	2024-01-04 23:34:30.548477+07	2024-01-04 23:34:30.548477+07
12	IBM ThinkPad X1 Yoga	https://www.lenovo.com/medias/lenovo-thinkpad-x1-yoga-gallery-01-Thinkpad-X1-YOGA-Hero-Front-facing-left-Black.jpg?context=bWFzdGVyfHJvb3R8MjEyNDMwfGltYWdlL2pwZWd8aDJjL2hmZi8xNDMzMjk4MzQ3NjI1NC5qcGd8Y2NiOGY0MjczNTNiMzM1NzUyZmE1MTc2ZjVjZTRmYTljZDBiOTFlNmNjMGVkYTlmYTc4NmVkZTUyNWNiNDcyNg	The IBM ThinkPad X1 Yoga is a versatile 2-in-1 laptop designed for flexibility and productivity. Featuring a durable chassis and a vibrant display, it seamlessly transitions between laptop and tablet modes, catering to work and creative tasks.	\N	156	1299.99	\N	70	t	2024-01-04 23:34:30.548477+07	2024-01-04 23:34:30.548477+07
13	IBM ThinkPad T60	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T60 is a classic laptop that was known for its reliability and durability during its time. Equipped with older Intel processors and featuring a sturdy build, it was a popular choice for professionals.	\N	156	399.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
14	IBM ThinkPad X41	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X41 was a compact and lightweight laptop known for its portability. Despite its smaller size, it offered decent performance and was suitable for on-the-go professionals.	\N	156	299.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
15	IBM ThinkPad R51	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad R51 was a reliable workhorse known for its sturdy design and decent performance. Although older, it was a dependable choice for everyday business tasks.	\N	156	249.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
16	IBM ThinkPad A31	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad A31 was a budget-friendly laptop offering decent performance and a comfortable keyboard. It catered to users seeking an affordable yet functional computing device.	\N	156	199.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
17	IBM ThinkPad T42	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T42 was a reliable and durable laptop known for its robust build and security features. It was favored by professionals needing a dependable work companion.	\N	156	299.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
18	IBM ThinkPad X31	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X31 was a compact and lightweight laptop known for its portability. Despite its smaller size, it offered decent performance and was suitable for on-the-go professionals.	\N	156	249.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
112	Dell Latitude D630c	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude D630c was a reliable business laptop known for its robust build and reliability.	\N	156	349.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
113	Dell XPS 13 2-in-1	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS 13 2-in-1 was a versatile convertible laptop offering portability and performance.	\N	156	999.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
19	IBM ThinkPad R52	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad R52 was a reliable workhorse known for its sturdy design and decent performance. Although older, it was a dependable choice for everyday business tasks.	\N	156	299.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
20	IBM ThinkPad A22m	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad A22m was an affordable and durable laptop designed for basic computing tasks. Despite its age, it offered reliability for everyday use.	\N	156	149.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
21	IBM ThinkPad T30	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T30 was a robust and reliable laptop known for its durability and security features. It was a suitable choice for professionals requiring a dependable work device.	\N	156	199.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
22	IBM ThinkPad 600	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 600 was a classic laptop that offered a balance of performance and portability during its time. Known for its reliability, it was a popular choice among professionals.	\N	156	299.99	\N	70	t	2024-01-04 23:37:56.155002+07	2024-01-04 23:37:56.155002+07
23	IBM ThinkPad 701C	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 701C was known for its innovative butterfly keyboard design and compact form factor. Despite its age, it was a testament to IBM\\s commitment to unique and functional design.	\N	156	399.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
24	IBM ThinkPad 380ED	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 380ED was a solid performer known for its durability and reliable performance. It catered to professionals requiring a dependable workhorse.	\N	156	299.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
25	IBM ThinkPad 760E	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 760E was a robust and reliable laptop offering decent performance and a comfortable keyboard. It was favored by professionals needing a dependable work companion.	\N	156	249.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
26	IBM ThinkPad 600E	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 600E was known for its reliability and functionality during its time. It was a popular choice for professionals seeking a balance of performance and portability.	\N	156	299.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
27	IBM ThinkPad A20m	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad A20m was a budget-friendly and durable laptop designed for basic computing tasks. Despite its age, it offered reliability for everyday use.	\N	156	199.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
28	IBM ThinkPad T22	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T22 was a robust and reliable laptop known for its durability and security features. It was a suitable choice for professionals requiring a dependable work device.	\N	156	199.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
29	IBM ThinkPad 390E	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 390E was a classic laptop offering a balance of performance and reliability. Known for its sturdy design, it was a popular choice among professionals.	\N	156	299.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
30	IBM ThinkPad 385XD	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad 385XD was a reliable workhorse known for its sturdy design and decent performance. Although older, it was a dependable choice for everyday business tasks.	\N	156	299.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
31	IBM ThinkPad i1400	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad i1400 was an affordable and durable laptop designed for basic computing tasks. Despite its age, it offered reliability for everyday use.	\N	156	149.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
32	IBM ThinkPad R40	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad R40 was known for its durability and security features. It was favored by professionals needing a reliable and secure work device.	\N	156	199.99	\N	70	t	2024-01-04 23:39:01.027321+07	2024-01-04 23:39:01.027321+07
33	IBM ThinkPad X200	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X200 was a compact and durable laptop known for its portability and decent performance. Despite its smaller size, it provided reliable computing power for professionals on-the-go.	\N	156	349.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
34	IBM ThinkPad T400	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T400 was a reliable workhorse known for its durability and robust performance. It was a suitable choice for professionals requiring a dependable work device.	\N	156	399.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
35	IBM ThinkPad W500	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad W500 was a powerful workstation laptop designed for demanding workloads. With its dedicated graphics and ample processing power, it excelled in handling intensive tasks like graphic design and engineering.	\N	156	599.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
36	IBM ThinkPad Edge 13	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad Edge 13 was a budget-friendly and compact laptop known for its simplicity and reliability. It catered to users seeking a basic yet dependable computing device.	\N	156	299.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
37	IBM ThinkPad SL410	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad SL410 was a business-oriented laptop offering decent performance and security features. It was a suitable choice for professionals prioritizing work-related functionalities.	\N	156	449.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
38	IBM ThinkPad L512	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad L512 was known for its sturdy build and reliability. Despite its age, it provided decent performance and was suitable for everyday business tasks.	\N	156	349.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
39	IBM ThinkPad X100e	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X100e was a compact and affordable laptop offering decent performance for basic computing needs. It was a suitable choice for students and casual users.	\N	156	249.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
40	IBM ThinkPad T410s	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T410s was a lightweight and powerful laptop known for its portability and robust performance. It catered to professionals seeking mobility without compromising power.	\N	156	499.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
41	IBM ThinkPad E220s	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad E220s was an ultraportable and sleek laptop known for its design and compactness. Despite its smaller size, it provided reliable performance.	\N	156	399.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
42	IBM ThinkPad R400	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad R400 was a reliable workhorse known for its sturdy design and decent performance. Although older, it was a dependable choice for everyday business tasks.	\N	156	349.99	\N	70	t	2024-01-04 23:40:02.815457+07	2024-01-04 23:40:02.815457+07
43	IBM ThinkPad X301	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X301 was a premium and lightweight laptop known for its portability and exceptional performance. Despite its smaller size, it provided reliable computing power for professionals.	\N	156	699.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
44	IBM ThinkPad T510	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T510 was a robust and reliable laptop known for its durability and performance. It was a suitable choice for professionals requiring a dependable work device.	\N	156	499.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
45	IBM ThinkPad W510	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad W510 was a powerful workstation laptop designed for demanding tasks. With its dedicated graphics and ample processing power, it excelled in handling intensive workloads.	\N	156	799.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
46	IBM ThinkPad Edge E420s	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad Edge E420s was a sleek and affordable laptop offering decent performance and reliability. It catered to users seeking a balance between functionality and design.	\N	156	399.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
47	IBM ThinkPad SL510	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad SL510 was a business-oriented laptop offering reliability and security features. It was a suitable choice for professionals seeking a work-focused device.	\N	156	449.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
48	IBM ThinkPad L412	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad L412 was known for its sturdy build and reliability. Despite its age, it provided decent performance and was suitable for everyday business tasks.	\N	156	349.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
49	IBM ThinkPad X120e	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X120e was a compact and affordable laptop offering decent performance for basic computing needs. It was a suitable choice for students and casual users.	\N	156	249.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
50	IBM ThinkPad T420s	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T420s was a lightweight and powerful laptop known for its portability and robust performance. It catered to professionals seeking mobility without compromising power.	\N	156	599.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
53	IBM ThinkPad T430	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad T430 was a reliable business-oriented laptop known for its durability and robust performance. It was a suitable choice for professionals requiring a dependable work device.	\N	156	549.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
54	IBM ThinkPad X230	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad X230 was a compact and powerful laptop known for its portability and performance. Despite its smaller size, it provided reliable computing power for professionals.	\N	156	499.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
55	IBM ThinkPad W530	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad W530 was a powerful workstation laptop designed for demanding tasks. With its dedicated graphics and ample processing power, it excelled in handling intensive workloads.	\N	156	899.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
56	IBM ThinkPad Edge E430	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The IBM ThinkPad Edge E430 was a sleek and affordable laptop offering decent performance and reliability. It catered to users seeking a balance between functionality and design.	\N	156	399.99	\N	70	t	2024-01-04 23:41:44.440343+07	2024-01-04 23:41:44.440343+07
64	Dell Latitude 7420	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude 7420 is a powerful and portable business laptop designed for professionals. With its durable build, vibrant display, and robust performance, it ensures productivity on-the-go.	\N	156	1299.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
65	Dell XPS 13	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS 13 is an ultraportable powerhouse known for its stunning display, sleek design, and impressive performance. Its a perfect blend of style and functionality.	\N	156	1399.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
66	Dell Inspiron 15 7000	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 15 7000 series offers a balance of performance and affordability, catering to users seeking reliable everyday computing.	\N	156	899.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
67	Dell G5 15 Gaming Laptop	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell G5 15 Gaming Laptop is a robust gaming machine, featuring powerful hardware and a high-refresh-rate display for an immersive gaming experience.	\N	156	1299.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
68	Dell Precision 5560	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Precision 5560 is a mobile workstation crafted for professionals requiring high-performance computing. With its powerful specs, it handles demanding tasks effortlessly.	\N	156	1899.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
69	Dell Vostro 14	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Vostro 14 is a reliable and affordable business laptop, designed to provide essential features and security for small businesses.	\N	156	599.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
70	Dell Alienware m15 R6	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Alienware m15 R6 is a high-performance gaming laptop with top-of-the-line specs, delivering an exceptional gaming experience in a portable form factor.	\N	156	1999.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
71	Dell Latitude 5520	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude 5520 is a versatile and durable business laptop that offers a perfect blend of performance and security features for professionals.	\N	156	1099.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
72	Dell XPS 17	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS 17 is a premium large-screen laptop that combines power and elegance, delivering an immersive viewing experience and exceptional performance.	\N	156	2199.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
73	Dell Inspiron 13 5000 2-in-1	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 13 5000 2-in-1 is a versatile convertible laptop offering flexibility and performance for both work and entertainment.	\N	156	799.99	\N	84	t	2024-01-04 23:47:55.922087+07	2024-01-04 23:47:55.922087+07
74	Dell Latitude E6430	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude E6430 was a reliable and durable business laptop, known for its robust build quality and reliable performance, suitable for professional use.	\N	156	499.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
75	Dell Studio 15	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Studio 15 was a multimedia-centric laptop offering decent performance and features for entertainment and media consumption.	\N	156	399.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
76	Dell XPS 15z	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS 15z was a slim and powerful laptop that stood out for its sleek design, powerful performance, and high-resolution display.	\N	156	899.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
77	Dell Inspiron 1525	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 1525 was a budget-friendly laptop offering decent performance for everyday computing tasks and casual usage.	\N	156	299.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
78	Dell Alienware 17 R4	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Alienware 17 R4 was a powerhouse gaming laptop with top-tier specs, designed to handle demanding games and deliver an immersive gaming experience.	\N	156	1599.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
79	Dell Precision M4800	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Precision M4800 was a robust mobile workstation offering high-end performance and reliability for professional users dealing with complex tasks.	\N	156	1199.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
80	Dell Vostro 3550	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Vostro 3550 was a business-oriented laptop with a sturdy build and essential features, catering to small business owners.	\N	156	399.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
81	Dell Inspiron Mini 10	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron Mini 10 was a compact and portable netbook, suitable for basic internet browsing and lightweight tasks.	\N	156	199.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
82	Dell XPS M1730	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS M1730 was a gaming laptop featuring dual GPUs, delivering high performance and catering to gaming enthusiasts.	\N	156	999.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
83	Dell Latitude D630	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude D630 was a durable and reliable business laptop known for its sturdy build and long-lasting performance.	\N	156	349.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
84	Dell Inspiron 14 5000 2-in-1	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 14 5000 2-in-1 was a versatile convertible laptop offering a blend of performance and flexibility for various computing needs.	\N	156	649.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
85	Dell Precision 7710	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Precision 7710 was a robust mobile workstation designed for professionals requiring high performance and reliability.	\N	156	1499.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
86	Dell Alienware 18	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Alienware 18 was a dual-GPU gaming laptop, providing exceptional gaming performance and a large display for immersive gameplay.	\N	156	1899.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
87	Dell Vostro 1000	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Vostro 1000 was a budget-friendly laptop designed for small businesses and home users, offering essential features and decent performance.	\N	156	249.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
88	Dell XPS M1330	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS M1330 was a compact and stylish laptop, known for its slim design and good performance, catering to mobile users.	\N	156	499.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
89	Dell Latitude E6410	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude E6410 was a reliable business laptop known for its sturdy build, security features, and reliable performance.	\N	156	399.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
90	Dell Inspiron 600m	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 600m was a compact and portable laptop offering decent performance for everyday computing needs.	\N	156	299.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
91	Dell Alienware 15 R3	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Alienware 15 R3 was a powerful gaming laptop known for its high-end specs and dedicated graphics, offering an immersive gaming experience.	\N	156	1299.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
92	Dell Inspiron 1520	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 1520 was a mid-range laptop with decent performance and features, catering to users seeking reliable computing.	\N	156	349.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
93	Dell Latitude E6500	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude E6500 was a durable business laptop known for its robust build quality and reliable performance for professional use.	\N	156	599.99	\N	84	t	2024-01-04 23:49:45.971229+07	2024-01-04 23:49:45.971229+07
94	Dell Inspiron 1545	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 1545 was a budget-friendly laptop offering decent performance and reliability for everyday computing tasks.	\N	156	399.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
95	Dell XPS 14	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS 14 was a compact and powerful laptop known for its high-resolution display and robust performance.	\N	156	899.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
96	Dell Alienware 13 R2	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Alienware 13 R2 was a compact gaming laptop featuring powerful hardware and a portable form factor.	\N	156	1199.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
97	Dell Precision M6700	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Precision M6700 was a robust mobile workstation designed for professionals requiring high-performance computing.	\N	156	1399.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
98	Dell Inspiron 9300	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 9300 was a multimedia-focused laptop offering a large display and decent performance for entertainment.	\N	156	299.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
99	Dell Latitude 3540	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude 3540 was a reliable business laptop known for its durability and essential features for professional use.	\N	156	499.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
100	Dell Vostro 1720	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Vostro 1720 was a business-oriented laptop offering a large display and reliable performance for small businesses.	\N	156	399.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
101	Dell XPS M1530	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS M1530 was a stylish and powerful laptop known for its sleek design and performance.	\N	156	699.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
102	Dell Inspiron 17 5000	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 17 5000 series offered a large-screen experience and decent performance for multimedia and entertainment.	\N	156	799.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
103	Dell Latitude D820	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude D820 was a sturdy and reliable business laptop known for its durability and performance.	\N	156	349.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
104	Dell Studio XPS 16	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Studio XPS 16 was a multimedia powerhouse offering a high-resolution display and premium entertainment features.	\N	156	899.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
105	Dell Alienware 14	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Alienware 14 was a mid-sized gaming laptop known for its performance and gaming-centric design.	\N	156	1299.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
106	Dell Precision 3510	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Precision 3510 was a mobile workstation designed for professionals needing reliable performance.	\N	156	999.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
107	Dell Inspiron 1526	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 1526 was a budget-friendly laptop offering decent performance for everyday computing.	\N	156	399.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
108	Dell Latitude E6320	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Latitude E6320 was a compact and reliable business laptop known for its durability and security features.	\N	156	499.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
109	Dell XPS 12	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell XPS 12 was a convertible laptop offering a unique flip-screen design and performance.	\N	156	899.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
110	Dell Precision 5510	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Precision 5510 was a powerful mobile workstation aimed at professionals needing high performance and reliability.	\N	156	1399.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
111	Dell Inspiron 1521	https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_Hust.png/609px-Logo_Hust.png	The Dell Inspiron 1521 was a mid-range laptop offering decent performance and features for everyday use.	\N	156	399.99	\N	84	t	2024-01-04 23:50:44.033168+07	2024-01-04 23:50:44.033168+07
\.


--
-- TOC entry 5177 (class 0 OID 30145)
-- Dependencies: 248
-- Data for Name: cart_item; Type: TABLE DATA; Schema: shopping; Owner: postgres
--

COPY shopping.cart_item (cart_item_id, user_id, product_id, quantity, created_at, modified_at) FROM stdin;
\.


--
-- TOC entry 5181 (class 0 OID 30153)
-- Dependencies: 252
-- Data for Name: order_detail; Type: TABLE DATA; Schema: shopping; Owner: postgres
--

COPY shopping.order_detail (order_detail_id, user_id, total, delivery_method, created_at, modified_at, address_id, payment_id) FROM stdin;
\.


--
-- TOC entry 5184 (class 0 OID 30161)
-- Dependencies: 255
-- Data for Name: order_item; Type: TABLE DATA; Schema: shopping; Owner: postgres
--

COPY shopping.order_item (order_item_id, order_detail_id, product_id, quantity, condition, created_at, modified_at, delivery_provider_id) FROM stdin;
\.


--
-- TOC entry 5188 (class 0 OID 30171)
-- Dependencies: 259
-- Data for Name: delivery_method; Type: TABLE DATA; Schema: store; Owner: postgres
--

COPY store.delivery_method (delivery_method_id, store_id, method_name, price, is_active, created_at, modified_at) FROM stdin;
5	1	business	3.00	t	2023-12-29 01:03:55.739931+07	2024-01-04 19:33:31.044176+07
8	2	business	3.00	t	2023-12-29 01:06:28.646763+07	2024-01-04 19:33:31.044176+07
11	3	business	3.00	t	2023-12-29 01:09:00.991728+07	2024-01-04 19:33:31.044176+07
14	4	business	3.00	t	2023-12-29 01:10:07.678675+07	2024-01-04 19:33:31.044176+07
17	5	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
23	7	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
26	8	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
29	9	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
32	10	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
35	11	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
38	12	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
41	13	business	3.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:33:31.044176+07
44	14	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
50	16	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
53	17	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
4	1	fast	5.00	t	2023-12-29 01:03:03.534135+07	2024-01-04 19:34:13.744695+07
7	2	fast	5.00	t	2023-12-29 01:06:28.646763+07	2024-01-04 19:34:13.744695+07
10	3	fast	5.00	t	2023-12-29 01:09:00.991728+07	2024-01-04 19:34:13.744695+07
13	4	fast	5.00	t	2023-12-29 01:10:07.678675+07	2024-01-04 19:34:13.744695+07
16	5	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
22	7	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
25	8	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
28	9	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
31	10	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
34	11	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
37	12	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
40	13	fast	5.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:13.744695+07
43	14	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
49	16	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
52	17	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
55	18	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
58	19	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
61	20	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
64	21	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
67	22	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
70	23	fast	5.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:13.744695+07
3	1	express	7.00	t	2023-12-29 01:02:16.421232+07	2024-01-04 19:34:53.077175+07
6	2	express	7.00	t	2023-12-29 01:06:28.646763+07	2024-01-04 19:34:53.077175+07
9	3	express	7.00	t	2023-12-29 01:09:00.991728+07	2024-01-04 19:34:53.077175+07
12	4	express	7.00	t	2023-12-29 01:10:07.678675+07	2024-01-04 19:34:53.077175+07
15	5	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
21	7	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
24	8	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
27	9	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
30	10	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
33	11	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
36	12	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
39	13	express	7.00	t	2023-12-29 01:12:10.144573+07	2024-01-04 19:34:53.077175+07
42	14	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
48	16	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
51	17	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
54	18	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
57	19	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
60	20	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
63	21	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
66	22	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
69	23	express	7.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:34:53.077175+07
56	18	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
59	19	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
62	20	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
65	21	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
68	22	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
71	23	business	3.00	t	2023-12-29 01:12:34.043489+07	2024-01-04 19:33:31.044176+07
73	32	business	3.00	t	2024-01-04 22:47:13.993897+07	2024-01-04 22:47:13.993897+07
75	34	business	3.00	t	2024-01-04 22:48:38.454922+07	2024-01-04 22:48:38.454922+07
82	41	business	3.00	t	2024-01-04 22:48:38.454922+07	2024-01-04 22:48:38.454922+07
86	45	business	3.00	t	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
88	47	business	3.00	t	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
89	48	business	3.00	t	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
92	51	business	3.00	t	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
94	53	business	3.00	t	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
97	56	business	3.00	t	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
98	57	business	3.00	t	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
100	59	business	3.00	t	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
102	61	business	3.00	t	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
104	63	business	3.00	t	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
105	64	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
106	65	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
108	67	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
110	69	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
111	70	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
112	71	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
113	72	business	3.00	t	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
116	75	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
118	77	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
119	78	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
120	79	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
121	80	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
122	81	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
124	83	business	3.00	t	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
125	84	business	3.00	t	2024-01-04 23:44:55.646881+07	2024-01-04 23:44:55.646881+07
\.


--
-- TOC entry 5191 (class 0 OID 30181)
-- Dependencies: 262
-- Data for Name: store; Type: TABLE DATA; Schema: store; Owner: postgres
--

COPY store.store (store_id, user_id, name, description, created_at, modified_at) FROM stdin;
1	1	Gucci	Gucci is an Italian luxury brand celebrated for its exquisite craftsmanship and innovative designs since its establishment in 1921. Renowned for its iconic double G logo and daring styles, Guccis offerings span from high-end fashion to accessories, encompassing handbags, shoes, ready-to-wear collections, fragrances, eyewear, and jewelry. With an emphasis on merging tradition with modernity, Gucci consistently sets trends in the fashion industry under the guidance of visionary creative directors, captivating global audiences with its distinctively bold and opulent aesthetic.	2023-12-29 00:41:19.455223+07	2023-12-29 00:45:18.293611+07
2	10	Louis Vuitton	Louis Vuitton, a French luxury fashion house founded in 1854, is renowned for its high-quality leather goods, iconic monogrammed patterns, and elegant accessories spanning from handbags to travel accessories.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
3	11	Apple	Apple, a tech giant established in 1976, pioneers innovation with its range of groundbreaking products, including the iPhone, iPad, Mac computers, and a host of software and services, redefining the tech landscape.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
4	12	Nike	Nike, a global sports brand founded in 1964, dominates the athletic footwear and apparel industry, celebrated for its innovative designs, cutting-edge technology, and endorsement deals with top athletes.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
5	13	Chanel	Chanel, a Parisian fashion house founded in 1909, epitomizes timeless elegance with its haute couture, perfumes, and accessories, including the iconic Chanel suit and the classic quilted handbags.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
7	15	Google	Google, founded in 1998, revolutionized the internet era with its search engine, and has since expanded its portfolio with services like Gmail, Android, Google Maps, and numerous other tech innovations.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
8	16	Prada	Prada, an Italian luxury brand established in 1913, stands for sophistication and modernity, offering high-end fashion, leather goods, and accessories admired for their avant-garde designs and craftsmanship.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
9	17	Amazon	Amazon, founded in 1994, redefined online retail, evolving into a tech giant offering a vast array of products, cloud computing services, streaming, and innovations like Alexa and Amazon Prime.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
10	18	Rolex	Rolex, a Swiss watchmaker established in 1905, is synonymous with luxury and precision, crafting iconic timepieces recognized for their quality, innovation, and enduring style.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
11	19	Zara	Zara, a Spanish fast-fashion brand founded in 1974, is known for its trendy yet affordable clothing lines, adapting quickly to fashion trends and maintaining a rapid product turnover.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
12	20	Microsoft	Microsoft, established in 1975, is a global tech company renowned for its software, including the Windows operating system, Office suite, Xbox gaming console, and cloud services.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
13	21	Hermes	Hermes, a French luxury brand founded in 1837, specializes in exquisite leather goods, silk scarves, perfumes, and high fashion, epitomizing timeless luxury and craftsmanship.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
14	22	Tesla	Tesla, established in 2003, revolutionizes the automotive industry with its electric vehicles, pushing boundaries in sustainable energy, autonomous driving, and energy storage solutions.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
16	24	Burberry	Burberry, a British luxury brand established in 1856, is recognized for its iconic trench coats, classic plaid pattern, and sophisticated yet modern apparel, accessories, and fragrances.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
17	25	Sony	Sony, founded in 1946, is a pioneering electronics company offering a diverse range of products including TVs, PlayStation gaming consoles, cameras, audio devices, and entertainment content.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
18	26	Tiffany & Co.	Tiffany & Co., founded in 1837, is an American luxury jewelry brand renowned for its engagement rings, diamonds, and exquisite craftsmanship, symbolizing elegance and romance.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
19	27	Versace	Versace, an Italian luxury fashion house established in 1978, is famed for its bold and glamorous designs, vibrant prints, and high-end clothing, accessories, and fragrances.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
20	28	Puma	Puma, founded in 1948, is a leading sports brand known for its athletic footwear, apparel, and accessories, blending performance with style and endorsed by athletes worldwide.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
21	29	Cartier	Cartier, a French luxury brand established in 1847, specializes in fine jewelry, watches, and accessories, renowned for its exquisite craftsmanship and timeless elegance.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
22	30	Coca-Cola	Coca-Cola, founded in 1886, is a global beverage company known for its iconic soda, encompassing a range of soft drink variations and an enduring presence in the global market.	2023-12-29 00:43:40.129549+07	2023-12-29 00:45:18.293611+07
23	31	Fendi	Fendi, an Italian luxury fashion house established in 1925, is recognized for its high-quality leather goods, fur, ready-to-wear collections, and accessories, blending tradition with innovation and timeless elegance.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
24	32	Under Armour	Under Armour, founded in 1996, is a prominent sportswear brand known for its performance-enhancing apparel, shoes, and accessories designed to empower athletes with cutting-edge technology and style.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
26	34	H&M	H&M, established in 1947, is a Swedish multinational fashion brand recognized for its trendy and affordable clothing, catering to diverse fashion tastes and sustainability efforts.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
27	35	Vans	Vans, founded in 1966, is a popular skateboarding-inspired brand offering footwear, apparel, and accessories, known for its iconic sneakers and street-style culture.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
28	36	Dior	Dior, a French luxury brand established in 1946, is celebrated for its haute couture, ready-to-wear fashion, accessories, and fragrances, symbolizing timeless elegance and sophistication.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
29	37	Lululemon	Lululemon, founded in 1998, is a Canadian athletic apparel brand known for its yoga-inspired activewear, emphasizing comfort, functionality, and a lifestyle approach to fitness.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
30	38	Givenchy	Givenchy, a French luxury fashion house founded in 1952, is acclaimed for its elegant couture, perfumes, and accessories, showcasing innovative designs and an enduring legacy in the fashion industry.	2023-12-29 00:44:18.230256+07	2023-12-29 00:45:18.293611+07
32	39	TeeLab	TeeLab is a prominent Vietnamese fashion brand known for its vibrant and contemporary approach to t-shirt design. Specializing in unique and expressive graphic tees, TeeLab infuses local cultural elements with modern aesthetics, appealing to a diverse demographic of fashion-forward individuals. Renowned for its quality craftsmanship and diverse collections, TeeLab has established itself as a go-to destination for trendsetting, casual wear in Vietnams fashion landscape.	2024-01-04 22:47:13.993897+07	2024-01-04 22:47:13.993897+07
34	41	Adidas	Adidas, a renowned sports brand, provides high-performance athletic wear, shoes, and accessories. With a focus on innovation and design, Adidas blends sport and style for athletes and lifestyle enthusiasts globally.	2024-01-04 22:48:38.454922+07	2024-01-04 22:48:38.454922+07
41	48	Samsung	Samsung, a leading technology company, produces a wide array of electronics, from smartphones to home appliances. Renowned for innovation and reliability, Samsung continues to shape the tech industry.	2024-01-04 22:48:38.454922+07	2024-01-04 22:48:38.454922+07
45	52	Toyota	Toyota, a leading automotive brand, is renowned for its reliable and innovative vehicles. Known for quality, efficiency, and technological advancements, Toyota stands as a pillar in the automotive industry.	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
47	54	LOréal	L\\Oréal, a French beauty company, is a leader in cosmetics and beauty products. With a wide range of skincare, makeup, and hair care, L\\Oréal stands for beauty innovation and diversity.	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
48	55	IKEA	IKEA, a Swedish furniture retailer, offers affordable and stylish home furnishings. Known for its flat-pack designs and functional furniture, IKEA revolutionizes home decor and interior design.	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
51	58	Mercedes-Benz	Mercedes-Benz, a luxury automobile manufacturer, stands for innovation and luxury in the automotive industry. Known for its high-quality vehicles, Mercedes-Benz sets benchmarks in design and technology.	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
53	60	Hermès	Hermès, a French luxury brand, specializes in high-quality leather goods and fashion. Renowned for its craftsmanship and iconic Birkin bags, Hermès epitomizes luxury and exclusivity.	2024-01-04 22:49:38.49542+07	2024-01-04 22:49:38.49542+07
56	63	Delta Airlines	Delta Airlines, a major American airline, provides domestic and international flights. Known for its service and reliability, Delta remains a prominent player in the airline industry.	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
57	64	Nissan	Nissan, a leading automotive manufacturer, offers a diverse range of vehicles. Known for innovation and performance, Nissan cars are appreciated globally for their quality and design.	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
59	66	Panasonic	Panasonic, a multinational electronics company, produces consumer electronics and home appliances. Known for its quality and innovation, Panasonic is a household name in electronics.	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
61	68	Hewlett-Packard (HP)	Hewlett-Packard (HP), a technology corporation, manufactures computers, printers, and other hardware. Known for its reliability and innovation, HP is a leader in tech solutions.	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
63	70	General Electric (GE)	General Electric (GE), a multinational conglomerate, operates in various industries such as aviation, healthcare, and renewable energy. Known for innovation and scale, GE is a major player in industrial technology.	2024-01-04 22:50:20.038444+07	2024-01-04 22:50:20.038444+07
64	71	Lamborghini	Lamborghini, an Italian luxury sports car manufacturer, is celebrated for its high-performance and visually stunning automobiles. Renowned for speed and design, Lamborghini represents automotive excellence.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
65	72	Disney	Disney, an entertainment conglomerate, is known for its iconic characters, theme parks, and movies. Renowned for storytelling and imagination, Disney holds a special place in global entertainment.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
67	74	Nokia	Nokia, a telecommunications company, is known for its mobile phones and network equipment. Renowned for its durability and innovation, Nokia was a pioneer in the mobile phone industry.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
69	76	Ferrari	Ferrari, an Italian sports car manufacturer, is synonymous with speed, luxury, and racing heritage. Renowned for its iconic red cars, Ferrari embodies automotive excellence and passion.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
70	77	IBM	IBM, a multinational technology company, offers hardware, software, and cloud services. Renowned for innovation and enterprise solutions, IBM is a leader in technology.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
71	78	Bose	Bose, an audio equipment company, is known for its high-quality speakers and sound systems. Renowned for its audio innovation and clarity, Bose delivers premium sound experiences.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
72	79	Volkswagen	Volkswagen, a German automotive manufacturer, produces a wide range of vehicles. Renowned for reliability and innovation, Volkswagen is a prominent name in the automotive industry.	2024-01-04 22:50:46.090731+07	2024-01-04 22:50:46.090731+07
75	82	The North Face	The North Face, an outdoor recreation company, offers high-performance apparel and equipment for outdoor activities. Renowned for durability and innovation, The North Face is trusted by adventurers.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
77	84	Canon	Canon, a multinational corporation, specializes in imaging and optical products. Renowned for cameras and imaging solutions, Canon is a leader in photography technology.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
78	85	Delta Faucet	Delta Faucet, a plumbing fixture company, offers innovative kitchen and bathroom products. Renowned for quality and design, Delta Faucet is a trusted name in home improvement.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
79	86	American Express	American Express, a financial services company, provides credit cards, travel, and financial solutions. Renowned for reliability and prestige, American Express serves affluent consumers globally.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
80	87	Sony Pictures	Sony Pictures, a subsidiary of Sony Corporation, is a leading film and television studio. Renowned for blockbuster movies and TV shows, Sony Pictures is a major player in entertainment.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
81	88	Fossil	Fossil, a fashion and lifestyle brand, offers watches, accessories, and apparel. Renowned for stylish designs and craftsmanship, Fossil appeals to fashion-conscious individuals.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
83	90	Estée Lauder	Estée Lauder, an American cosmetics company, specializes in skincare, makeup, and fragrance. Renowned for luxury and quality, Estée Lauder is a leader in beauty products.	2024-01-04 22:52:22.699435+07	2024-01-04 22:52:22.699435+07
84	91	Dell	Welcome to the Dell Store! Explore a wide range of cutting-edge laptops, from the business-oriented Latitude series to the high-performance XPS line. Discover sleek designs, powerful processors, and innovative features that cater to various needs and preferences. Dive into a world of reliability, performance, and innovation with Dell.	2024-01-04 23:44:55.646881+07	2024-01-04 23:44:55.646881+07
\.


--
-- TOC entry 5194 (class 0 OID 30190)
-- Dependencies: 265
-- Data for Name: active_chain; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.active_chain (chain_id, client_name, started_at) FROM stdin;
\.


--
-- TOC entry 5195 (class 0 OID 30196)
-- Dependencies: 266
-- Data for Name: active_session; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.active_session (client_pid, server_pid, client_name, started_at) FROM stdin;
\.


--
-- TOC entry 5196 (class 0 OID 30202)
-- Dependencies: 267
-- Data for Name: chain; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.chain (chain_id, chain_name, run_at, max_instances, timeout, live, self_destruct, exclusive_execution, client_name, on_error) FROM stdin;
9	execute-func	@every 1 minute	\N	0	t	f	f	\N	\N
10	updatedeletedis	@every 1 minute	\N	0	t	f	f	\N	\N
\.


--
-- TOC entry 5198 (class 0 OID 30212)
-- Dependencies: 269
-- Data for Name: execution_log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.execution_log (chain_id, task_id, txid, last_run, finished, pid, returncode, ignore_error, kind, command, output, client_name) FROM stdin;
\.


--
-- TOC entry 5199 (class 0 OID 30218)
-- Dependencies: 270
-- Data for Name: log; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.log (ts, pid, log_level, client_name, message, message_data) FROM stdin;
\.


--
-- TOC entry 5200 (class 0 OID 30225)
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
-- TOC entry 5201 (class 0 OID 30230)
-- Dependencies: 272
-- Data for Name: parameter; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.parameter (task_id, order_id, value) FROM stdin;
7	1	\N
8	1	\N
\.


--
-- TOC entry 5202 (class 0 OID 30236)
-- Dependencies: 273
-- Data for Name: task; Type: TABLE DATA; Schema: timetable; Owner: postgres
--

COPY timetable.task (task_id, chain_id, task_order, task_name, kind, command, run_as, database_connection, ignore_error, autonomous, timeout) FROM stdin;
7	9	10	\N	SQL	SELECT public.update_condition_after_delay()	\N	\N	t	t	0
8	10	10	\N	SQL	SELECT update_and_delete_discount()	\N	\N	t	t	0
\.


--
-- TOC entry 5271 (class 0 OID 0)
-- Dependencies: 222
-- Name: address_address_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.address_address_id_seq', 444, true);


--
-- TOC entry 5272 (class 0 OID 0)
-- Dependencies: 223
-- Name: address_user_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.address_user_id_seq', 1, false);


--
-- TOC entry 5273 (class 0 OID 0)
-- Dependencies: 225
-- Name: payment_register_pay_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.payment_register_pay_id_seq', 104, true);


--
-- TOC entry 5274 (class 0 OID 0)
-- Dependencies: 226
-- Name: payment_register_user_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.payment_register_user_id_seq', 1, false);


--
-- TOC entry 5275 (class 0 OID 0)
-- Dependencies: 228
-- Name: role_role_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.role_role_id_seq', 2, true);


--
-- TOC entry 5276 (class 0 OID 0)
-- Dependencies: 231
-- Name: user_user_id_seq; Type: SEQUENCE SET; Schema: account; Owner: postgres
--

SELECT pg_catalog.setval('account.user_user_id_seq', 86, true);


--
-- TOC entry 5277 (class 0 OID 0)
-- Dependencies: 233
-- Name: delivery_provider_delivery_provider_id_seq; Type: SEQUENCE SET; Schema: delivery; Owner: postgres
--

SELECT pg_catalog.setval('delivery.delivery_provider_delivery_provider_id_seq', 101, true);


--
-- TOC entry 5278 (class 0 OID 0)
-- Dependencies: 235
-- Name: category_category_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.category_category_id_seq', 156, true);


--
-- TOC entry 5279 (class 0 OID 0)
-- Dependencies: 236
-- Name: category_parent_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.category_parent_id_seq', 6, true);


--
-- TOC entry 5280 (class 0 OID 0)
-- Dependencies: 238
-- Name: discount_discount_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.discount_discount_id_seq', 2, true);


--
-- TOC entry 5281 (class 0 OID 0)
-- Dependencies: 240
-- Name: inventory_inventory_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.inventory_inventory_id_seq', 94, true);


--
-- TOC entry 5282 (class 0 OID 0)
-- Dependencies: 241
-- Name: inventory_product_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.inventory_product_id_seq', 1, false);


--
-- TOC entry 5283 (class 0 OID 0)
-- Dependencies: 244
-- Name: product_category_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.product_category_id_seq', 1, false);


--
-- TOC entry 5284 (class 0 OID 0)
-- Dependencies: 245
-- Name: product_discount_Id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product."product_discount_Id_seq"', 2, true);


--
-- TOC entry 5285 (class 0 OID 0)
-- Dependencies: 246
-- Name: product_product_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.product_product_id_seq', 113, true);


--
-- TOC entry 5286 (class 0 OID 0)
-- Dependencies: 247
-- Name: product_store_id_seq; Type: SEQUENCE SET; Schema: product; Owner: postgres
--

SELECT pg_catalog.setval('product.product_store_id_seq', 1, false);


--
-- TOC entry 5287 (class 0 OID 0)
-- Dependencies: 275
-- Name: temp_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.temp_seq', 1, false);


--
-- TOC entry 5288 (class 0 OID 0)
-- Dependencies: 249
-- Name: cart_item_cart_item_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.cart_item_cart_item_id_seq', 57, true);


--
-- TOC entry 5289 (class 0 OID 0)
-- Dependencies: 250
-- Name: cart_item_product_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.cart_item_product_id_seq', 1, false);


--
-- TOC entry 5290 (class 0 OID 0)
-- Dependencies: 251
-- Name: cart_item_session_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.cart_item_session_id_seq', 1, false);


--
-- TOC entry 5291 (class 0 OID 0)
-- Dependencies: 253
-- Name: order_detail_order_detail_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_detail_order_detail_id_seq', 2, true);


--
-- TOC entry 5292 (class 0 OID 0)
-- Dependencies: 254
-- Name: order_detail_user_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_detail_user_id_seq', 1, false);


--
-- TOC entry 5293 (class 0 OID 0)
-- Dependencies: 256
-- Name: order_item_order_detail_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_item_order_detail_id_seq', 1, false);


--
-- TOC entry 5294 (class 0 OID 0)
-- Dependencies: 257
-- Name: order_item_order_item_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_item_order_item_id_seq', 14, true);


--
-- TOC entry 5295 (class 0 OID 0)
-- Dependencies: 258
-- Name: order_item_product_id_seq; Type: SEQUENCE SET; Schema: shopping; Owner: postgres
--

SELECT pg_catalog.setval('shopping.order_item_product_id_seq', 1, false);


--
-- TOC entry 5296 (class 0 OID 0)
-- Dependencies: 260
-- Name: delivery_methods_delivery_method_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.delivery_methods_delivery_method_id_seq', 131, true);


--
-- TOC entry 5297 (class 0 OID 0)
-- Dependencies: 261
-- Name: delivery_methods_store_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.delivery_methods_store_id_seq', 1, false);


--
-- TOC entry 5298 (class 0 OID 0)
-- Dependencies: 263
-- Name: store_store_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.store_store_id_seq', 90, true);


--
-- TOC entry 5299 (class 0 OID 0)
-- Dependencies: 264
-- Name: store_user_id_seq; Type: SEQUENCE SET; Schema: store; Owner: postgres
--

SELECT pg_catalog.setval('store.store_user_id_seq', 1, false);


--
-- TOC entry 5300 (class 0 OID 0)
-- Dependencies: 268
-- Name: chain_chain_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.chain_chain_id_seq', 11, true);


--
-- TOC entry 5301 (class 0 OID 0)
-- Dependencies: 274
-- Name: task_task_id_seq; Type: SEQUENCE SET; Schema: timetable; Owner: postgres
--

SELECT pg_catalog.setval('timetable.task_task_id_seq', 9, true);


--
-- TOC entry 4928 (class 2606 OID 30263)
-- Name: address address_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.address
    ADD CONSTRAINT address_pkey PRIMARY KEY (address_id);


--
-- TOC entry 4930 (class 2606 OID 30265)
-- Name: payment payment_register_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.payment
    ADD CONSTRAINT payment_register_pkey PRIMARY KEY (payment_id);


--
-- TOC entry 4932 (class 2606 OID 30267)
-- Name: role role_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.role
    ADD CONSTRAINT role_pkey PRIMARY KEY (role_id);


--
-- TOC entry 4934 (class 2606 OID 30440)
-- Name: user user_name; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account."user"
    ADD CONSTRAINT user_name UNIQUE (username);


--
-- TOC entry 4936 (class 2606 OID 30269)
-- Name: user user_pkey; Type: CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account."user"
    ADD CONSTRAINT user_pkey PRIMARY KEY (user_id);


--
-- TOC entry 4938 (class 2606 OID 30271)
-- Name: delivery_provider delivery_provider_pkey; Type: CONSTRAINT; Schema: delivery; Owner: postgres
--

ALTER TABLE ONLY delivery.delivery_provider
    ADD CONSTRAINT delivery_provider_pkey PRIMARY KEY (delivery_provider_id);


--
-- TOC entry 4940 (class 2606 OID 30273)
-- Name: category category_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.category
    ADD CONSTRAINT category_pkey PRIMARY KEY (category_id);


--
-- TOC entry 4942 (class 2606 OID 30275)
-- Name: discount discount_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.discount
    ADD CONSTRAINT discount_pkey PRIMARY KEY (discount_id);


--
-- TOC entry 4944 (class 2606 OID 30277)
-- Name: inventory inventory_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.inventory
    ADD CONSTRAINT inventory_pkey PRIMARY KEY (inventory_id);


--
-- TOC entry 4946 (class 2606 OID 30468)
-- Name: product name; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT name UNIQUE (name);


--
-- TOC entry 4948 (class 2606 OID 30279)
-- Name: product product_pkey; Type: CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (product_id);


--
-- TOC entry 4950 (class 2606 OID 30281)
-- Name: cart_item cart_item_pkey; Type: CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item
    ADD CONSTRAINT cart_item_pkey PRIMARY KEY (cart_item_id);


--
-- TOC entry 4952 (class 2606 OID 30283)
-- Name: order_detail order_detail_pkey; Type: CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT order_detail_pkey PRIMARY KEY (order_detail_id);


--
-- TOC entry 4954 (class 2606 OID 30285)
-- Name: order_item order_item_pkey; Type: CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT order_item_pkey PRIMARY KEY (order_item_id);


--
-- TOC entry 4956 (class 2606 OID 30287)
-- Name: delivery_method delivery_methods_pkey; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.delivery_method
    ADD CONSTRAINT delivery_methods_pkey PRIMARY KEY (delivery_method_id);


--
-- TOC entry 4958 (class 2606 OID 30458)
-- Name: store name; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT name UNIQUE (name);


--
-- TOC entry 4960 (class 2606 OID 30289)
-- Name: store store_pkey; Type: CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT store_pkey PRIMARY KEY (store_id);


--
-- TOC entry 4962 (class 2606 OID 30291)
-- Name: chain chain_chain_name_key; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain
    ADD CONSTRAINT chain_chain_name_key UNIQUE (chain_name);


--
-- TOC entry 4964 (class 2606 OID 30293)
-- Name: chain chain_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.chain
    ADD CONSTRAINT chain_pkey PRIMARY KEY (chain_id);


--
-- TOC entry 4966 (class 2606 OID 30295)
-- Name: migration migration_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.migration
    ADD CONSTRAINT migration_pkey PRIMARY KEY (id);


--
-- TOC entry 4968 (class 2606 OID 30297)
-- Name: parameter parameter_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.parameter
    ADD CONSTRAINT parameter_pkey PRIMARY KEY (task_id, order_id);


--
-- TOC entry 4970 (class 2606 OID 30299)
-- Name: task task_pkey; Type: CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task
    ADD CONSTRAINT task_pkey PRIMARY KEY (task_id);


--
-- TOC entry 4992 (class 2620 OID 30300)
-- Name: user auto_create_role; Type: TRIGGER; Schema: account; Owner: postgres
--

CREATE TRIGGER auto_create_role AFTER INSERT ON account."user" FOR EACH ROW EXECUTE FUNCTION public.autocreaterole();


--
-- TOC entry 4993 (class 2620 OID 30301)
-- Name: user update_user; Type: TRIGGER; Schema: account; Owner: postgres
--

CREATE TRIGGER update_user BEFORE UPDATE ON account."user" FOR EACH ROW EXECUTE FUNCTION public.updateuser();


--
-- TOC entry 4994 (class 2620 OID 30302)
-- Name: delivery_provider update_delivery_provider; Type: TRIGGER; Schema: delivery; Owner: postgres
--

CREATE TRIGGER update_delivery_provider BEFORE UPDATE ON delivery.delivery_provider FOR EACH ROW EXECUTE FUNCTION public.updatedeliveryprovider();


--
-- TOC entry 4995 (class 2620 OID 30303)
-- Name: category update_category; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_category BEFORE UPDATE ON product.category FOR EACH ROW EXECUTE FUNCTION public.updatecategory();


--
-- TOC entry 4996 (class 2620 OID 30304)
-- Name: discount update_discount; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_discount BEFORE UPDATE ON product.discount FOR EACH ROW EXECUTE FUNCTION public.updatediscount();


--
-- TOC entry 4997 (class 2620 OID 30305)
-- Name: inventory update_inventory; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_inventory BEFORE UPDATE ON product.inventory FOR EACH ROW EXECUTE FUNCTION public.updateinventory();


--
-- TOC entry 4998 (class 2620 OID 30306)
-- Name: product update_product; Type: TRIGGER; Schema: product; Owner: postgres
--

CREATE TRIGGER update_product BEFORE UPDATE ON product.product FOR EACH ROW EXECUTE FUNCTION public.updateproduct();


--
-- TOC entry 4999 (class 2620 OID 30307)
-- Name: cart_item update_cart_item; Type: TRIGGER; Schema: shopping; Owner: postgres
--

CREATE TRIGGER update_cart_item BEFORE UPDATE ON shopping.cart_item FOR EACH ROW EXECUTE FUNCTION public.updatecartitem();


--
-- TOC entry 5000 (class 2620 OID 30308)
-- Name: order_detail update_order_detail; Type: TRIGGER; Schema: shopping; Owner: postgres
--

CREATE TRIGGER update_order_detail BEFORE UPDATE ON shopping.order_detail FOR EACH ROW EXECUTE FUNCTION public.updateorderdetail();


--
-- TOC entry 5001 (class 2620 OID 30309)
-- Name: order_item update_order_item; Type: TRIGGER; Schema: shopping; Owner: postgres
--

CREATE TRIGGER update_order_item BEFORE UPDATE ON shopping.order_item FOR EACH ROW EXECUTE FUNCTION public.updateorderitem();


--
-- TOC entry 5003 (class 2620 OID 30310)
-- Name: store auto_create_deli_method; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER auto_create_deli_method AFTER INSERT ON store.store FOR EACH ROW EXECUTE FUNCTION public.autocreatedelimethod();


--
-- TOC entry 5004 (class 2620 OID 30311)
-- Name: store auto_reupdate_role; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER auto_reupdate_role AFTER DELETE ON store.store FOR EACH ROW EXECUTE FUNCTION public.autoreupdaterole();


--
-- TOC entry 5005 (class 2620 OID 30312)
-- Name: store auto_update_role; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER auto_update_role AFTER INSERT ON store.store FOR EACH ROW EXECUTE FUNCTION public.autoupdaterole();


--
-- TOC entry 5002 (class 2620 OID 30313)
-- Name: delivery_method update_delimethod; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER update_delimethod BEFORE UPDATE ON store.delivery_method FOR EACH ROW EXECUTE FUNCTION public.updatedelimethod();


--
-- TOC entry 5006 (class 2620 OID 30314)
-- Name: store update_store; Type: TRIGGER; Schema: store; Owner: postgres
--

CREATE TRIGGER update_store BEFORE UPDATE ON store.store FOR EACH ROW EXECUTE FUNCTION public.updatestore();


--
-- TOC entry 4973 (class 2606 OID 30315)
-- Name: user_role role_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.user_role
    ADD CONSTRAINT role_fk FOREIGN KEY (role_id) REFERENCES account.role(role_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4972 (class 2606 OID 30320)
-- Name: payment user_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.payment
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4974 (class 2606 OID 30325)
-- Name: user_role user_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.user_role
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4971 (class 2606 OID 30330)
-- Name: address user_fk; Type: FK CONSTRAINT; Schema: account; Owner: postgres
--

ALTER TABLE ONLY account.address
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4975 (class 2606 OID 30335)
-- Name: category cate_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.category
    ADD CONSTRAINT cate_fk FOREIGN KEY (parent_id) REFERENCES product.category(category_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4977 (class 2606 OID 30340)
-- Name: product cate_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT cate_fk FOREIGN KEY (category_id) REFERENCES product.category(category_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4978 (class 2606 OID 30345)
-- Name: product dis_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT dis_fk FOREIGN KEY (discount_id) REFERENCES product.discount(discount_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4976 (class 2606 OID 30350)
-- Name: inventory prod_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.inventory
    ADD CONSTRAINT prod_fk FOREIGN KEY (product_id) REFERENCES product.product(product_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4979 (class 2606 OID 30355)
-- Name: product store_fk; Type: FK CONSTRAINT; Schema: product; Owner: postgres
--

ALTER TABLE ONLY product.product
    ADD CONSTRAINT store_fk FOREIGN KEY (store_id) REFERENCES store.store(store_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4982 (class 2606 OID 30360)
-- Name: order_detail add_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT add_fk FOREIGN KEY (address_id) REFERENCES account.address(address_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4985 (class 2606 OID 30365)
-- Name: order_item deli_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT deli_fk FOREIGN KEY (delivery_provider_id) REFERENCES delivery.delivery_provider(delivery_provider_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4986 (class 2606 OID 30370)
-- Name: order_item detail_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT detail_fk FOREIGN KEY (order_detail_id) REFERENCES shopping.order_detail(order_detail_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4983 (class 2606 OID 30375)
-- Name: order_detail pay_id; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT pay_id FOREIGN KEY (payment_id) REFERENCES account.payment(payment_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4980 (class 2606 OID 30380)
-- Name: cart_item prod_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item
    ADD CONSTRAINT prod_fk FOREIGN KEY (product_id) REFERENCES product.product(product_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4987 (class 2606 OID 30385)
-- Name: order_item prod_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_item
    ADD CONSTRAINT prod_fk FOREIGN KEY (product_id) REFERENCES product.product(product_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4981 (class 2606 OID 30390)
-- Name: cart_item user_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.cart_item
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4984 (class 2606 OID 30395)
-- Name: order_detail user_fk; Type: FK CONSTRAINT; Schema: shopping; Owner: postgres
--

ALTER TABLE ONLY shopping.order_detail
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE SET NULL NOT VALID;


--
-- TOC entry 4988 (class 2606 OID 30400)
-- Name: delivery_method deli_fk; Type: FK CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.delivery_method
    ADD CONSTRAINT deli_fk FOREIGN KEY (store_id) REFERENCES store.store(store_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4989 (class 2606 OID 30405)
-- Name: store user_fk; Type: FK CONSTRAINT; Schema: store; Owner: postgres
--

ALTER TABLE ONLY store.store
    ADD CONSTRAINT user_fk FOREIGN KEY (user_id) REFERENCES account."user"(user_id) ON DELETE CASCADE NOT VALID;


--
-- TOC entry 4990 (class 2606 OID 30410)
-- Name: parameter parameter_task_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.parameter
    ADD CONSTRAINT parameter_task_id_fkey FOREIGN KEY (task_id) REFERENCES timetable.task(task_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 4991 (class 2606 OID 30415)
-- Name: task task_chain_id_fkey; Type: FK CONSTRAINT; Schema: timetable; Owner: postgres
--

ALTER TABLE ONLY timetable.task
    ADD CONSTRAINT task_chain_id_fkey FOREIGN KEY (chain_id) REFERENCES timetable.chain(chain_id) ON UPDATE CASCADE ON DELETE CASCADE;


-- Completed on 2024-01-09 09:11:15

--
-- PostgreSQL database dump complete
--

