import * as moment from "moment";
import {isEmpty} from "../../utils/Base";
import {ISource, ISourceParams} from "../../interfaces/ISource";
import {ExtractJsonColumn, ReadStreamToArray} from "../../stream/Util";
import OracleDB, {IOracleDBConfig} from "./OracleDB";

export class OracleSource implements ISource {
    private oraDb: OracleDB;
    constructor(name: string, params: IOracleDBConfig) {
        this.oraDb = new OracleDB(name, {
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
                    obj[key] = isEmpty(val)
                        ? ""
                        : {
                              dir: this.oraDb.oracledb.BIND_IN,
                              type: this.oraDb.oracledb.DATE,
                              val: moment(val).toDate(),
                          };
                } else {
                    obj[key] = val;
                }

                return obj;
            }, {});
        const outParams = Object.entries(data.queryParam)
            .filter((val) => val[0].startsWith("out_"))
            .reduce((obj, val) => {
                const name = val[0].substr("out_".length);

                obj[name] = name.indexOf("cur_") === 0 ? "CURSOR" : null;

                return obj;
            }, {});

        return this.oraDb
            .executeStmt(data.querySource!, null, inParams, outParams, data.sourceParam)
            .then((res) => res.stream.pipe(ExtractJsonColumn()))
            .then((stream) => ReadStreamToArray(stream));
    }
}
