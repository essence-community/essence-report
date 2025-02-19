--liquibase formatted sql
--changeset patcher-core:ERGetReport dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetReport', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetReport*/
select /*Pagination*/
       count(1) over() as jn_total_cnt,
       /*Report*/
       t.*
  from (
	select
	    tr.ck_id,
	    tr.cv_name,
	    tr.ck_d_default_queue,
	    tr.ck_authorization,
	    ta.cv_name as cv_authorization,
	    tr.cn_day_expire_storage,
	    tr.cn_priority,
	    tr.ck_user,
	    tr.ct_change at time zone :sess_cv_timezone as ct_change
	from
	    t_report tr
    join t_authorization ta
    on tr.ck_authorization = ta.ck_id
	where true
	/*##filter.ck_id*/ and tr.ck_id = (:json::jsonb#>>''{filter,ck_id}'')::uuid/*filter.ck_id##*/
  ) t
 where &FILTER
 order by &SORT
offset &OFFSET rows
 fetch first &FETCH rows only')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
