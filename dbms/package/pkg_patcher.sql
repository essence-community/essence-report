--liquibase formatted sql
--changeset artemov_i:pkg_patcher dbms:postgresql runOnChange:true splitStatements:false stripComments:false
DROP SCHEMA IF EXISTS pkg_patcher cascade;

CREATE SCHEMA pkg_patcher AUTHORIZATION ${user.update};

CREATE OR REPLACE FUNCTION pkg_patcher.p_modify_patch(pv_action character varying, INOUT pot_create_patch ${user.table}.t_create_patch) RETURNS ${user.table}.t_create_patch
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pkg_patcher', '${user.table}', 'public'
    AS $$
declare
  -- переменные пакета
  i sessvarstr;
  u sessvarstr;
  d sessvarstr;

  gv_error sessvarstr;

  -- переменные функции
begin
    -- инициализация/получение переменных пакета
    i = sessvarstr_declare('pkg', 'i', 'I');
    u = sessvarstr_declare('pkg', 'u', 'U');
    d = sessvarstr_declare('pkg', 'd', 'D');
    gv_error = sessvarstr_declare('pkg', 'gv_error', '');

    if pv_action = d::varchar then
        delete from ${user.table}.t_create_patch where ck_id = pot_create_patch.ck_id;
        return;
    end if;
    if nullif(gv_error::varchar, '') is not null then
   	    return;
    end if;
    if pv_action = i::varchar then
      if pot_create_patch.ck_id is null then
        pot_create_patch.ck_id := uuid_generate_v4();
      end if;
      insert into ${user.table}.t_create_patch values (pot_create_patch.*);
    elsif pv_action = u::varchar then
      update ${user.table}.t_create_patch set
        (cv_file_name, ck_user, ct_change) = (pot_create_patch.cv_file_name, pot_create_patch.ck_user, pot_create_patch.ct_change)
      where ck_id = pot_create_patch.ck_id;
      if not found then
        perform pkg.p_set_error(504);
      end if;
    end if;
end;
$$;

ALTER FUNCTION pkg_patcher.p_modify_patch(pv_action character varying, INOUT pot_create_patch ${user.table}.t_create_patch) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_patcher.p_lock_patch(pk_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO '${user.table}', 'pkg_patcher', 'public'
    AS $$
declare
  vn_lock bigint;
begin
  if pk_id is not null then
    select 1 into vn_lock from ${user.table}.t_create_patch where ck_id = pk_id for update nowait;
  end if;
end;
$$;


ALTER FUNCTION pkg_patcher.p_lock_patch(pk_id uuid) OWNER TO ${user.update};

CREATE OR REPLACE FUNCTION pkg_patcher.p_change_role_connect_user(pv_connect_user VARCHAR, pv_table_schema VARCHAR) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO '${user.table}', 'pkg_patcher', 'public'
    AS $$
declare
  rec record;
begin
  for rec in (select 'GRANT USAGE ON SCHEMA ' || nspname || ' TO ' || pv_connect_user || ';' as alter_cmd 
    from pg_catalog.pg_namespace 
    where lower(nspname) like 'pkg_json_%') loop
    EXECUTE rec.alter_cmd;
  end loop;
  
  EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s', pv_table_schema, pv_connect_user);

  for rec in (select
    'GRANT SELECT ON TABLE ' || schemaname || '.' || tablename || ' TO ' || pv_connect_user || ';' as alter_cmd 
    from
        pg_catalog.pg_tables
    where
    lower(schemaname) = lower(pv_table_schema)) loop
    EXECUTE rec.alter_cmd;
  end loop;

  for rec in (select
    'GRANT EXECUTE ON FUNCTION ' || nsp.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid)|| ') TO ' || pv_connect_user || ';' as alter_cmd 
    from
        pg_proc p
    join pg_namespace nsp on
        p.pronamespace = nsp.oid
    where
        lower(nsp.nspname) like 'pkg_json_%') loop
    EXECUTE rec.alter_cmd;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION pkg_patcher.p_change_role_update_user(pv_update_user VARCHAR, pv_table_schema VARCHAR) RETURNS void
    LANGUAGE plpgsql
    SET search_path TO '${user.table}', 'pkg_patcher', 'public'
    AS $$
declare
  rec record;
begin
  for rec in (select 'ALTER SCHEMA ' || nspname || ' OWNER TO ' || pv_update_user || ';' as alter_cmd 
    from pg_catalog.pg_namespace 
    where lower(nspname) like 'pkg_%') loop
    EXECUTE rec.alter_cmd;
  end loop;

  EXECUTE format('GRANT USAGE ON SCHEMA %s TO %s', pv_table_schema, pv_update_user);

  for rec in (select
    'GRANT INSERT, SELECT, UPDATE, DELETE ON TABLE ' || schemaname || '.' || tablename || ' TO ' || pv_update_user || ';' as alter_cmd 
    from
        pg_catalog.pg_tables
    where
    lower(schemaname) = lower(pv_table_schema)) loop
    EXECUTE rec.alter_cmd;
  end loop;

  for rec in (select
    'ALTER FUNCTION ' || nsp.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid)|| ') OWNER TO ' || pv_update_user || ';'  as alter_cmd
    from
        pg_proc p
    join pg_namespace nsp on
        p.pronamespace = nsp.oid
    where
        lower(nsp.nspname) like 'pkg_%') loop
    EXECUTE rec.alter_cmd;
  end loop;
end;
$$;
