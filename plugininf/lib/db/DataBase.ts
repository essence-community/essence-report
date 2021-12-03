/* eslint-disable filenames/match-exported */
import * as fs from "fs";
import * as path from "path";
import * as TOML from "@iarna/toml";
import PostgresDB, { IPostgresDBConfig } from "../db/postgres/PostgresDB";

export const DB_PROPERTY_FILE =
    process.env.ESSENCE_REPORT_DB_PROPERTY ||
    path.resolve(__dirname, "..", "..", "..", "config", "db_property.toml");

export class DataBase {
    public pgDb: PostgresDB;
    public property: Record<string, any>;
    constructor() {
        this.property = fs.existsSync(DB_PROPERTY_FILE)
            ? TOML.parse(
                  fs.readFileSync(DB_PROPERTY_FILE, {
                      encoding: "utf-8",
                  }),
              )
            : {};
        if (process.env.DB_HOST) {
            this.property.connectString = `postgres://${process.env.DB_HOST}:${
                process.env.DB_PORT ? process.env.DB_PORT : "5432"
            }/${
                process.env.DB_DATABASE
                    ? process.env.DB_DATABASE
                    : "essence_report"
            }`;
        }
        if (process.env.DB_USERNAME) {
            this.property.user = process.env.DB_USERNAME;
        }
        if (process.env.DB_PASSWORD) {
            this.property.password = process.env.DB_PASSWORD;
        }
        if (process.env.DB_POOL_MAX) {
            this.property.poolMax = parseInt(process.env.DB_POOL_MAX, 10);
        }
        if (process.env.DB_POOL_MIN) {
            this.property.poolMin = parseInt(process.env.DB_POOL_MIN, 10);
        }

        this.pgDb = new PostgresDB("core", this.property as IPostgresDBConfig);
    }

    public init() {
        this.pgDb.createPool();
    }

    public getCoreDb(): PostgresDB {
        return this.pgDb;
    }
}

export const dataBase = new DataBase();
export default dataBase;
