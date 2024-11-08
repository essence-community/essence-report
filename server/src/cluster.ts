import * as cl from "cluster";
import Logger from "@essence-report/plugininf/lib/Logger";
import { CLUSTER_NUM } from "./constant";

const logger = Logger.getLogger("Cluster");
const cluster: cl.Cluster = cl as any;
const workers = {};

function initNodeHttp(id: string) {
    const node = cluster.fork({
        ...process.env,
        NODE_HTTP_ID: id,
    });

    workers[node.process.pid] = id;
}
process.on("unhandledRejection", (reason, promise) => {
    logger.error(
        "HTTP id: %s, Unhandled Rejection at: %s\nreason: %s",
        process.env.NODE_HTTP_ID || "master",
        promise,
        reason,
    );
});
process.on("uncaughtException", (err, origin) => {
    logger.error(
        "HTTP id: %s, Uncaught Exception at: %s\nreason: %s",
        process.env.NODE_HTTP_ID || "master",
        err,
        origin,
    );
    process.exit(1);
});

if (cluster.isMaster) {
    cluster.on("online", (worker) => {
        logger.info(
            `Child process running PID: ${
                worker.process?.pid
            } PROCESS_NUMBER: ${(worker as any).process?.env?.processNumber}`,
        );
    });
    cluster.on("exit", (worker, code, signal) => {
        logger.warn(
            "Worker die %s, code %s, signal %s",
            worker.process.pid,
            code,
            signal,
        );
        const id = workers[worker.process.pid];

        delete workers[worker.process.pid];
        initNodeHttp(id);
    });
    const max = CLUSTER_NUM + 1;

    for (let i = 1; i < max; i += 1) {
        initNodeHttp(`${i}`);
    }
} else {
    import("./node").then((node) => {
        node.start().catch((err) => {
            logger.error(`Error starting server: ${err.message}`);
            process.exit(1);
        });
    });
}
