/* eslint-disable filenames/match-exported */
import dataBase, { DataBase } from "@essence-report/plugininf/lib/db/DataBase";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import managerAuth from "../managerplugin/ManagerAuth";
import { ResultFault } from "../typings";
import { Fault } from "../dto/Fault";

export class AuthService {
    private pgSql: PostgresDB;
    constructor(db: DataBase) {
        this.pgSql = db.getCoreDb();
    }

    public accessDenied(): ResultFault {
        return {
            success: false,
            ck_error: "access_denied",
            cv_message: "Access denied",
        };
    }

    public async runPlugin(ckAuthorization: string, session?: string) {
        const plugin = managerAuth.getAuthPlugin(ckAuthorization);

        if (plugin) {
            const res = await plugin.checkSession(session);

            if (res && !res.session) {
                res.session = session;
            }

            return res;
        }

        return false;
    }

    public getAuthDataByReport(ckReport: string, session?: string) {
        return this.pgSql
            .executeStmt(
                "select\n" +
                    "    r.ck_authorization\n" +
                    "from\n" +
                    "    t_report r where r.ck_id = :ckReport\n",
                null,
                {
                    ckReport,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(async ([row]) => {
                if (row) {
                    return this.runPlugin(row.ck_authorization, session);
                }

                return false;
            })
            .catch((err) => new Fault("system_error", err.message));
    }
    public getAuthDataByQueue(ckQueue: string, session?: string) {
        return this.pgSql
            .executeStmt(
                "select\n" +
                    "    rep.ck_authorization\n" +
                    "from\n" +
                    "    t_queue q\n" +
                    "join t_report rep on\n" +
                    "    q.ck_report = rep.ck_id\n" +
                    "where\n" +
                    "    q.ck_id = :ckQueue\n",
                null,
                {
                    ckQueue,
                },
            )
            .then((res) => ReadStreamToArray(res.stream))
            .then(([row]) => {
                if (row) {
                    return this.runPlugin(row.ck_authorization, session);
                }

                return false;
            })
            .catch((err) => new Fault("system_error", err.message));
    }
}

export const authService = new AuthService(dataBase);
export default authService;
