--liquibase formatted sql
--changeset artemov_i:pkg dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg cascade;

CREATE SCHEMA pkg
    AUTHORIZATION ${user.update};


ALTER SCHEMA pkg OWNER TO ${user.update};

/*
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;
  gv_error sessvarstr;
  gv_warning sessvarstr;
  gv_info sessvarstr;
  gt_msg_macro sessvarstr;
  gk_msg_macro sessvari;
  gt_varchar2 sessvarstr;
  gn_user sessvari;
  gl_warning sessvari;
  gex_parentkey sessvarstr;
  gex_childrecords sessvarstr;


  i = sessvarstr_declare('pkg', 'i', 'I');
  u = sessvarstr_declare('pkg', 'u', 'U');
  d = sessvarstr_declare('pkg', 'd', 'D');
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  gv_warning = sessvarstr_declare('pkg', 'gv_warning', '');
  gv_info = sessvarstr_declare('pkg', 'gv_info', '');
  gt_msg_macro = sessvarstr_declare('pkg', 'gt_msg_macro', '{}');
  gk_msg_macro = sessvari_declare('pkg', 'gk_msg_macro', 1);
  gt_varchar2 = sessvarstr_declare('pkg', 'gt_varchar2', '{}');
  gn_user = sessvari_declare('pkg', 'gn_user', -1);
  gl_warning = sessvari_declare('pkg', 'gl_warning', 0);

  gex_parentkey = sessvarstr_declare('pkg', 'gex_parentkey', '23000'); --ORA-02291: integrity constraint violated-parent key not found
  gex_childrecords = sessvarstr_declare('pkg', 'gex_parentkey', '23503'); --ORA-02292 Constraint violation - child records found


  gex_nowait exception;
  pragma exception_init(gex_nowait, -54);          ORA-00054: указан занятый ресурс и его получение с опцией NOWAIT
  gex_connectbyloop exception;
  pragma exception_init(gex_nowait, -1436);        ORA-01436: CONNECT BY loop in user data
  gex_longField exception;
  pragma exception_init(gex_longField, -12899);    ORA-12899: value too large for column
  gex_job_exists exception;
  pragma exception_init(gex_job_exists, -27477);   ORA-27477: "JOB.NAME" already exists
*/

CREATE FUNCTION pkg.p_form_response() RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gt_msg_macro sessvarstr;

  vv_res varchar(32767);
begin
  -- инициализация/получение переменных пакета
  gt_msg_macro = sessvarstr_declare('pkg', 'gt_msg_macro', '{}');

  -- код функции
  return coalesce(
    (
      select
        jsonb_object_agg(
          t.ck_message::varchar,
          array_to_json(t.ct_macro)::jsonb
        )
      from unnest(gt_msg_macro::varchar::ct_msg_macro[]) as t
    )::varchar,
    'null'
  );
end;
$$;

ALTER FUNCTION pkg.p_form_response() OWNER TO ${user.update};

CREATE FUNCTION pkg.p_reset_response(pn_user bigint DEFAULT NULL::bigint) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gv_error sessvarstr;
  gv_warning sessvarstr;
  gv_info sessvarstr;
  gt_msg_macro sessvarstr;
  gt_varchar2 sessvarstr;
  gn_user sessvari;
  gl_warning sessvari;
begin
  -- инициализация/получение переменных пакета
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  gv_warning = sessvarstr_declare('pkg', 'gv_warning', '');
  gv_info = sessvarstr_declare('pkg', 'gv_info', '');
  gt_msg_macro = sessvarstr_declare('pkg', 'gt_msg_macro', '{}');
  gt_varchar2 = sessvarstr_declare('pkg', 'gt_varchar2', '{}');
  gn_user = sessvari_declare('pkg', 'gn_user', -1);
  gl_warning = sessvari_declare('pkg', 'gl_warning', 0);

  -- обнулим признак согласия пользователя с предупреждениями
  perform gl_warning == 0;
  -- обнулим переменные для формирования ответа на фронт
  perform gv_error == '';
  perform gv_warning == '';
  perform gv_info == '';
  -- очистим коллекции, нужные для формирования ошибок с макросами
  perform gt_varchar2 == '{}';
  perform gt_msg_macro == '{}';
  -- выставим ИД пользователя
  perform gn_user == pn_user;
end;
$$;


ALTER FUNCTION pkg.p_reset_response(pn_user bigint) OWNER TO ${user.update};

