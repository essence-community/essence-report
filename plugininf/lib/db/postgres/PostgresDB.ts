/* eslint-disable max-lines-per-function */
/* eslint-disable max-statements */
import { Readable, Transform, TransformCallback } from "stream";
import * as URL from "url";
import { forEach, isObject, noop } from "lodash";
import * as pg from "pg";
// @ts-ignore
import * as QueryStream from "pg-query-stream";
import { IRufusLogger } from "rufus";
import { IParamsInfo } from "../../interfaces/ICCTParams";
import { IResultProvider } from "../../interfaces/IResult";
import Logger from "../../Logger";
import { safePipe } from "../../stream/Util";
import { initParams, isEmpty } from "../../utils/Base";
import Connection from "../Connection";
import IOptions from "../../interfaces/IOptions";

const re = /(?!\B'[^']*):(\w+)(?![^']*'\B)/gi;
const prepareSql = (query: string) => {
    return (data: any) => {
        const values = [];

        return {
            text: query.replace(
                /(--.*?$)|(\/\*[\s\S]*?\*\/)|('[^']*?')|("[^"]*?")|(::?)([a-zA-Z0-9_]+)/g,
                (_, ...group) => {
                    const noReplace = group.slice(0, 4);
                    const [prefix, key] = group.slice(4);

                    if (prefix === ":") {
                        values.push(data[key] || null);

                        return `$${values.length}`;
                    } else if (prefix && prefix.length > 1) {
                        return prefix + key;
                    }

                    return noReplace.find((val) => typeof val !== "undefined");
                },
            ),
            values,
        };
    };
};

export interface IPostgresDBConfig {
    connectString: string;
    partRows?: number;
    idleTimeoutMillis?: number;
    connectionTimeoutMillis?: number;
    poolMax?: number;
    poolMin?: number;
    queryTimeout?: number;
    user?: string;
    password?: string;
    lvl_logger?: string;
    poolPg?: string | Record<string, any>;
    setConnectionParam?: string;
}
interface IParams {
    [key: string]: string | boolean | number | Record<string, any>;
}
export default class PostgresDB {
    public static getParamsInfo(): IParamsInfo {
        return {
            /* tslint:disable:object-literal-sort-keys */
            connectString: {
                description: "Пример: postgres://IP:PORT/NAME_DB",
                name: "Строка подключения к БД",
                required: true,
                type: "string",
            },
            user: {
                name: "Наименвание учетной записи БД",
                type: "string",
            },
            password: {
                name: "Пароль учетной записи БД",
                type: "password",
            },
            connectionTimeoutMillis: {
                defaultValue: 2000,
                name: "Время выполнения ожидания конекта",
                type: "integer",
            },
            idleTimeoutMillis: {
                defaultValue: 30000,
                name: "время жизни idle в милисек",
                type: "integer",
            },
            partRows: {
                defaultValue: 1000,
                name: "Количество строк при вытаскивании в режиме stream",
                type: "integer",
            },
            poolMax: {
                defaultValue: 5,
                name: "Максимальное колличество конектов к БД в пуле",
                type: "integer",
            },
            poolMin: {
                defaultValue: 0,
                name: "Минимальное колличество конектов к БД в пуле",
                type: "integer",
            },
            queryTimeout: {
                name: "Время выполнения запроса",
                type: "integer",
            },
            poolPg: {
                name: "Extra Postgres param",
                type: "long_string",
                defaultValue: "{}",
                description: "https://node-postgres.com/api/pool",
            },
            setConnectionParam: {
                name: "Extra set param connection",
                type: "long_string",
                defaultValue: "{}",
                description: "set ...",
            },
            lvl_logger: {
                displayField: "ck_id",
                name: "Level logger",
                records: [
                    {
                        ck_id: "NOTSET",
                    },
                    { ck_id: "VERBOSE" },
                    { ck_id: "DEBUG" },
                    { ck_id: "INFO" },
                    { ck_id: "WARNING" },
                    { ck_id: "ERROR" },
                    { ck_id: "CRITICAL" },
                    { ck_id: "WARN" },
                    { ck_id: "TRACE" },
                    { ck_id: "FATAL" },
                ],
                type: "combo",
                valueField: [{ in: "ck_id" }],
            },
            /* tslint:enable:object-literal-sort-keys */
        };
    }

    public name: string;
    public queryTimeout: number;
    public connectionConfig: IPostgresDBConfig;
    public partRows: number;
    public pg: any;
    public pool?: pg.Pool;

    private log: IRufusLogger;
    private setAppData: string[] = [];
    constructor(name: string, params: IPostgresDBConfig) {
        this.name = name;
        let setConnectionParam = {};

        this.connectionConfig = initParams(PostgresDB.getParamsInfo(), params);

        if (!this.connectionConfig.connectString) {
            throw new Error(
                "Не указан параметр connectString при вызове констуктора",
            );
        }
        if (
            typeof this.connectionConfig.poolPg === "string" &&
            this.connectionConfig.poolPg.startsWith("{") &&
            this.connectionConfig.poolPg.endsWith("}")
        ) {
            this.connectionConfig.poolPg = JSON.parse(
                this.connectionConfig.poolPg,
            );
        }
        if (
            typeof this.connectionConfig.setConnectionParam === "string" &&
            this.connectionConfig.setConnectionParam.startsWith("{") &&
            this.connectionConfig.setConnectionParam.endsWith("}")
        ) {
            setConnectionParam = JSON.parse(
                this.connectionConfig.setConnectionParam,
            );
        }
        if (typeof this.connectionConfig.setConnectionParam === "object") {
            setConnectionParam = this.connectionConfig.setConnectionParam;
        }
        this.log = Logger.getLogger(`PostgresDB ${name}`);
        if (params.lvl_logger && params.lvl_logger !== "NOTSET") {
            const rootLogger = Logger.getRootLogger();

            this.log.setLevel(params.lvl_logger);
            for (const handler of rootLogger._handlers) {
                this.log.addHandler(handler);
            }
        }
        if (!isEmpty(params.queryTimeout)) {
            this.queryTimeout = params.queryTimeout * 1000;
        } else {
            this.queryTimeout = null;
        }

        this.partRows =
            this.connectionConfig.partRows ||
            (PostgresDB.getParamsInfo().partRows.defaultValue as number);

        Object.entries(setConnectionParam).forEach(([key, value]) => {
            this.setAppData.push(`set ${key} = ${value};`);
        });
        this.pg = pg;
    }

    public resetPool(): Promise<void> {
        return this.pool
            ? this.pool.end().then(
                  () => {
                      this.pool = null;

                      return Promise.resolve();
                  },
                  () => {
                      this.pool = null;

                      return Promise.resolve();
                  },
              )
            : Promise.resolve();
    }

    /**
     * Получаем коннект к БД
     * @returns {Promise}
     */
    public getPool(): Promise<pg.Pool> {
        if (this.pool) {
            return Promise.resolve(this.pool);
        }

        return this.createPool();
    }

    /**
     * Создаем пул коннект
     * @returns {Promise}
     */
    public createPool(): Promise<pg.Pool> {
        const connectionString = URL.parse(this.connectionConfig.connectString);
        const [user, pass] = (connectionString.auth || "").split(":");
        /* tslint:disable:object-literal-sort-keys */
        const pool = new pg.Pool({
            ...(typeof this.connectionConfig.poolPg === "object"
                ? this.connectionConfig.poolPg
                : {}),
            application_name: this.name,
            host: connectionString.hostname,
            port: parseInt(connectionString.port || "5432", 10),
            user: this.connectionConfig.user || user,
            password: this.connectionConfig.password || pass,
            database: connectionString.path.substr(1),
            connectionTimeoutMillis:
                this.connectionConfig.connectionTimeoutMillis ||
                (PostgresDB.getParamsInfo().connectionTimeoutMillis
                    .defaultValue as number),
            idleTimeoutMillis:
                this.connectionConfig.idleTimeoutMillis ||
                (PostgresDB.getParamsInfo().idleTimeoutMillis
                    .defaultValue as number),
            max: this.connectionConfig.poolMax || 4,
            min: this.connectionConfig.poolMin || 0,
        });

        /* tslint:enable:object-literal-sort-keys */
        this.pool = pool;
        pool.on("error", (err) =>
            this.log.error(`PG Pool error ${err.message}`, err),
        );

        return Promise.resolve(pool);
    }

    /**
     * Получаем конект текущий коннект или выдаем из пула
     * @param conn
     * @returns {Promise.<*>}
     */
    public async getConnection(conn?: Connection): Promise<Connection> {
        if (conn) {
            return Promise.resolve(conn);
        }

        return this.getPool()
            .then((pool) => pool.connect())
            .then(async (pgconn) => {
                if (this.setAppData.length) {
                    await Promise.all(
                        this.setAppData.map((sql) => pgconn.query(sql)),
                    );
                }

                return new Connection(this, "postgresql", pgconn);
            });
    }

    /**
     * Получаем конект текущий коннект или выдаем из пула
     * @param conn
     * @returns {Promise.<*>}
     */
    public getConnectionNew(params: IPostgresDBConfig): Promise<Connection> {
        const client = new pg.Client(params as pg.ClientConfig);

        return client.connect().then(async () => {
            if (this.setAppData.length) {
                await Promise.all(
                    this.setAppData.map((sql) => client.query(sql)),
                );
            }

            return new Connection(this, "postgresql", client);
        });
    }

    /**
     * Создаем новое соединение или возращаем коннект из пула
     * @param params
     * @returns {Promise}
     */
    public open(params?: IPostgresDBConfig): Promise<Connection> {
        return params ? this.getConnectionNew(params) : this.getConnection();
    }

    /**
     * Закрываем коннект
     * @param conn
     * @returns {Promise.<void>}
     */
    public onClose(conn?: pg.Client | pg.PoolClient): Promise<void> {
        if (conn) {
            return (conn as pg.PoolClient).release
                ? new Promise<void>((resolve) => {
                      (conn as pg.PoolClient).release();
                      resolve();
                  })
                : (conn as pg.Client).end();
        }

        return Promise.resolve();
    }

    /**
     * Освобождаем коннект
     * @param conn
     * @returns {Promise}
     */
    public onRelease(conn?: pg.Client | pg.PoolClient): Promise<void> {
        if (conn) {
            return (conn as pg.PoolClient).release
                ? new Promise((resolve) => {
                      (conn as pg.PoolClient).release();
                      resolve();
                  })
                : (conn as pg.Client).end();
        }

        return Promise.resolve();
    }

    /**
     * Фиксируем
     * @param conn
     * @returns {Promise.<*|{value, enumerable, writable}>}
     */
    public onCommit(conn?: pg.ClientBase): Promise<void> {
        if (conn) {
            return conn.query("COMMIT").then(() => Promise.resolve());
        }

        return Promise.resolve();
    }

    /**
     * Откатываем запрос
     * @param conn
     * @returns {Promise.<*|{value, enumerable, writable}>}
     */
    public onRollBack(conn?: pg.ClientBase): Promise<void> {
        if (conn) {
            return conn.query("ROLLBACK").then(() => Promise.resolve());
        }

        return Promise.resolve();
    }

    public async onTx(conn?: pg.ClientBase): Promise<void> {
        if (conn) {
            return conn.query("BEGIN").then(() => Promise.resolve());
        }

        return Promise.resolve();
    }

    /**
     * Вызываем запрос
     * @param conn - Коннект к бд
     * @param sql - Тело запроса
     * @param inParam - Входящие параметры
     * @param outParam - Исходящие параметры
     * @param options - Конфигурации запроса
     * @param executeOptions - Дополнтельные данные
     * @returns {Promise}
     */
    public executeStmt(
        sql: string,
        conn?: pg.Client | pg.PoolClient,
        inParam?: Record<string, any>,
        outParam?: Record<string, any>,
        options?: IOptions,
    ): Promise<IResultProvider> {
        const params = {};

        /**
         * Проверка параметров на соответсвие с квери
         */
        if (isObject(inParam)) {
            Object.keys(inParam).forEach((key) => {
                if (sql.match(`:${key}(?![A-z0-9_])`)) {
                    params[key] = inParam[key];
                }
            });
        }

        /**
         * Добавление output параметров
         */
        if (isObject(outParam)) {
            Object.keys(outParam).forEach((key) => {
                if (sql.match(`:${key}(?![A-z0-9_])`)) {
                    params[key] = "";
                }
            });
        }

        /*
         Проверяем все ли переданы параметры если каких нет пытаемя добавить null
         */
        const findParam = sql.match(re);

        if (findParam && findParam.length) {
            findParam.forEach((item) => {
                const key = item.substr(1);

                if (!params[key]) {
                    params[key] = null;
                }
            });
        }

        return this._executeStmt(
            sql,
            params,
            {
                autoCommit: isEmpty(conn),
                ...options,
            },
            conn,
        );
    }

    /**
     * Вызываем запрос
     * @param conn - Коннект к бд
     * @param sql - Тело запроса
     * @param params - Параметры запроса
     * @param options - Конфигурации запроса
     * @returns {Promise}
     * @private
     */
    public async _executeStmt(
        sql: string,
        params: IParams,
        options: IOptions,
        inConnection?: pg.Client | pg.PoolClient,
    ): Promise<IResultProvider> {
        let estimateTimerId = null;
        let result;
        const conn: pg.Client | pg.PoolClient = inConnection
            ? inConnection
            : await this.getConnection().then(async (c) =>
                  c.getCurrentConnection(),
              );
        const isRelease = isEmpty(inConnection) || options.isRelease;

        if (this.log.isDebugEnabled()) {
            const logParam = { ...params };

            delete logParam.cv_password;
            delete logParam.cv_hash_password;
            delete logParam.pwd;
            this.log.trace(
                `execute sql:\n${sql}\nparams:\n${JSON.stringify(logParam)}`,
            );
        }

        if (this.queryTimeout !== null && !options.resultSet) {
            await conn.query("SELECT pg_backend_pid()").then(async (res) => {
                const pid = res.rows[0][0];

                estimateTimerId = setTimeout(() => {
                    this.pool.query("SELECT pg_cancel_backend($1)", [pid]);
                }, this.queryTimeout);

                return;
            });
        }
        const query = prepareSql(sql)(params);

        try {
            if (options.resultSet) {
                const stream: Readable = conn.query(
                    new QueryStream(query.text, query.values, {
                        batchSize: this.partRows,
                    }),
                );

                result = {
                    metaData: this.extractMetaData(
                        (stream as any).cursor._result.fields,
                    ),
                    stream,
                };
                await new Promise<void>((resolve, reject) => {
                    let isData = false;

                    stream.once("end", () => {
                        if (isData) {
                            return;
                        }
                        result.metaData = this.extractMetaData(
                            (stream as any).cursor._result.fields,
                        );
                        result.stream = new Readable({
                            highWaterMark: this.partRows,
                            objectMode: true,
                            read() {
                                this.push(null);
                                this.emit("close");
                            },
                        });
                        resolve();
                    });
                    stream.once("error", (error) => reject(error));
                    const reader = () => {
                        const chunk = stream.read();

                        if (chunk) {
                            stream.unshift(chunk);
                        }
                        isData = true;
                        result.metaData = this.extractMetaData(
                            (stream as any).cursor._result.fields,
                        );
                        stream.removeListener("readable", reader);
                        resolve();
                    };

                    stream.on("readable", reader);
                });
                result.stream = safePipe(
                    result.stream,
                    this.DatasetSerializer(),
                );
                result.stream.on("end", () => {
                    if (estimateTimerId !== null) {
                        clearTimeout(estimateTimerId);
                    }
                    if (isRelease) {
                        this.onRelease(conn).then(noop, noop);
                    }
                });

                return result;
            }

            let res = await conn.query(query.text, query.values);

            if (estimateTimerId !== null) {
                clearTimeout(estimateTimerId);
            }
            if (res.rows) {
                result = {
                    metaData: this.extractMetaData(res.fields),
                    stream: new Readable({
                        highWaterMark: this.partRows,
                        objectMode: true,
                        read() {
                            forEach(res.rows, (item) => this.push(item));
                            this.push(null);
                            this.emit("close");
                        },
                    }),
                };
                result.stream = safePipe(
                    result.stream,
                    this.DatasetSerializer(),
                );
            }
            if (isRelease) {
                result.stream.on("end", () => {
                    if (options.autoCommit) {
                        this.onRelease(conn).then(noop, noop);
                    } else {
                        this.onCommit(conn)
                            .then(
                                () => this.onRelease(conn),
                                (err) => {
                                    this.log.warn(err);

                                    return this.onRelease(conn);
                                },
                            )
                            .then(noop, noop);
                    }
                });
            }
            const errFn = (err) => result.stream.emit("error", err);

            conn.once("error", errFn);
            result.stream.on("end", () => {
                conn.removeListener("error", errFn);
            });

            return result;
        } catch (err) {
            if (estimateTimerId !== null) {
                clearTimeout(estimateTimerId);
            }
            if (isRelease && conn) {
                await this.onRollBack(conn)
                    .then(() => this.onClose(conn))
                    .then(
                        () => Promise.reject(new Error(err)),
                        () => Promise.reject(new Error(err)),
                    );
            }
            this.log.error(err);
            throw new Error(err);
        }
    }

    public DatasetSerializer(): Transform {
        const trans = new Transform({
            readableObjectMode: true,
            writableObjectMode: true,
            transform(chunk: any, encode: string, callback: TransformCallback) {
                const ret = {};
                const column = {};

                forEach(chunk, (value, key) => {
                    ret[key.toLowerCase()] = value;
                    column[key] = {
                        name: key.toLowerCase(),
                    };
                });
                const transform = (
                    chunkData: any,
                    encodeStr: string,
                    callBack: TransformCallback,
                ) => {
                    const ref = {};

                    forEach(column, (value: any, key) => {
                        ref[value.name] = chunkData[key];
                    });
                    callBack(null, ref);
                };

                trans._transform = transform.bind(trans);
                callback(null, ret);
            },
        });

        return trans;
    }

    private extractMetaData(arr: pg.FieldDef[] = []) {
        return arr.map((data) => {
            let datatype = "text";

            switch (data.dataTypeID) {
                case 20: // int8
                case 21: // int2
                case 23: // int4
                case 1005: // _int2
                case 1007: // _int4
                case 1016: // _int8
                    datatype = "integer";
                    break;
                case 700: // float4/real
                case 701: // float8/double
                case 1021: // _float4
                case 1022: // _float8
                case 1231: // _numeric
                    datatype = "numeric";
                    break;
                case 16:
                    datatype = "boolean";
                    break;
                case 1082: // date
                case 1114: // timestamp without timezone
                case 1184: // timestamp
                case 1115: // timestamp without time zone[]
                case 1182: // _date
                case 1185: // timestamp with time zone[]
                    datatype = "date";
                    break;
                default:
                    datatype = "text";
                    break;
            }

            return {
                column: data.name,
                datatype,
            };
        });
    }
}
