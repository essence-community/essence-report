import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import {Reporter} from "jsreport-core";
// @ts-ignore
import * as JsReportText from "jsreport-text";
import {ReadStreamToArray} from "@essence-report/plugininf/lib/stream/Util";

const defaultParam = {};
const keyLib = "jsreport-text";

export async function InitFormat(pgSql: PostgresDB, jsReport: Reporter, params: Record<string, any>) {
    if (!Object.prototype.hasOwnProperty.call(params, keyLib)) {
        await pgSql
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_d_format('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb) as result",
                null,
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "I",
                        },
                        data: {
                            ck_id: "csv",
                            cv_name: "CSV",
                            cv_extension: ".csv",
                            cv_name_lib: keyLib,
                            cv_recipe: "text",
                            cv_content_type: "text/csv",
                            cct_parameter: defaultParam,
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
        await pgSql
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_d_format('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb) as result",
                null,
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "I",
                        },
                        data: {
                            ck_id: "html",
                            cv_name: "HTML",
                            cv_extension: ".html",
                            cv_name_lib: keyLib,
                            cv_recipe: "text",
                            cv_content_type: "text/html",
                            cct_parameter: defaultParam,
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
        await pgSql
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_d_format('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb) as result",
                null,
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "I",
                        },
                        data: {
                            ck_id: "text",
                            cv_name: "TEXT",
                            cv_extension: ".txt",
                            cv_name_lib: keyLib,
                            cv_recipe: "text",
                            cv_content_type: null,
                            cct_parameter: defaultParam,
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }
    // @ts-ignore
    jsReport.use(JsReportText(params[keyLib] || defaultParam));
}
