--liquibase formatted sql
--changeset artemov_i:pkg_json_user dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_json_user cascade;

CREATE SCHEMA pkg_json_user
    AUTHORIZATION ${user.update};


ALTER SCHEMA pkg_json_user OWNER TO ${user.update};


CREATE FUNCTION pkg_json_user.f_get_context(pv_attribute character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_json_user', 'pkg_user', 'public'
    AS $$
begin
  return pkg_user.f_get_context(pv_attribute);
end;
$$;

ALTER FUNCTION pkg_json_user.f_get_context(pv_attribute character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg_json_user.f_modify_user(pc_json jsonb, pv_hash character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_json_user', 'pkg_user', 'public'
    AS $$
declare
  vct_user ct_user;
begin
  -- Обнулим глобальные переменные с перечнем ошибок/предупреждений/информационных сообщений
  perform pkg.p_reset_response();
  -- JSON -> collection
  select
    array_agg(
      (
        trim(jt.ck_id)::varchar,
        trim(jt.cv_login)::varchar,
        trim(jt.cv_surname)::varchar,
        trim(jt.cv_name)::varchar,
        trim(jt.cv_patronymic)::varchar,
        trim(jt.cv_email)::varchar,
        jt.cct_data
      )::ot_user
    )::ct_user
  into
    vct_user
  from (
    select
      (r.res->>'ck_id') as ck_id,
      (r.res->>'cv_login') as cv_login,
      (r.res->>'cv_surname') as cv_surname,
      (r.res->>'cv_name') as cv_name,
      (r.res->>'cv_patronymic') as cv_patronymic,
      (r.res->>'cv_email') as cv_email,
      r.res as cct_data
    from jsonb_array_elements(pc_json) as r(res)
  ) as jt;
  -- Проверим и сохраним данные
  perform pkg_user.p_modify_user(vct_user, pv_hash);
  return '{"ck_id":null,"cv_error":' || pkg.p_form_response() || '}';
end;
$$;


ALTER FUNCTION pkg_json_user.f_modify_user(pc_json jsonb, pv_hash character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg_json_user.f_modify_user_action(pc_json jsonb, pv_hash character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_json_user', 'pkg_user', 'public'
    AS $$
declare
  vct_user_action ct_user_action;
begin
  -- Обнулим глобальные переменные с перечнем ошибок/предупреждений/информационных сообщений
  perform pkg.p_reset_response();
  -- JSON -> collection
  select
    array_agg(
      (
        trim(jt.ck_user)::varchar,
        trim(jt.cn_action)::bigint
      )::ot_user_action
    )::ct_user_action
  into
    vct_user_action
  from(
    select
      (r.res->>'ck_user') as ck_user,
      (r.res->>'cn_action') as cn_action
    from jsonb_array_elements(pc_json) as r(res)
  ) jt;
  -- Проверим и сохраним данные
  perform pkg_user.p_modify_user_action(vct_user_action, pv_hash);
  return '{"ck_user":null,"cv_error":' || pkg.p_form_response() || '}';
end;
$$;


ALTER FUNCTION pkg_json_user.f_modify_user_action(pc_json jsonb, pv_hash character varying) OWNER TO ${user.update};

-- deprecated
CREATE FUNCTION pkg_json_user.f_modify_user_department(pc_json jsonb, pv_hash character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_json_user', 'pkg_user', 'public'
    AS $$
begin
  -- Обнулим глобальные переменные с перечнем ошибок/предупреждений/информационных сообщений
  perform pkg.p_reset_response();

  -- Проверим и сохраним данные
  perform pkg_user.p_set_context('hash_user_department', pv_hash);
  return '{"ck_user":null,"cv_error":' || pkg.p_form_response() || '}';
end;
$$;


ALTER FUNCTION pkg_json_user.f_modify_user_department(pc_json jsonb, pv_hash character varying) OWNER TO ${user.update};
