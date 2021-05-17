--liquibase formatted sql
--changeset artemov_i:s_su_init dbms:postgresql splitStatements:false stripComments:false
--для корректной работы функции sys_guid (uuid_generate_v4)
create extension IF NOT EXISTS "uuid-ossp";
