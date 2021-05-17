/**
 * Created by artemov_i on 06.12.2018.
 */
declare module "rufus" {
    export const NOTSET: number;
    export const VERBOSE: number;
    export const DEBUG: number;
    export const INFO: number;
    export const WARNING: number;
    export const ERROR: number;
    export const CRITICAL: number;
    export const WARN: number;
    export const TRACE: number;
    export const FATAL: number;
    export class IRufusLogger {
        isEnabledFor(level: number): boolean;
        isDebugEnabled(): boolean;
        isTraceEnabled(): boolean;
        isWarnEnabled(): boolean;
        isInfoEnabled(): boolean;
        setLevel(lvl: string): void;
        addHandler(handle: any): IRufusLogger;
        notset(msg: string): void;
        verbose(msg: string): void;
        debug(msg: string): void;
        info(msg: string): void;
        warning(msg: string): void;
        error(msg: string): void;
        critical(msg: string): void;
        warn(msg: string): void;
        trace(msg: string): void;
        fatal(msg: string): void;
        notset(err: any): void;
        verbose(err: any): void;
        debug(err: any): void;
        info(err: any): void;
        warning(err: any): void;
        error(err: any): void;
        critical(err: any): void;
        warn(err: any): void;
        trace(err: any): void;
        fatal(err: any): void;
        notset(msg: string, ...args): void;
        verbose(msg: string, ...args): void;
        debug(msg: string, ...args): void;
        info(msg: string, ...args): void;
        warning(msg: string, ...args): void;
        error(msg: string, ...args): void;
        critical(msg: string, ...args): void;
        warn(msg: string, ...args): void;
        trace(msg: string, ...args): void;
        fatal(msg: string, ...args): void;
    }
    export function getLogger(name: string): IRufusLogger;
    export function config(obj: any): void;
}
