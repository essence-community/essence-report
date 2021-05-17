import {Readable} from "stream";

/**
 * Created by artemov_i on 04.12.2018.
 */
export interface IMetaData {
    [key: string]: string | string[] | number[] | number | Date | IMetaData | IMetaData[];
}
export interface IResult {
    type: "success" | "false" | "error" | "file" | "binary" | "attachment" | "break";
    data: Readable;
    metaData?: IMetaData;
}
export default IResult;
export interface IResultProvider {
    stream: Readable;
    metaData?: any;
}
