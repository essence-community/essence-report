/* eslint-disable filenames/match-exported */
import * as URL from "url";
import * as http from "http";
import dataBase, { DataBase } from "@essence-report/plugininf/lib/db/DataBase";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";

import { isEmpty } from "@essence-report/plugininf/lib/utils/Base";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import { noop } from "lodash";
import Logger from "@essence-report/plugininf/lib/Logger";
import { Execute, ResultSuccess, ResultFault } from "../typings";

import { QueueStatus } from "../dto/QueueStatus";
import { Queue } from "../dto/Queue";
import { NotFound } from "../dto/NotFound";
import authService from "./AuthService";
import { reportSystem } from "./ReportSystem";

export class ExecuteService {
    private pgSql: PostgresDB;
    private logger;
    // MAX WAIT ONLINE 11 minute
    private "MAX_ONlINE_WAIT_COUNT" = 1320;
    constructor(db: DataBase) {
        this.pgSql = db.getCoreDb();
        this.logger = Logger.getLogger("TaskService");
    }

    public async runGet(
        ckQueue: string,
        session?: string,
    ): Promise<ResultSuccess | ResultFault> {
        if (isEmpty(ckQueue)) {
            return new NotFound("Not found require parameter ck_queue");
        }
        const sessionData = await authService.getAuthDataByQueue(
            ckQueue,
            session,
        );

        if (!sessionData) {
            return authService.accessDenied();
        }

        return QueueStatus.getStatusByQueue(ckQueue);
    }

    public async runDelete(
        ckQueue: string,
        session?: string,
    ): Promise<ResultSuccess | ResultFault> {
        if (isEmpty(ckQueue)) {
            return new NotFound("Not found require parameter ck_queue");
        }
        const sessionData = await authService.getAuthDataByQueue(
            ckQueue,
            session,
        );

        if (!sessionData) {
            return authService.accessDenied();
        }

        return Queue.deleteQueue(ckQueue, sessionData);
    }

    public async runPost(
        execute: Execute,
    ): Promise<ResultSuccess | ResultFault> {
        const noFound = [];

        ["ck_report", "ck_format", "cct_parameter"].forEach((key) => {
            if (isEmpty(execute[key])) {
                noFound.push(key);
            }
        });
        if (noFound.length) {
            return new NotFound(
                `Not found require parameter ${noFound.join(",")}`,
            );
        }
        const sessionData = await authService.getAuthDataByReport(
            execute.ck_report,
            execute.session,
        );

        if (!sessionData) {
            return authService.accessDenied();
        }
        const result = await Queue.createQueue(execute, sessionData);

        if (!execute.cl_online || !result.success) {
            return result;
        }

        return this.runOnline(result.ck_id);
    }

