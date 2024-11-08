import * as fs from "fs";
import * as path from "path";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import Logger from "@essence-report/plugininf/lib/Logger";
import * as JsReport from "@jsreport/jsreport-core";
import { FORMAT_PLUGIN_DIR } from "../constant";

export class ManagerFormat {
    private pgSql: PostgresDB;
    private dirs: Record<string, string> = {};
    private logger;
    constructor(pgSql: PostgresDB) {
        this.pgSql = pgSql;
        this.logger = Logger.getLogger("ManagerFormat");
    }
    public async init(
        jsReport: JsReport.Reporter,
        params: Record<string, any>,
    ) {
        if (!fs.existsSync(FORMAT_PLUGIN_DIR)) {
            throw new Error(`Not found ${FORMAT_PLUGIN_DIR}`);

            return;
        }
        fs.readdirSync(FORMAT_PLUGIN_DIR).forEach((file) => {
            if (
                !fs.existsSync(path.join(FORMAT_PLUGIN_DIR, file, "index.js"))
            ) {
                return;
            }
            const name = file.replace(".js", "").toLowerCase();

            this.dirs[name] = path.join(FORMAT_PLUGIN_DIR, file, "index.js");
        });
        await Promise.all(
            Object.entries(this.dirs).map(([key, val]) => {
                return new Promise<void>(async (resolve, reject) => {
                    try {
                        const pluginClass = await import(val);

                        if (pluginClass) {
                            if (
                                pluginClass.default &&
                                typeof pluginClass.default === "function"
                            ) {
                                return pluginClass
                                    .default(this.pgSql, jsReport, params)
                                    .then(resolve, reject);
                            }
                            if (
                                pluginClass.InitFormat &&
                                typeof pluginClass.InitFormat === "function"
                            ) {
                                return pluginClass
                                    .InitFormat(this.pgSql, jsReport, params)
                                    .then(resolve, reject);
                            }
                            if (
                                pluginClass.initFormat &&
                                typeof pluginClass.initFormat === "function"
                            ) {
                                return pluginClass
                                    .initFormat(this.pgSql, jsReport, params)
                                    .then(resolve, reject);
                            }
                            throw new Error(
                                `Not found InitFormat ${key} ${val}`,
                            );
                        } else {
                            throw new Error(
                                `Not found InitFormat ${key} ${val}`,
                            );
                        }
                    } catch (e) {
                        this.logger.error(
                            "Not init %s error %s",
                            key,
                            e.message,
                            e,
                        );

                        return reject(e);
                    }
                });
            }),
        );
    }
}
