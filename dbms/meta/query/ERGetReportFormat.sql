--liquibase formatted sql
--changeset patcher-core:ERGetReportFormat dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetReportFormat', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetReportFormat*/
select t.* from (
	select
	    trf.ck_id,
	    trf.ck_report,
	    trf.ck_d_format,
	    tdf.cv_name as cv_d_format,
	    trf.ck_asset,
	    ta.cv_name as cv_asset,
	    trf.ck_user,
	    trf.ct_change at time zone :sess_cv_timezone as ct_change
	from
	    t_report_format trf
	join t_asset ta
	on ta.ck_id = trf.ck_asset
	join t_d_format tdf
	on tdf.ck_id = trf.ck_d_format
	where trf.ck_report = (:json::jsonb#>>''{master,ck_id}'')::uuid
	/*##filter.ck_id*/ and trf.ck_id = (:json::jsonb#>>''{filter,ck_id}'')::uuid/*filter.ck_id##*/
) as t
where &FILTER
order by &SORT')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
