import * as http from "http";
import * as path from "path";
import * as cors from "cors";
import * as express from "express";
import { Server } from "typescript-rest";
import dataBase from "@essence-report/plugininf/lib/db/DataBase";
import Logger from "@essence-report/plugininf/lib/Logger";
import { DISABLED_TASK_SERVICE } from "./constant";
import managerAuth from "./managerplugin/ManagerAuth";
import reportSystem from "./service/ReportSystem";
import taskService from "./service/TaskService";

Error.stackTraceLimit = Infinity;
export class ApiServer {
    public PORT: number = +process.env.ESSENCE_REPORT_PORT || 8020;

    private readonly app: express.Application;
    private server: http.Server = null;
    private logger;

    constructor() {
        this.app = express();
        this.config();

        Server.loadServices(this.app, "controller/*", __dirname);
        Server.swagger(this.app, {
            endpoint: "api-docs",
            filePath: path.resolve(__dirname, "spec", "openapi.yaml"),
        });
        this.logger = Logger.getLogger("ApiServer");
    }

    /**
     * Start the server
     */
    public async start() {
        return new Promise<void>(async (resolve, reject) => {
            await dataBase.init();
            await reportSystem.init();
            await managerAuth.init();
            this.server = this.app.listen(this.PORT, async (...arg) => {
                if (DISABLED_TASK_SERVICE !== "true") {
                    await taskService.init();
                }
                if (arg && arg.length) {
                    return reject(...arg);
                }

                this.logger.info(`Listening to http://127.0.0.1:${this.PORT}`);

                return resolve();
            });
            this.server.setTimeout(99999999);
        });
    }

    /**
     * Stop the server (if running).
     * @returns {Promise<boolean>}
     */
    public async stop(): Promise<boolean> {
        return new Promise<boolean>((resolve) => {
            if (this.server) {
                this.server.close(() => {
                    return resolve(true);
                });
            } else {
                return resolve(true);
            }
        });
    }

    /**
     * Configure the express app.
     */
    private config(): void {
        this.app.use(cors());
    }
}