CREATE FUNCTION pkg.p_set_error(pk_id bigint, pv_macro_1 character varying DEFAULT NULL::character varying, pv_macro_2 character varying DEFAULT NULL::character varying, pv_macro_3 character varying DEFAULT NULL::character varying, pv_macro_4 character varying DEFAULT NULL::character varying, pv_macro_5 character varying DEFAULT NULL::character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gv_error sessvarstr;
begin
  -- инициализация/получение переменных пакета
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  -- код функции
  perform gv_error == (pk_id::varchar || ',' || gv_error::varchar);
  perform pkg.p_set_msg_macro(pk_id, pv_macro_1, pv_macro_2, pv_macro_3, pv_macro_4, pv_macro_5);
end;
$$;

ALTER FUNCTION pkg.p_set_error(pk_id bigint, pv_macro_1 character varying, pv_macro_2 character varying, pv_macro_3 character varying, pv_macro_4 character varying, pv_macro_5 character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg.p_set_info(pk_id bigint, pv_macro_1 character varying DEFAULT NULL::character varying, pv_macro_2 character varying DEFAULT NULL::character varying, pv_macro_3 character varying DEFAULT NULL::character varying, pv_macro_4 character varying DEFAULT NULL::character varying, pv_macro_5 character varying DEFAULT NULL::character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gv_info sessvarstr;
begin
  -- инициализация/получение переменных пакета
  gv_info = sessvarstr_declare('pkg', 'gv_info', '');
  -- код функции
  perform gv_info == (pk_id::varchar || ',' || gv_info::varchar);
  perform pkg.p_set_msg_macro(pk_id, pv_macro_1, pv_macro_2, pv_macro_3, pv_macro_4, pv_macro_5);
end;
$$;


ALTER FUNCTION pkg.p_set_info(pk_id bigint, pv_macro_1 character varying, pv_macro_2 character varying, pv_macro_3 character varying, pv_macro_4 character varying, pv_macro_5 character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg.p_set_msg_macro(pk_id bigint, pv_macro_1 character varying DEFAULT NULL::character varying, pv_macro_2 character varying DEFAULT NULL::character varying, pv_macro_3 character varying DEFAULT NULL::character varying, pv_macro_4 character varying DEFAULT NULL::character varying, pv_macro_5 character varying DEFAULT NULL::character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gt_varchar2 sessvarstr;
  gt_msg_macro sessvarstr;
  gk_msg_macro sessvari;
begin
  -- инициализация/получение переменных пакета
  gt_varchar2 = sessvarstr_declare('pkg', 'gt_varchar2', '{}');
  gt_msg_macro = sessvarstr_declare('pkg', 'gt_msg_macro', '{}');
  gk_msg_macro = sessvari_declare('pkg', 'gk_msg_macro', 1);
  -- Очистим коллекцию варчаров
  perform gt_varchar2 == '{}';
  -- Добавим макросы в коллекцию варчаров по очереди
  if pv_macro_1 is not null then
    perform pkg.sp_add(pv_macro_1);
    if pv_macro_2 is not null then
      perform pkg.sp_add(pv_macro_2);
      if pv_macro_3 is not null then
        perform pkg.sp_add(pv_macro_3);
        if pv_macro_4 is not null then
          perform pkg.sp_add(pv_macro_4);
          if pv_macro_5 is not null then
            perform pkg.sp_add(pv_macro_5);
          end if;
        end if;
      end if;
    end if;
  end if;
  -- Добавим запись в основную коллекцию
  perform gt_msg_macro == (gt_msg_macro::varchar::ct_msg_macro[] || row(gk_msg_macro::bigint, pk_id, gt_varchar2::varchar)::ct_msg_macro)::varchar;
  perform gk_msg_macro == (gk_msg_macro::bigint + 1); -- a la sequence for gt_msg_macro.ck_id
end;
$$;


ALTER FUNCTION pkg.p_set_msg_macro(pk_id bigint, pv_macro_1 character varying, pv_macro_2 character varying, pv_macro_3 character varying, pv_macro_4 character varying, pv_macro_5 character varying) OWNER TO ${user.update};

COMMENT ON FUNCTION pkg.p_set_msg_macro(pk_id bigint, pv_macro_1 character varying, pv_macro_2 character varying, pv_macro_3 character varying, pv_macro_4 character varying, pv_macro_5 character varying) IS 'Установка макросов для сообщений';

CREATE FUNCTION pkg.p_set_warning(pk_id bigint, pv_macro_1 character varying DEFAULT NULL::character varying, pv_macro_2 character varying DEFAULT NULL::character varying, pv_macro_3 character varying DEFAULT NULL::character varying, pv_macro_4 character varying DEFAULT NULL::character varying, pv_macro_5 character varying DEFAULT NULL::character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gv_warning sessvarstr;
begin
  -- инициализация/получение переменных пакета
  gv_warning = sessvarstr_declare('pkg', 'gv_warning', '');
  -- код функции
  perform gv_warning == (pk_id || ',' || gv_warning::varchar);
  perform pkg.p_set_msg_macro(pk_id, pv_macro_1, pv_macro_2, pv_macro_3, pv_macro_4, pv_macro_5);
end;
$$;


ALTER FUNCTION pkg.p_set_warning(pk_id bigint, pv_macro_1 character varying, pv_macro_2 character varying, pv_macro_3 character varying, pv_macro_4 character varying, pv_macro_5 character varying) OWNER TO ${user.update};

CREATE FUNCTION pkg.sp_add(spv_macro character varying) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg', 'public'
    AS $$
declare
  -- переменные пакета
  gt_varchar2 sessvarstr;
begin
  -- инициализация/получение переменных пакета
  gt_varchar2 = sessvarstr_declare('pkg', 'gt_varchar2', '{}');
  -- код функции
  perform gt_varchar2 == (gt_varchar2::varchar::ct_varchar || spv_macro)::varchar;
end;
$$;


ALTER FUNCTION pkg.sp_add(spv_macro character varying) OWNER TO ${user.update};

COMMENT ON FUNCTION pkg.sp_add(spv_macro character varying) IS 'саб-метод для добавления записии в коллекцию варчаров';


