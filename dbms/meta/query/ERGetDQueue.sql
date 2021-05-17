--liquibase formatted sql
--changeset patcher-core:ERGetDQueue dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetDQueue', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetDQueue*/
select
    ck_id,
    cv_runner_url,
    ck_parent,
    ck_user,
    ct_change at time zone :sess_cv_timezone as ct_change
from
    t_d_queue
where true
/*##filter.ck_id*/ and ck_id = :json::jsonb#>>''{filter,ck_id}''/*filter.ck_id##*/
and &FILTER
order by &SORT')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
