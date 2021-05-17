import * as path from "path";
import * as os from "os";

export const PLUGIN_DIR =
    process.env.ESSENCE_REPORT_PLUGIN_DIR || path.resolve(__dirname, "..", "plugins");
export const AUTH_PLUGIN_DIR =
    process.env.ESSENCE_REPORT_AUTH_PLUGIN_DIR || path.resolve(PLUGIN_DIR, "auth");
export const SOURCE_PLUGIN_DIR =
    process.env.ESSENCE_REPORT_SOURCE_PLUGIN_DIR || path.resolve(PLUGIN_DIR, "source");
export const FORMAT_PLUGIN_DIR =
    process.env.ESSENCE_REPORT_FORMAT_PLUGIN_DIR || path.resolve(PLUGIN_DIR, "format");
export const DISABLED_TASK_SERVICE =
    process.env.ESSENCE_REPORT_DISABLED_TASK_SERVICE || "false";
export const CLUSTER_NUM: number = process.env.ESSENCE_REPORT_CLUSTER_NUM
    ? parseInt(process.env.ESSENCE_REPORT_CLUSTER_NUM, 10)
    : os.cpus().length;
export const TMP_DIR = process.env.ESSENCE_REPORT_TMP_DIR || os.tmpdir();
