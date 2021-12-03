/* eslint-disable max-statements */
/* eslint-disable max-lines-per-function */
/* eslint-disable max-len */
/* eslint-disable filenames/match-exported */
import * as path from "path";
import * as fs from "fs";
import { Agent as HttpsAgent, AgentOptions } from "https";
import { Agent as HttpAgent } from "http";
import * as url from "url";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import { parse } from "@essence-report/plugininf/lib/parser/parserAsync";
import {
    ISource,
    ISourceParams,
} from "@essence-report/plugininf/lib/interfaces/ISource";
import { isEmpty, initParams } from "@essence-report/plugininf/lib/utils/Base";
import Logger, { IRufusLogger } from "@essence-report/plugininf/lib/Logger";
import { IParamsInfo } from "@essence-report/plugininf/lib/interfaces/ICCTParams";
import * as axios from "axios";
import * as qs from "qs";
import * as FormData from "form-data";
import * as JSONStream from "JSONStream";
import {
    IRestEssenceProxyConfig,
    IRestEssenceProxyParams,
    OptionsRequest,
    ValidHeader,
} from "./RestTransform.types";
import { BreakResult } from "./BreakResult";

export async function InitSource(pgSql: PostgresDB) {
    const isExists = await pgSql
        .executeStmt(
            // eslint-disable-next-line max-len
            "select 1 from t_d_source_type where ck_id=:ck_id",
            null,
            {
                ck_id: "RestTransform".toLowerCase(),
            },
        )
        .then((res) => ReadStreamToArray(res.stream));

    if (isExists.length === 0) {
        await pgSql
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_d_source_type('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb) as result",
                null,
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "I",
                        },
                        data: {
                            ck_id: "RestTransform".toLowerCase(),
                            cv_name: "Rest Transform Server",
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }
}

export class RestTransform implements ISource {
    public static getParamsInfo(): IParamsInfo {
        return {
            defaultGateUrl: {
                name: "Ссылка на проксируемый шлюз",
                type: "string",
            },
            proxy: {
                name: "Прокси сервер",
                type: "string",
            },
            timeout: {
                defaultValue: 660,
                name: "Время ожидания внешнего сервиса в секундах",
                type: "integer",
            },
            useGzip: {
                defaultValue: false,
                name: "Использовать компрессию",
                type: "boolean",
            },
            httpsAgent: {
                name: "Настройки https agent",
                type: "long_string",
            },
            extraParam: {
                type: "form_repeater",
                name: "Дополнительные настройки",
                childs: {
                    key: {
                        type: "string",
                        name: "Ключ",
                        required: true,
                    },
                    value: {
                        type: "string",
                        name: "Значание",
                        required: true,
                    },
                },
            },
            extraParamEncrypt: {
                type: "form_repeater",
                name: "Дополнительные настройки шифрованые",
                childs: {
                    key: {
                        type: "string",
                        name: "Ключ",
                        required: true,
                    },
                    value: {
                        type: "password",
                        name: "Значание",
                        required: true,
                    },
                },
            },
        };
    }
    private extraParam: Record<string, string> = {};
    public params: IRestEssenceProxyParams;
    private name: string;
    private logger: IRufusLogger;

    constructor(name: string, params: Record<string, any>) {
        this.params = initParams(RestTransform.getParamsInfo(), params);
        this.name = name;
        this.logger = Logger.getLogger(`Sourse:${name}`);
    }
    async init(): Promise<void> {
        return;
    }
    async getData(data: ISourceParams): Promise<Record<string, any>[]> {
        if (isEmpty(data.querySource)) {
            return [] as any;
        }
        this.logger.debug(`Path ${data.querySource}`);
        const parser = parse(data.querySource);
        const param = {
            jt_in_param: {
                ...data.sourceParam,
                ...data.queryParam,
            },
            jt_source_params: this.params,
            jt_extra_params: this.extraParam,
        };
        let result = [];

        try {
            const config = await parser.runer<IRestEssenceProxyConfig>({
                get: (key: string, isKeyEmpty: boolean) => {
                    if (key === "callRequest") {
                        return (
                            configRest: IRestEssenceProxyConfig,
                            name?: string,
                        ) => this.callRequest(configRest, param, name);
                    }

                    return param[key] || (isKeyEmpty ? "" : key);
                },
            });

            result = await this.callRequest(config, param);
        } catch (err) {
            if (err instanceof BreakResult) {
                result = err.result;
            } else {
                throw err;
            }
        }

        if (!Array.isArray(result)) {
            result = [result];
        }

        if (result.length && typeof result[0] !== "object") {
            result = result.map((res) => ({ raw: res }));
        }

        return result;
    }

    public async callRequest(
        config: IRestEssenceProxyConfig,
        param: Record<string, any>,
        name?: string,
    ): Promise<any[]> {
        if (name && Object.prototype.hasOwnProperty.call(param, name)) {
            return param[name];
        }
        const headers = {
            ...(config.header || {}),
        };

        if (isEmpty(config.url || this.params.defaultGateUrl)) {
            throw new Error("Not found required parameters url");
        }
        /* tslint:enable:object-literal-sort-keys */
        const urlGate = url.parse(
            config.url || this.params.defaultGateUrl,
            true,
        ) as any;
        const params: axios.AxiosRequestConfig = {
            method: "POST",
            timeout: this.params.timeout
                ? parseInt(this.params.timeout, 10) * 1000
                : 660000,
            headers: {},
            responseType: "stream",
            validateStatus: () => true,
        };

        OptionsRequest.forEach((key) => {
            if (Object.prototype.hasOwnProperty.call(config, key)) {
                params[key] = config[key];
            }
        });

        if (urlGate) {
            params.url = url.format(urlGate);
        }

        if (config.json) {
            params.data =
                typeof config.json === "string"
                    ? JSON.parse(config.json)
                    : config.json;
            params.headers["content-type"] = "application/json";
        }

        if (config.form) {
            params.data =
                typeof config.form === "string"
                    ? config.form
                    : qs.stringify(config.form);
            params.headers["content-type"] =
                "application/x-www-form-urlencoded";
        }

        if (config.formData) {
            const formData = new FormData();

            Object.entries(config.formData).forEach(([key, value]) => {
                if (
                    (Array.isArray(value) &&
                        typeof value[0] === "object" &&
                        (value[0] as any).path) ||
                    (typeof value === "object" && (value as any).path)
                ) {
                    (Array.isArray(value) ? value : [value]).forEach(
                        (val: any) => {
                            formData.append(
                                key,
                                fs.readFileSync(val.path) as any,
                                {
                                    contentType: val.headers["content-type"],
                                    filename: val.originalFilename,
                                } as any,
                            );
                        },
                    );

                    return;
                }
                if (typeof value === "string" && fs.existsSync(value)) {
                    formData.append(
                        key,
                        fs.readFileSync(value) as any,
                        {
                            contentType: "application/octet-stream",
                            filename: path.basename(value),
                        } as any,
                    );

                    return;
                }
                formData.append(key, value);
            });
            params.data = formData;
            params.headers = {
                ...params.headers,
                ...formData.getHeaders(),
            };
        }

        if (Object.keys(headers).length) {
            params.headers = headers as any;
        }

        if (this.params.proxy) {
            const proxy = this.params.proxy.startsWith("{")
                ? JSON.parse(this.params.proxy)
                : url.parse(this.params.proxy, true);
            const proxyauth = proxy.auth.split(":");

            params.proxy = this.params.proxy.startsWith("{")
                ? proxy
                : {
                      host: proxy.host,
                      port: parseInt(proxy.port, 10),
                      auth: proxy.auth
                          ? { username: proxyauth[0], password: proxyauth[1] }
                          : undefined,
                      protocol: proxy.protocol,
                  };
        }

        if (typeof params.proxy === "string") {
            const proxy = (params.proxy as string).startsWith("{")
                ? JSON.parse(this.params.proxy)
                : url.parse(params.proxy, true);
            const proxyauth = proxy.auth.split(":");

            params.proxy = (params.proxy as string).startsWith("{")
                ? proxy
                : {
                      host: proxy.host,
                      port: parseInt(proxy.port, 10),
                      auth: proxy.auth
                          ? { username: proxyauth[0], password: proxyauth[1] }
                          : undefined,
                      protocol: proxy.protocol,
                  };
        }
        if (this.params.httpsAgent) {
            params.httpsAgent = JSON.parse(this.params.httpsAgent);
        }
        if (params.httpsAgent) {
            const httpsAgent: AgentOptions = (params.httpsAgent as string).startsWith(
                "{",
            )
                ? JSON.parse(params.httpsAgent as string)
                : params.httpsAgent;

            if (
                typeof httpsAgent.key === "string" &&
                httpsAgent.key.indexOf("/") > -1 &&
                fs.existsSync(httpsAgent.key)
            ) {
                httpsAgent.key = fs.readFileSync(httpsAgent.key);
            }
            if (
                typeof httpsAgent.ca === "string" &&
                httpsAgent.ca.indexOf("/") > -1 &&
                fs.existsSync(httpsAgent.ca)
            ) {
                httpsAgent.ca = fs.readFileSync(httpsAgent.ca);
            }
            if (
                typeof httpsAgent.cert === "string" &&
                httpsAgent.cert.indexOf("/") > -1 &&
                fs.existsSync(httpsAgent.cert)
            ) {
                httpsAgent.cert = fs.readFileSync(httpsAgent.cert);
            }
            if (
                typeof httpsAgent.crl === "string" &&
                httpsAgent.crl.indexOf("/") > -1 &&
                fs.existsSync(httpsAgent.crl)
            ) {
                httpsAgent.crl = fs.readFileSync(httpsAgent.crl);
            }
            if (
                typeof httpsAgent.dhparam === "string" &&
                httpsAgent.dhparam.indexOf("/") > -1 &&
                fs.existsSync(httpsAgent.dhparam)
            ) {
                httpsAgent.dhparam = fs.readFileSync(httpsAgent.dhparam);
            }
            if (
                typeof httpsAgent.pfx === "string" &&
                httpsAgent.pfx.indexOf("/") > -1 &&
                fs.existsSync(httpsAgent.pfx)
            ) {
                httpsAgent.pfx = fs.readFileSync(httpsAgent.pfx);
            }

            params.httpsAgent = new HttpsAgent(httpsAgent);
        }

        if (params.httpAgent) {
            const httpAgent = (params.httpAgent as string).startsWith("{")
                ? JSON.parse(params.httpAgent as string)
                : params.httpAgent;

            params.httpAgent = new HttpAgent(httpAgent);
        }

        if (this.logger.isDebugEnabled()) {
            this.logger.debug(
                `Request: proxy params:\n${JSON.stringify(params).substr(
                    0,
                    4000,
                )}`,
            );
        }

        return new Promise(async (resolve, reject) => {
            try {
                const response = await axios.default.request(params);
                const ctHeader =
                    response.headers["content-type"] || "application/json";

                if (this.logger.isDebugEnabled()) {
                    this.logger.debug(
                        "Response: Status: %s,  proxy headers:\n%j",
                        response.status,
                        response.headers,
                    );
                }
                let arr: any = [];
                let jtBody;

                if (ValidHeader.find((key) => ctHeader.startsWith(key))) {
                    response.data.on("error", (err) => {
                        if (err) {
                            this.logger.error(err);
                            reject(new Error("Ошибка вызова внешнего сервиса"));
                        }

                        return undefined;
                    });
                    if (
                        isEmpty(config.resultPath) ||
                        config.resultPath === "" ||
                        !ctHeader.startsWith("application/json")
                    ) {
                        arr = await new Promise<any[]>((resolveArr) => {
                            let json = "";

                            response.data.on("data", (data) => {
                                json += data;
                            });
                            response.data.on("end", () => {
                                try {
                                    const parseData = ctHeader.startsWith(
                                        "application/json",
                                    )
                                        ? isEmpty(json)
                                            ? []
                                            : JSON.parse(json)
                                        : {
                                              response_data: json,
                                          };

                                    resolveArr(parseData);
                                } catch (e) {
                                    this.logger.error(
                                        `Parse json error: \n ${json}`,
                                        e,
                                    );
                                    reject(e);
                                }
                            });
                        });
                    } else if (ctHeader.startsWith("application/json")) {
                        const stream = JSONStream.parse(
                            config.resultPath || "*",
                        );

                        response.data.pipe(stream);

                        arr = await ReadStreamToArray(stream as any);
                    }
                } else {
                    jtBody = await new Promise((resolveChild, rejectChild) => {
                        const bufs = [];

                        response.data.on("error", (err) => {
                            if (err) {
                                this.logger.error("Error query", err);

                                return rejectChild(
                                    new Error("Ошибка вызова внешнего сервиса"),
                                );
                            }
                        });
                        response.data.on("data", (d) => {
                            bufs.push(d);
                        });
                        response.data.on("end", () => {
                            resolveChild(Buffer.concat(bufs));
                        });
                    });
                    arr = {
                        jt_body: jtBody,
                    };
                }
                let result = arr;

                if (config.breakResult) {
                    const responseParam = {
                        ...param,
                        jt_response_header: response.headers,
                        jt_result: result,
                        jt_body: jtBody,
                    };
                    const parserResult = parse(config.breakResult);

                    const res = await parserResult.runer({
                        get: (key: string, isKeyEmpty: boolean) => {
                            if (key === "callRequest") {
                                return (
                                    configRestChild: IRestEssenceProxyConfig,
                                    nameChild?: string,
                                ) =>
                                    this.callRequest(
                                        configRestChild,
                                        param,
                                        nameChild,
                                    );
                            }

                            return (
                                responseParam[key] || (isKeyEmpty ? "" : key)
                            );
                        },
                    });

                    if (res) {
                        throw new BreakResult(res);
                    }
                }
                if (config.resultParse) {
                    const responseParam = {
                        ...param,
                        jt_response_header: response.headers,
                        jt_result: result,
                        jt_body: jtBody,
                    };
                    const parserResult = parse(config.resultParse);

                    result = await parserResult.runer({
                        get: (key: string, isKeyEmpty: boolean) => {
                            if (key === "callRequest") {
                                return (
                                    configRestChild: IRestEssenceProxyConfig,
                                    nameChild?: string,
                                ) =>
                                    this.callRequest(
                                        configRestChild,
                                        param,
                                        nameChild,
                                    );
                            }

                            return (
                                responseParam[key] || (isKeyEmpty ? "" : key)
                            );
                        },
                    });
                }
                if (config.resultRowParse && Array.isArray(result)) {
                    const parserRowResult = parse(config.resultRowParse);
                    const responseParam = {
                        ...param,
                        jt_response_header: response.headers,
                        jt_result: result,
                        jt_body: jtBody,
                    };

                    result = await Promise.all(
                        result.map((item, index) => {
                            const rowParam = {
                                ...responseParam,
                                jt_result_row: item,
                                jt_result_row_index: index,
                                jt_body: jtBody,
                            };

                            return parserRowResult.runer({
                                get: (key: string, isKeyEmpty: boolean) => {
                                    if (key === "callRequest") {
                                        return (
                                            configRestChild: IRestEssenceProxyConfig,
                                            nameChild?: string,
                                        ) =>
                                            this.callRequest(
                                                configRestChild,
                                                param,
                                                nameChild,
                                            );
                                    }

                                    return (
                                        rowParam[key] || (isKeyEmpty ? "" : key)
                                    );
                                },
                            });
                        }),
                    );
                }
                if (name) {
                    param[name] = result;
                }

                return resolve(result);
            } catch (err) {
                reject(err);
            }
        });
    }
}

export default RestTransform;
