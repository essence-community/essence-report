import {Readable} from "stream";

export interface IFile {
    /**
     * the filename that the user reports for the file
     */
    originalFilename: string;
    /**
     * the absolute path of the uploaded file on disk
     */
    file: Buffer | Readable;
    /**
     * the HTTP headers that were sent along with this file
     */
    contentType: string;
    /**
     * size of the file in bytes
     */
    size?: number;
}

export declare class IStorage {
    public saveFile(
        path: string,
        buffer: Buffer | Readable,
        content: string,
        metaData?: Record<string, string>,
        size?: number,
    ): Promise<void>;
    public deletePath(path: string): Promise<void>;
    public getFile(key: string): Promise<IFile>;
}
