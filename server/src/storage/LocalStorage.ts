import { Readable } from "stream";
import { IRufusLogger } from "@essence-report/plugininf/lib/Logger";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres";
import {
    IFile,
    IStorage,
} from "@essence-report/plugininf/lib/interfaces/IStorage";
import dataBase from "@essence-report/plugininf/lib/db/DataBase";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";

export class LocalStorage implements IStorage {
    private params: Record<string, string>;
    private logger: IRufusLogger;
    private pgSql: PostgresDB;
    constructor(params: Record<string, string>, logger: IRufusLogger) {
        this.params = params;
        this.logger = logger;
        this.pgSql = dataBase.getCoreDb();
    }
    /**
     * Сохраняем в папку
     * @param gateContext
     * @param json
     * @param val
     * @param query
     * @returns
     */
    public async saveFile(
        key: string,
        buffer: Buffer | Readable,
        content: string,
        metaData: Record<string, string> = {},
    ): Promise<void> {
        const json = {
            service: {
                cv_action: "I",
            },
            data: {
                ck_id: key,
                cv_content_type: content,
                cct_meta_data: metaData,
            },
        };
        const upload: Buffer = (buffer as Readable).pipe
            ? await new Promise((resolve, reject) => {
                  const bufs = [];

                  (buffer as Readable).on("data", (data) => bufs.push(data));
                  (buffer as Readable).on("error", (err) => reject(err));
                  (buffer as Readable).on("end", () =>
                      resolve(Buffer.concat(bufs)),
                  );
              })
            : (buffer as Buffer);

        await this.pgSql
            .executeStmt(
                "select pkg_json_essence_report.f_modify_file('-11'::varchar, " +
                    "'USPO_SERVER'::varchar, :json, :upload) as result",
                null,
                {
                    json: JSON.stringify(json),
                    upload,
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }
    public async deletePath(key: string): Promise<void> {
        const json = {
            service: {
                cv_action: "D",
            },
            data: {
                ck_id: key,
            },
        };

        await this.pgSql
            .executeStmt(
                "select pkg_json_essence_report.f_modify_file('-11'::varchar, 'USPO_SERVER'::varchar, :json) as result",
                null,
                {
                    json: JSON.stringify(json),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }

    public getFile(key: string): Promise<IFile> {
        return this.pgSql
            .executeStmt(
                "select cv_content_type, cb_result, cct_meta_data from t_queue_storage where ck_id = :ckId::uuid",
                null,
                {
                    ckId: key,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(([row]) => {
                if (row) {
                    const metaData =
                        typeof row.cct_meta_data === "string"
                            ? JSON.parse(row.cct_meta_data)
                            : row.cct_meta_data;

                    return {
                        contentType: row.cv_content_type,
                        originalFilename: metaData.originalFilename,
                        file: row.cb_result,
                        size: row.cb_result.length,
                    };
                }
            });
    }
}
