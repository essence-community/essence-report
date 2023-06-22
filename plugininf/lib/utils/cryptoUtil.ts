/* eslint-disable @typescript-eslint/explicit-module-boundary-types */
import * as crypto from "crypto";

const DEFAULT_ALGORITHM = {
    /**
     * GCM is an authenticated encryption mode that
     * not only provides confidentiality but also
     * provides integrity in a secured way
     * */
    BLOCK_CIPHER: "aes-256-gcm" as crypto.CipherGCMTypes,

    /**
     * 128 bit auth tag is recommended for GCM
     */
    AUTH_TAG_BYTE_LEN: 16,

    /**
     * NIST recommends 96 bits or 12 bytes IV for GCM
     * to promote interoperability, efficiency, and
     * simplicity of design
     */
    IV_BYTE_LEN: 12,

    /**
     * Note: 256 (in algorithm name) is key size.
     * Block size for AES is always 128
     */
    KEY_BYTE_LEN: 32,

    /**
     * To prevent rainbow table attacks
     * */
    SALT_BYTE_LEN: 16,
};

const ALGORITHM = {
    "aes-128-gcm": {
        AUTH_TAG_BYTE_LEN: 16,
        IV_BYTE_LEN: 12,
        KEY_BYTE_LEN: 16,
        SALT_BYTE_LEN: 16,
    },
    "aes-192-gcm": {
        AUTH_TAG_BYTE_LEN: 16,
        IV_BYTE_LEN: 12,
        KEY_BYTE_LEN: 24,
        SALT_BYTE_LEN: 16,
    },
    "aes-256-gcm": {
        AUTH_TAG_BYTE_LEN: 16,
        IV_BYTE_LEN: 16,
        KEY_BYTE_LEN: 32,
        SALT_BYTE_LEN: 16,
    },
    "aes-128-ccm": {
        AUTH_TAG_BYTE_LEN: 16,
        IV_BYTE_LEN: 12,
        KEY_BYTE_LEN: 16,
        SALT_BYTE_LEN: 16,
    },
    "aes-192-ccm": {
        AUTH_TAG_BYTE_LEN: 16,
        IV_BYTE_LEN: 12,
        KEY_BYTE_LEN: 24,
        SALT_BYTE_LEN: 16,
    },
    "aes-256-ccm": {
        AUTH_TAG_BYTE_LEN: 16,
        IV_BYTE_LEN: 12,
        KEY_BYTE_LEN: 32,
        SALT_BYTE_LEN: 16,
    },
};

const getIV = (type: crypto.CipherCCMTypes | crypto.CipherGCMTypes) =>
    crypto.randomBytes((ALGORITHM[type] || DEFAULT_ALGORITHM).IV_BYTE_LEN);

export const getRandomKey = (
    type: crypto.CipherCCMTypes | crypto.CipherGCMTypes,
) => crypto.randomBytes((ALGORITHM[type] || DEFAULT_ALGORITHM).KEY_BYTE_LEN);
export const getSalt = (type: crypto.CipherCCMTypes | crypto.CipherGCMTypes) =>
    crypto.randomBytes((ALGORITHM[type] || DEFAULT_ALGORITHM).SALT_BYTE_LEN);

/**
 *
 * @param {Buffer} password - The password to be used for generating key
 *
 */
export const getKeyFromPassword = (
    type: crypto.CipherCCMTypes | crypto.CipherGCMTypes,
    password: string,
    salt: string,
) => {
    return crypto.scryptSync(
        password,
        salt,
        (ALGORITHM[type] || DEFAULT_ALGORITHM).KEY_BYTE_LEN,
    );
};

/**
 *
 * @param {Buffer} messagetext - The clear text message to be encrypted
 * @param {Buffer} key - The key to be used for encryption
 */
export const encrypt = (
    type: crypto.CipherCCMTypes | crypto.CipherGCMTypes,
    messagetext: string,
    key: Buffer,
) => {
    const iv = getIV(type);
    const cipher = crypto.createCipheriv(
        (type as any) || DEFAULT_ALGORITHM.BLOCK_CIPHER,
        key,
        iv,
        {
            authTagLength: (ALGORITHM[type] || DEFAULT_ALGORITHM)
                .AUTH_TAG_BYTE_LEN,
        },
    );
    let encryptedMessage = cipher.update(messagetext);

    encryptedMessage = Buffer.concat([encryptedMessage, cipher.final()]);

    return Buffer.concat([cipher.getAuthTag(), encryptedMessage, iv]).toString(
        "hex",
    );
};

/**
 *
 * @param {Buffer} ciphertext - Cipher text
 * @param {Buffer} key - The key to be used for decryption
 *
 */
export const decrypt = (
    type: crypto.CipherCCMTypes | crypto.CipherGCMTypes,
    text: string,
    key: Buffer,
) => {
    const ciphertext = Buffer.from(text, "hex");
    const authTag = ciphertext.slice(
        0,
        (ALGORITHM[type] || DEFAULT_ALGORITHM).AUTH_TAG_BYTE_LEN,
    );
    const iv = ciphertext.slice(
        -(ALGORITHM[type] || DEFAULT_ALGORITHM).IV_BYTE_LEN,
    );
    const encryptedMessage = ciphertext.slice(
        (ALGORITHM[type] || DEFAULT_ALGORITHM).AUTH_TAG_BYTE_LEN,
        -(ALGORITHM[type] || DEFAULT_ALGORITHM).IV_BYTE_LEN,
    );
    const decipher = crypto.createDecipheriv(
        (type as any) || DEFAULT_ALGORITHM.BLOCK_CIPHER,
        key,
        iv,
        {
            authTagLength: (ALGORITHM[type] || DEFAULT_ALGORITHM)
                .AUTH_TAG_BYTE_LEN,
        },
    );

    decipher.setAuthTag(authTag);
    let messagetext = decipher.update(encryptedMessage);

    messagetext = Buffer.concat([messagetext, decipher.final()]);

    return messagetext.toString();
};
