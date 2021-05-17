/* eslint-disable filenames/match-exported */
import * as fs from "fs";
import * as path from "path";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import dataBase, { DataBase } from "@essence-report/plugininf/lib/db/DataBase";
import { IAuthPlugin } from "@essence-report/plugininf/lib/interfaces/IAuthPlugin";
import Logger from "@essence-report/plugininf/lib/Logger";
import { NoAuth } from "../auth/NoAuth";
import { CoreAuth } from "../auth/CoreAuth";
import { AUTH_PLUGIN_DIR } from "../constant";

export class ManagerAuth {
    private pgSql: PostgresDB;
    private plugins: Record<string, IAuthPlugin> = {};
    private params: Record<string, any> = {};
    private dirs: Record<string, string> = {};
    private logger;
    constructor(db: DataBase) {
        this.pgSql = db.getCoreDb();
        this.logger = Logger.getLogger("ManagerAuth");
    }
    public async init() {
        this.params = await this.pgSql
            .executeStmt(
                "select ck_id, cv_name, cv_plugin, cct_parameter from t_authorization",
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then((arr) =>
                arr.reduce((res, obj) => {
                    obj.cct_parameter =
                        typeof obj.cct_parameter === "string"
                            ? JSON.parse(obj.cct_parameter)
                            : obj.cct_parameter;
                    res[obj.ck_id] = obj;

                    return res;
                }, {}),
            );
        if (!fs.existsSync(AUTH_PLUGIN_DIR)) {
            throw new Error(`Not found ${AUTH_PLUGIN_DIR}`);

            return;
        }
        fs.readdirSync(AUTH_PLUGIN_DIR).forEach((file) => {
            if (!fs.existsSync(path.join(AUTH_PLUGIN_DIR, file, "index.js"))) {
                return;
            }
            const name = file.replace(".js", "").toLowerCase();

            this.dirs[name] = path.join(AUTH_PLUGIN_DIR, file, "index.js");
        });
        await Promise.all(
            Object.entries(this.params).map(([key, val]) => {
                return new Promise(async (resolve, reject) => {
                    try {
                        let plugin: IAuthPlugin;

                        switch (val.cv_plugin) {
                            case "no_auth":
                                plugin = new NoAuth();
                                break;
                            case "core":
                                plugin = new CoreAuth(
                                    val.cv_name,
                                    val.cct_parameter,
                                );
                                break;
                            default:
                                const pluginClass = await import(
                                    this.dirs[val.cv_plugin.toLowerCase()]
                                );

                                if (pluginClass) {
                                    plugin = pluginClass.default
                                        ? new pluginClass.default(
                                              val.cv_name,
                                              val.cct_parameter,
                                          )
                                        : new pluginClass(
                                              val.cv_name,
                                              val.cct_parameter,
                                          );
                                } else {
                                    throw new Error(
                                        `Not found class ${val.cv_plugin}`,
                                    );
                                }
                        }
                        this.plugins[key] = plugin;

                        return plugin.init().then(resolve, reject);
                    } catch (e) {
                        this.logger.error(
                            "Not init %s error %s",
                            val.cv_name,
                            e.message,
                            e,
                        );

                        return reject(e);
                    }
                });
            }),
        );
    }

    public getAuthPlugin(key: string): IAuthPlugin {
        return this.plugins[key];
    }
}

export const managerAuth = new ManagerAuth(dataBase);
export default managerAuth;
