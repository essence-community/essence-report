import * as fs from "fs";
import * as path from "path";
import * as crypto from "crypto";
import { isString, toString, toNumber } from "lodash";
import * as moment from "moment";
import { IParamInfo, IParamsInfo } from "../interfaces/ICCTParams";
import Constant from "../Constant";
import * as cu from "./cryptoUtil";

export function isEmpty(value: any, allowEmptyString = false) {
    return (
        value == null ||
        (allowEmptyString ? false : value === "") ||
        (Array.isArray(value) && value.length === 0)
    );
}

function decryptAes(
    type: crypto.CipherCCMTypes | crypto.CipherGCMTypes,
    data: string,
): string {
    const key = cu.getKeyFromPassword(
        type,
        Constant.PW_KEY_SECRET,
        Constant.PW_SALT_SECRET,
    );

    return cu.decrypt(type, data, key);
}

function decryptUseKey(data: string): string {
    return crypto
        .privateDecrypt(
            {
                key: Constant.PW_RSA_SECRET,
                passphrase: Constant.PW_RSA_SECRET_PASSPHRASE,
            },
            Buffer.from(data, "hex"),
        )
        .toString();
}

export function encryptAes(
    type: crypto.CipherCCMTypes | crypto.CipherGCMTypes,
    data: string,
): string {
    if (!Constant.PW_KEY_SECRET) {
        throw new Error(
            "Not found key, need init environment ESSENCE_PW_KEY_SECRET",
        );
    }
    const key = cu.getKeyFromPassword(
        type,
        Constant.PW_KEY_SECRET,
        Constant.PW_SALT_SECRET,
    );

    return cu.encrypt(type, data, key);
}

export function encryptUseKey(data: string): string {
    if (!Constant.PW_RSA_SECRET) {
        throw new Error(
            "Not found private key, need init environment ESSSENCE_PW_RSA",
        );
    }

    return crypto
        .publicEncrypt(
            {
                key: Constant.PW_RSA_SECRET,
                passphrase: Constant.PW_RSA_SECRET_PASSPHRASE,
            } as any,
            Buffer.from(data),
        )
        .toString("hex");
}
/**
 * Encrypt password
 * @param data
 * @param type
 * @returns
 */
export function encryptPassword(
    data: string,
    type = Constant.DEFAULT_ALG,
): string {
    if (!Constant.isUseEncrypt) {
        return data;
    }
    switch (type) {
        case "privatekey": {
            if (!Constant.PW_RSA_SECRET) {
                return data;
            }

            return `{privatekey}${encryptUseKey(data)}`;
        }
        case "aes-128-gcm":
        case "aes-192-gcm":
        case "aes-256-gcm":
        case "aes-128-ccm":
        case "aes-192-ccm":
        case "aes-256-ccm":
        case "aes-128-cbc":
        case "aes-192-cbc":
        case "aes-256-cbc": {
            if (!Constant.PW_KEY_SECRET) {
                return data;
            }

            return `{${type}}${encryptAes(type as any, data)}`;
        }
        default:
            return data;
    }
}

export function decryptPassword(value: string) {
    if (
        typeof value !== "string" ||
        isEmpty(value) ||
        value.indexOf("{") !== 0 ||
        !Constant.isUseEncrypt
    ) {
        return value;
    }
    const endIndex = value.indexOf("}");
    const type = value.substring(1, endIndex);
    const hash = value.substring(endIndex + 1);

    switch (type) {
        case "aes-128-gcm":
        case "aes-192-gcm":
        case "aes-256-gcm":
        case "aes-128-ccm":
        case "aes-192-ccm":
        case "aes-256-ccm":
        case "aes-128-cbc":
        case "aes-192-cbc":
        case "aes-256-cbc":
            return decryptAes(type as any, hash);
        case "privatekey":
            return decryptUseKey(hash);
        default:
            return value;
    }
}

