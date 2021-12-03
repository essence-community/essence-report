/* eslint-disable max-lines-per-function */
import * as util from "util";
import * as lodash from "lodash";
/* eslint-disable @typescript-eslint/no-use-before-define, no-use-before-define */
import * as esprima from "esprima";
import {
    Expression,
    Property,
    Pattern,
    Super,
    LogicalExpression,
    UnaryExpression,
    Statement,
    Function as IFunction,
    // eslint-disable-next-line import/no-extraneous-dependencies, import/extensions, import/no-unresolved
} from "estree";
import * as QS from "qs";
import * as YAML from "js-yaml";
import Logger from "../Logger";
import { isEmpty } from "../utils/Base";

interface IGetValue {
    get: (key: string) => any;
}

export interface IParseReturnType {
    runer<
        T =
            | Record<string, undefined | string | boolean | number>
            | undefined
            | string
            | boolean
            | number
    >(
        values?: Record<string, any> | IGetValue,
    ): Promise<T>;
    variables: string[];
    hasError: boolean;
}

interface IValues {
    get?($key: string, isEmpty?: boolean): any;
    [$key: string]: any;
}

const logger = Logger.getLogger("parser");

const operators: any = {
    "!": async ({ argument }: UnaryExpression, values: IValues) =>
        !(await parseOperations(argument, values)),
    "!=": async ({ left, right }: LogicalExpression, values: IValues) =>
        // eslint-disable-next-line eqeqeq
        (await parseOperations(left, values)) !=
        (await parseOperations(right, values)),
    "!==": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) !==
        (await parseOperations(right, values)),
    "&&": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) &&
        (await parseOperations(right, values)),
    "+": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) +
        (await parseOperations(right, values)),
    "<": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) <
        (await parseOperations(right, values)),
    "==": async ({ left, right }: LogicalExpression, values: IValues) =>
        // eslint-disable-next-line eqeqeq
        (await parseOperations(left, values)) ==
        (await parseOperations(right, values)),
    "===": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) ===
        (await parseOperations(right, values)),
    ">": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) >
        (await parseOperations(right, values)),
    in: async ({ left, right }: LogicalExpression, values: IValues) => {
        let value = await parseOperations(right, values);

        if (
            typeof value === "string" &&
            value.startsWith("[") &&
            value.endsWith("]")
        ) {
            try {
                value = JSON.parse(value);
            } catch (err) {
                logger.warn("Parsed error %s", value, err);
            }
        }

        return (
            (Array.isArray(value) ? value : [value]).indexOf(
                await parseOperations(left, values),
            ) !== -1
        );
    },
    "||": async ({ left, right }: LogicalExpression, values: IValues) =>
        (await parseOperations(left, values)) ||
        (await parseOperations(right, values)),
};

const utils = {
    JSON,
    QS,
    YAML,
    isEmpty,
    lodash,
    util,
    Object,
    Array,
    encodeURIComponent,
    decodeURIComponent,
};

