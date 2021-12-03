#!/usr/bin/env node
"use strict";

import * as cl from "cluster";
import Logger from "@essence-report/plugininf/lib/Logger";
import { CLUSTER_NUM } from "./constant";
import { start } from "./node";

const logger = Logger.getLogger("Cluster");
const cluster: cl.Cluster = cl as any;

if (cluster.isMaster) {
    const n = CLUSTER_NUM;

    logger.info("Starting child processes...");

    for (let i = 0; i < n; i++) {
        const env = { processNumber: i + 1 };
        const worker = cluster.fork(env);

        (worker as any).process.env = env;
    }

    cluster.on("online", (worker) => {
        logger.info(
            `Child process running PID: ${worker.process.pid} PROCESS_NUMBER: ${
                (worker as any).process.env.processNumber
            }`,
        );
    });

    cluster.on("exit", (worker, code, signal) => {
        logger.info(
            `PID ${worker.process.pid}  code: ${code}  signal: ${signal}`,
        );
        const env = (worker as any).process.env;
        const newWorker = cluster.fork(env);

        (newWorker as any).process.env = env;
    });
} else {
    start().catch((err) => {
        logger.error(`Error starting server: ${err.message}`);
        process.exit(-1);
    });
}

process.on("uncaughtException", (err: any) => {
    logger.error(err);
});
