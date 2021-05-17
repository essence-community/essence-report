/* eslint-disable filenames/match-exported */
import * as http from "http";
import * as URL from "url";
import dataBase, { DataBase } from "@essence-report/plugininf/lib/db/DataBase";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";

import Connection from "@essence-report/plugininf/lib/db/Connection";
import Logger from "@essence-report/plugininf/lib/Logger";
import * as cron from "cron";
import { throttle, isEmpty } from "@essence-report/plugininf/lib/utils/Base";
import { noop } from "lodash";
import * as CronParser from "cron-parser";
import reportSystem from "../service/ReportSystem";

export class TaskService {
    private pgSql: PostgresDB;
    private eventConnect: Connection;
    private logger;
    private job: cron.CronJob;
    private jobScheduler: cron.CronJob;
    private jobDeleteQueue: cron.CronJob;
    constructor(db: DataBase) {
        this.pgSql = db.getCoreDb();
        this.logger = Logger.getLogger("TaskService");
    }

    private _execute = async () => {
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
                    "    tq.ck_d_status = 'add'\n",
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

        queueParams.forEach((queue) => {
            if (!queue.url || queue.url.length === 0) {
                reportSystem.runReport(queue.ck_id).then(noop, (err) => {
                    this.logger.error("Error run report %s", err.message, err);
                });

                return;
            }
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

                    return;
                }
                res.setEncoding("utf8");
                let rawData = "";

                res.on("data", (chunk) => {
                    rawData += chunk;
                });
                res.on("end", () => {
                    try {
                        const parsedData = JSON.parse(rawData);

                        if (parsedData.success) {
                            this.logger.trace(
                                "GET response url %j code %s content-type %s data %j",
                                urlRunner,
                                statusCode,
                                contentType,
                                rawData,
                            );
                        } else {
                            this.logger.error(
                                "GET response url %j code %s content-type %s data %j",
                                urlRunner,
                                statusCode,
                                contentType,
                                rawData,
                            );
                        }
                    } catch (e) {
                        this.logger.error(
                            "GET response url %j code %s content-type %s data %j",
                            urlRunner,
                            statusCode,
                            contentType,
                            rawData,
                        );
                    }

                    return;
                });
            });
        });
    };

    public execute = throttle(this._execute, 1000);

    public async init() {
        this.logger.debug("Init task service");
        this.eventConnect = await this.pgSql.getConnection();
        const conn = this.eventConnect.getCurrentConnection();

        conn.on("notification", (msg) => {
            this.logger.debug("Notification %j", msg);
            const payload = JSON.parse(msg.payload);

            if (
                payload.table &&
                payload.table.toLowerCase().endsWith("t_queue")
            ) {
                this.execute();
            }
        });
        await conn.query("LISTEN events");
        this.job = new cron.CronJob({
            cronTime: "*/1 * * * * *",
            onTick: () => {
                try {
                    this.logger.trace("Run execute task runner");
                    this.execute();
                } catch (err) {
                    this.logger.error(err.message, err);
                }
            },
            start: true,
            timeZone: "Europe/Moscow",
        });
        this.job.start();
        this.jobScheduler = new cron.CronJob({
            cronTime: "0 */1 * * * *",
            onTick: () => {
                try {
                    this.logger.trace("Run scheduler task runner");
                    this.executeScheduler();
                } catch (err) {
                    this.logger.error(err.message, err);
                }
            },
            start: true,
            timeZone: "Europe/Moscow",
        });
        this.jobScheduler.start();
        this.jobDeleteQueue = new cron.CronJob({
            cronTime: "0 0 1 * * *",
            onTick: () => {
                try {
                    this.logger.trace("Run delete queue task runner");
                    this.executeDeleteQueue();
                } catch (err) {
                    this.logger.error(err.message, err);
                }
            },
            start: true,
            timeZone: "Europe/Moscow",
        });
        this.jobDeleteQueue.start();
    }

    public async executeScheduler() {
        const conn = await this.pgSql.getConnection();

        try {
            const schedulerData = await conn
                .executeStmt(
                    "select\n" +
                        "    *\n" +
                        "from\n" +
                        "    pkg_json_essence_report.f_get_scheduler()",
                )
                .then((res) => ReadStreamToArray(res.stream));

            await Promise.all(
                schedulerData.map(async (scheduler) => {
                    if (isEmpty(scheduler.ct_next_run_cron)) {
                        await this.changeNextTime(scheduler, conn);

                        return;
                    }
                    await conn
                        .executeStmt(
                            // eslint-disable-next-line max-len
                            "select pkg_json_essence_report.f_modify_queue('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb, 1::smallint) as result",
                            {
                                json: JSON.stringify({
                                    service: {
                                        cv_action: "I",
                                    },
                                    data: {
                                        ck_d_format: scheduler.ck_d_format,
                                        ck_report: scheduler.ck_report,
                                        cv_report_name:
                                            scheduler.cv_report_name,
                                        cct_parameter: {
                                            ...(scheduler.cct_parameter || {}),
                                        },
                                        ck_scheduler: scheduler.ck_id,
                                        ck_user: scheduler.ck_user,
                                    },
                                }),
                            },
                        )
                        .then((res) => ReadStreamToArray(res.stream));
                    await this.changeNextTime(scheduler, conn);
                }),
            );
            await conn.commit();
        } catch (err) {
            this.logger.error(err);
        } finally {
            conn.rollbackAndRelease();
        }
    }
    public async executeDeleteQueue() {
        const conn = await this.pgSql.getConnection();

        try {
            const needDeleteData = await conn
                .executeStmt(
                    "select\n" +
                        "    ck_id\n" +
                        "from\n" +
                        "    pkg_json_essence_report.f_get_need_delete()",
                )
                .then((res) => ReadStreamToArray(res.stream));

            await Promise.all(
                needDeleteData.map(async (needDelete) => {
                    await conn
                        .executeStmt(
                            // eslint-disable-next-line max-len
                            "select pkg_json_essence_report.f_modify_queue('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb, 1::smallint) as result",
                            {
                                json: JSON.stringify({
                                    service: {
                                        cv_action: "D",
                                    },
                                    data: {
                                        ck_id: needDelete.ck_id,
                                    },
                                }),
                            },
                        )
                        .then((res) => ReadStreamToArray(res.stream));
                    await reportSystem.storage.deletePath(needDelete.ck_id);
                }),
            );
            await conn.commit();
        } catch (err) {
            this.logger.error(err);
        } finally {
            conn.rollbackAndRelease();
        }
    }
    private async changeNextTime(scheduler, conn) {
        const options = {
            currentDate: scheduler.ct_current_time,
        };

        try {
            let nextTime = null;

            if (!isEmpty(scheduler.cv_unix_cron)) {
                const interval = CronParser.parseExpression(
                    `0 ${scheduler.cv_unix_cron}`,
                    options,
                );

                nextTime = interval.next();
                this.logger.trace(
                    "Scheduler %s cron %s next start time %s current time %s",
                    scheduler.ck_id,
                    scheduler.cv_unix_cron,
                    nextTime,
                    scheduler.ct_current_time,
                );
            }
            await conn
                .executeStmt(
                    // eslint-disable-next-line max-len
                    "select pkg_json_essence_report.f_modify_scheduler('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb, 1::smallint) as result",
                    {
                        json: JSON.stringify({
                            service: {
                                cv_action: "U",
                            },
                            data: {
                                ck_id: scheduler.ck_id,
                                ct_next_run_cron: nextTime,
                            },
                        }),
                    },
                )
                .then((res) => ReadStreamToArray(res.stream));
        } catch (err) {
            this.logger.error("Interval Error %s", err.message, err);
        }
    }
}

export const taskService = new TaskService(dataBase);
export default taskService;
