import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import {Reporter} from "@jsreport/jsreport-core";
// @ts-ignore
import * as JsReportDocxTemplater from "@jsreport/jsreport-docxtemplater";
import {ReadStreamToArray} from "@essence-report/plugininf/lib/stream/Util";

const defaultParam = {};
const keyLib = "jsreport-docxtemplater";

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
                            ck_id: "docx-docxtemplater",
                            cv_name: "DOCX",
                            cv_extension: ".docx",
                            cv_name_lib: keyLib,
                            cv_recipe: "docxtemplater",
                            cv_content_type: null,
                            cct_parameter: defaultParam,
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }
    // @ts-ignore
    jsReport.use(JsReportDocxTemplater(params[keyLib] || defaultParam));
}
