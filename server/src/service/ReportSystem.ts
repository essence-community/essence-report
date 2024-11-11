/* eslint-disable max-lines-per-function */
/* eslint-disable max-statements */
/* eslint-disable filenames/match-exported */
import { Readable } from "stream";
import * as path from "path";
import * as fs from "fs";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import * as JsReport from "@jsreport/jsreport-core";
// @ts-ignore
import * as JsReportHandlerBars from "@jsreport/jsreport-handlebars";
import Logger from "@essence-report/plugininf/lib/Logger";
import { IStorage } from "@essence-report/plugininf/lib/interfaces/IStorage";
import { defaultsDeep } from "lodash";
import { IReportData } from "@essence-report/plugininf/lib/interfaces/IReportData";
import dataBase, { DataBase } from "@essence-report/plugininf/lib/db/DataBase";
import Connection from "@essence-report/plugininf/lib/db/Connection";
import {
    deleteFolderRecursive,
    isEmpty,
} from "@essence-report/plugininf/lib/utils/Base";
import * as AdmZip from "adm-zip";
import { TMP_DIR } from "../constant";
import { LocalStorage } from "../storage/LocalStorage";
import { DirStorage } from "../storage/DirStorage";
import { S3Storage } from "../storage/S3Storage";
import { ManagerFormat } from "../managerplugin/ManagerFormat";
import { ManagerSource } from "../managerplugin/ManagerSource";
import { ReportAssets } from "../jsreportsmodule/ReportAssets";
import { defaultHelper, engineHelper } from "../jsreportsmodule/Helper";

export class ReportSystem {
    private pgSql: PostgresDB;
    private jsReport: JsReport.Reporter;
    private managerSource: ManagerSource;
    private managerFormat: ManagerFormat;
    public params: Record<string, string>;
    public storage: IStorage;
    private logger;
    constructor(db: DataBase) {
        this.pgSql = db.getCoreDb();
        this.managerSource = new ManagerSource(this.pgSql);
        this.logger = Logger.getLogger("ReportSystem");
        this.managerFormat = new ManagerFormat(this.pgSql);
    }
    public async init() {
        this.params = await this.pgSql
            .executeStmt("select ck_id, cv_value from t_d_global_setting")
            .then((res) => ReadStreamToArray(res.stream))
            .then((arr) =>
                arr.reduce((res, obj) => {
                    res[obj.ck_id] = obj.cv_value;

                    return res;
                }, {}),
            );
        this.jsReport = JsReport(
            defaultsDeep(JSON.parse(this.params.JSREPORT_SETTING || "{}"), {
                reportTimeout: 99999999,
                timeout: 99999999,
                tasks: {
                    allowedModules: "*",
                },
                extensions: {
                    authentication: {
                        enabled: false,
                    },
                    studio: {
                        enabled: false,
                    },
                    express: {
                        enabled: false,
                    },
                    assets: {
                        allowedFiles: "**/*.*",
                        searchOnDiskIfNotFoundInStore: true,
                    },
                },
            }),
        );
        const paramFormat = await this.pgSql
            .executeStmt("select cv_name_lib, cct_parameter from t_d_format")
            .then((res) => ReadStreamToArray(res.stream))
            .then((arr) =>
                arr.reduce((res, obj) => {
                    res[obj.cv_name_lib] =
                        typeof obj.cct_parameter === "string"
                            ? JSON.parse(obj.cct_parameter)
                            : obj.cct_parameter;

                    return res;
                }, {}),
            );

        await this.managerFormat.init(this.jsReport, paramFormat);
        // @ts-ignore
        this.jsReport.use(JsReportHandlerBars());
        // @ts-ignore
        // this.jsReport.use(ReportAssets());
        switch (this.params.TYPE_STORAGE) {
            case "riak":
            case "aws":
                this.storage = new S3Storage(this.params, this.logger);
                break;
            case "local":
                this.storage = new LocalStorage(this.params, this.logger);
                break;
            default:
                this.storage = new DirStorage(this.params, this.logger);
                break;
        }
        await this.managerSource.init();
        await this.jsReport.init();
    }

