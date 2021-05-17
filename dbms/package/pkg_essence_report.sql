--liquibase formatted sql
--changeset template:pkg_essence_report dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_essence_report cascade;
    
CREATE SCHEMA pkg_essence_report
    AUTHORIZATION ${user.update};
    
ALTER SCHEMA pkg_essence_report OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_essence_report.p_modify_queue(pv_action varchar, pl_server smallint, INOUT pot_queue ${user.table}.t_queue) RETURNS ${user.table}.t_queue
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;
  pv_not_found VARCHAR := '';
begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        update ${user.table}.t_queue
        set ck_d_status='delete'
        where ck_id = pot_queue.ck_id;
        return;
    end if;
    if pot_queue.ck_report is null then
   	    perform pkg.p_set_error(200, 'ck_report');
        pv_not_found := pv_not_found || ' ck_report';
    end if;
    if nullif(pot_queue.ck_d_format, '') is null then
   	    perform pkg.p_set_error(200, 'ck_d_format');
        pv_not_found := pv_not_found || ' ck_format';
    end if;
    if pv_action = u::varchar then
      if pot_queue.ck_id is null then
   	    perform pkg.p_set_error(200, 'ck_id');
        pv_not_found := pv_not_found || ' ck_id';
      end if;
    end if;
    if nullif(gv_error::varchar, '') is not null then
        if pl_server = 1 then
          RAISE EXCEPTION 'Not found %', pv_not_found
          USING HINT = 'Need require parameter';
        end if;
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_queue.ck_id := public.uuid_generate_v4();
      pot_queue.ct_create := CURRENT_TIMESTAMP;
      insert into ${user.table}.t_queue values (pot_queue.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_queue set
        (ck_d_status, cct_parameter, ck_d_format, ck_d_queue, ct_create, ct_st, ct_en, ck_report, ck_scheduler, ct_cleaning, cv_report_name, ck_user, ct_change) = 
        (pot_queue.ck_d_status, pot_queue.cct_parameter, pot_queue.ck_d_format, pot_queue.ck_d_queue, pot_queue.ct_create, pot_queue.ct_st, pot_queue.ct_en, pot_queue.ck_report, pot_queue.ck_scheduler, pot_queue.ct_cleaning, pot_queue.cv_report_name, pot_queue.ck_user, pot_queue.ct_change)
      where ck_id = pot_queue.ck_id;
      if not found then
        if pl_server = 1 then
          RAISE EXCEPTION 'Not found %', pot_queue.ck_id::varchar
          USING HINT = 'Not found queue';
        end if;
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_queue(pv_action character varying, pl_server smallint, INOUT pot_queue ${user.table}.t_queue) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_essence_report.p_lock_queue(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_queue where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_lock_queue(pk_id varchar) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_essence_report.p_modify_queue_log(pv_action varchar, INOUT pot_queue_log ${user.table}.t_queue_log) RETURNS ${user.table}.t_queue_log
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_queue_log where ck_id = pot_queue_log.ck_id;
        return;
    end if;
    if pot_queue_log.ck_queue is null then
   	    perform pkg.p_set_error(200, 'ck_queue');
    end if;
    if nullif(pot_queue_log.ck_d_error, '') is null then
   	    perform pkg.p_set_error(200, 'ck_d_error');
    end if;
    if pv_action = u::varchar then
      if pot_queue_log.ck_id is null then
   	    perform pkg.p_set_error(200, 'ck_id');
      end if;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_queue_log.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_queue_log values (pot_queue_log.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_queue_log set
        (ck_queue, ck_d_error, cv_error, cv_error_stacktrace, ck_user, ct_change) = 
        (pot_queue_log.ck_queue, pot_queue_log.ck_d_error, pot_queue_log.cv_error, pot_queue_log.cv_error_stacktrace, pot_queue_log.ck_user, pot_queue_log.ct_change)
      where ck_id = pot_queue_log.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_queue_log(pv_action character varying, INOUT pot_queue_log ${user.table}.t_queue_log) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_essence_report.p_lock_queue_log(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_queue_log where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_queue_log(pk_id varchar) OWNER TO ${user.update};
      
CREATE OR REPLACE FUNCTION pkg_essence_report.p_modify_file(pv_action varchar, INOUT pot_queue_storage ${user.table}.t_queue_storage) RETURNS ${user.table}.t_queue_storage
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_queue_storage where ck_id = pot_queue_storage.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_queue_storage values (pot_queue_storage.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_queue_storage set
        (cv_content_type, cct_meta_data) = (pot_queue_storage.cv_content_type, pot_queue_storage.cct_meta_data)
      where ck_id = pot_queue_storage.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_file(pv_action character varying, INOUT pot_queue_storage ${user.table}.t_queue_storage) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_essence_report.p_lock_file(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_queue_storage where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_file(pk_id varchar) OWNER TO ${user.update};

            
CREATE FUNCTION pkg_essence_report.p_modify_scheduler(pv_action varchar, INOUT pot_scheduler ${user.table}.t_scheduler) RETURNS ${user.table}.t_scheduler
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_scheduler where ck_id = pot_scheduler.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_scheduler.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_scheduler values (pot_scheduler.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_scheduler set
        (cct_parameter, cn_priority, cv_unix_cron, ct_next_run_cron, ck_d_format, ck_report, cv_report_name, ck_user, ct_change, ct_start_run_cron, cl_enable) = 
        (pot_scheduler.cct_parameter, pot_scheduler.cn_priority, pot_scheduler.cv_unix_cron, pot_scheduler.ct_next_run_cron, pot_scheduler.ck_d_format, pot_scheduler.ck_report, pot_scheduler.cv_report_name, pot_scheduler.ck_user, pot_scheduler.ct_change, pot_scheduler.ct_start_run_cron, pot_scheduler.cl_enable)
      where ck_id = pot_scheduler.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_scheduler(pv_action character varying, INOUT pot_scheduler ${user.table}.t_scheduler) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_scheduler(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_scheduler where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_scheduler(pk_id varchar) OWNER TO ${user.update};


CREATE OR REPLACE FUNCTION pkg_essence_report.add_notification_queue() RETURNS TRIGGER 
LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
AS $$
  DECLARE
    msg JSONB;
    cv_name varchar;
  BEGIN
    if OLD.ck_d_status = 'processing' and (NEW.ck_d_status = 'success' or NEW.ck_d_status = 'fault') then
      if NEW.ck_d_status = 'success' then
        select 
          coalesce(nullif(trim(tq.cv_report_name), ''), regexp_replace(tr.cv_name, '^.*\\/(.+)$', '\\1')) as cv_report_name
        into cv_name
        from
            t_queue tq
        join t_report tr on
            tq.ck_report = tr.ck_id 
        where tq.ck_id = OLD.ck_id;
        msg := jsonb_build_object('cv_error', jsonb_build_object('47',jsonb_build_array(cv_name)));
      else
        msg := jsonb_build_object('cv_error', jsonb_build_object('50', '[]'::jsonb));
      end if;
      if OLD.cct_parameter#>>'{json}' is not null then
        if (OLD.cct_parameter#>>'{json}')::jsonb#>>'{service,ck_page}' is not null then
          msg := msg || jsonb_build_object('reloadpageobject', jsonb_build_object('ck_page',(OLD.cct_parameter#>>'{json}')::jsonb#>>'{service,ck_page}','ck_page_object', (OLD.cct_parameter#>>'{json}')::jsonb#>>'{service,ck_page_object}'));
        end if;
      end if;
      INSERT INTO s_ut.t_notification
      (ck_id, cd_st, cd_en, ck_user, cl_sent, cv_message)
        VALUES(public.sys_guid(), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP + interval '1' day, coalesce(nullif(trim(OLD.cct_parameter#>>'{sess_ck_id}'), ''), OLD.ck_user), 0, msg::text);
    end if;
    RETURN NULL;
  END;
$$;

ALTER FUNCTION pkg_essence_report.add_notification_queue() OWNER TO ${user.update};

DROP TRIGGER IF EXISTS notification_queue_event ON ${user.table}.t_queue;

CREATE TRIGGER notification_queue_event
AFTER UPDATE ON ${user.table}.t_queue
  FOR EACH ROW EXECUTE PROCEDURE pkg_essence_report.add_notification_queue();

            
CREATE FUNCTION pkg_essence_report.p_modify_global_setting(pv_action varchar, INOUT pot_d_global_setting ${user.table}.t_d_global_setting) RETURNS ${user.table}.t_d_global_setting
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_d_global_setting where ck_id = pot_d_global_setting.ck_id;
        return;
    end if;
    if pot_d_global_setting.ck_id is null then
      perform pkg.p_set_error(200, 'meta:e0cd88534f90436da2b3b5eeae0ae340');
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_global_setting values (pot_d_global_setting.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_global_setting set
        (cv_value, cv_description, ck_user, ct_change) = 
        (pot_d_global_setting.cv_value, pot_d_global_setting.cv_description, pot_d_global_setting.ck_user, pot_d_global_setting.ct_change)
      where ck_id = pot_d_global_setting.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_global_setting(pv_action character varying, INOUT pot_d_global_setting ${user.table}.t_d_global_setting) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_global_setting(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_global_setting where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_global_setting(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_d_engine(pv_action varchar, INOUT pot_d_engine ${user.table}.t_d_engine) RETURNS ${user.table}.t_d_engine
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');
    if pot_d_engine.ck_id is null then
      perform pkg.p_set_error(200, 'meta:e0cd88534f90436da2b3b5eeae0ae340');
    end if;

    if pv_action = d::varchar and nullif(gv_error::varchar, '') is null then
        delete from ${user.table}.t_d_engine where ck_id = pot_d_engine.ck_id;
        return;
    end if;
    
    if pot_d_engine.cv_name is null then
      perform pkg.p_set_error(200, 'meta:e0cd88534f90436da2b3b5eeae0ae340');
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_engine values (pot_d_engine.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_engine set
        (cv_name, ck_user, ct_change) = (pot_d_engine.cv_name, pot_d_engine.ck_user, pot_d_engine.ct_change)
      where ck_id = pot_d_engine.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_d_engine(pv_action character varying, INOUT pot_d_engine ${user.table}.t_d_engine) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_d_engine(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_engine where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_d_engine(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_d_format(pv_action varchar, INOUT pot_d_format ${user.table}.t_d_format) RETURNS ${user.table}.t_d_format
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');
    if pot_d_format.ck_id is null then
        perform pkg.p_set_error(200, 'meta:e0cd88534f90436da2b3b5eeae0ae340');
    end if;
    if pv_action = d::varchar and nullif(gv_error::varchar, '') is null then
        delete from ${user.table}.t_d_format where ck_id = pot_d_format.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_format values (pot_d_format.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_format set
        (cv_name, cv_extension, cv_name_lib, cv_recipe, cct_parameter, cv_content_type, ck_user, ct_change) = 
        (pot_d_format.cv_name, pot_d_format.cv_extension, pot_d_format.cv_name_lib, pot_d_format.cv_recipe, pot_d_format.cct_parameter, pot_d_format.cv_content_type, pot_d_format.ck_user, pot_d_format.ct_change)
      where ck_id = pot_d_format.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_d_format(pv_action character varying, INOUT pot_d_format ${user.table}.t_d_format) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_d_format(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_format where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_d_format(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_report(pv_action varchar, INOUT pot_report ${user.table}.t_report) RETURNS ${user.table}.t_report
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_report_asset where ck_report = pot_report.ck_id;
        delete from ${user.table}.t_report_query where ck_report = pot_report.ck_id;
        delete from ${user.table}.t_report_format where ck_report = pot_report.ck_id;
        delete from ${user.table}.t_report where ck_id = pot_report.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_report.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_report values (pot_report.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_report set
        (cv_name, ck_d_default_queue, ck_authorization, cn_day_expire_storage, cct_parameter, cn_priority, ck_user, ct_change) = 
        (pot_report.cv_name, pot_report.ck_d_default_queue, pot_report.ck_authorization, pot_report.cn_day_expire_storage, pot_report.cct_parameter, pot_report.cn_priority, pot_report.ck_user, pot_report.ct_change)
      where ck_id = pot_report.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_report(pv_action character varying, INOUT pot_report ${user.table}.t_report) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_report(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_report where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_report(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_report_format(pv_action varchar, INOUT pot_report_format ${user.table}.t_report_format) RETURNS ${user.table}.t_report_format
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_report_format where ck_id = pot_report_format.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_report_format.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_report_format values (pot_report_format.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_report_format set
        (ck_report, ck_d_format, cct_parameter, ck_asset, ck_user, ct_change) = 
        (pot_report_format.ck_report, pot_report_format.ck_d_format, pot_report_format.cct_parameter, pot_report_format.ck_asset, pot_report_format.ck_user, pot_report_format.ct_change)
      where ck_id = pot_report_format.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_report_format(pv_action character varying, INOUT pot_report_format ${user.table}.t_report_format) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_report_format(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_report_format where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_report_format(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_report_query(pv_action varchar, INOUT pot_report_query ${user.table}.t_report_query) RETURNS ${user.table}.t_report_query
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_report_query where ck_id = pot_report_query.ck_id;
        return;
    end if;
    if pv_action = u::varchar and pot_report_query.ck_id = pot_report_query.ck_parent then
      perform pkg.p_set_error(504);
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_report_query.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_report_query values (pot_report_query.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_report_query set
        (cv_name, cv_body, ck_source, ck_report, cct_parameter, cct_source_parameter, ck_parent, ck_user, ct_change) = 
        (pot_report_query.cv_name, pot_report_query.cv_body, pot_report_query.ck_source, pot_report_query.ck_report, pot_report_query.cct_parameter, pot_report_query.cct_source_parameter, pot_report_query.ck_parent, pot_report_query.ck_user, pot_report_query.ct_change)
      where ck_id = pot_report_query.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_report_query(pv_action character varying, INOUT pot_report_query ${user.table}.t_report_query) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_report_query(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_report_query where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_report_query(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_report_asset(pv_action varchar, INOUT pot_report_asset ${user.table}.t_report_asset) RETURNS ${user.table}.t_report_asset
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_report_asset where ck_id = pot_report_asset.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_report_asset.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_report_asset values (pot_report_asset.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_report_asset set
        (cv_name, ck_asset, ck_report, cct_parameter, ck_user, ct_change) = 
        (pot_report_asset.cv_name, pot_report_asset.ck_asset, pot_report_asset.ck_report, pot_report_asset.cct_parameter, pot_report_asset.ck_user, pot_report_asset.ct_change)
      where ck_id = pot_report_asset.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_report_asset(pv_action character varying, INOUT pot_report_asset ${user.table}.t_report_asset) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_report_asset(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_report_asset where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_report_asset(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_authorization(pv_action varchar, INOUT pot_authorization ${user.table}.t_authorization) RETURNS ${user.table}.t_authorization
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_authorization where ck_id = pot_authorization.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_authorization.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_authorization values (pot_authorization.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_authorization set
        (cv_name, cv_plugin, cct_parameter, ck_user, ct_change) = 
        (pot_authorization.cv_name, pot_authorization.cv_plugin, pot_authorization.cct_parameter, pot_authorization.ck_user, pot_authorization.ct_change)
      where ck_id = pot_authorization.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_authorization(pv_action character varying, INOUT pot_authorization ${user.table}.t_authorization) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_authorization(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_authorization where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_authorization(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_source(pv_action varchar, INOUT pot_source ${user.table}.t_source) RETURNS ${user.table}.t_source
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_source where ck_id = pot_source.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_source values (pot_source.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_source set
        (cct_parameter, cv_plugin, ck_d_source, cl_enable, ck_user, ct_change) = 
        (pot_source.cct_parameter, pot_source.cv_plugin, pot_source.ck_d_source, pot_source.cl_enable, pot_source.ck_user, pot_source.ct_change)
      where ck_id = pot_source.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_source(pv_action character varying, INOUT pot_source ${user.table}.t_source) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_source(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_source where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_source(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_asset(pv_action varchar, INOUT pot_asset ${user.table}.t_asset) RETURNS ${user.table}.t_asset
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_asset where ck_id = pot_asset.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      pot_asset.ck_id := public.uuid_generate_v4();
      insert into ${user.table}.t_asset values (pot_asset.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_asset set
        (cv_name, cv_template, ck_engine, cb_asset, cct_parameter, cv_helpers, cl_archive, ck_user, ct_change) = 
        (pot_asset.cv_name, pot_asset.cv_template, pot_asset.ck_engine, pot_asset.cb_asset, pot_asset.cct_parameter, pot_asset.cv_helpers, pot_asset.cl_archive, pot_asset.ck_user, pot_asset.ct_change)
      where ck_id = pot_asset.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_asset(pv_action character varying, INOUT pot_asset ${user.table}.t_asset) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_asset(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_asset where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_asset(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_d_source_type(pv_action varchar, INOUT pot_d_source_type ${user.table}.t_d_source_type) RETURNS ${user.table}.t_d_source_type
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_d_source_type where ck_id = pot_d_source_type.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_source_type values (pot_d_source_type.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_source_type set
        (cv_name, ck_user, ct_change) = (pot_d_source_type.cv_name, pot_d_source_type.ck_user, pot_d_source_type.ct_change)
      where ck_id = pot_d_source_type.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_d_source_type(pv_action character varying, INOUT pot_d_source_type ${user.table}.t_d_source_type) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_d_source_type(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_source_type where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_d_source_type(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_d_status(pv_action varchar, INOUT pot_d_status ${user.table}.t_d_status) RETURNS ${user.table}.t_d_status
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_d_status where ck_id = pot_d_status.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_status values (pot_d_status.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_status set
        (cv_name, ck_user, ct_change) = (pot_d_status.cv_name, pot_d_status.ck_user, pot_d_status.ct_change)
      where ck_id = pot_d_status.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_d_status(pv_action character varying, INOUT pot_d_status ${user.table}.t_d_status) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_d_status(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_status where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_d_status(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_d_queue(pv_action varchar, INOUT pot_d_queue ${user.table}.t_d_queue) RETURNS ${user.table}.t_d_queue
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_d_queue where ck_id = pot_d_queue.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_queue values (pot_d_queue.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_queue set
        (cv_runner_url, ck_parent, ck_user, ct_change) = 
        (pot_d_queue.cv_runner_url, pot_d_queue.ck_parent, pot_d_queue.ck_user, pot_d_queue.ct_change)
      where ck_id = pot_d_queue.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_d_queue(pv_action character varying, INOUT pot_d_queue ${user.table}.t_d_queue) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_d_queue(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_queue where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_d_queue(pk_id varchar) OWNER TO ${user.update};

            
            
CREATE FUNCTION pkg_essence_report.p_modify_d_error(pv_action varchar, INOUT pot_d_error ${user.table}.t_d_error) RETURNS ${user.table}.t_d_error
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_essence_report', '${user.table}', 'public'
    AS $$
declare
  -- var package
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

begin
    -- init
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_d_error where ck_id = pot_d_error.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      insert into ${user.table}.t_d_error values (pot_d_error.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_d_error set
        (cv_name, ck_user, ct_change) = (pot_d_error.cv_name, pot_d_error.ck_user, pot_d_error.ct_change)
      where ck_id = pot_d_error.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_essence_report.p_modify_d_error(pv_action character varying, INOUT pot_d_error ${user.table}.t_d_error) OWNER TO ${user.update};

CREATE FUNCTION pkg_essence_report.p_lock_d_error(pk_id varchar) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_essence_report', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_d_error where ck_id::varchar = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_essence_report.p_lock_d_error(pk_id varchar) OWNER TO ${user.update};

            