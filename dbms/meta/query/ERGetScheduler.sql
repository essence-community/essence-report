--liquibase formatted sql
--changeset patcher-core:ERGetScheduler dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetScheduler', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetScheduler*/
select /*Pagination*/
       count(1) over() as jn_total_cnt,
       /*Scheduler*/
       t.*
  from (
	select
	    ts.ck_id,
	    ts.cn_priority,
	    ts.cv_unix_cron,
	    ts.ct_next_run_cron at time zone :sess_cv_timezone as ct_next_run_cron,
	    ts.ck_d_format,
	    tdf.cv_name as cv_d_format,
	    ts.ck_report,
	    tr.cv_name as cv_report,
	    ts.cv_report_name,
	    ts.ct_start_run_cron at time zone :sess_cv_timezone as ct_start_run_cron,
	    ts.cl_enable,
	    ts.ck_user,
	    ts.ct_change at time zone :sess_cv_timezone as ct_change
	from
	    t_scheduler ts
    join t_d_format tdf
    on tdf.ck_id = ts.ck_d_format
    join t_report tr
    on tr.ck_id = ts.ck_report
	where true
	/*##filter.ck_id*/ and ts.ck_id = (:json::jsonb#>>''{filter,ck_id}'')::uuid/*filter.ck_id##*/
  ) t
 where &FILTER
 order by &SORT
offset &OFFSET rows
 fetch first &FETCH rows only')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
