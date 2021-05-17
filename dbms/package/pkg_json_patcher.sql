--liquibase formatted sql
--changeset artemov_i:pkg_json_patcher dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_json_patcher cascade;

CREATE SCHEMA pkg_json_patcher
    AUTHORIZATION ${user.update};

ALTER SCHEMA pkg_json_patcher OWNER TO ${user.update};

CREATE FUNCTION pkg_json_patcher.f_modify_patch(pv_user character varying, pk_session character varying, pc_json jsonb) RETURNS character varying
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_json_patcher', 'pkg_patcher', 'public'
    AS $$
declare
  -- переменные пакета
  gv_error sessvarstr;
  u sessvarstr;

  -- переменные функции
  pot_create_patch  ${user.table}.t_create_patch;
  vv_action varchar(1);
begin
  -- инициализация/получение переменных пакета
  gv_error = sessvarstr_declare('pkg', 'gv_error', '');
  u = sessvarstr_declare('pkg', 'u', 'U');

  -- код функции
  --обнулим глобальные переменные с перечнем ошибок/предупреждений/информационных сообщений
  perform pkg.p_reset_response();
  --JSON -> rowtype

  pot_create_patch.ck_id = (nullif(trim(pc_json#>>'{data,ck_id}'), ''))::uuid;
  pot_create_patch.cv_file_name = nullif(trim(pc_json#>>'{data,cv_file_name}'), '');
  pot_create_patch.cn_size = (nullif(trim(pc_json#>>'{data,cn_size}'), ''))::bigint;
  pot_create_patch.сj_param = pc_json;
  pot_create_patch.cd_create = CURRENT_DATE;
  pot_create_patch.ck_user = pv_user;
  pot_create_patch.ct_change = CURRENT_TIMESTAMP;
  vv_action = (pc_json#>>'{service,cv_action}');

  --проверка прав доступа
  perform pkg_access.p_check_access(pv_user);
  if nullif(gv_error::varchar, '') is not null then
    return '{"ck_id":"","cv_error":' || pkg.p_form_response() || '}'; --ошибка прав доступа.
  end if;
  --блочим основную таблицу
  if vv_action = u::varchar then
    perform pkg_patcher.p_lock_patch(pot_create_patch.ck_id);
  end if;
  --проверяем и сохраняем данные
  pot_create_patch := pkg_patcher.p_modify_patch(vv_action, pot_create_patch);
  --логируем данные
  perform pkg_log.p_save(pv_user, pk_session, pc_json, 'pkg_json_patcher.f_modify_patch', pot_create_patch.ck_id::varchar, vv_action);
  return '{"ck_id":"' || coalesce(pot_create_patch.ck_id::varchar, '') || '","cv_error":' || pkg.p_form_response() || '}';
end;
$$;

ALTER FUNCTION pkg_json_patcher.f_modify_patch(character varying, character varying, jsonb) OWNER TO ${user.update};