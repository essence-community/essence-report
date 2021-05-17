--liquibase formatted sql
--changeset patcher-core:ERGetQueue dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetQueue', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetQueue*/
select /*Pagination*/
       count(1) over() as jn_total_cnt,
       /*Queue*/
       t.*
  from (
	select
	    tq.ck_id,
	    tq.ck_d_status,
	    tds.cv_name as cv_d_status,
	    tq.ck_d_format,
	    tdf.cv_name as cv_d_format,
	    tq.ck_d_queue,
	    tq.ct_create at time zone :sess_cv_timezone as ct_create,
	    tq.ct_st at time zone :sess_cv_timezone as ct_st,
	    tq.ct_en at time zone :sess_cv_timezone as ct_en,
	    tq.ck_report,
	    tr.cv_name as cv_report,
	    tq.ck_scheduler,
	    case when tq.ck_scheduler is not null then 1 else 0 end as cl_scheduler, 
	    tq.ct_cleaning at time zone :sess_cv_timezone as ct_cleaning,
	    tq.cv_report_name,
	    tq.cn_priority,
	    tq.ck_user,
	    tq.ct_change at time zone :sess_cv_timezone as ct_change
	from
	    t_queue tq
    join t_d_status tds
    on tds.ck_id = tq.ck_d_status
    join t_d_format tdf
    on tdf.ck_id = tq.ck_d_format
    join t_report tr
    on tr.ck_id = tq.ck_report
	where true
	/*##filter.ck_id*/ and tq.ck_id = (:json::jsonb#>>''{filter,ck_id}'')::uuid/*filter.ck_id##*/
  ) t
 where &FILTER
 order by &SORT
offset &OFFSET rows
 fetch first &FETCH rows only')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
