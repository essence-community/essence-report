export interface ISourceParams {
    ck_id: string;
    cct_parameter: Record<string, any>;
}

export interface ISourceParams {
    querySource?: string;
    queryParam: Record<string, any>;
    sourceParam: Record<string, any>;
}

export interface ISource {
    init(): Promise<void>;
    getData(data: ISourceParams): Promise<Record<string, any>[]>;
}
