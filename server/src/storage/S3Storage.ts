/* eslint-disable compat/compat */
import { Readable } from "stream";
import * as AWS from "@aws-sdk/client-s3";
import { IRufusLogger } from "@essence-report/plugininf/lib/Logger";
import {
    IFile,
    IStorage,
} from "@essence-report/plugininf/lib/interfaces/IStorage";

export class S3Storage implements IStorage {
    private clients: AWS.S3;
    private params: Record<string, string>;
    private logger: IRufusLogger;
    constructor(params: Record<string, string>, logger: IRufusLogger) {
        this.params = params;
        this.logger = logger;
        const preParams = JSON.parse(
            this.params.S3_PARAMETER || "{}",
        ) as AWS.S3ClientConfig;
        const credentials = {
            accessKeyId: this.params.S3_KEY_ID,
            secretAccessKey: this.params.S3_SECRET_KEY,
        };

        if (this.params.TYPE_STORAGE === "riak") {
            const endpoint =
                this.params.S3_ENDPOINT || "http://s3.amazonaws.com";
            const config = {
                apiVersion: "2006-03-01",
                credentials,
                endpoint,
                ...(this.params.RIAK_PROXY
                    ? {
                          httpOptions: {
                              proxy: this.params.RIAK_PROXY,
                          },
                      }
                    : {}),
                region: "us-east-1",
                s3DisableBodySigning: true,
                s3ForcePathStyle: true,
                signatureVersion: "v2",
                sslEnabled: false,
                ...preParams,
            } as AWS.S3ClientConfig;

            this.clients = new AWS.S3(config);
        } else if (this.params.TYPE_STORAGE === "aws") {
            const endpoint = this.params.S3_ENDPOINT;
            const config = {
                ...preParams,
                credentials,
                endpoint,
            } as AWS.S3ClientConfig;

            this.clients = new AWS.S3(config);
        }
    }

    /**
     * Сохраняем в S3 хранилище
     * @param gateContext
     * @param json
     * @param val
     * @param query
     * @returns file
     */
    public saveFile(
        key: string,
        buffer: Buffer | Readable,
        content: string,
        Metadata: Record<string, string> = {},
        size: number = (buffer as Readable).pipe
            ? undefined
            : Buffer.byteLength(buffer as Buffer),
    ): Promise<void> {
        return new Promise<void>((resolve, reject) => {
            this.clients.putObject(
                {
                    ...(this.params.S3_READ_PUBLIC === "true"
                        ? { ACL: "public-read" }
                        : {}),
                    Body: buffer,
                    Bucket: this.params.S3_BUCKET,
                    ContentLength: size,
                    ContentType: content,
                    Key: key,
                    Metadata: {
                        ...Metadata,
                        originalFilename:
                            Metadata &&
                            encodeURIComponent(Metadata.originalFilename),
                    },
                },
                (err) => {
                    if (err) {
                        return reject(err);
                    }
                    resolve();
                },
            );
        });
    }
    public deletePath(key: string): Promise<void> {
        return new Promise((resolve, reject) => {
            this.clients.headObject(
                {
                    Bucket: this.params.S3_BUCKET,
                    Key: key,
                },
                (er) => {
                    if (er) {
                        this.logger.debug(er);

                        return resolve();
                    }
                    this.clients.deleteObject(
                        {
                            Bucket: this.params.S3_BUCKET,
                            Key: key,
                        },
                        (err) => {
                            if (err) {
                                return reject(err);
                            }

                            return resolve();
                        },
                    );
                },
            );
        });
    }

    public getFile(key: string): Promise<IFile> {
        return new Promise((resolve, reject) => {
            this.clients.getObject(
                {
                    Bucket: this.params.S3_BUCKET,
                    Key: key,
                },
                (err, response) => {
                    if (err) {
                        return reject(err);
                    }
                    resolve({
                        contentType: response.ContentType,
                        file: response.Body as Buffer,
                        originalFilename:
                            response.Metadata &&
                            decodeURI(response.Metadata.originalFilename),
                        size: response.ContentLength,
                    });
                },
            );
        });
    }
}
