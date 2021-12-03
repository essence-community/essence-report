export default interface ICCTParams {
    [key: string]: any;
}

export interface IComboValueParam {
    in: string;
    out?: string;
}

export interface ISetGlobalValueParam {
    in?: string;
    out: string;
}
export interface IBaseParamInfo {
    required?: boolean;
    type:
        | "string"
        | "boolean"
        | "integer"
        | "numeric"
        | "date"
        | "password"
        | "long_string"
        | "combo"
        | "form_nested"
        | "form_repeater";
    setGlobal?: ISetGlobalValueParam[];
    getGlobal?: string;
    hiddenRules?: string;
    disabledRules?: string;
    defaultValue?: any;
    name: string;
    maxsize?: number;
    description?: string;
    hidden?: boolean;
    disabled?: boolean;
    checkvalue?: (val) => string | number | boolean;
}

export interface IComboParamInfo extends IBaseParamInfo {
    type: "combo";
    valueField: IComboValueParam[];
    getGlobalToStore?: IComboValueParam[];
    displayField: string;
    idproperty?: string;
    allownew?: string;
    minchars?: number;
    pagesize?: number;
    querymode?: "remote" | "local";
    queryparam?: string;
    query?: string;
    // tslint:disable-line array-type
    records?: Record<string, any>[];
    defaultValue?: string | number | boolean;
}

export interface IStringAreaParamInfo extends IBaseParamInfo {
    type: "string" | "password" | "long_string";
    defaultValue?: string;
}

export interface INumberParamInfo extends IBaseParamInfo {
    type: "integer" | "numeric";
    minValue?: number;
    maxValue?: number;
    defaultValue?: number;
}

export interface IDateParamInfo extends IBaseParamInfo {
    type: "date";
    format: "1" | "2" | "3" | "4" | "5" | "6";
    defaultValue?: string;
}

export interface IBooleanParamInfo extends IBaseParamInfo {
    type: "boolean";
    defaultValue?: boolean;
}

export interface IFormNestedParamInfo extends IBaseParamInfo {
    type: "form_nested";
    childs: IParamsInfo;
    defaultValue?: Record<string, any>;
}

export interface IFormRepeaterParamInfo extends IBaseParamInfo {
    type: "form_repeater";
    childs: IParamsInfo;
    defaultValue?: Record<string, any>[];
}

export type IParamInfo =
    | IBooleanParamInfo
    | IDateParamInfo
    | INumberParamInfo
    | IStringAreaParamInfo
    | IComboParamInfo
    | IFormNestedParamInfo
    | IFormRepeaterParamInfo;

export interface IParamsInfo {
    [key: string]: IParamInfo;
}
