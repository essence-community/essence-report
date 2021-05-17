import * as util from "util";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import dataBase from "@essence-report/plugininf/lib/db/DataBase";
import reportSystem from "../service/ReportSystem";
import { Execute } from "../typings";
import { NotFound } from "./NotFound";
import { QueueStatus } from "./QueueStatus";
import { Fault } from "./Fault";

export class Queue {
    public static async deleteQueue(
        ckQueue: string,
        sessionData: Record<string, any> = {},
    ): Promise<QueueStatus | NotFound> {
        const params = {
            json: JSON.stringify({
                service: {
                    cv_action: "D",
                },
                data: {
                    ck_id: ckQueue,
                },
            }),
        };

        Object.entries(sessionData).forEach(([key, value]) => {
            params[`sess_${key}`] =
                Array.isArray(value) || typeof value === "object"
                    ? JSON.stringify(value)
                    : value;
        });
        const status = await QueueStatus.getStatusByQueue(ckQueue);

        return dataBase
            .getCoreDb()
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_queue(:sess_ck_id, :sess_session, :json, 1::smallint) as result",
                null,
                params,
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(async ([row]) => {
                if (row && row.result) {
                    const result = JSON.parse(row.result);

                    if (result.cv_error) {
                        return new NotFound(
                            `Not remove found queue ${ckQueue}`,
                        );
                    } else {
                        if (status.success && status.cv_status === "success") {
                            await reportSystem.storage.deletePath(ckQueue);
                        }

                        return QueueStatus.getStatusByQueue(ckQueue);
                    }
                }

                return new NotFound(`Not found queue ${ckQueue}`);
            })
            .catch((err) => new Fault("system_error", err.message));
    }

    public static async createQueue(
        execute: Execute,
        sessionData: Record<string, any> = {},
    ): Promise<QueueStatus | NotFound> {
        const params: Record<string, any> = {
            json: {
                service: {
                    cv_action: "I",
                },
                data: {
                    ck_d_format: execute.ck_format,
                    ck_report: execute.ck_report,
                    cv_report_name: execute.cv_name,
                    cct_parameter: { ...(execute.cct_parameter || {}) },
                },
            },
        };

        Object.entries(sessionData).forEach(([key, value]) => {
            params[`sess_${key}`] =
                Array.isArray(value) || typeof value === "object"
                    ? JSON.stringify(value)
                    : value;
            params.json.data.cct_parameter[`sess_${key}`] =
                Array.isArray(value) || typeof value === "object"
                    ? JSON.stringify(value)
                    : value;
        });
        params.json = JSON.stringify(params.json);

        return dataBase
            .getCoreDb()
            .executeStmt(
                "select pkg_json_essence_report.f_modify_queue(:sess_ck_id, :sess_session, :json) as result",
                null,
                params,
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(async ([row]) => {
                if (row && row.result) {
                    const result = JSON.parse(row.result);

                    if (result.cv_error) {
                        return new Fault(
                            "db_error",
                            util.format("Error %j", result.cv_error),
                        );
                    } else {
                        return QueueStatus.getStatusByQueue(result.ck_id);
                    }
                }

                return new NotFound();
            })
            .catch((err) => new Fault("system_error", err.message));
    }
}