function parseParam(conf: IParamInfo, value: any) {
    switch (conf.type) {
        case "string":
        case "long_string":
            return conf.checkvalue
                ? conf.checkvalue(toString(value))
                : toString(value);
        case "password": {
            const decryptPass = decryptPassword(toString(value));

            return conf.checkvalue ? conf.checkvalue(decryptPass) : decryptPass;
        }
        case "boolean": {
            if (isString(value)) {
                return conf.checkvalue
                    ? conf.checkvalue(value === "true" || value === "1")
                    : value === "true" || value === "1";
            }

            return conf.checkvalue ? conf.checkvalue(!!value) : !!value;
        }
        case "integer":
        case "numeric":
            return conf.checkvalue
                ? conf.checkvalue(toNumber(value))
                : toNumber(value);
        case "date":
            return conf.checkvalue
                ? conf.checkvalue(moment(value).toDate())
                : moment(value).toDate();
        case "form_nested":
            return Object.entries(conf.childs).reduce((res, [key, obj]) => {
                if (!isEmpty((value || {})[key])) {
                    res[key] = parseParam(obj, value[key]);
                } else if (
                    isEmpty((value || {})[key]) &&
                    !isEmpty(
                        (isEmpty(value) ? conf.defaultValue || {} : value)[key],
                    )
                ) {
                    res[key] = parseParam(
                        obj,
                        (isEmpty(value) ? conf.defaultValue || {} : value)[key],
                    );
                } else if (
                    isEmpty((value || {})[key]) &&
                    !isEmpty(obj.defaultValue)
                ) {
                    res[key] = obj.defaultValue;
                }

                return res;
            }, {});
        case "form_repeater":
            return (value || conf.defaultValue || []).map((val) =>
                Object.entries(conf.childs).reduce((res, [key, obj]) => {
                    if (!isEmpty(val[key])) {
                        res[key] = parseParam(obj, val[key]);
                    } else if (
                        isEmpty(val[key]) &&
                        !isEmpty(obj.defaultValue)
                    ) {
                        res[key] = obj.defaultValue;
                    }

                    return res;
                }, {}),
            );
        default: {
            const decryptPass = decryptPassword(value);

            return conf.checkvalue ? conf.checkvalue(decryptPass) : decryptPass;
        }
    }
}
/**
 * Функция для инициализации параметров в случаеесли нет обязательных параметров выкинет ErrorException
 * @param conf Настройки плагинов
 * @param param Параметры
 * @returns params Объект с параметрами
 */
export function initParams(
    conf: IParamsInfo,
    param: Record<string, any> = {},
): any {
    const notFound = [];
    const result = { ...param };

    Object.entries(conf).forEach(([key, value]) => {
        if (!isEmpty(param[key])) {
            result[key] = parseParam(value, param[key]);
        } else if (
            isEmpty(param[key]) &&
            isEmpty(value.defaultValue) &&
            value.required
        ) {
            notFound.push(key);
        } else if (isEmpty(param[key]) && !isEmpty(value.defaultValue)) {
            result[key] = value.defaultValue;
        }
    });
    if (notFound.length) {
        throw new Error(`Not found require params ${notFound.join(",")}`);
    }

    return result;
}

type TDebounce = (...arg) => void;

/**
 * Функция вызывается не более одного раза в указанный период времени
 * (например, раз в 10 секунд). Другими словами ― троттлинг предотвращает запуск функции,
 * если она уже запускалась недавно.
 * @param f {Function} Функция которая должна вызваться
 * @param t {number} Время в милиссекундах
 */
export function throttle(f: TDebounce, t: number) {
    let lastCall;

    return (...args) => {
        const previousCall = lastCall;

        lastCall = Date.now();
        if (
            previousCall === undefined || // function is being called for the first time
            lastCall - previousCall > t
        ) {
            // throttle time has elapsed
            f(...args);
        }
    };
}

