--liquibase formatted sql
--changeset patcher-core:ERGetReportQueryExtra dbms:postgresql runOnChange:true splitStatements:false stripComments:false
INSERT INTO s_mt.t_query (ck_id, ck_provider, ck_user, ct_change, cr_type, cr_access, cn_action, cv_description, cc_query)
 VALUES('ERGetReportQueryExtra', 'e_report', '4fd05ca9-3a9e-4d66-82df-886dfa082113', '2020-10-28T08:52:27.000+0000', 'select', 'po_session', null, 'Список настроек отчетного сервера ',
 '/*ERGetReportQueryExtra*/
select
    trq.ck_id,
    trq.cv_name,
    trq.cv_body,
    trq.ck_source,
    trq.ck_report,
    trq.ck_parent,
    trq.cct_parameter#>>''{}'' as cct_parameter,
    trq.cct_source_parameter#>>''{}'' as cct_source_parameter
from
    t_report_query trq
where trq.ck_id = (:json::jsonb#>>''{master,ck_id}'')::uuid
/*##filter.ck_id*/ and trq.ck_id = (:json::jsonb#>>''{filter,ck_id}'')::uuid/*filter.ck_id##*/
and &FILTER
order by &SORT')
 on conflict (ck_id) do update set cc_query = excluded.cc_query, ck_provider = excluded.ck_provider, ck_user = excluded.ck_user, ct_change = excluded.ct_change, cr_type = excluded.cr_type, cr_access = excluded.cr_access, cn_action = excluded.cn_action, cv_description = excluded.cv_description;
