/* eslint-disable filenames/match-exported */
import { Readable } from "stream";
import dataBase, { DataBase } from "@essence-report/plugininf/lib/db/DataBase";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";

import { Return } from "typescript-rest";
import { isEmpty } from "@essence-report/plugininf/lib/utils/Base";
import { ResultSuccess, ResultFault } from "../typings";

import { QueueStatus } from "../dto/QueueStatus";
import reportSystem from "../service/ReportSystem";
import { NotFound } from "../dto/NotFound";
import authService from "./AuthService";

export class StoreService {
    private pgSql: PostgresDB;
    constructor(db: DataBase) {
        this.pgSql = db.getCoreDb();
    }

    public async runGet(
        ckQueue: string,
        session?: string,
    ): Promise<Return.DownloadBinaryData | ResultSuccess | ResultFault> {
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
        const status = await QueueStatus.getStatusByQueue(ckQueue);

        if (!status.success || status.cv_status !== "success") {
            return status;
        }
        const file = await reportSystem.storage.getFile(ckQueue);

        return new Return.DownloadBinaryData(
            (file.file as Readable).pipe
                ? await new Promise((resolve, reject) => {
                      const buffer = [];

                      (file.file as Readable).on("data", (data) =>
                          buffer.push(data),
                      );
                      (file.file as Readable).on("error", (err) => reject(err));
                      (file.file as Readable).on("end", () =>
                          resolve(Buffer.concat(buffer)),
                      );
                  })
                : (file.file as Buffer),
            file.contentType,
            encodeURIComponent(file.originalFilename),
        );
    }
}

export const storeService = new StoreService(dataBase);
export default storeService;
