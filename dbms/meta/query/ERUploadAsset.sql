--liquibase formatted sql
--changeset patcher-core:ERUploadAsset dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERUploadAsset', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'dml', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERUploadAsset*/
select pkg_json_essence_report.f_modify_asset(:sess_ck_id, :sess_session, :json::jsonb, :upload_file, :upload_file_name, :upload_file_type) as result')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
