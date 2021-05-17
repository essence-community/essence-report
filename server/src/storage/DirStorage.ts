import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { Readable } from "stream";
import { IRufusLogger } from "@essence-report/plugininf/lib/Logger";
import {
    IFile,
    IStorage,
} from "@essence-report/plugininf/lib/interfaces/IStorage";

export class DirStorage implements IStorage {
    private params: Record<string, string>;
    private logger: IRufusLogger;
    private UPLOAD_DIR: string = os.tmpdir();
    constructor(params: Record<string, string>, logger: IRufusLogger) {
        this.params = params;
        this.logger = logger;
        if (this.params.DIR_STORAGE_PATH) {
            this.UPLOAD_DIR = this.params.DIR_STORAGE_PATH;
        }
    }
    /**
     * Сохраняем в папку
     * @param gateContext
     * @param json
     * @param val
     * @param query
     * @returns
     */
    public saveFile(
        key: string,
        buffer: Buffer | Readable,
        content: string,
        metaData: Record<string, string> = {},
        size: number = (buffer as Readable).pipe
            ? undefined
            : Buffer.byteLength(buffer as Buffer),
    ): Promise<void> {
        const prePath = key.charAt(0) === "/" ? key.substr(1) : key;

        return new Promise((resolve, reject) => {
            const file = path.resolve(this.UPLOAD_DIR, prePath);
            const parent = path.dirname(file);

            if (!fs.existsSync(parent)) {
                fs.mkdirSync(parent, {
                    recursive: true,
                });
            }
            fs.writeFileSync(
                `${file}.meta`,
                JSON.stringify({
                    ...metaData,
                    ContentLength: size,
                    ContentType: content,
                }),
            );
            if ((buffer as Readable).pipe) {
                const ws = fs.createWriteStream(`${file}`);

                ws.on("error", (err) => reject(err));
                (buffer as Readable).on("error", (err) => reject(err));
                (buffer as Readable).on("end", () => resolve());
                (buffer as Readable).pipe(ws);

                return;
            }
            fs.writeFile(`${file}`, buffer as Buffer, (err) => {
                if (err) {
                    reject(err);
                }
                resolve();
            });
        });
    }
    public deletePath(key: string): Promise<void> {
        const prePath = key.charAt(0) === "/" ? key.substr(1) : key;

        return new Promise((resolve, reject) => {
            const file = path.resolve(this.UPLOAD_DIR, prePath);

            if (!fs.existsSync(file)) {
                return resolve();
            }
            fs.unlink(`${file}.meta`, (err) => {
                if (err) {
                    return reject(err);
                }
                fs.unlink(file, (errChild) => {
                    if (errChild) {
                        return reject(errChild);
                    }
                    resolve();
                });
            });
        });
    }

    public getFile(key: string): Promise<IFile> {
        const prePath = key.charAt(0) === "/" ? key.substr(1) : key;

        return new Promise((resolve) => {
            const file = path.resolve(this.UPLOAD_DIR, prePath);
            const readMetaData = JSON.parse(
                fs.readFileSync(`${file}.meta`).toString(),
            );

            resolve({
                contentType: readMetaData.ContentType,
                originalFilename: readMetaData.originalFilename,
                file: fs.createReadStream(file),
                size: readMetaData.ContentLength,
            });
        });
    }
}
