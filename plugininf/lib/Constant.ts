import * as fs from "fs";
import { scryptSync } from "crypto";

export class BuildConstant {
    /** Время загрузки приложения */
    public APP_START_TIME = new Date().getTime();
    /**
     * Формат даты по умолчанию
     */
    public JSON_DATE_FORMAT = "YYYY-MM-DDTHH:mm:ss";
    /** Префикс сессионного параметра */
    public SESSION_PARAM_PREFIX = "sess_";
    /** Префикс для выходного параметра (не входит в имя параметра запроса к БД) */
    public OUT_PARAM_PREFIX = "out_";
    /** Префикс для параметра с типом дата (входит в имя параметра запроса к БД) */
    public DATE_PARAM_PREFIX: ["dt_", "cd_", "ct_"];
    /** Рандомная соль */
    public HASH_SALT = "";
    /** Наименование запроса получения сессии */
    public QUERY_GETSESSIONDATA = "getsessiondata";
    /** Сервис выхода */
    public QUERY_LOGOUT = "logout";

    /** Секрет для подписи сессии */
    public SESSION_SECRET =
        process.env.SESSION_SECRET ||
        "9cb564113f96325c37b9e43280eebfb6723176b65db38627c85f763d32c20fa8";

    /** PW для шифрования пароля */
    public PW_KEY_SECRET: string;
    /** SALT для шифрования пароля */
    public PW_SALT_SECRET: string =
        process.env.ESSSENCE_PW_SALT ||
        "bf359e3e7beb05473be3b0acb8e36adb597b9e34";
    /** PW для шифрования пароля */
    public PW_IV_SECRET = Buffer.from(
        process.env.ESSSENCE_PW_IV ||
            "a290e34766b2afdca71948366cf73154eaaf880f141393c1d38542cb36a0370b",
        "hex",
    );

    public DEFAULT_ALG = process.env.ESSENCE_PW_DEFAULT_ALG || "aes-256-cbc";

    /** PW Key RSA для шифрования пароля */
    public PW_RSA_SECRET: string;
    public PW_RSA_SECRET_PASSPHRASE: string;

    public isUseEncrypt = false;

    // eslint-disable-next-line max-statements
    constructor() {
        let isUseEncrypt = false;

        if (process.env.ESSSENCE_PW_KEY_SECRET) {
            if (fs.existsSync(process.env.ESSSENCE_PW_KEY_SECRET)) {
                this.PW_KEY_SECRET = fs
                    .readFileSync(process.env.ESSSENCE_PW_KEY_SECRET)
                    .toString();
            } else {
                this.PW_KEY_SECRET = process.env.ESSSENCE_PW_KEY_SECRET;
            }
            if (process.env.ESSSENCE_PW_SALT) {
                if (fs.existsSync(process.env.ESSSENCE_PW_SALT)) {
                    this.PW_SALT_SECRET = fs
                        .readFileSync(process.env.ESSSENCE_PW_SALT)
                        .toString();
                } else {
                    this.PW_SALT_SECRET = process.env.ESSSENCE_PW_SALT;
                }
            }
            if (this.PW_IV_SECRET.length > 16) {
                this.PW_IV_SECRET = this.PW_IV_SECRET.slice(0, 16);
            } else if (this.PW_IV_SECRET.length < 16) {
                this.PW_IV_SECRET = scryptSync(
                    this.PW_IV_SECRET,
                    this.PW_SALT_SECRET,
                    16,
                );
            }
            isUseEncrypt = true;
        }
        if (process.env.ESSSENCE_PW_RSA) {
            if (fs.existsSync(process.env.ESSSENCE_PW_RSA)) {
                this.PW_RSA_SECRET = fs
                    .readFileSync(process.env.ESSSENCE_PW_RSA)
                    .toString();
            } else {
                this.PW_RSA_SECRET = process.env.ESSSENCE_PW_RSA;
            }
            if (process.env.ESSSENCE_PW_RSA_PASSPHRASE) {
                if (fs.existsSync(process.env.ESSSENCE_PW_RSA_PASSPHRASE)) {
                    this.PW_RSA_SECRET_PASSPHRASE = fs
                        .readFileSync(process.env.ESSSENCE_PW_RSA_PASSPHRASE)
                        .toString();
                } else {
                    this.PW_RSA_SECRET_PASSPHRASE =
                        process.env.ESSSENCE_PW_RSA_PASSPHRASE;
                }
            }
            isUseEncrypt = true;
        }
        if (!process.env.ESSENCE_PW_DEFAULT_ALG) {
            if (this.PW_RSA_SECRET) {
                this.DEFAULT_ALG = "privatekey";
            } else {
                this.DEFAULT_ALG = "aes-256-cbc";
            }
        }
        this.isUseEncrypt = isUseEncrypt;
    }
}
export const Constant = new BuildConstant();
export default Constant;
