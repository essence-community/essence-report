import * as fs from "fs";
import * as path from "path";
import { ISource } from "@essence-report/plugininf/lib/interfaces/ISource";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import { OracleSource } from "@essence-report/plugininf/lib/db/oracle/OracleSource";
import { PostgresSource } from "@essence-report/plugininf/lib/db/postgres/PostgresSource";
import Logger from "@essence-report/plugininf/lib/Logger";
import { SOURCE_PLUGIN_DIR } from "../constant";

export class ManagerSource {
    private sources: Record<string, ISource> = {};
    private pgSql: PostgresDB;
    private dirs: Record<string, string> = {};
    private logger;
    constructor(pgSql: PostgresDB) {
        this.pgSql = pgSql;
        this.logger = Logger.getLogger("TaskService");
    }

    public async init() {
        const params = await this.pgSql
            .executeStmt(
                "select " +
                    "ck_id, cct_parameter, cv_plugin, ck_d_source " +
                    "from t_source where cl_enable = 1",
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then((arr) =>
                arr.map((val) => {
                    return {
                        ...val,
                        cct_parameter:
                            typeof val.cct_parameter === "string"
                                ? JSON.parse(val.cct_parameter)
                                : val.cct_parameter,
                    };
                }),
            );

        if (!fs.existsSync(SOURCE_PLUGIN_DIR)) {
            throw new Error(`Not found ${SOURCE_PLUGIN_DIR}`);

            return;
        }
        fs.readdirSync(SOURCE_PLUGIN_DIR).forEach((file) => {
            if (
                !fs.existsSync(path.join(SOURCE_PLUGIN_DIR, file, "index.js"))
            ) {
                return;
            }
            const nameFile = file.replace(".js", "").toLowerCase();

            this.dirs[nameFile] = path.join(
                SOURCE_PLUGIN_DIR,
                file,
                "index.js",
            );
        });
        await Promise.all(
            Object.values(this.dirs).map(async (filePath) => {
                const pluginClass = await import(filePath);

                if (pluginClass && pluginClass.InitSource) {
                    await pluginClass.InitSource(this.pgSql);
                }
            }),
        );
        await Promise.all(
            params.map(async (param) => {
                try {
                    switch (param.ck_d_source) {
                        case "oracle":
                            const ora = new OracleSource(
                                param.ck_id,
                                param.cct_parameter,
                            );

                            await ora.init();
                            this.sources[param.ck_id] = ora;
                            break;
                        case "postgres":
                            const postgres = new PostgresSource(
                                param.ck_id,
                                param.cct_parameter,
                            );

                            await postgres.init();
                            this.sources[param.ck_id] = postgres;
                            break;
                        case "plugin":
                            const pluginClass = await import(
                                this.dirs[param.cv_plugin]
                            );

                            if (pluginClass) {
                                const plugin = pluginClass.default
                                    ? new pluginClass.default(
                                          param.ck_id,
                                          param.cct_parameter,
                                      )
                                    : new pluginClass(
                                          param.ck_id,
                                          param.cct_parameter,
                                      );

                                await plugin.init();
                                this.sources[param.ck_id] = plugin;
                            } else {
                                throw new Error(
                                    `Undefined source ${param.ck_id} plugin ${param.cv_plugin}`,
                                );
                            }
                            break;
                        default:
                            if (this.dirs[param.ck_d_source.toLowerCase()]) {
                                const pluginClass = await import(
                                    this.dirs[param.ck_d_source]
                                );

                                if (pluginClass) {
                                    const plugin = pluginClass.default
                                        ? new pluginClass.default(
                                              param.ck_id,
                                              param.cct_parameter,
                                          )
                                        : new pluginClass(
                                              param.ck_id,
                                              param.cct_parameter,
                                          );

                                    await plugin.init();
                                    this.sources[param.ck_id] = plugin;
                                } else {
                                    throw new Error(
                                        `Undefined source ${param.ck_id} plugin ${param.cv_plugin}`,
                                    );
                                }
                            } else {
                                throw new Error(
                                    `Undefined source ${param.ck_id} type ${param.ck_d_source}`,
                                );
                            }
                    }
                } catch (e) {
                    this.logger.error(
                        "Not init %s error %s",
                        param.ck_id,
                        e.message,
                        e,
                    );
                    throw e;
                }
            }),
        );
    }

    public async getSource(name: string) {
        if (this.sources[name]) {
            return this.sources[name];
        }
        const param = await this.pgSql
            .executeStmt(
                "select " +
                    "ck_id, cct_parameter, cv_plugin, ck_d_source " +
                    "from t_source where ck_id = :name and cl_enable = 1",
                null,
                {
                    name,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(([val]) => {
                return {
                    ...val,
                    cct_parameter:
                        typeof val.cct_parameter === "string"
                            ? JSON.parse(val.cct_parameter)
                            : val.cct_parameter,
                };
            });

        fs.readdirSync(SOURCE_PLUGIN_DIR).forEach((file) => {
            if (
                !fs.existsSync(path.join(SOURCE_PLUGIN_DIR, file, "index.js"))
            ) {
                return;
            }
            const nameFile = file.replace(".js", "").toLowerCase();

            this.dirs[nameFile] = path.join(
                SOURCE_PLUGIN_DIR,
                file,
                "index.js",
            );
        });
        await new Promise<void>(async (resolve, reject) => {
            try {
                switch (param.ck_d_source) {
                    case "oracle":
                        const ora = new OracleSource(
                            param.ck_id,
                            param.cct_parameter,
                        );

                        await ora.init();
                        this.sources[param.ck_id] = ora;
                        break;
                    case "postgres":
                        const postgres = new PostgresSource(
                            param.ck_id,
                            param.cct_parameter,
                        );

                        await postgres.init();
                        this.sources[param.ck_id] = postgres;
                        break;
                    case "plugin":
                        const pluginClass = await import(
                            this.dirs[param.cv_plugin.toLowerCase()]
                        );

                        if (pluginClass) {
                            const plugin = pluginClass.default
                                ? new pluginClass.default(
                                      param.ck_id,
                                      param.cct_parameter,
                                  )
                                : new pluginClass(
                                      param.ck_id,
                                      param.cct_parameter,
                                  );

                            await plugin.init();
                            this.sources[param.ck_id] = plugin;
                            resolve();
                        } else {
                            throw new Error(
                                `Undefined source ${param.ck_id} plugin ${param.cv_plugin}`,
                            );
                        }
                        break;
                    default:
                        if (this.dirs[param.ck_d_source.toLowerCase()]) {
                            const pluginClass = await import(
                                this.dirs[param.ck_d_source]
                            );

                            if (pluginClass) {
                                const plugin = pluginClass.default
                                    ? new pluginClass.default(
                                          param.ck_id,
                                          param.cct_parameter,
                                      )
                                    : new pluginClass(
                                          param.ck_id,
                                          param.cct_parameter,
                                      );

                                await plugin.init();
                                this.sources[param.ck_id] = plugin;
                            } else {
                                throw new Error(
                                    `Undefined source ${param.ck_id} plugin ${param.cv_plugin}`,
                                );
                            }
                        } else {
                            throw new Error(
                                `Undefined source ${param.ck_id} type ${param.ck_d_source}`,
                            );
                        }
                }
            } catch (e) {
                this.logger.error(
                    "Not init %s error %s",
                    param.ck_id,
                    e.message,
                    e,
                );

                return reject(e);
            }
        });

        return this.sources[name];
    }
}