async function parseOperations(
    expression: Expression | Pattern | Super | IFunction | Statement | any,
    values: IValues,
): Promise<any> {
    if (!expression) {
        return null;
    }
    switch (expression.type) {
        case "UnaryExpression":
        case "BinaryExpression":
        case "LogicalExpression":
            return operators[expression.operator]
                ? await operators[expression.operator](expression, values)
                : false;
        case "SequenceExpression":
            return Promise.all(
                expression.expressions.map((exp: Expression) =>
                    parseOperations(exp, values),
                ),
            );
        case "Literal":
            // @ts-ignore
            if (expression.isMember) {
                return (
                    (values.get
                        ? // @ts-ignore
                          values.get(expression.value, true)
                        : // @ts-ignore
                          values[expression.value]) || expression.value
                );
            }

            return expression.value;
        case "Identifier":
            // @ts-ignore
            if (!expression.isMember && expression.name === "undefined") {
                return undefined;
            }
            // @ts-ignore
            if (!expression.isMember && expression.name === "null") {
                return null;
            }
            // @ts-ignore
            if (!expression.isMember && expression.name === "true") {
                return true;
            }
            // @ts-ignore
            if (!expression.isMember && expression.name === "false") {
                return false;
            }

            return (
                (values.get
                    ? values.get(expression.name, true)
                    : values[expression.name]) ||
                // @ts-ignore
                (expression.isMember && expression.name)
            );
        case "AssignmentExpression":
            return await parseOperations(expression.right, values);
        case "ObjectExpression":
            return await expression.properties.reduce(
                (accProm: Promise<IValues>, prop: Property) =>
                    accProm.then(async (acc: IValues) => {
                        // @ts-ignore
                        prop.key.isMember = true;
                        acc[
                            await parseOperations(prop.key, values)
                        ] = await parseOperations(prop.value, values);

                        return acc;
                    }),
                Promise.resolve({}),
            );
        case "ArrayExpression":
            return await Promise.all(
                expression.elements.map((element: any) =>
                    parseOperations(element, values),
                ),
            );
        case "ConditionalExpression":
            return (await parseOperations(expression.test, values))
                ? await parseOperations(expression.consequent, values)
                : await parseOperations(expression.alternate, values);
        case "MemberExpression":
            if (expression.property.type === "Literal") {
                // @ts-ignore
                expression.property.isMember = true;
            }

            let res = await parseOperations(expression.object, values);

            if (
                typeof res === "string" &&
                (res.charAt(0) === "{" || res.charAt(0) === "[")
            ) {
                try {
                    res = JSON.parse(res);
                } catch (e) {
                    logger.info(e);
                }
            }
            if (
                (expression.object.type === "ObjectExpression" ||
                    expression.object.type === "ArrayExpression" ||
                    expression.object.type === "Identifier") &&
                expression.property.type === "Identifier"
            ) {
                expression.property.name =
                    (values.get
                        ? values.get(expression.property.name, true)
                        : values[expression.property.name]) ||
                    expression.property.name;
            }
            const property = await parseOperations(
                expression.property,
                res
                    ? {
                          get: (key) => {
                              if (
                                  Array.isArray(res) ||
                                  typeof res === "object" ||
                                  typeof res === "function"
                              ) {
                                  const result =
                                      res[key] ||
                                      (values.get
                                          ? values.get(key, true)
                                          : values[key]);

                                  if (typeof result === "function") {
                                      result.parentFn = res;
                                  }

                                  return result;
                              }

                              return values.get
                                  ? values.get(key, true)
                                  : values[key];
                          },
                      }
                    : values,
            );

            return res &&
                (expression.object.type === "ObjectExpression" ||
                    expression.object.type === "ArrayExpression")
                ? res[property] || property
                : property;
        case "TemplateLiteral":
            return expression.expressions
                ? await expression.expressions.reduce(
                      (accProm, expr, index) =>
                          accProm.then(
                              async (acc) =>
                                  `${acc}${await parseOperations(
                                      expr,
                                      values,
                                  )}${expression.quasis[index + 1].value.raw}`,
                          ),
                      Promise.resolve(expression.quasis[0].value.raw),
                  )
                : "";
        case "CallExpression":
            const fn = await parseOperations(expression.callee, {
                get: (key) => {
                    return (
                        utils[key] ||
                        (values.get ? values.get(key, true) : values[key])
                    );
                },
            });

            return typeof fn === "function"
                ? await fn.apply(
                      fn.parentFn || fn,
                      await Promise.all(
                          expression.arguments.map((arg) =>
                              // @ts-ignore
                              parseOperations(arg, values),
                          ),
                      ),
                  )
                : "";
        case "ArrowFunctionExpression":
            return async (...ags) =>
                await parseOperations(expression.body, {
                    get: (key) => {
                        const resArrow = ags.reduce((resParam, val, ind) => {
                            // @ts-ignore
                            resParam[expression.params[ind]?.name] = val;

                            return resParam;
                        }, {});

                        if (Object.keys(resArrow).length) {
                            return (
                                resArrow[key] ||
                                (values.get
                                    ? values.get(key, true)
                                    : values[key])
                            );
                        }

                        return values.get ? values.get(key, true) : values[key];
                    },
                });
        default:
            logger.error("expression not found: ", expression);

            return undefined;
    }
}

export const parse = (src: string, withTokens = false): IParseReturnType => {
    let parsedSrc: esprima.Program | null = null;

    try {
        parsedSrc = esprima.parseScript(`result = ${src}`, {
            tokens: withTokens,
        });
    } catch (error) {
        logger.error(error.message, error);

        throw error;
    }

    return {
        hasError: false,
        runer: async (values: IValues = {}) => {
            const expression = parsedSrc
                ? (parsedSrc.body[0] as any).expression
                : undefined;

            return expression ? parseOperations(expression, values) : "";
        },
        variables:
            withTokens && parsedSrc && parsedSrc.tokens
                ? parsedSrc.tokens
                      .filter(
                          (token: esprima.Token) =>
                              token.type === "Identifier" &&
                              token.value !== "result",
                      )
                      .map((token: esprima.Token) => token.value)
                      .filter(
                          (value: string, idx: number, arr: string[]) =>
                              arr.indexOf(value) === idx,
                      )
                : [],
    };
};