export interface IDebounce extends TDebounce {
    cancel: () => void;
}
/**
 * Все вызовы будут игнорироваться до тех пор,
 * пока они не прекратятся на определённый период времени.
 * Только после этого функция будет вызвана.
 * @param f {Function} Функция которая должна вызваться
 * @param t {number} Время в милиссекундах
 */
export function debounce(f: TDebounce, t: number): IDebounce {
    let lastCallTimer = null;
    let lastCall = null;
    const fn = (...args) => {
        const previousCall = lastCall;

        lastCall = Date.now();
        if (previousCall && lastCall - previousCall <= t) {
            clearTimeout(lastCallTimer);
        }
        lastCallTimer = setTimeout(() => {
            lastCallTimer = null;
            lastCall = null;
            f(...args);
        }, t);
    };

    fn.cancel = () => {
        clearTimeout(lastCallTimer);
    };

    return fn;
}

export const deleteFolderRecursive = (pathDir: string) => {
    if (fs.existsSync(pathDir)) {
        if (fs.lstatSync(pathDir).isDirectory()) {
            fs.readdirSync(pathDir).forEach((file) => {
                const curPath = path.join(pathDir, file);

                if (fs.lstatSync(curPath).isDirectory()) {
                    // recurse
                    deleteFolderRecursive(curPath);
                } else {
                    // delete file
                    fs.unlinkSync(curPath);
                }
            });
            fs.rmdirSync(pathDir);

            return;
        }
        fs.unlinkSync(pathDir);
    }
};

export const deepFind = (
    obj: Record<string, any>,
    path: string | string[],
): [boolean, Record<string, any> | any] => {
    if (isEmpty(obj) || isEmpty(path)) {
        return [false, undefined];
    }
    const paths: any[] = Array.isArray(path) ? path : path.split(".");
    let current: any = obj;

    for (const [idx, val] of paths.entries()) {
        if (
            typeof current === "string" &&
            (current.trim().charAt(0) === "[" ||
                current.trim().charAt(0) === "{")
        ) {
            current = JSON.parse(current);
        }
        if (!Array.isArray(current) && typeof current !== "object") {
            return [false, undefined];
        }

        if (
            val === "*" &&
            (current[val] === undefined || current[val] === null)
        ) {
            const arr = (
                Array.isArray(current)
                    ? current.map(
                          (obj) => deepFind(obj, paths.slice(idx + 1))[1],
                      )
                    : Object.entries(current).map(
                          ([, obj]) =>
                              deepFind(obj as any, paths.slice(idx + 1))[1],
                      )
            ).filter((val) => val !== undefined && val !== null);

            return [arr.length > 0, arr];
        }

        if (current[val] === undefined || current[val] === null) {
            return [false, current[val]];
        }

        current = current[val];
    }

    return [true, current];
};

export const deepChange = (
    obj: Record<string, any>,
    path: string,
    value: Record<string, any> | any,
): boolean => {
    if (isEmpty(path) || isEmpty(obj)) {
        return false;
    }
    const paths: any[] = path.split(".");
    const last = paths.pop();
    let current: any = obj;

    if (
        paths.length &&
        !Array.isArray(current[paths[0]]) &&
        typeof current[paths[0]] !== "object"
    ) {
        current[paths[0]] = /[0-9]+/.test(paths[0]) ? [] : {};
    }
    for (const val of paths) {
        current = current[val];
        if (!Array.isArray(current) && typeof current !== "object") {
            current[val] = /[0-9]+/.test(val) ? [] : {};
            current = current[val];
        }
    }
    current[last] = value;

    return true;
};

export const deepDelete = (
    obj: Record<string, any>,
    path: string,
): Record<string, any> => {
    const res = { ...obj };
    const paths: any[] = path.split(".");
    const end = paths.pop();
    let current: any = res;

    for (const val of paths) {
        if (current[val] === undefined) {
            return res;
        }
        current = current[val];
    }

    if (Array.isArray(current)) {
        current.splice(end, 1);
    } else {
        delete current[end];
    }

    return res;
};
