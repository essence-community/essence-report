--liquibase formatted sql
--changeset artemov_i:public_global_var dbms:postgresql splitStatements:false stripComments:false
/*
 Целочисленный тип
*/
create type public.sessvari as (nm_ext varchar);

-- функция декларирования
create or replace function public.sessvari_declare(p_pcg_name varchar, p_var_name varchar, p_init_value bigint)
returns sessvari as
$$
declare 
  v_nm_ext varchar = ('sessvari.' || p_pcg_name || '_' || p_var_name);
begin
  if nullif(current_setting(v_nm_ext, true), '') is null then
    perform set_config(v_nm_ext, p_init_value::varchar, false);
  end if;
  
  return row(v_nm_ext)::sessvari;
end;
$$language plpgsql;

grant execute on function public.sessvari_declare(varchar, varchar, bigint) to public;

-- функция установки значения из типа bigint
create or replace function public.sessvari_seti(p_var sessvari, p_value bigint)
returns sessvari as
$$
declare
begin
  perform set_config(p_var.nm_ext, p_value::varchar, false);
  return p_var;
end;
$$language plpgsql;
grant execute on function public.sessvari_seti(sessvari, bigint) to public;

create operator public.==(
  LEFTARG = sessvari,
  RIGHTARG = bigint,
  PROCEDURE = public.sessvari_seti
);

-- функции преобразования к скалярым типам
create or replace function public.sessvari_getbi(p_var sessvari)
returns bigint as
$$
declare
begin
  return nullif(current_setting(p_var.nm_ext, true), '')::bigint;
end;
$$language plpgsql;
grant execute on function public.sessvari_getbi(sessvari) to public;

create cast(sessvari as bigint) with function public.sessvari_getbi(sessvari) as assignment;

create or replace function public.sessvari_geti(p_var sessvari)
returns int as
$$
declare
begin
  return nullif(current_setting(nullif(p_var.nm_ext, ''), true), '')::int;
end;
$$language plpgsql;
grant execute on function public.sessvari_geti(sessvari) to public;

create cast(sessvari as int) with function public.sessvari_geti(sessvari) as assignment;

/*
  Вещественный тип
*/
create type public.sessvarf as (nm_ext varchar);

-- функция декларирования
create or replace function public.sessvarf_declare(p_pcg_name varchar, p_var_name varchar, p_init_value float)
returns sessvarf as
$$
declare 
  v_nm_ext varchar = ('sessvarf.' || p_pcg_name || '_' || p_var_name);
begin
  if nullif(current_setting(v_nm_ext, true), '') is null then
    perform set_config(v_nm_ext, p_init_value::varchar, false);
  end if;
  
  return row(v_nm_ext)::sessvarf;
end;
$$language plpgsql;

grant execute on function public.sessvarf_declare(varchar, varchar, float) to public;

-- функция установки значения из типа float
create or replace function public.sessvarf_setf(p_var sessvarf, p_value float)
returns sessvarf as
$$
declare
begin
  perform set_config(p_var.nm_ext, p_value::varchar, false);
  return p_var;
end;
$$language plpgsql;
grant execute on function public.sessvarf_setf(sessvarf, float) to public;

create operator public.==(
  LEFTARG = sessvarf,
  RIGHTARG = float,
  PROCEDURE = public.sessvarf_setf
);

-- функции преобразования к скалярым типам
create or replace function public.sessvarf_getbf(p_var sessvarf)
returns float as
$$
declare
begin
  return nullif(current_setting(p_var.nm_ext, true), '')::float;
end;
$$language plpgsql;
grant execute on function public.sessvarf_getbf(sessvarf) to public;

create cast(sessvarf as float) with function public.sessvarf_getbf(sessvarf) as assignment;

/*
  Строчный тип
*/
create type public.sessvarstr as (nm_ext varchar);

-- функция декларирования
create or replace function public.sessvarstr_declare(p_pcg_name varchar, p_var_name varchar, p_init_value varchar)
returns sessvarstr as
$$
declare 
  v_nm_ext varchar = ('sessvarstr.' || p_pcg_name || '_' || p_var_name);
begin
  if nullif(current_setting(v_nm_ext, true), '') is null then
    perform set_config(v_nm_ext, p_init_value, false);
  end if;
  
  return row(v_nm_ext)::sessvarstr;
end;
$$language plpgsql;

grant execute on function public.sessvarstr_declare(varchar, varchar, varchar) to public;

-- функция установки значения из типа varchar
create or replace function public.sessvarstr_setstr(p_var sessvarstr, p_value varchar)
returns sessvarstr as
$$
declare
begin
  perform set_config(p_var.nm_ext, p_value, false);
  return p_var;
end;
$$language plpgsql;

grant execute on function public.sessvarstr_setstr(sessvarstr, varchar) to public;

create operator public.==(
  LEFTARG = sessvarstr,
  RIGHTARG = varchar,
  PROCEDURE = public.sessvarstr_setstr
);

-- функции преобразования к скалярым типам
create or replace function public.sessvarstr_getbstr(p_var sessvarstr)
returns varchar as
$$
declare
begin
  return current_setting(p_var.nm_ext, true);
end;
$$language plpgsql;
grant execute on function public.sessvarstr_getbstr(sessvarstr) to public;

create cast(sessvarstr as varchar) with function public.sessvarstr_getbstr(sessvarstr) as assignment;
