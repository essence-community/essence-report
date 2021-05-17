import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import {Reporter} from "jsreport-core";
// @ts-ignore
import * as JsReportChromePdf from "jsreport-chrome-pdf";
import {ReadStreamToArray} from "@essence-report/plugininf/lib/stream/Util";

const defaultParam = {timeout: 99999999, strategy: "chrome-pool", numberOfWorkers: 4};
const keyLib = "jsreport-chrome-pdf";

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
                            ck_id: "pdf-chrome",
                            cv_name: "PDF",
                            cv_extension: ".pdf",
                            cv_name_lib: keyLib,
                            cv_recipe: "chrome-pdf",
                            cv_content_type: null,
                            cct_parameter: defaultParam,
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }
    // @ts-ignore
    jsReport.use(JsReportChromePdf(params[keyLib] || defaultParam));
}
