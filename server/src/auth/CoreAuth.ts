import * as URL from "url";
import * as http from "http";
import { IAuthPlugin } from "@essence-report/plugininf/lib/interfaces/IAuthPlugin";
import Logger from "@essence-report/plugininf/lib/Logger";
import { ISessionData } from "@essence-report/plugininf/lib/interfaces/ISessionData";

export class CoreAuth implements IAuthPlugin {
    private params: Record<string, any>;
    private logger;
    constructor(name: string, params: Record<string, any>) {
        this.params = params;
        this.logger = Logger.getLogger(name);
    }
    public async init(): Promise<void> {
        return;
    }
    public async checkSession(session?: string): Promise<false | ISessionData> {
        const url = URL.parse(this.params.cv_url, true);

        url.query.session = session;

        return new Promise((resolve) => {
            this.logger.debug("GET url %j", url);
            http.get(URL.format(url), async (res) => {
                const { statusCode } = res;
                const contentType = res.headers["content-type"];

                if (
                    statusCode !== 200 ||
                    !/^application\/json/.test(contentType)
                ) {
                    this.logger.error(
                        "GET response url %j code %s content-type %s",
                        url,
                        statusCode,
                        contentType,
                    );
                    res.resume();

                    return resolve(false);
                }
                res.setEncoding("utf8");
                let rawData = "";

                res.on("data", (chunk) => {
                    rawData += chunk;
                });
                res.on("end", () => {
                    try {
                        const parsedData = JSON.parse(rawData);

                        if (
                            parsedData.success &&
                            parsedData.data &&
                            parsedData.data.length
                        ) {
                            return resolve({ session, ...parsedData.data[0] });
                        } else {
                            this.logger.error(
                                "GET response url %j code %s content-type %s data %j",
                                url,
                                statusCode,
                                contentType,
                                rawData,
                            );
                        }
                    } catch (e) {
                        this.logger.error(
                            "GET response url %j code %s content-type %s data %j",
                            url,
                            statusCode,
                            contentType,
                            rawData,
                        );
                    }

                    return resolve(false);
                });
            });
        });
    }
}
