--liquibase formatted sql
--changeset patcher-core:Provider_e_report dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_provider (ck_id, cv_name, ck_user, ct_change)VALUES('e_report', 'Essence report system', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-29T07:58:54.489+0000') on conflict (ck_id) do update set ck_id = excluded.ck_id, cv_name = excluded.cv_name, ck_user = excluded.ck_user, ct_change = excluded.ct_change;
