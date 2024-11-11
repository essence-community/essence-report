/* eslint-disable max-lines-per-function */
/* eslint-disable max-statements */
/**
 * Created by artemov_i on 05.12.2018.
 */

import { Readable, Transform, TransformCallback } from "stream";
import { forEach, isObject, noop } from "lodash";
import * as oracledb from "oracledb";
import { IRufusLogger } from "rufus";
import { IParamsInfo } from "../../interfaces/ICCTParams";
import { IResultProvider } from "../../interfaces/IResult";
import Logger from "../../Logger";
import { safePipe } from "../../stream/Util";
import { initParams, isEmpty } from "../../utils/Base";
import Connection from "../Connection";
import IOptions from "../../interfaces/IOptions";

const re = /(?!\B'[^']*):(\w+)(?![^']*'\B)/gi;

export interface IOracleDBConfig {
    user: string;
    password: string;
    connectString: string;
    events?: boolean;
    poolAlias?: string;
    partRows?: number;
    maxRows?: number;
    prefetchRows?: number;
    poolMin?: number;
    poolMax?: number;
    queueTimeout?: number;
    queryTimeout?: number;
    lvl_logger?: string;
}

interface IParams {
    [key: string]: string | boolean | number | Record<string, any>;
}

const prepareSql = (query: string) => {
    return (data: Record<string, any>) => {
        const values = {};

        return {
            text: query.replace(
                /(--.*?$)|(\/\*[\s\S]*?\*\/)|('[^']*?')|("[^"]*?")|(::?)([a-zA-Z0-9_]+)/g,
                (_, ...group) => {
                    const noReplace = group.slice(0, 4);
                    const [prefix, key] = group.slice(4);

                    if (prefix === ":") {
                        values[key] = data[key] || null;

                        return `:${key}`;
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

export default class OracleDB {
    public static getParamsInfo(): IParamsInfo {
        return {
            connectString: {
                name: "Строка подключения к БД",
                required: true,
                type: "string",
            },
            maxRows: {
                defaultValue: 100,
                name: "Количество строк при обычном вызове",
                type: "integer",
            },
            partRows: {
                defaultValue: 1000,
                name: "Количество строк при вытаскивании в режиме stream",
                type: "integer",
            },
            password: {
                name: "Пароль учетной записи БД",
                required: true,
                type: "password",
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
            prefetchRows: {
                defaultValue: 500,
                name:
                    "Это свойство задает размер внутреннего буфера," +
                    " используемого для извлечения строк запроса из базы данных Oracle.",
                type: "integer",
            },
            queryTimeout: {
                name: "Максимальное время выполнения запроса в секундах",
                type: "integer",
            },
            queueTimeout: {
                defaultValue: 120000,
                name: "Время ожидания конекта в очереди",
                type: "integer",
            },
            user: {
                name: "Наименвание учетной записи БД",
                required: true,
                type: "string",
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
        };
    }

    public name: string;
    public queryTimeout?: number;
    public connectionConfig: IOracleDBConfig;
    public partRows: number;
    public oracledb: any;
    public pool?: oracledb.Pool;
    private log: IRufusLogger;
    constructor(name: string, params: IOracleDBConfig) {
        if (!isObject(params) || Object.keys(params).length === 0) {
            throw new Error(
                "Не указанты параметры базы данных при вызове констуктора",
            );
        }
        this.log = Logger.getLogger(`OracleDB ${name}`);
        if (params.lvl_logger && params.lvl_logger !== "NOTSET") {
            const rootLogger = Logger.getRootLogger();

            this.log.setLevel(params.lvl_logger);
            for (const handler of rootLogger._handlers) {
                this.log.addHandler(handler);
            }
        }
        this.connectionConfig = initParams(OracleDB.getParamsInfo(), params);
        this.name = name;
        this.partRows =
            this.connectionConfig.partRows ||
            (OracleDB.getParamsInfo().partRows.defaultValue as number);
        this.oracledb = oracledb;
        this.oracledb.outFormat = this.oracledb.OBJECT;
        this.oracledb.autoCommit = true;
        this.oracledb.fetchAsString = [
            this.oracledb.CLOB,
            this.oracledb.NUMBER,
        ];
        this.oracledb.fetchAsBuffer = [this.oracledb.BLOB];
        this.oracledb.maxRows =
            this.connectionConfig.maxRows ||
            OracleDB.getParamsInfo().maxRows.defaultValue;
        this.oracledb.prefetchRows =
            this.connectionConfig.prefetchRows ||
            OracleDB.getParamsInfo().prefetchRows.defaultValue;
        this.oracledb.stmtCacheSize = 200;
        this.oracledb.poolIncrement = 5;
        if (!isEmpty(params.queryTimeout)) {
            this.queryTimeout = params.queryTimeout * 1000;
        } else {
            this.queryTimeout = null;
        }
    }

    public resetPool(name?: string): Promise<void> {
        return new Promise((resolve, reject) => {
            let pool = this.pool;

            if (!pool) {
                try {
                    pool = this.oracledb.getPool(name || this.name);
                } catch (err) {
                    this.log.trace(`${this.name}`, err);
                }
            }
            if (pool) {
                this.onClose(pool)
                    .then(() => {
                        this.pool = undefined;
                        this.log.debug(`Пул сброшен ${this.name}`);
                        resolve();
                    })
                    .catch((err) => {
                        this.log.error(
                            `Ошибка закрытия пула ${this.name}`,
                            err,
                        );
                        reject(err);
                    });
            } else {
                resolve();
            }
        });
    }

    /**
     * Получаем коннект к БД
     * @param name
     * @returns {Promise}
     */
    public getPool(name: string): Promise<oracledb.Pool> {
        return new Promise((resolve, reject) => {
            try {
                const pool = this.oracledb.getPool(name);

                resolve(pool);
            } catch (err) {
                reject(err);
            }
        });
    }

    /**
     * Создаем пул коннект
     * @returns {Promise}
     */
    public createPool(): any {
        return new Promise((resolve, reject) =>
            this.oracledb
                .createPool({
                    connectString: this.connectionConfig.connectString,
                    password: this.connectionConfig.password,
                    poolAlias: this.name,
                    poolMax:
                        this.connectionConfig.poolMax ||
                        OracleDB.getParamsInfo().poolMax.defaultValue,
                    poolMin:
                        this.connectionConfig.poolMin ||
                        OracleDB.getParamsInfo().poolMin.defaultValue,
                    queueTimeout:
                        this.connectionConfig.queueTimeout ||
                        OracleDB.getParamsInfo().queueTimeout.defaultValue,
                    user: this.connectionConfig.user,
                })
                .then((pool) => {
                    this.pool = pool;

                    return resolve(pool);
                })
                .catch((err) => {
                    if (
                        err.message.indexOf(
                            `poolAlias "${this.name}" already exists`,
                        ) > -1
                    ) {
                        return this.getPool(this.name).then((pool) => {
                            this.pool = pool;

                            return resolve(pool);
                        }, reject);
                    }
                    this.log.error("Ошибка создания пула", err);

                    return reject(new Error(err));
                }),
        );
    }

    /**
     * Получаем конект текущий коннект или выдаем из пула
     * @param conn
     * @returns {Promise.<*>}
     */
    public async getConnection(conn?: Connection): Promise<Connection> {
        if (conn) {
            return conn;
        }
        if (!this.pool) {
            return this.getPool(this.name)
                .then(async (pool) => {
                    this.pool = pool;
                    if (this.pool && this.log.isDebugEnabled()) {
                        this.log.debug(
                            `GetConnection Provider pool: ${this.pool.poolAlias},` +
                                ` Connections open: ${this.pool.connectionsOpen}`,
                        );
                        this.log.debug(
                            `GetConnection Provider pool: ${this.pool.poolAlias},` +
                                ` Connections in use: ${this.pool.connectionsInUse}`,
                        );
                    }
                    const oconnect = await pool.getConnection();

                    return new Connection(this, "oracle", oconnect);
                })
                .catch(() =>
                    this.createPool().then(
                        async (oconnect) =>
                            new Connection(this, "oracle", oconnect),
                    ),
                );
        }
        if (this.pool && this.log.isDebugEnabled()) {
            this.log.debug(
                `GetConnection Provider pool: ${this.pool.poolAlias},` +
                    ` Connections open: ${this.pool.connectionsOpen}`,
            );
            this.log.debug(
                `GetConnection Provider pool: ${this.pool.poolAlias},` +
                    ` Connections in use: ${this.pool.connectionsInUse}`,
            );
        }

        return this.pool
            .getConnection()
            .then((oconnect) => new Connection(this, "oracle", oconnect));
    }

    /**
     * Получаем конект текущий коннект или выдаем из пула
     * @param conn
     * @returns {Promise.<*>}
     */
    public async getConnectionNew(
        params?: IOracleDBConfig,
    ): Promise<Connection> {
        if (params.poolAlias) {
            const pool = await this.getPool(params.poolAlias).catch(() =>
                this.oracledb
                    .createPool({
                        poolMax: 10,
                        poolMin: 0,
                        queueTimeout: 120000,
                        ...params,
                    })
                    .catch((err) => {
                        if (typeof err !== "undefined") {
                            this.log.error(
                                "Ошибка подключения к базе данных",
                                err,
                            );

                            return Promise.reject(new Error(err));
                        }

                        return new Promise((resolve, reject) => {
                            setTimeout(() => {
                                this.getConnectionNew(params).then(
                                    resolve,
                                    reject,
                                );
                            }, 1000);
                        });
                    }),
            );

            return pool
                .getConnection()
                .then((oconnect) => new Connection(this, "oracle", oconnect));
        }

        return this.oracledb
            .getConnection(params)
            .then((oconnect) => new Connection(this, oconnect))
            .catch((err) => {
                this.log.error("Ошибка подключения к базе данных", err);

                return Promise.reject(new Error(err));
            });
    }

    /**
     * Создаем новое соединение или возращаем коннект из пула
     * @param params
     * @returns {Promise}
     */
    public async open(params?: IOracleDBConfig): Promise<Connection> {
        try {
            const connect = params
                ? await this.getConnectionNew(params)
                : await this.getConnection();

            return connect;
        } catch (err) {
            if (typeof err !== "undefined") {
                this.log.error("Ошибка подключения к базе данных", err);
                throw new Error(err);
            }

            return new Promise((resolve, reject) => {
                setTimeout(() => {
                    this.open(params).then(resolve, reject);
                }, 1000);
            });
        }
    }

    /**
     * Создаем новое соединение или возращаем коннект из пула
     * @param params
     * @returns {Promise}
     */
    public openEvents(params?: IOracleDBConfig): oracledb.Connection {
        return this.oracledb
            .getConnection({
                connectString: this.connectionConfig.connectString,
                events: true,
                password: this.connectionConfig.password,
                user: this.connectionConfig.user,
                ...params,
            })
            .catch((err) => {
                if (typeof err !== "undefined") {
                    this.log.error("Ошибка подключения к базе данных", err);

                    return Promise.reject(new Error(err));
                }

                return undefined;
            });
    }

    /**
     * Закрываем коннект
     * @param conn
     * @returns {Promise.<void>}
     */
    public onClose(
        conn?:
            | oracledb.Connection
            | oracledb.ResultSet<Record<string, any>>
            | oracledb.Pool,
    ): any {
        if (conn) {
            return conn.close();
        }

        return;
    }

    /**
     * Останавливаем выполнение
     * @param conn
     * @returns {Promise.<void>}
     */
    public async onBreak(conn?: oracledb.Connection): Promise<any> {
        if (conn) {
            return conn.break();
        }

        return;
    }

    /**
     * Освобождаем коннект
     * @param conn
     * @returns {Promise}
     */
    public async onRelease(conn?: oracledb.Connection): Promise<any> {
        if (conn) {
            return conn.release();
        }

        return;
    }

    /**
     * Фиксируем
     * @param conn
     * @returns {Promise.<*|{value, enumerable, writable}>}
     */
    public async onCommit(conn?: oracledb.Connection): Promise<any> {
        if (conn) {
            return conn.commit();
        }

        return;
    }

    /**
     * Откатываем запрос
     * @param conn
     * @returns {Promise.<*|{value, enumerable, writable}>}
     */
    public async onRollBack(conn?: oracledb.Connection): Promise<any> {
        if (conn) {
            return conn.rollback();
        }

        return;
    }

    public async onTx(conn?: oracledb.Connection): Promise<any> {
        if (conn) {
            return conn.execute("BEGIN").then(() => Promise.resolve());
        }

        return;
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
        conn?: oracledb.Connection,
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
                    params[key] = {
                        dir: this.oracledb.BIND_OUT,
                        maxSize: 65000,
                        type:
                            this.oracledb[outParam[key]] ||
                            this.oracledb.DEFAULT,
                    };
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
                // eslint-disable-line no-underscore-dangle
                autoCommit: isEmpty(conn),
                extendedMetaData: true,
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
        inConnection?: oracledb.Connection,
    ): Promise<IResultProvider> {
        let estimateTimerId = null;
        const conn = inConnection
            ? inConnection
            : await this.getConnection().then(async (oconnect) =>
                  oconnect.getCurrentConnection(),
              );
        const isRelease = isEmpty(inConnection) || options.isRelease;

        if (this.pool && this.log.isDebugEnabled()) {
            const logParam = { ...params };

            delete logParam.cv_password;
            delete logParam.cv_hash_password;
            delete logParam.pwd;
            this.log.trace(
                `execute sql:\n${sql}\nparams:\n${JSON.stringify(logParam)}`,
            );
            this.log.debug(
                `Provider pool: ${this.pool.poolAlias}, Connections open: ${this.pool.connectionsOpen}`,
            );
            this.log.debug(
                `Provider pool: ${this.pool.poolAlias}, Connections in use: ${this.pool.connectionsInUse}`,
            );
        }
        if (this.queryTimeout !== null) {
            estimateTimerId = setTimeout(() => {
                this.onBreak(conn);
            }, this.queryTimeout);
        }
        const query = prepareSql(sql)(params);

        return conn
            .execute(query.text, query.values, {
                autoCommit: options.autoCommit,
                extendedMetaData: options.extendedMetaData,
                resultSet: options.resultSet,
            })
            .then((res) => {
                let result: IResultProvider;

                if (estimateTimerId !== null) {
                    clearTimeout(estimateTimerId);
                }
                if (res.resultSet) {
                    result = {
                        metaData: this.extractMetaData(res.resultSet.metaData),
                        stream: res.resultSet.toQueryStream(),
                    };
                    result.stream = safePipe(
                        result.stream,
                        this.DatasetSerializer(res.resultSet.metaData),
                    );
                } else if (res.rows) {
                    result = {
                        metaData: this.extractMetaData(res.metaData),
                        stream: new Readable({
                            highWaterMark: this.oracledb.maxRows,
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
                        this.DatasetSerializer(res.metaData),
                    );
                } else if (res.rowsAffected) {
                    result = {
                        metaData: this.extractMetaData(res.metaData),
                        stream: new Readable({
                            highWaterMark: this.oracledb.maxRows,
                            objectMode: true,
                            read() {
                                this.push({
                                    execute_count: res.rowsAffected,
                                });
                                this.push(null);
                                this.emit("close");
                            },
                        }),
                    };
                    result.stream = safePipe(
                        result.stream,
                        this.DatasetSerializer(res.metaData),
                    );
                } else if (res.outBinds) {
                    let isNotCursor = true;

                    forEach<any>(res.outBinds, (value) => {
                        if (
                            isObject(value) &&
                            (value as oracledb.ResultSet<Record<string, any>>)
                                .toQueryStream
                        ) {
                            isNotCursor = false;
                            result = {
                                metaData: this.extractMetaData(
                                    (value as oracledb.ResultSet<
                                        Record<string, any>
                                    >).metaData,
                                ),
                                stream: (value as oracledb.ResultSet<
                                    Record<string, any>
                                >).toQueryStream(),
                            };
                            result.stream = safePipe(
                                result.stream,
                                this.DatasetSerializer(
                                    (value as oracledb.ResultSet<
                                        Record<string, any>
                                    >).metaData,
                                ),
                            );
                        }
                    });
                    if (isNotCursor) {
                        result = {
                            metaData: this.extractMetaData(res.metaData),
                            stream: new Readable({
                                highWaterMark: this.oracledb.maxRows,
                                objectMode: true,
                                read() {
                                    this.push(res.outBinds);
                                    this.push(null);
                                    this.emit("close");
                                },
                            }),
                        };
                        result.stream = safePipe(
                            result.stream,
                            this.DatasetSerializer(res.metaData),
                        );
                    }
                }
                if (isRelease) {
                    result.stream.on("end", () => {
                        setTimeout(() => {
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
                        }, 0);
                    });
                }

                return Promise.resolve(result);
            })
            .catch((err) => {
                if (estimateTimerId !== null) {
                    clearTimeout(estimateTimerId);
                }
                if (isRelease && conn) {
                    return this.onRollBack(conn)
                        .then(
                            () => this.onRelease(conn),
                            () => this.onRelease(conn),
                        )
                        .then(
                            () => Promise.reject(new Error(err)),
                            () => Promise.reject(new Error(err)),
                        );
                }

                return Promise.reject(new Error(err));
            });
    }

    /**
     * Разбираем ответ от базы key переводим lowerCase
     * @param rowsIn - Object/Array
     * @param rowsOut - Исходящий массив
     * @param metaData - Данные ответа
     * @constructor
     */
    public DatasetSerializer(
        metaData: oracledb.Metadata<Record<string, any>>[],
    ): Transform {
        const column = {};

        if (metaData && metaData.length) {
            let i = 0;

            for (i = 0; i < metaData.length; i += 1) {
                column[metaData[i].name] = {
                    name: `${metaData[i].name}`.toLowerCase(),
                    value:
                        metaData[i].dbType === oracledb.DB_TYPE_NUMBER
                            ? (value) => {
                                  let result = value;

                                  if (value) {
                                      if (
                                          value.indexOf(",") > -1 ||
                                          value.indexOf(".") > -1
                                      ) {
                                          result = value.replace(/,/g, ".");
                                          if (result.indexOf(".") === 0) {
                                              result = `0${result}`;
                                          }
                                      } else {
                                          result = parseInt(value, 10);
                                      }
                                  }

                                  return result;
                              }
                            : (value) => value,
                };
            }
            this.log.debug(`MetaData: ${JSON.stringify(metaData)}`);
        }
        const trans = new Transform({
            readableObjectMode: true,
            writableObjectMode: true,
            transform(chunk: any, encode: string, callback: TransformCallback) {
                const ret = {};

                forEach(chunk, (value, key) => {
                    if (!column[key]) {
                        column[key] = {
                            name: key.toLowerCase(),
                            value: (val) => val,
                        };
                    }
                    ret[column[key].name] = column[key].value(value);
                });
                const transform = (
                    chunkData: any,
                    encodeStr: string,
                    callBack: TransformCallback,
                ) => {
                    const ref = {};

                    forEach(column, (value: any, key) => {
                        ref[value.name] = value.value(chunkData[key]);
                    });
                    callBack(null, ref);
                };

                trans._transform = transform.bind(trans);
                callback(null, ret);
            },
        });

        return trans;
    }

    private extractMetaData(
        metaData: oracledb.Metadata<Record<string, any>>[] = [],
    ) {
        return metaData.map((data) => {
            let datatype = "text";

            switch (data.dbType) {
                case oracledb.DB_TYPE_DATE:
                case oracledb.DB_TYPE_TIMESTAMP:
                case oracledb.DB_TYPE_TIMESTAMP_TZ:
                case oracledb.DB_TYPE_TIMESTAMP_LTZ:
                    datatype = "date";
                    break;
                case oracledb.DB_TYPE_NUMBER:
                    datatype = data.scale === 0 ? "integer" : "numeric";
                    break;
                default:
                    datatype = "text";
                    break;
            }

            return {
                column: data.name,
                datatype,
                decimalprecision: data.scale >= 0 ? data.scale : 17,
            };
        });
    }
}
