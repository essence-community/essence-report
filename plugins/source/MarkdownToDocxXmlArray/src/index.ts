/* eslint-disable max-len */
/* eslint-disable filenames/match-exported */
import * as path from "path";
import * as fs from "fs";
import * as os from "os";
import { exec } from "child_process";
import PostgresDB from "@essence-report/plugininf/lib/db/postgres/PostgresDB";
import { ReadStreamToArray } from "@essence-report/plugininf/lib/stream/Util";
import {
    ISource,
    ISourceParams,
} from "@essence-report/plugininf/lib/interfaces/ISource";
import {
    isEmpty,
    deepFind,
    deleteFolderRecursive,
} from "@essence-report/plugininf/lib/utils/Base";
import { v4 as uuid } from "uuid";
import * as AdmZip from "adm-zip";
import { DOMParser } from "xmldom";
import * as xpath from "xpath";
import Logger, { IRufusLogger } from "@essence-report/plugininf/lib/Logger";

const pandocExec = process.env.ESSENCE_PANDOC_EXEC || "pandoc";

export async function InitSource(pgSql: PostgresDB) {
    const isExists = await pgSql
        .executeStmt(
            // eslint-disable-next-line max-len
            "select 1 from t_d_source_type where ck_id=:ck_id",
            null,
            {
                ck_id: "MarkdownToDocxXmlArray".toLowerCase(),
            },
        )
        .then((res) => ReadStreamToArray(res.stream));

    if (isExists.length === 0) {
        await pgSql
            .executeStmt(
                // eslint-disable-next-line max-len
                "select pkg_json_essence_report.f_modify_d_source_type('-11'::varchar, 'USPO_SERVER'::varchar, :json::jsonb) as result",
                null,
                {
                    json: JSON.stringify({
                        service: {
                            cv_action: "I",
                        },
                        data: {
                            ck_id: "MarkdownToDocxXmlArray".toLowerCase(),
                            cv_name: "Markdown To Docx Xml Array",
                        },
                    }),
                },
            )
            .then((res) => ReadStreamToArray(res.stream));
    }
}

export class MarkdownToDocxXmlArray implements ISource {
    private name: string;
    private params: Record<string, any>;
    private logger: IRufusLogger;

    constructor(name: string, params: Record<string, any>) {
        this.name = name;
        this.params = params;
        this.logger = Logger.getLogger(name);
    }
    async init(): Promise<void> {
        return;
    }
    getData(data: ISourceParams): Promise<Record<string, any>[]> {
        if (isEmpty(data.querySource)) {
            return [] as any;
        }
        this.logger.debug(`Path ${data.querySource}`);
        const [isExists, markdown] = deepFind(
            data.queryParam,
            data.querySource,
        );

        this.logger.debug(`Path ${data.querySource} and md: ${markdown}`);
        if (!isExists) {
            return [] as any;
        }
        const pathTemp = path.resolve(os.tmpdir(), uuid());

        fs.mkdirSync(pathTemp, {
            recursive: true,
        });
        fs.writeFileSync(path.join(pathTemp, "input.md"), markdown);

        return new Promise((resolve, reject) => {
            exec(
                `${pandocExec} -t docx ${path.resolve(
                    pathTemp,
                    "input.md",
                )} -o ${path.resolve(pathTemp, "output.docx")}`,
                (err) => {
                    if (err) {
                        return reject(err);
                    }
                    try {
                        const zip = new AdmZip(
                            path.join(pathTemp, "output.docx"),
                        );
                        const doc = new DOMParser().parseFromString(
                            zip.readFile("word/document.xml").toString(),
                        );
                        const nodes = xpath.select(
                            "//*[local-name(.)='body']/*",
                            doc,
                        );

                        this.logger.debug("Xml nodes %j", nodes);

                        return resolve(
                            nodes.length
                                ? nodes.map((element) => ({
                                      xml: element.toString(),
                                  }))
                                : [],
                        );
                    } catch (e) {
                        reject(e);
                    } finally {
                        deleteFolderRecursive(pathTemp);
                    }
                },
            );
        });
    }
}

export default MarkdownToDocxXmlArray;
