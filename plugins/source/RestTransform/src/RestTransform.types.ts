import { AxiosRequestConfig } from "axios";

export const OptionsRequest = [
    "url",
    "method",
    "baseURL",
    "headers",
    "params",
    "data",
    "timeout",
    "timeoutErrorMessage",
    "withCredentials",
    "adapter",
    "auth",
    "xsrfCookieName",
    "xsrfHeaderName",
    "maxContentLength",
    "maxRedirects",
    "httpAgent",
    "httpsAgent",
    "proxy",
];

export const ValidHeader = ["application/json", "application/xml", "text/"];

export interface IRestEssenceProxyConfig extends Partial<AxiosRequestConfig> {
    header?: Record<string, string | string[]>;
    url?: string;
    json?: Record<string, any> | string | string[] | Record<string, any>[];
    form?: Record<string, any> | string;
    formData?: Record<string, any>;
    resultPath?: string;
    resultParse?: string;
    resultRowParse?: string;
    breakResult?: string;
    proxyResult?: boolean;
}

interface IPairValue {
    key: string;
    value: string;
}

export interface IRestEssenceProxyParams {
    defaultGateUrl: string;
    proxy?: string;
    timeout: string;
    useGzip: boolean;
    httpsAgent?: string;
    extraParam?: IPairValue[];
    extraParamEncrypt?: IPairValue[];
}
