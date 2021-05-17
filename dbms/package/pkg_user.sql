--liquibase formatted sql
--changeset artemov_i:pkg_user dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_user cascade;

CREATE SCHEMA pkg_user
    AUTHORIZATION ${user.update};


ALTER SCHEMA pkg_user OWNER TO ${user.update};

CREATE FUNCTION pkg_user.f_get_context(pv_attribute character varying) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_user', 'public'
    AS $$
declare
  C_CONTEXT_NAMESPACE varchar = 'ctx_m_user';
  ctx_var sessvarstr;
begin
  ctx_var = sessvarstr_declare(C_CONTEXT_NAMESPACE, pv_attribute, '');
  return nullif(ctx_var::varchar, '');
end;
$$;


ALTER FUNCTION pkg_user.f_get_context(pv_attribute character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg_user.p_modify_user(pct_user public.ct_user, pv_hash character varying DEFAULT NULL::character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_user', 'public'
    AS $$
declare
  -- переменные пакета
  gv_error sessvarstr;

  -- переменные функции
  vcur_cnt record;
begin
  -- инициализация/получение переменных пакета
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');

  -- создаем временные таблицы если они не были созданны ранее
  create temp table if not exists tt_user(
    ck_id         varchar(150),
    cv_login      varchar(30),
    cv_surname    varchar(2000),
    cv_name       varchar(2000),
    cv_patronymic varchar(2000),
    cv_email      varchar(150),
    cct_data      json
  )on commit preserve rows;

  create temp table if not exists tt_user_action(
    ck_user varchar,
    cn_action bigint
  )on commit preserve rows;

  create temp table if not exists tt_user_department(
    ck_user varchar,
    ck_department bigint
  )on commit preserve rows;

  GRANT SELECT ON TABLE tt_user TO ${user.connect};
  GRANT SELECT ON TABLE tt_user_action TO ${user.connect};
  GRANT SELECT ON TABLE tt_user_department TO ${user.connect};
  -- код функции
  /* очистим таблицу и связанные с ней */
  begin
    delete from tt_user_action;
    delete from tt_user_department;
    delete from tt_user;
    perform pkg_user.p_set_context('hash_user', null);
  exception
    when integrity_constraint_violation then
      perform pkg.p_set_error(29);
    when foreign_key_violation then
      perform pkg.p_set_error(29);
  end;
  /* зальем новые данные */
  if nullif(gv_error::varchar, '') is null then
    insert into tt_user
    select t.*
    from unnest(pct_user) as t;

    /* выставим контекст */
    for vcur_cnt in (select count(1) from tt_user) loop
      perform pkg_user.p_set_context('hash_user', pv_hash);
    end loop;
  end if;
end;
$$;

ALTER FUNCTION pkg_user.p_modify_user(pct_user public.ct_user, pv_hash character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg_user.p_modify_user_action(pct_user_action public.ct_user_action, pv_hash character varying DEFAULT NULL::character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_user', 'public'
    AS $$
declare
  vcur_cnt record;
begin
  -- создаем временные таблицы если они не были созданны ранее
   create temp table if not exists tt_user_action(
    ck_user varchar,
    cn_action bigint
  )on commit preserve rows;
  GRANT SELECT ON TABLE tt_user_action TO ${user.connect};

  /* очистим таблицу */
  delete from tt_user_action;
  perform pkg_user.p_set_context('hash_user_action', null);
  /* зальем новые данные */
  insert into tt_user_action
  select t.*
  from unnest(pct_user_action) as t;

  /* выставим контекст */
  for vcur_cnt in (select count(1) from tt_user_action) loop
    perform pkg_user.p_set_context('hash_user_action', pv_hash);
  end loop;
end;
$$;

ALTER FUNCTION pkg_user.p_modify_user_action(pct_user_action public.ct_user_action, pv_hash character varying) OWNER TO ${user.update};


CREATE FUNCTION pkg_user.p_set_context(pv_attribute character varying, pv_value character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_user', 'public'
    AS $$
declare
  C_CONTEXT_NAMESPACE varchar = 'ctx_m_user';
  ctx_var sessvarstr;
begin
  ctx_var = sessvarstr_declare(C_CONTEXT_NAMESPACE, pv_attribute, '');
  perform ctx_var == coalesce(pv_value, '');
end;
$$;


ALTER FUNCTION pkg_user.p_set_context(pv_attribute character varying, pv_value character varying) OWNER TO ${user.update};
