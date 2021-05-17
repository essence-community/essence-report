import * as fs from "fs";
import * as path from "path";
import {IParamInfo, IParamsInfo} from "../interfaces/ICCTParams";

export function isEmpty(value: any, allowEmptyString = false) {
    return value == null || (allowEmptyString ? false : value === "") || (Array.isArray(value) && value.length === 0);
}

function parseParam(conf: IParamInfo, value: any) {
    switch (conf.type) {
        case "string":
        case "long_string":
        case "password":
            return String(value);
        case "boolean": {
            if (typeof value === "string") {
                return value === "true";
            }

            return !!value;
        }
        case "integer":
        case "numeric":
            return Number(value);
        default:
            return String(value);
    }
}
/**
 * Функция для инициализации параметров в случаеесли нет обязательных параметров выкинет ErrorException
 * @param conf Настройки плагинов
 * @param param Параметры
 * @returns params Объект с параметрами
 */
export function initParams(conf: IParamsInfo, param: Record<string, any> = {}): any {
    const notFound = [];
    const result = {...param};

    Object.entries(conf).forEach(([key, value]) => {
        if (!isEmpty(param[key])) {
            result[key] = parseParam(value, param[key]);
        } else if (isEmpty(param[key]) && isEmpty(value.defaultValue) && value.required) {
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
