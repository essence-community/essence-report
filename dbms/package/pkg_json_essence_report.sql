--liquibase formatted sql
--changeset artemov_i:pkg_json_essence_report dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_json_essence_report cascade;
    
CREATE SCHEMA pkg_json_essence_report
    AUTHORIZATION ${user.update};
    
ALTER SCHEMA pkg_json_essence_report OWNER TO ${user.update};

CREATE FUNCTION pkg_json_essence_report.f_modify_queue(pv_user varchar, pk_session varchar, pc_json jsonb, pl_server smallint default 0) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_queue  ${user.table}.t_queue;
  vv_action varchar(1);
  rec record;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	ck_d_status varchar(30) NOT NULL,
	cct_parameter jsonb NULL,
	ck_d_format varchar(30) NOT NULL,
	ck_d_queue varchar(30) NOT NULL,
	ct_create timestamp NOT NULL DEFAULT LOCALTIMESTAMP,
	ct_st timestamp NULL,
	ct_en timestamp NULL,
	ck_report uuid NOT NULL,
	ck_scheduler uuid NULL,
	ct_cleaning timestamp NOT NULL DEFAULT 'infinity'::timestamp without time zone,
	cv_report_name varchar(50) NULL,
  */
  for rec in (
  select
      (
          coalesce(jq.ck_id, tq.ck_id)
      ) as ck_id,
      (
          coalesce(jq.cn_priority, tq.cn_priority, tr.cn_priority, 100::int4)
      ) as cn_priority,
      (
          coalesce(jq.ck_d_status, tq.ck_d_status, 'add')
      ) as ck_d_status,
      (
          coalesce(jq.cct_parameter, tq.cct_parameter, '{}'::jsonb)
      ) as cct_parameter,
      (
          coalesce(jq.ck_d_format, tq.ck_d_format)
      ) as ck_d_format,
      (
          coalesce(jq.ck_d_queue, tq.ck_d_queue, 'default')
      ) as ck_d_queue,
      (
          coalesce(jq.ct_create, tq.ct_create, CURRENT_TIMESTAMP)
      ) as ct_create,
      (
          coalesce(jq.ct_st, tq.ct_st, CASE WHEN tq.ck_d_status = 'add' and jq.ck_d_status = 'processing' THEN CURRENT_TIMESTAMP
            ELSE NULL::timestamp
       END)
      ) as ct_st,
      (
          coalesce(jq.ct_en, tq.ct_en, CASE WHEN jq.ck_d_status = 'fault' or jq.ck_d_status = 'success' THEN CURRENT_TIMESTAMP
            ELSE NULL::timestamp
       END)
      ) as ct_en,
      (
          coalesce(jq.ck_report, tq.ck_report)
      ) as ck_report,
      (
          coalesce(jq.ck_scheduler, tq.ck_scheduler)
      ) as ck_scheduler,
      (
          coalesce(jq.ct_cleaning, tq.ct_cleaning, CURRENT_TIMESTAMP + (tr.cn_day_expire_storage::varchar || ' day')::interval)
      ) as ct_cleaning,
      (
          coalesce(jq.cv_report_name, tq.cv_report_name)
      ) as cv_report_name,
      (
          coalesce(jq.ck_user, tq.ck_user, pv_user, '-11')
      ) as ck_user,
      (
          coalesce(jq.ct_change, tq.ct_change, CURRENT_TIMESTAMP)
      ) as ct_change
  from
      jsonb_populate_record(null::${user.table}.t_queue, coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}')) as jq
  left join t_queue tq on
      jq.ck_id = tq.ck_id
  left join t_report tr on
      coalesce(jq.ck_report, tq.ck_report) = tr.ck_id) loop
      pot_queue.ck_id := rec.ck_id;
      pot_queue.ck_d_status := rec.ck_d_status;
      pot_queue.cct_parameter := (rec.cct_parameter#>>'{}')::jsonb;
      pot_queue.ck_d_format := rec.ck_d_format;
      pot_queue.ck_d_queue := rec.ck_d_queue;
      pot_queue.ct_create := rec.ct_create;
      pot_queue.ct_st := rec.ct_st;
      pot_queue.ct_en := rec.ct_en;
      pot_queue.ck_report := rec.ck_report;
      pot_queue.ck_scheduler := rec.ck_scheduler;
      pot_queue.ct_cleaning := rec.ct_cleaning;
      pot_queue.cv_report_name := rec.cv_report_name;
      pot_queue.ck_user := rec.ck_user;
      pot_queue.ct_change := rec.ct_change;
      pot_queue.cn_priority := rec.cn_priority;
  end loop;
  if pv_user <> '-11' then
    pot_queue.ck_user = pv_user;
  end if;
  pot_queue.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pot_queue.ck_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_queue(pot_queue.ck_id::varchar);
  end if;
  --modify
  pot_queue := pkg_essence_report.p_modify_queue(vv_action, pl_server, pot_queue);
  --log
  perform pkg_log.p_save(pot_queue.ck_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_queue', pot_queue.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_queue.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_queue(varchar, varchar, jsonb, smallint) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_json_essence_report.f_processing_queue(pk_id varchar) RETURNS VARCHAR
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare 
  vv_queue VARCHAR;
begin
  select ck_id 
  into vv_queue
  from t_queue 
  where ck_id = pk_id::uuid and ck_d_status = 'add' for update skip locked;
  if nullif(vv_queue, '') is null THEN
    return 'false';
  end if;
  perform pkg_json_essence_report.f_modify_queue('-11'::varchar, 'USPO_SERVER'::varchar, jsonb_build_object('service', jsonb_build_object('cv_action', 'U'), 'data', jsonb_build_object('ck_id', pk_id, 'ck_d_status', 'processing')), 1::smallint);
  return 'true';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_processing_queue(pk_id varchar) OWNER TO ${user.update};
    
CREATE FUNCTION pkg_json_essence_report.f_modify_queue_log(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_queue_log  ${user.table}.t_queue_log;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();

  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	ck_queue uuid NOT NULL,
	cv_error text NULL,
	cv_error_stacktrace text NULL,
	ck_d_error varchar(30) NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamp NOT NULL,
  */
  pot_queue_log.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''))::uuid;
  pot_queue_log.ck_queue = (nullif(trim(pc_json#>>'{data,ck_queue}'), ''))::uuid;
  pot_queue_log.ck_d_error = (nullif(trim(pc_json#>>'{data,ck_d_error}'), ''));
  pot_queue_log.cv_error = (nullif(trim(pc_json#>>'{data,cv_error}'), ''));
  pot_queue_log.cv_error_stacktrace = (nullif(trim(pc_json#>>'{data,cv_error_stacktrace}'), ''));
  pot_queue_log.ck_user = coalesce(pv_user, '-11');
  pot_queue_log.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');
  if nullif(trim(pc_json#>>'{master,ck_id}'), '') is not null then
    pot_queue_log.ck_queue = nullif(trim(pc_json#>>'{master,ck_id}'), '')::uuid;
  end if;

  --check access
  perform pkg_access.p_check_access(pot_queue_log.ck_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_queue_log(pot_queue_log.ck_id::varchar);
  end if;
  --modify
  pot_queue_log := pkg_essence_report.p_modify_queue_log(vv_action, pot_queue_log);
  --log
  perform pkg_log.p_save(pot_queue_log.ck_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_queue_log', pot_queue_log.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_queue_log.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_queue_log(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_file(pv_user varchar, pk_session varchar, pc_json jsonb, pb_upload bytea default null::bytea) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_queue_storage  ${user.table}.t_queue_storage;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  --JSON -> rowtype Example
  pot_queue_storage.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''))::uuid;
  pot_queue_storage.cv_content_type = nullif(trim(pc_json#>>'{data,cv_content_type}'), '');
  pot_queue_storage.cct_meta_data = (nullif(trim(pc_json#>>'{data,cct_meta_data}'), ''))::jsonb;
  pot_queue_storage.cb_result = pb_upload;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_file(pot_queue_storage.ck_id::varchar);
  end if;
  --modify
  pot_queue_storage := pkg_essence_report.p_modify_file(vv_action, pot_queue_storage);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_file', pot_queue_storage.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_queue_storage.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_file(varchar, varchar, jsonb, bytea) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_scheduler(pv_user varchar, pk_session varchar, pc_json jsonb, pl_server smallint default 0::smallint) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_scheduler  ${user.table}.t_scheduler;
  vv_action varchar(1);
  rec record;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();

  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(),
	cct_parameter jsonb NULL,
	cn_priority int4 NOT NULL DEFAULT 100::int4,
	cl_enable SMALLINT NOT NULL DEFAULT 0::smallint,
	ct_start_run_cron timestamp NULL,
	cv_unix_cron varchar(100) NOT NULL,
	ct_next_run_cron timestamp NULL,
	ck_d_format varchar(30) NOT NULL,
	ck_report uuid NOT NULL,
	cv_report_name varchar(50) NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamp NOT NULL,
  */
 for rec in (
  select
      (
          coalesce(jq.ck_id, tq.ck_id)
      ) as ck_id,
      (
          coalesce(jq.cn_priority, tq.cn_priority, tr.cn_priority, 100::int4)
      ) as cn_priority,
      (
          coalesce(jq.cl_enable, tq.cl_enable, 0::smallint)
      ) as cl_enable,
      (
          coalesce(jq.cct_parameter, tq.cct_parameter, '{}'::jsonb)
      ) as cct_parameter,
      (
          coalesce(jq.ct_start_run_cron, tq.ct_start_run_cron, CURRENT_TIMESTAMP)
      ) as ct_start_run_cron,
      (
          coalesce(jq.cv_unix_cron, tq.cv_unix_cron)
      ) as cv_unix_cron,
      (
          coalesce(jq.ct_next_run_cron, case when pl_server = 1 then null else coalesce(tq.ct_next_run_cron, jq.ct_start_run_cron, CURRENT_TIMESTAMP) end)
      ) as ct_next_run_cron,
      (
          coalesce(jq.ck_d_format, tq.ck_d_format)
      ) as ck_d_format,
      (
          coalesce(jq.ck_report, tq.ck_report)
      ) as ck_report,
      (
          coalesce(jq.cv_report_name, tq.cv_report_name)
      ) as cv_report_name,
      (
          coalesce(jq.ck_user, tq.ck_user, pv_user, '-11')
      ) as ck_user,
      (
          coalesce(jq.ct_change, tq.ct_change, CURRENT_TIMESTAMP)
      ) as ct_change
  from
      jsonb_populate_record(null::${user.table}.t_scheduler, coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}')) as jq
  left join t_scheduler tq on
      jq.ck_id = tq.ck_id
  left join t_report tr on
      coalesce(jq.ck_report, tq.ck_report) = tr.ck_id) loop
    pot_scheduler.ck_id := rec.ck_id;
    pot_scheduler.cct_parameter := (rec.cct_parameter#>>'{}')::jsonb;
    pot_scheduler.cn_priority := rec.cn_priority;
    pot_scheduler.cv_unix_cron := rec.cv_unix_cron;
    pot_scheduler.ct_next_run_cron := rec.ct_next_run_cron;
    pot_scheduler.ck_d_format := rec.ck_d_format;
    pot_scheduler.ck_report := rec.ck_report;
    pot_scheduler.cv_report_name := rec.cv_report_name;
    pot_scheduler.ck_user := rec.ck_user;
    pot_scheduler.ct_change := rec.ct_change;
    pot_scheduler.ct_start_run_cron := rec.ct_start_run_cron;
    pot_scheduler.cl_enable := rec.cl_enable;
  end loop;
  if pv_user <> '-11' then
    pot_scheduler.ck_user = pv_user;
  end if;
  pot_scheduler.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pot_scheduler.ck_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar and pl_server = 0 then
    perform pkg_essence_report.p_lock_scheduler(pot_scheduler.ck_id::varchar);
  end if;
  --modify
  pot_scheduler := pkg_essence_report.p_modify_scheduler(vv_action, pot_scheduler);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_scheduler', pot_scheduler.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_scheduler.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_scheduler(varchar, varchar, jsonb, smallint) OWNER TO ${user.update};

    
CREATE FUNCTION pkg_json_essence_report.f_get_scheduler() RETURNS table (
  ck_id uuid,
	cct_parameter jsonb,
	cn_priority int4,
	cl_enable smallint,
	ct_start_run_cron timestamp with time zone,
	cv_unix_cron varchar,
	ct_next_run_cron timestamp with time zone,
	ck_d_format varchar,
	ck_report uuid,
	cv_report_name varchar,
	ck_user varchar,
	ct_change timestamp with time zone,
  ct_current_time timestamp with time zone
)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
begin
  return query 
        select
            ts.ck_id,
            ts.cct_parameter,
            ts.cn_priority,
            ts.cl_enable,
            ts.ct_start_run_cron,
            ts.cv_unix_cron,
            ts.ct_next_run_cron,
            ts.ck_d_format,
            ts.ck_report,
            ts.cv_report_name,
            ts.ck_user,
            ts.ct_change,
            current_timestamp as ct_current_time
        from
            t_scheduler ts
        where
            ts.cl_enable = 1
            and ts.ct_start_run_cron < current_timestamp
            and (
                (ts.ct_next_run_cron is null and nullif(trim(ts.cv_unix_cron), '') is not null)
                or ts.ct_next_run_cron < current_timestamp + interval '30'
            )
        order by
            cn_priority asc
        for update skip locked;
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_get_scheduler() OWNER TO ${user.update};

CREATE FUNCTION pkg_json_essence_report.f_get_need_delete() RETURNS table (
  ck_id uuid
)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
begin
  return query 
        select
            tq.ck_id
        from
            t_queue tq
        where
            tq.ck_d_status = 'success' and ct_cleaning < CURRENT_TIMESTAMP
        for update skip locked;
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_get_need_delete() OWNER TO ${user.update};

            
CREATE FUNCTION pkg_json_essence_report.f_modify_global_setting(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_global_setting  ${user.table}.t_d_global_setting;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  --JSON -> rowtype Example
  pot_d_global_setting.ck_id = nullif(trim(pc_json#>>'{data,ck_id}'), '');
  pot_d_global_setting.cv_value = nullif(trim(pc_json#>>'{data,cv_value}'), '');
  pot_d_global_setting.cv_description = nullif(trim(pc_json#>>'{data,cv_description}'), '');
  pot_d_global_setting.ck_user = pv_user;
  pot_d_global_setting.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_global_setting(pot_d_global_setting.ck_id::varchar);
  end if;
  --modify
  pot_d_global_setting := pkg_essence_report.p_modify_global_setting(vv_action, pot_d_global_setting);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_global_setting', pot_d_global_setting.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_global_setting.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_global_setting(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_d_engine(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_engine  ${user.table}.t_d_engine;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  --JSON -> rowtype Example
  pot_d_engine.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''));
  pot_d_engine.cv_name = nullif(trim(pc_json#>>'{data,cv_name}'), '');
  pot_d_engine.ck_user = pv_user;
  pot_d_engine.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_d_engine(pot_d_engine.ck_id::varchar);
  end if;
  --modify
  pot_d_engine := pkg_essence_report.p_modify_d_engine(vv_action, pot_d_engine);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_d_engine', pot_d_engine.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_engine.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_d_engine(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_d_format(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_format  ${user.table}.t_d_format;
  vv_action varchar(1);
  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id varchar(30) NOT NULL, -- Индетификатор
	cv_name varchar(300) NOT NULL, -- Наименование
	cv_extension varchar(10) NOT NULL, -- Расширение файла
	cv_name_lib varchar(30) NOT NULL, -- Наименование библиотеки jsreports
	cv_recipe varchar(100) NOT NULL, -- Наименование настроек в jsreports
	cct_parameter jsonb NULL, -- Настройка формата
	cv_content_type varchar(100) NULL, -- Mime type
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  pot_d_format.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''));
  pot_d_format.cv_name = (nullif(trim(vct_data#>>'{cv_name}'), ''));
  pot_d_format.cv_extension = (nullif(trim(vct_data#>>'{cv_extension}'), ''));
  pot_d_format.cv_name_lib = (nullif(trim(vct_data#>>'{cv_name_lib}'), ''));
  pot_d_format.cv_recipe = (nullif(trim(vct_data#>>'{cv_recipe}'), ''));
  pot_d_format.cv_content_type = (nullif(trim(vct_data#>>'{cv_content_type}'), ''));
  pot_d_format.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  pot_d_format.ck_user = pv_user;
  pot_d_format.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_d_format(pot_d_format.ck_id::varchar);
  end if;
  --modify
  pot_d_format := pkg_essence_report.p_modify_d_format(vv_action, pot_d_format);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_d_format', pot_d_format.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_format.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_d_format(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_report(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_report  ${user.table}.t_report;
  vv_action varchar(1);
  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(), -- Индетификатор
	cv_name varchar(300) NOT NULL, -- Наименование
	ck_d_default_queue varchar(30) NULL, -- Индетификатор типа череди по умолчанию
	ck_authorization uuid NOT NULL, -- Индетификатор авторизации
	cn_day_expire_storage int2 NOT NULL DEFAULT 365, -- Время хранения готового отчета
	cct_parameter jsonb NULL, -- Настройки отчета
	cn_priority int4 NOT NULL DEFAULT 100, -- Приоритет
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  pot_report.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''))::uuid;
  pot_report.cv_name = nullif(trim(vct_data#>>'{cv_name}'), '');
  pot_report.ck_d_default_queue = coalesce(nullif(trim(vct_data#>>'{ck_d_default_queue}'), ''), 'default');
  pot_report.ck_authorization = nullif(trim(vct_data#>>'{ck_authorization}'), '');
  pot_report.cn_day_expire_storage = (coalesce(nullif(trim(vct_data#>>'{cn_day_expire_storage}'), ''), '365'))::int2;
  pot_report.cn_priority = (coalesce(nullif(trim(vct_data#>>'{cn_priority}'), ''), '100'))::int4;
  pot_report.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  pot_report.ck_user = pv_user;
  pot_report.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_report(pot_report.ck_id::varchar);
  end if;
  --modify
  pot_report := pkg_essence_report.p_modify_report(vv_action, pot_report);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_report', pot_report.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_report.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_report(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_report_format(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_report_format  ${user.table}.t_report_format;
  vv_action varchar(1);
  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(), -- Индетификатор
	ck_report uuid NOT NULL, -- Индетификатор отчета
	ck_d_format varchar(30) NOT NULL, -- Индетификатор формата
	cct_parameter jsonb NULL, -- Настройки формата
	ck_asset uuid NOT NULL, -- Индетификатор ресурса
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_report_format.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''))::uuid;
  pot_report_format.ck_d_format = (nullif(trim(vct_data#>>'{ck_d_format}'), ''));
  pot_report_format.ck_report = (nullif(trim(pc_json#>>'{master,ck_id}'), ''))::uuid;
  pot_report_format.ck_asset = (nullif(trim(vct_data#>>'{ck_asset}'), ''))::uuid;
  pot_report_format.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  pot_report_format.ck_user = pv_user;
  pot_report_format.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_report_format(pot_report_format.ck_id::varchar);
  end if;
  --modify
  pot_report_format := pkg_essence_report.p_modify_report_format(vv_action, pot_report_format);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_report_format', pot_report_format.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_report_format.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_report_format(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_report_query(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_report_query  ${user.table}.t_report_query;
  vv_action varchar(1);
  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(), -- Индетификатор
	cv_name varchar(30) NOT NULL, -- Наименование
	cv_body text NULL, -- Содеражание запроса например SQL ЗАПРОС
	ck_source varchar(30) NOT NULL, -- Индетификатор источника данных
	ck_report uuid NOT NULL, -- Индетификатор отчета
	cct_parameter jsonb NULL, -- Настройки запроса
	cct_source_parameter jsonb NULL, -- Дополнительные настройки источника данных
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_report_query.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''))::uuid;
  pot_report_query.ck_report = (nullif(trim(pc_json#>>'{master,ck_id}'), ''))::uuid;
  pot_report_query.cv_name = (nullif(trim(vct_data#>>'{cv_name}'), ''));
  pot_report_query.cv_body = (nullif(trim(vct_data#>>'{cv_body}'), ''));
  pot_report_query.ck_source = (nullif(trim(vct_data#>>'{ck_source}'), ''));
  pot_report_query.ck_parent = (nullif(trim(vct_data#>>'{ck_parent}'), ''))::uuid;
  pot_report_query.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  pot_report_query.cct_source_parameter = (nullif(trim(vct_data#>>'{cct_source_parameter}'), ''))::jsonb;
  pot_report_query.ck_user = pv_user;
  pot_report_query.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_report_query(pot_report_query.ck_id::varchar);
  end if;
  --modify
  pot_report_query := pkg_essence_report.p_modify_report_query(vv_action, pot_report_query);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_report_query', pot_report_query.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_report_query.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_report_query(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_report_asset(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_report_asset  ${user.table}.t_report_asset;
  vv_action varchar(1);
  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');

  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(), -- Индетификатор
	cv_name varchar(30) NOT NULL, -- Наименование
	ck_asset uuid NOT NULL, -- Индетифкатор ресурса
	ck_report uuid NOT NULL, -- Индетификатор отчета
	cct_parameter jsonb NULL, -- Настройки
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_report_asset.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''))::uuid;
  pot_report_asset.cv_name = (nullif(trim(vct_data#>>'{cv_name}'), ''));
  pot_report_asset.ck_report = (nullif(trim(pc_json#>>'{master,ck_id}'), ''))::uuid;
  pot_report_asset.ck_asset = (nullif(trim(vct_data#>>'{ck_asset}'), ''))::uuid;
  pot_report_asset.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  pot_report_asset.ck_user = pv_user;
  pot_report_asset.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_report_asset(pot_report_asset.ck_id::varchar);
  end if;
  --modify
  pot_report_asset := pkg_essence_report.p_modify_report_asset(vv_action, pot_report_asset);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_report_asset', pot_report_asset.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_report_asset.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_report_asset(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_authorization(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_authorization  ${user.table}.t_authorization;
  vv_action varchar(1);

  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();
  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(), -- Индетификатор
	cv_name varchar(30) NOT NULL, -- Наименование
	cv_plugin varchar(300) NOT NULL,
	cct_parameter jsonb NOT NULL,
	ck_user varchar(100) NOT NULL,
	ct_change timestamptz NOT NULL,
  */

  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  pot_authorization.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''))::uuid;
  pot_authorization.cv_name = (nullif(trim(vct_data#>>'{cv_name}'), ''));
  pot_authorization.cv_plugin = (nullif(trim(vct_data#>>'{cv_plugin}'), ''));
  pot_authorization.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  if pot_authorization.cv_plugin is not null 
      and substr(pot_authorization.cv_plugin, 0, 5) = 'new:'
      and length(pot_authorization.cv_plugin) > 4 then 
        pot_authorization.cv_plugin := substr(pot_authorization.cv_plugin, 5);
    end if;
  pot_authorization.ck_user = pv_user;
  pot_authorization.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_authorization(pot_authorization.ck_id::varchar);
  end if;
  --modify
  pot_authorization := pkg_essence_report.p_modify_authorization(vv_action, pot_authorization);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_authorization', pot_authorization.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_authorization.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_authorization(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_source(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_source  ${user.table}.t_source;
  vv_action varchar(1);

  vct_data jsonb;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id varchar(30) NOT NULL, -- Индетификатор
	cct_parameter jsonb NULL, -- Настройки
	cv_plugin varchar(300) NULL, -- Наименование плагина
	ck_d_source varchar(30) NOT NULL, -- Индетификатор типа источника данных
  cl_enable smallint NOT NULL, -- Признак активности
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  pot_source.ck_id = (nullif(trim(vct_data#>>'{ck_id}'), ''));
  pot_source.ck_d_source = (nullif(trim(vct_data#>>'{ck_d_source}'), ''));
  pot_source.cv_plugin = (nullif(trim(vct_data#>>'{cv_plugin}'), ''));
  pot_source.cl_enable = COALESCE((nullif(trim(vct_data#>>'{cl_enable}'), ''))::smallint, 1::smallint);
  pot_source.cct_parameter = (nullif(trim(vct_data#>>'{cct_parameter}'), ''))::jsonb;
  pot_source.ck_user = pv_user;
  pot_source.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_source(pot_source.ck_id::varchar);
  end if;
  --modify
  pot_source := pkg_essence_report.p_modify_source(vv_action, pot_source);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_source', pot_source.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_source.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_source(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_asset(pv_user varchar, pk_session varchar, pc_json jsonb, pb_data bytea default NULL, pv_name_file VARCHAR default NULL, pv_mime_type VARCHAR default NULL) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_asset  ${user.table}.t_asset;
  vv_action varchar(1);
  vct_data jsonb;
  rec record;
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  vct_data := coalesce(pc_json#>'{data,cct_data}', pc_json#>'{data}');
  /*
  ck_id uuid NOT NULL DEFAULT uuid_generate_v4(), -- Индетификатор
	cv_name text NOT NULL, -- Наименование
	cv_template text NULL, -- Шаблон
	ck_engine varchar(30) NULL, -- Индетификатор шаблонизатора
	cb_asset bytea NULL, -- Файл
	cct_parameter jsonb NULL, -- Настройки
	cv_helpers text NULL, -- Дополнительные функции
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
for rec in (
  select
      ja.ck_id,
      ja.cv_name,
      ja.cv_template,
      ja.ck_engine,
      ja.cct_parameter,
      ja.cv_helpers,
      (
          coalesce(pb_data, ta.cb_asset)
      ) as cb_asset,
      (
          coalesce(case when lower(pv_name_file) like '%.zip' or pv_mime_type in ('application/zip', 'application/x-zip-compressed', 'multipart/x-zip') then '1' else ja.cl_archive end, ta.cl_archive, '0')
      ) as cl_archive
  from
      jsonb_populate_record(null::${user.table}.t_asset, vct_data) as ja
  left join t_asset ta on
      ja.ck_id = ta.ck_id
) loop
      pot_asset.ck_id := rec.ck_id;
      pot_asset.cv_name := rec.cv_name;
      pot_asset.cv_template := rec.cv_template;
      pot_asset.ck_engine := nullif(trim(rec.ck_engine), '');
      pot_asset.cct_parameter := (rec.cct_parameter#>>'{}')::jsonb;
      pot_asset.cv_helpers := rec.cv_helpers;
      pot_asset.cb_asset := rec.cb_asset;
      pot_asset.cl_archive := rec.cl_archive::smallint;
  end loop;
  pot_asset.ck_user = pv_user;
  pot_asset.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_asset(pot_asset.ck_id::varchar);
  end if;
  --modify
  pot_asset := pkg_essence_report.p_modify_asset(vv_action, pot_asset);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_asset', pot_asset.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_asset.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_asset(varchar, varchar, jsonb, bytea, varchar, varchar) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_d_source_type(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_source_type  ${user.table}.t_d_source_type;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id varchar(30) NOT NULL, -- Индетификатор
	cv_name varchar(300) NOT NULL, -- Описаниние
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_d_source_type.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''));
  pot_d_source_type.cv_name = nullif(trim(pc_json#>>'{data,cv_name}'), '');
  pot_d_source_type.ck_user = pv_user;
  pot_d_source_type.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_d_source_type(pot_d_source_type.ck_id::varchar);
  end if;
  --modify
  pot_d_source_type := pkg_essence_report.p_modify_d_source_type(vv_action, pot_d_source_type);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_d_source_type', pot_d_source_type.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_source_type.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_d_source_type(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_d_status(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_status  ${user.table}.t_d_status;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id varchar(30) NOT NULL, -- Индетификатор
	cv_name varchar(300) NOT NULL, -- Наименование
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_d_status.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''));
  pot_d_status.cv_name = nullif(trim(pc_json#>>'{data,cv_name}'), '');
  pot_d_status.ck_user = pv_user;
  pot_d_status.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_d_status(pot_d_status.ck_id::varchar);
  end if;
  --modify
  pot_d_status := pkg_essence_report.p_modify_d_status(vv_action, pot_d_status);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_d_status', pot_d_status.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_status.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_d_status(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_d_queue(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_queue  ${user.table}.t_d_queue;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id varchar(30) NOT NULL, -- Индетификатор
	cv_runner_url varchar(2000) NULL, -- Ссылка на контекст запуска. Например http://localhost:8020/runner
	ck_parent varchar(30) NULL, -- Ссылка на родительский индетификатор
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_d_queue.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''));
  pot_d_queue.cv_runner_url = nullif(trim(pc_json#>>'{data,cv_runner_url}'), '');
  pot_d_queue.ck_parent = nullif(trim(pc_json#>>'{data,ck_parent}'), '');
  pot_d_queue.ck_user = pv_user;
  pot_d_queue.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_d_queue(pot_d_queue.ck_id::varchar);
  end if;
  --modify
  pot_d_queue := pkg_essence_report.p_modify_d_queue(vv_action, pot_d_queue);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_d_queue', pot_d_queue.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_queue.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_d_queue(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            
            
CREATE FUNCTION pkg_json_essence_report.f_modify_d_error(pv_user varchar, pk_session varchar, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_essence_report', 'pkg_essence_report', 'public'
    AS $$
declare
  -- var package
  gv_error sessvarstr;
  u sessvarstr;

  -- var fn
  pot_d_error  ${user.table}.t_d_error;
  vv_action varchar(1);
begin
  -- Init
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- Reset global
  perform pkg.p_reset_response();


  /*
  ck_id varchar(30) NOT NULL, -- Индетификатор
	cv_name varchar(300) NOT NULL, -- Наименование ошибки
	ck_user varchar(100) NOT NULL, -- Индетификатор пользователя изменившего/создавшего запись
	ct_change timestamptz NOT NULL, -- Время модификации
  */
  pot_d_error.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''));
  pot_d_error.cv_name = (nullif(trim(pc_json#>>'{data,cv_name}'), ''));
  pot_d_error.ck_user = pv_user;
  pot_d_error.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --check access
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}';
  end if;
  --lock row
  if vv_action = u::varchar then
    perform pkg_essence_report.p_lock_d_error(pot_d_error.ck_id::varchar);
  end if;
  --modify
  pot_d_error := pkg_essence_report.p_modify_d_error(vv_action, pot_d_error);
  --log
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_essence_report.f_modify_d_error', pot_d_error.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_d_error.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_essence_report.f_modify_d_error(varchar, varchar, jsonb) OWNER TO ${user.update};

    
            