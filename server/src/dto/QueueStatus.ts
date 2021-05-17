import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import dataBase from "@essence-report/plugininf/lib/db/DataBase";
import { ResultSuccess } from "../typings";
import { NotFound } from "./NotFound";
import { Fault } from "./Fault";

export class QueueStatus implements ResultSuccess {
    public success: true = true;
    public "ck_id": string;
    public "cv_status": "add" | "processing" | "success" | "fault" | "delete";

    constructor(
        ckId: string,
        cvStatus: "add" | "processing" | "success" | "fault" | "delete",
    ) {
        this.ck_id = ckId;
        this.cv_status = cvStatus;
    }

    public static getStatusByQueue(
        ckQueue: string,
    ): Promise<QueueStatus | NotFound> {
        return dataBase
            .getCoreDb()
            .executeStmt(
                "select ck_id, ck_d_status from t_queue where ck_id = :ckQueue::uuid",
                null,
                {
                    ckQueue,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(([row]) => {
                if (row) {
                    return new QueueStatus(row.ck_id, row.ck_d_status);
                }

                return new NotFound(`Not found queue ${ckQueue}`);
            })
            .catch((err) => new Fault("system_error", err.message));
    }
}
