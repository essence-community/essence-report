--liquibase formatted sql
--changeset artemov_i:public_init dbms:postgresql splitStatements:false stripComments:false
create or replace function public.sys_guid()
returns varchar as
$$
begin
  return upper(replace(uuid_generate_v4()::varchar, '-', ''));
end;
$$language plpgsql;

create table public.dual(dummy varchar);
insert into public.dual(dummy) values('X');

--create type public

create domain public.ct_varchar as varchar[];
create type public.ct_msg_macro as (ck_id bigint, ck_message bigint, ct_macro ct_varchar);

create type public.ot_user as
 (
  ck_id         varchar(150),
  cv_login      varchar(30),
  cv_surname    varchar(2000),
  cv_name       varchar(2000),
  cv_patronymic varchar(2000),
  cv_email      varchar(150),
  cct_data      json
);

create domain public.ct_user as public.ot_user[];

create type public.ot_user_action as
(
  ck_user varchar(150),
  cn_action bigint
);

create domain public.ct_user_action as public.ot_user_action[];


CREATE OR REPLACE FUNCTION public.notify_event() RETURNS TRIGGER AS $$
  DECLARE
    record RECORD;
    payload JSON;
  BEGIN
    IF (TG_OP = 'DELETE') THEN
      record = OLD;
    ELSE
      record = NEW;
    END IF;

    payload = json_build_object('table', TG_TABLE_NAME,
                                'action', TG_OP,
                                'data', row_to_json(record));

    PERFORM pg_notify('events', payload::text);

    RETURN NULL;
  END;
$$ LANGUAGE plpgsql;

--changeset artemov_i:log dbms:postgresql
CREATE SEQUENCE public.seq_log
 INCREMENT 1 MINVALUE 1
 START 1 CACHE 1;
