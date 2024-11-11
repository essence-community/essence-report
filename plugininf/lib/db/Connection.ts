import {EventEmitter} from "events";
import {IResultProvider} from "../interfaces/IResult";
import IOptions from "../interfaces/IOptions";

type nameType = "oracle" | "postgresql";
class Connection extends EventEmitter {
    public name: nameType;
    private connection?: any;
    private DataSource: any;
    private isReleased = false;
    private isExecute = false;
    private isTx = false;
    constructor(dataSource: any, name: nameType, connection?: any) {
        super();
        this.name = name;
        this.DataSource = dataSource;
        this.connection = connection;
    }
    public getCurrentConnection() {
        return this.connection;
    }
    public getNewConnection() {
        return this.DataSource.getConnection();
    }
    public async executeStmt(
        sql: string,
        inParam?: Record<string, any>,
        outParam?: Record<string, any>,
        options?: IOptions,
    ): Promise<IResultProvider> {
        let result = null;

        this.isExecute = true;
        try {
            result = await this.DataSource.executeStmt(sql, this.connection, inParam, outParam, options);
        } finally {
            if (result) {
                result.stream.once("end", () => {
                    this.isExecute = false;
                    this.emit("finish");
                });
            } else {
                this.isExecute = false;
                this.emit("finish");
            }
        }

        return result;
    }

    public async tx(): Promise<void> {
        if (this.isTx) {
            return;
        }
        return this.DataSource.onTx(this.connection).then(() => {
            this.isTx = true;
        });
    }

    public async release(): Promise<void> {
        if (this.isReleased) {
            return;
        }
        if (this.isExecute) {
            return new Promise((resolve, reject) => {
                this.once("finish", () => {
                    this.release().then(
                        () => resolve(),
                        (err) => reject(err),
                    );
                });
            });
        }
        try {
            this.isExecute = true;
            if (this.isTx) {
                await this.rollback();
                this.isTx = false;
            }
            await this.DataSource.onRelease(this.connection);
        } finally {
            this.isExecute = false;
            this.isReleased = true;
            this.emit("finish");
        }

        return;
    }
    public async close(): Promise<void> {
        if (this.isReleased) {
            return;
        }
        if (this.isExecute) {
            return new Promise((resolve, reject) => {
                this.once("finish", () => {
                    this.close().then(
                        () => resolve(),
                        (err) => reject(err),
                    );
                });
            });
        }
        try {
            this.isExecute = true;
            if (this.isTx) {
                await this.rollback();
                this.isTx = false;
            }
            await this.DataSource.onClose(this.connection);
        } finally {
            this.isExecute = false;
            this.isReleased = true;
            this.emit("finish");
        }

        return;
    }
    public async commit(): Promise<void> {
        if (this.isReleased) {
            return;
        }
        if (this.isExecute) {
            return new Promise((resolve, reject) => {
                this.once("finish", () => {
                    this.commit().then(
                        () => resolve(),
                        (err) => reject(err),
                    );
                });
            });
        }
        this.isExecute = true;
        try {
            await this.DataSource.onCommit(this.connection);
        } finally {
            this.isExecute = false;
            this.isTx = false;
            this.emit("finish");
        }

        return;
    }
    public async rollback(): Promise<void> {
        if (this.isReleased) {
            return;
        }
        if (this.isExecute) {
            return new Promise((resolve, reject) => {
                this.once("finish", () => {
                    this.rollback().then(
                        () => resolve(),
                        (err) => reject(err),
                    );
                });
            });
        }
        this.isExecute = true;
        try {
            await this.DataSource.onRollBack(this.connection);
        } finally {
            this.isExecute = false;
            this.isTx = false;
            this.emit("finish");
        }

        return;
    }
    public rollbackAndRelease(): Promise<void> {
        return this.rollback()
            .then(
                () => this.release(),
                () => this.release(),
            )
            .then(
                () => Promise.resolve(),
                () => Promise.resolve(),
            );
    }
    public rollbackAndClose(): Promise<void> {
        return this.rollback()
            .then(
                () => this.close(),
                () => this.close(),
            )
            .then(
                () => Promise.resolve(),
                () => Promise.resolve(),
            );
    }
}

export default Connection;
