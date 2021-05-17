import * as moment from "moment";
import {isEmpty} from "../../utils/Base";
import {ISource, ISourceParams} from "../../interfaces/ISource";
import {ExtractJsonColumn, ReadStreamToArray} from "../../stream/Util";
import PostgresDB, {IPostgresDBConfig} from "./PostgresDB";

export class PostgresSource implements ISource {
    private oraDb: PostgresDB;
    constructor(name: string, params: IPostgresDBConfig) {
        this.oraDb = new PostgresDB(name, {
            poolMin: 0,
            poolMax: 200,
            ...(params as any),
        });
    }
    public async init() {
        await this.oraDb.createPool();
    }
    public getData(data: ISourceParams): Promise<Record<string, any>[]> {
        const inParams = Object.entries(data.queryParam)
            .filter((val) => !val[0].startsWith("out_"))
            .reduce((obj, [key, val]) => {
                if (key.startsWith("cd_") || key.startsWith("ct_")) {
                    obj[key] = isEmpty(val) ? "" : moment(val).toDate();
                } else {
                    obj[key] = val;
                }

                return obj;
            }, {});

        return this.oraDb
            .executeStmt(data.querySource!, null, inParams, null, data.sourceParam)
            .then((res) => res.stream.pipe(ExtractJsonColumn()))
            .then((stream) => ReadStreamToArray(stream));
    }
}
