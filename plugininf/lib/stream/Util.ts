import * as http from "http";
import {Readable, Transform} from "stream";
import {isArray, isObject, isString, noop} from "lodash";

type TStream = Transform | NodeJS.ReadWriteStream | Readable;
/**
 * Преобразуем поток в массив
 * @param stream {ReadStream} Поток
 */
export function ReadStreamToArray(stream: Readable): Promise<any[]> {
    return new Promise((resolve, reject) => {
        const res = [];

        stream.on("error", (err) => reject(err));
        stream.on("data", (chunk) => res.push(chunk));
        stream.on("end", () => resolve(res));
    });
}
/**
 * Pipe c передачей ошибки из одного потока в другой
 * @param input
 * @param transforms
 */
export function safePipe(input: Readable, transforms: TStream | TStream[]): Readable {
    // @ts-ignore
    const arrStream: TStream[] = isArray(transforms) ? transforms : [transforms];

    // @ts-ignore
    return arrStream.reduce((stream, val) => {
        stream.on("error", (err) => val.emit("error", err));

        return stream.pipe(val as any);
    }, input);
}
/**
 * Обрываем передачу в случае ошибки в потоках
 * @param stream {ReadStream} Поток
 * @param response {WriteStream} Поток
 */
export function safeResponsePipe(stream: Readable, response: http.ServerResponse) {
    let isError = false;

    stream.on("error", () => {
        isError = true;
    });

    const prePushing = new Transform({
        transform(chunk, encoding, done) {
            done(null, chunk);
        },
    });

    function checkStream() {
        const data = prePushing.read();

        if (data) {
            prePushing.unshift(data);
        }
        setTimeout(() => {
            if (!isError) {
                prePushing.pipe(response);
            } else {
                prePushing.on("data", noop);
            }
        }, 0);
    }
    prePushing.once("readable", checkStream);
    stream.pipe(prePushing);
}

export function ExtractJsonColumn() {
    const columns = ["result", "json"];
    let columnExtract;
    const columnObjExtract = (name: string) => (stream: any, chunk: any, done: any) => {
        try {
            const obj = isString(chunk[name]) ? JSON.parse(chunk[name]) : chunk[name];

            if (isArray(obj)) {
                obj.forEach((val) => stream.push(val));
                done();

                return;
            }
            delete chunk[name];
            done(null, {
                ...chunk,
                ...obj,
            });
        } catch (e) {
            done(null, chunk);
        }
    };
    const columnExist = (stream: any, chunk: any, done: any) => {
        done(null, chunk);
    };
    const extractor = new Transform({
        readableObjectMode: true,
        writableObjectMode: true,
        transform(chunk: any, encode: string, done) {
            if (columnExtract) {
                columnExtract(this, chunk, done);

                return;
            }
            if (!isObject(chunk)) {
                columnExtract = columnExist;
                columnExtract(this, chunk, done);

                return;
            }
            if (columns.length) {
                const res = columns.every((val) => {
                    if (Object.prototype.hasOwnProperty.call(chunk, val)) {
                        columnExtract = columnObjExtract(val);
                        columnExtract(this, chunk, done);

                        return false;
                    }

                    return true;
                });

                if (!res) {
                    return;
                }
            }
            columnExtract = columnExist;
            columnExtract(this, chunk, done);

            return;
        },
    });

    return extractor;
}
