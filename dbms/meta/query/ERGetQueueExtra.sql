--liquibase formatted sql
--changeset patcher-core:ERGetQueueExtra dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetQueueExtra', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetQueueExtra*/
	select
	    tq.ck_id,
	    tq.ck_d_status,
	    tq.cct_parameter#>>''{}'' as cct_parameter,
	    tq.ck_d_format,
	    tq.ck_d_queue,
	    tq.ck_report,
	    tq.ck_scheduler,
	    tq.ct_cleaning at time zone :sess_cv_timezone as ct_cleaning,
	    tq.cv_report_name,
	    tq.cn_priority
	from
	    t_queue tq
	where tq.ck_id = (:json::jsonb#>>''{master,ck_id}'')::uuid
	/*##filter.ck_id*/ and tq.ck_id = (:json::jsonb#>>''{filter,ck_id}'')::uuid/*filter.ck_id##*/
and &FILTER
order by &SORT')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