    public async runReport(ckQueue: string) {
        this.logger.debug("Init connection");
        const conn = await this.pgSql.getConnection();
        const queuePath = path.resolve(TMP_DIR, `assets_${ckQueue}`);

        fs.mkdirSync(queuePath, {
            recursive: true,
        });
        try {
            this.logger.debug("Lock queue %s", ckQueue);
            const [rowLock] = await conn
                .executeStmt(
                    "select pkg_json_essence_report.f_processing_queue(:ckQueue) as success",
                    {
                        ckQueue,
                    },
                    null,
                    {
                        autoCommit: true
                    }
                )
                .then((res) => ReadStreamToArray(res.stream));

            if (isEmpty(rowLock) || rowLock.success !== "true") {
                return;
            }
            this.logger.debug("Load queue param %s", ckQueue);
            const reportData: IReportData = await conn
                .executeStmt(
                    "select\n" +
                        "    tq.cct_parameter,\n" +
                        "    tr.cct_parameter as cct_report_parameter,\n" +
                        "    coalesce(nullif(trim(tq.cv_report_name), ''), " +
                        "regexp_replace(tr.cv_name, '^.*\\/(.+)$', '\\1')) || " +
                        " tdf.cv_extension  as cv_report_name,\n" +
                        "    trf.cct_parameter as cct_format_parameter,\n" +
                        "    tdf.cv_content_type,\n" +
                        "    ta.ck_engine,\n" +
                        "    ta.cv_helpers,\n" +
                        "    ta.cv_template,\n" +
                        "    ta.cb_asset,\n" +
                        "    ta.cl_archive,\n" +
                        "    tdf.cv_recipe,\n" +
                        "    (\n" +
                        "        select\n" +
                        "            jsonb_agg(tq2.*)\n" +
                        "        from\n" +
                        "            t_report_query tq2\n" +
                        "        where\n" +
                        "            tq2.ck_report = tq.ck_report\n" +
                        "    ) as query\n" +
                        "from\n" +
                        "    t_queue tq\n" +
                        "join t_report tr on\n" +
                        "    tq.ck_report = tr.ck_id\n" +
                        "join t_report_format trf on\n" +
                        "    tq.ck_report = trf.ck_report\n" +
                        "    and tq.ck_d_format = trf.ck_d_format\n" +
                        "join t_asset ta on\n" +
                        "    trf.ck_asset = ta.ck_id\n" +
                        "join t_d_format tdf on\n" +
                        "    tdf.ck_id = trf.ck_d_format\n" +
                        "where\n" +
                        "    tq.ck_id = :ckQueue::uuid\n",
                    {
                        ckQueue,
                    },
                    null,
                    {
                        autoCommit: true
                    }
                )
                .then((res) => ReadStreamToArray(res.stream))
                .then(async ([row]) => {
                    if (row) {
                        const reportQuery =
                            typeof row.query === "string"
                                ? JSON.parse(row.query)
                                : row.query || [];
                        const archive =
                            typeof row.cl_archive === "number"
                                ? Boolean(row.cl_archive)
                                : row.cl_archive === "1";
                        let content = null;
                        let templateAsset = null;

                        if (archive) {
                            const zip = new AdmZip(row.cb_asset);

                            zip.extractAllTo(queuePath, true);
                            fs.readdirSync(queuePath).forEach((fileName) => {
                                const filePath = path.resolve(
                                    queuePath,
                                    fileName,
                                );

                                if (fileName.toLowerCase() === "main") {
                                    content = fs
                                        .readFileSync(filePath)
                                        .toString();
                                }
                                if (
                                    fileName
                                        .toLowerCase()
                                        .indexOf("template_asset") > -1 ||
                                    fileName
                                        .toLowerCase()
                                        .indexOf("templateasset") > -1
                                ) {
                                    templateAsset = fs.readFileSync(filePath);
                                }
                            });
                        }

                        return {
                            archive,
                            queueId: ckQueue,
                            recipe: row.cv_recipe,
                            engine: row.ck_engine,
                            reportQuery,
                            helpers: `${defaultHelper} ${engineHelper(
                                row.ck_engine,
                            )} ${row.cv_helpers || ""}`,
                            content: content || row.cv_template,
                            fileName: row.cv_report_name,
                            templateAsset: archive
                                ? templateAsset
                                : row.cb_asset,
                            contentType: row.cv_content_type,
                            reportConfigParameter:
                                typeof row.cct_report_parameter === "string"
                                    ? JSON.parse(
                                          row.cct_report_parameter || "{}",
                                      )
                                    : row.cct_report_parameter,
                            reportParameter:
                                typeof row.cct_parameter === "string"
                                    ? JSON.parse(row.cct_parameter || "{}")
                                    : row.cct_parameter,
                            formatParameter:
                                typeof row.cct_format_parameter === "string"
                                    ? JSON.parse(
                                          row.cct_format_parameter || "{}",
                                      )
                                    : row.cct_format_parameter,
                        } as IReportData;
                    }
                    throw new Error(
                        `Not found queue ${ckQueue} or status not 'add'`,
                    );
                });

            this.logger.debug("Queue queue %s param %j", ckQueue, reportData);
            this.logger.debug("Load asset in %s", ckQueue);
            await conn
                .executeStmt(
                    "select\n" +
                        "    tra.cv_name,\n" +
                        "    ta.cv_helpers,\n" +
                        "    ta.cv_template,\n" +
                        "    ta.cb_asset,\n" +
                        "    ta.cl_archive\n" +
                        "from\n" +
                        "    t_queue tq\n" +
                        "join t_report_asset tra on\n" +
                        "    tq.ck_report = tra.ck_report\n" +
                        "join t_asset ta on\n" +
                        "    tra.ck_asset = ta.ck_id\n" +
                        "where\n" +
                        "    tq.ck_id = :ckQueue::uuid\n",
                    {
                        ckQueue,
                    },
                    null,
                    {
                        autoCommit: true
                    }
                )
                .then((res) => ReadStreamToArray(res.stream))
                .then((assets) =>
                    Promise.all(
                        assets.map(async (asset) => {
                            const isArchive =
                                typeof asset.cl_archive === "number"
                                    ? Boolean(asset.cl_archive)
                                    : asset.cl_archive === "1";
                            const pathAsset = path.resolve(
                                queuePath,
                                asset.cv_name,
                            );

                            if (isArchive) {
                                fs.mkdirSync(pathAsset);
                                const zip = new AdmZip(asset.cb_asset);

                                zip.extractAllTo(pathAsset, true);
                            } else {
                                fs.writeFileSync(
                                    pathAsset,
                                    asset.cv_template || asset.cb_asset,
                                );
                            }
                        }),
                    ),
                );
            this.logger.debug("Load data query in %s", ckQueue);
            let queries;

            try {
                queries = await Promise.all(
                    reportData.reportQuery
                        .filter((query) => isEmpty(query.ck_parent))
                        .map((query) => {
                            this.logger.debug(
                                "%s - start load data query %s",
                                ckQueue,
                                query.cv_name,
                            );

                            return this.managerSource
                                .getSource(query.ck_source)
                                .then((source) =>
                                    source.getData({
                                        querySource: query.cv_body,
                                        queryParam: Object.assign(
                                            query.cct_parameter || {},
                                            reportData.reportParameter,
                                        ),
                                        sourceParam:
                                            query.cct_source_parameter || {},
                                    } as any),
                                )
                                .then(async (res) => {
                                    this.logger.debug(
                                        "%s - end load data query %s",
                                        ckQueue,
                                        query.cv_name,
                                    );
                                    await this.getQueryChildData(
                                        reportData,
                                        res,
                                        query,
                                    );

                                    return {
                                        name: query.cv_name,
                                        res,
                                    };
                                });
                        }),
                );
            } catch (err) {
                this.logger.error(
                    "Load query %s error %s",
                    ckQueue,
                    err.message,
                    err,
                );
                await this.changeError(conn, ckQueue, "db_error", err);

                return;
            }
            const configRender = defaultsDeep(
                reportData.reportConfigParameter,
                {
                    template: {
                        assetPath: queuePath,
                        recipe: reportData.recipe,
                        engine: reportData.engine,
                        helpers: reportData.helpers,
                        content: reportData.content,
                        [reportData.recipe]: {
                            ...(reportData.templateAsset
                                ? {
                                      templateAsset: {
                                          content: reportData.templateAsset.toString(
                                              "base64",
                                          ),
                                          encoding: "base64",
                                      },
                                  }
                                : {}),
                            ...reportData.formatParameter,
                        },
                    },
                    data: queries.reduce((res, obj) => {
                        res[obj.name] = obj.res;

                        return res;
                    }, {}),
                },
            ) as any;

            configRender.data.in_param = reportData.reportParameter;
            this.logger.debug("Build report %s", ckQueue);
            await this.jsReport
                .render(configRender)
                .then(async (res: any) => {
                    this.logger.debug(
                        "Save report in storage %s meta file %j",
                        ckQueue,
                        res.meta,
                    );
                    await this.storage.saveFile(
                        reportData.queueId,
                        res.stream as Readable,
                        (reportData.contentType ||
                            res.meta.contentType) as string,
                        {
                            originalFilename: reportData.fileName,
                        },
                    );
                    await conn
                        .executeStmt(
                            // eslint-disable-next-line max-len
                            "select pkg_json_essence_report.f_modify_queue('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb, 1::smallint) as result",
                            {
                                json: JSON.stringify({
                                    service: {
                                        cv_action: "U",
                                    },
                                    data: {
                                        ck_id: ckQueue,
                                        ck_d_status: "success",
                                    },
                                }),
                            },
                            null,
                            {
                                autoCommit: true,
                            },
                        )
                        .then((resPkg) => ReadStreamToArray(resPkg.stream));
                })
                .catch(async (err) => {
                    this.logger.error("Error build report %s", ckQueue, err);
                    try {
                        await conn.rollback();
                    } catch (e) {
                        this.logger.error("Error rollback %s", ckQueue, e);
                    }

                    return this.changeError(conn, ckQueue, "system_error", err);
                });
        } catch (err) {
            if (err.message && err.message.indexOf("Not found queue") > -1) {
                this.logger.warning("%s", err.message, err);
            } else {
                this.logger.error(
                    "Build report %s error %s",
                    ckQueue,
                    err.message,
                    err,
                );
                await this.changeError(conn, ckQueue, "system_error", err);
            }
        } finally {
            await conn.rollbackAndRelease();
            // deleteFolderRecursive(queuePath);
        }
    }
    private async changeError(
        conn: Connection,
        ckQueue: string,
        ckDError: string,
        err: Error,
    ) {
        await conn
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_queue('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb, 1::smallint) as result",
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "U",
                        },
                        data: {
                            ck_id: ckQueue,
                            ck_d_status: "fault",
                        },
                    }),
                },
                null,
                {
                    autoCommit: true,
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
        await conn
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_queue_log('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb) as result",
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "I",
                        },
                        data: {
                            ck_queue: ckQueue,
                            ck_d_error: ckDError,
                            cv_error: err.message,
                            cv_error_stacktrace: err.stack,
                        },
                    }),
                },
                null,
                {
                    autoCommit: true,
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }

    private async getQueryChildData(
        reportData: IReportData,
        res: Record<string, any>[],
        query: Record<string, any>,
    ) {
        await Promise.all(
            res.map(async (data) => {
                const param = {
                    jt_parent_result: data,
                };

                await Promise.all(
                    reportData.reportQuery
                        .filter(
                            (queryChild) =>
                                queryChild.ck_parent === query.ck_id,
                        )
                        .map(async (queryChild) => {
                            const childData = await this.managerSource
                                .getSource(queryChild.ck_source)
                                .then((source) =>
                                    source.getData({
                                        querySource: queryChild.cv_body,
                                        queryParam: Object.assign(
                                            queryChild.cct_parameter || {},
                                            param,
                                            reportData.reportParameter,
                                        ),
                                        sourceParam:
                                            queryChild.cct_source_parameter ||
                                            {},
                                    } as any),
                                );

                            await this.getQueryChildData(
                                reportData,
                                childData,
                                queryChild,
                            );
                            data[queryChild.cv_name] = childData;
                        }),
                );
            }),
        );
    }
}

export const reportSystem = new ReportSystem(dataBase);
export default reportSystem;
