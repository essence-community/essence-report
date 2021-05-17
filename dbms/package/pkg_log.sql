--liquibase formatted sql
--changeset artemov_i:pkg_log dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_log cascade;

CREATE SCHEMA pkg_log
    AUTHORIZATION ${user.update};


ALTER SCHEMA pkg_log OWNER TO ${user.update};

CREATE FUNCTION pkg_log.p_save(pv_user character varying, pv_session character varying, pc_json jsonb, pv_table character varying, pv_id character varying, pv_action character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_log', 'public'
    AS $$
declare
  vv_error varchar(10000);
begin
  vv_error = sessvarstr_declare('pkg', 'gv_error', '')::varchar;
  insert into ${user.table}.t_log
    (ck_id, cv_session, cc_json, cv_table, cv_id, cv_action, cv_error, ck_user, ct_change)
  values
    (nextval('seq_log'::regclass), pv_session, pc_json, pv_table, pv_id, pv_action, vv_error, pv_user, CURRENT_TIMESTAMP);
end;
$$;


ALTER FUNCTION pkg_log.p_save(pv_user character varying, pv_session character varying, pc_json jsonb, pv_table character varying, pv_id character varying, pv_action character varying) OWNER TO ${user.update};
