export default interface ICCTParams {
    [key: string]: any;
}

export interface IComboValueParam {
    in: string;
    out?: string;
}

export interface IParamInfo {
    required?: boolean;
    type: "string" | "boolean" | "integer" | "numeric" | "date" | "password" | "long_string" | "combo";
    setGlobal?: string;
    getGlobal?: string;
    hiddenRules?: string;
    disabledRules?: string;
    defaultValue?: any;
    name: string;
    description?: string;
    valueField?: IComboValueParam[];
    displayField?: string;
    query?: string;
    minValue?: number;
    maxValue?: number;
    allownew?: string;
    maxsize?: number;
    minchars?: number;
    pagesize?: number;
    querymode?: "remote" | "local";
    queryparam?: string;
    records?: Record<string, string | number>[];
}

export interface IParamsInfo {
    [key: string]: IParamInfo;
}