    // eslint-disable-next-line max-lines-per-function
    private async runOnline(ckQueue: string) {
        const queueParams = await this.pgSql
            .executeStmt(
                "select\n" +
                    "    tq.ck_id,\n" +
                    "    (\n" +
                    "        select\n" +
                    "            jsonb_agg(url.cv_runner_url)\n" +
                    "        from\n" +
                    "            (\n" +
                    "                with recursive ot_d_queue as (\n" +
                    "                    select\n" +
                    "                        ck_id, ck_parent, cv_runner_url, 1 as lvl\n" +
                    "                    from\n" +
                    "                        t_d_queue\n" +
                    "                    where\n" +
                    "                        ck_id = tdq.ck_id\n" +
                    "                union all\n" +
                    "                    select\n" +
                    "                        tdq2.ck_id, tdq2.ck_parent, tdq2.cv_runner_url, otdq.lvl + 1 as lvl\n" +
                    "                    from\n" +
                    "                        t_d_queue tdq2\n" +
                    "                    join ot_d_queue otdq on\n" +
                    "                        otdq.ck_parent = tdq2.ck_id\n" +
                    "                )\n" +
                    "                select\n" +
                    "                    otdq.cv_runner_url\n" +
                    "                from\n" +
                    "                    ot_d_queue otdq\n" +
                    "                where\n" +
                    "                    nullif(trim(otdq.cv_runner_url), '') is not null\n" +
                    "                order by\n" +
                    "                    otdq.lvl\n" +
                    "            ) as url\n" +
                    "    ) as url\n" +
                    "from\n" +
                    "    t_queue tq\n" +
                    "join t_d_queue tdq on\n" +
                    "    tdq.ck_id = tq.ck_d_queue\n" +
                    "where\n" +
                    "    tq.ck_d_status = 'add' and tq.ck_id = :ckQueue\n",
                null,
                {
                    ckQueue,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then((arr) =>
                arr.map((res) => {
                    res.url =
                        typeof res.url === "string"
                            ? JSON.parse(res.url)
                            : res.url;

                    return res;
                }),
            );

        if (queueParams.length) {
            try {
                await Promise.all(
                    queueParams.map((queue) => {
                        if (!queue.url || queue.url.length === 0) {
                            return reportSystem
                                .runReport(queue.ck_id)
                                .then(noop, (err) => {
                                    this.logger.error(
                                        "Error run report %s",
                                        err.message,
                                        err,
                                    );
                                });
                        }

                        return new Promise<void>((resolve, reject) => {
                            const urlRunner = URL.parse(queue.url[0], true);

                            urlRunner.query.ck_queue = queue.ck_id;
                            http.get(URL.format(urlRunner), (res) => {
                                const { statusCode } = res;
                                const contentType = res.headers["content-type"];

                                if (
                                    statusCode !== 200 ||
                                    !/^application\/json/.test(contentType)
                                ) {
                                    this.logger.error(
                                        "GET response url %j code %s content-type %s",
                                        urlRunner,
                                        statusCode,
                                        contentType,
                                    );
                                    res.resume();

                                    return reject();
                                }
                                res.setEncoding("utf8");
                                let rawData = "";

                                res.on("error", (error) => {
                                    reject(error);
                                });
                                res.on("data", (chunk) => {
                                    rawData += chunk;
                                });
                                res.on("end", () => {
                                    try {
                                        const parsedData = JSON.parse(
                                            rawData,
                                        ) as ResultSuccess | ResultFault;

                                        if (
                                            parsedData.success &&
                                            (parsedData.cv_status ===
                                                "success" ||
                                                parsedData.cv_status ===
                                                    "fault")
                                        ) {
                                            return resolve();
                                        }
                                    } catch (errorParse) {
                                        this.logger.error(
                                            "GET response url %j code %s content-type %s data %j",
                                            urlRunner,
                                            statusCode,
                                            contentType,
                                            rawData,
                                            errorParse,
                                        );

                                        return reject(errorParse);
                                    }

                                    return reject();
                                });
                            });
                        });
                    }),
                );
            } catch (e) {
                if (e) {
                    this.logger.error(e);
                }
                await this.waitDb(ckQueue);
            }
        } else {
            await this.waitDb(ckQueue);
        }

        return QueueStatus.getStatusByQueue(ckQueue);
    }

    private async waitDb(ckQueue: string, count = 0) {
        return this.pgSql
            .executeStmt(
                "select\n" +
                    "    tq.ck_id,\n" +
                    "    tq.ck_d_status\n" +
                    "from\n" +
                    "    t_queue tq\n" +
                    "where\n" +
                    "    tq.ck_id = :ckQueue\n",
                null,
                {
                    ckQueue,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(([row]) => {
                const newCount = count + 1;

                if (
                    row &&
                    row.ck_d_status === "processing" &&
                    newCount < this.MAX_ONlINE_WAIT_COUNT
                ) {
                    return new Promise((resolve, reject) => {
                        setTimeout(() => {
                            this.waitDb(ckQueue, newCount).then(
                                resolve,
                                reject,
                            );
                        }, 500);
                    });
                }
            });
    }
}

export const executeService = new ExecuteService(dataBase);
export default executeService;
