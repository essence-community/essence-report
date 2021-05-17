import dataBase from "@essence-report/plugininf/lib/db/DataBase";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import { ResultFault } from "../typings";

export class Fault implements ResultFault {
    success: false = false;
    "ck_error": string;
    "cv_message": string;
    constructor(ckError: string, cvMessage: string) {
        this.ck_error = ckError;
        this.cv_message = cvMessage;
    }

    public static getFaultByQueue(ckQueue: string) {
        return dataBase
            .getCoreDb()
            .executeStmt(
                "select\n" +
                    "    tql.ck_d_error,\n" +
                    "    tql.cv_error\n" +
                    "from\n" +
                    "    t_queue tq\n" +
                    "join t_queue_log tql on\n" +
                    "    tq.ck_id = tql.ck_queue\n" +
                    "where\n" +
                    "    tq.ck_id = :ckQueue\n",
                null,
                {
                    ckQueue,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(([row]) => {
                if (row) {
                    return new Fault(row.ck_d_error, row.cv_error);
                }

                return null;
            });
    }
}
