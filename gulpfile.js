/* eslint-disable max-lines-per-function */
/* eslint-disable quotes */
/* eslint-disable @typescript-eslint/no-var-requires */
const fs = require("fs");
const path = require("path");
const gulp = require("gulp");
const ts = require("gulp-typescript");
const cpy = require("cpy");

const homeDir = __dirname;

function list(val) {
    return val.toUpperCase().split(",");
}
const includePlugins = process.env.INCLUDE_PLUGINS
    ? list(process.env.INCLUDE_PLUGINS)
    : null;
const excludePlugins = process.env.EXCLUDE_PLUGINS
    ? list(process.env.EXCLUDE_PLUGINS)
    : null;

const isDev = process.env.NODE_ENV === "development";

gulp.task("plugins", () => {
    const rows = [];

    fs.readdirSync(path.resolve(homeDir, "plugins")).forEach((dir) => {
        if (fs.statSync(path.resolve(homeDir, "plugins", dir)).isDirectory()) {
            const pluginsDir = path.resolve(homeDir, "plugins", dir);
            const dirPlugins = path.join(homeDir, "dist", "plugins", dir);

            fs.mkdirSync(dirPlugins, { recursive: true });
            fs.readdirSync(pluginsDir)
                .filter((file) => {
                    let res =
                        includePlugins && includePlugins.length ? false : true;

                    if (excludePlugins && excludePlugins.length) {
                        res =
                            excludePlugins.filter(
                                (name) =>
                                    name.trim().toUpperCase() ===
                                    file.trim().toUpperCase(),
                            ).length === 0;
                    }
                    if (includePlugins && includePlugins.length) {
                        res =
                            includePlugins.filter(
                                (name) =>
                                    name.trim().toUpperCase() ===
                                    file.trim().toUpperCase(),
                            ).length > 0;
                    }

                    return res;
                })
                .forEach((file) => {
                    if (
                        fs.existsSync(
                            path.join(pluginsDir, file, "tsconfig.json"),
                        ) &&
                        fs.existsSync(
                            path.join(pluginsDir, file, "package.json"),
                        )
                    ) {
                        const tsProject = ts.createProject(
                            path.join(pluginsDir, file, "tsconfig.json"),
                            {
                                removeComments: !isDev,
                                sourceMap: !isDev,
                            },
                        );

                        rows.push(
                            new Promise((resolve, reject) => {
                                gulp.src(
                                    path.join(
                                        pluginsDir,
                                        file,
                                        "src",
                                        "**",
                                        "*.ts",
                                    ),
                                )
                                    .pipe(tsProject())
                                    .pipe(
                                        gulp.dest(path.join(dirPlugins, file)),
                                    )
                                    .on("end", () => {
                                        const rows = [];

                                        if (
                                            fs.existsSync(
                                                path.join(
                                                    pluginsDir,
                                                    file,
                                                    "assets",
                                                ),
                                            )
                                        ) {
                                            rows.push(
                                                cpy(
                                                    ["**/*.*", "**/*"],
                                                    path.join(
                                                        dirPlugins,
                                                        file,
                                                        "assets",
                                                    ),
                                                    {
                                                        cwd: path.join(
                                                            pluginsDir,
                                                            file,
                                                            "assets",
                                                        ),
                                                        parents: true,
                                                        dot: true,
                                                    },
                                                ),
                                            );
                                        }
                                        rows.push(
                                            new Promise((resolveChild) => {
                                                const packageJson = JSON.parse(
                                                    fs.readFileSync(
                                                        path.join(
                                                            pluginsDir,
                                                            file,
                                                            "package.json",
                                                        ),
                                                    ),
                                                );

                                                delete packageJson.devDependencies;
                                                fs.writeFileSync(
                                                    path.join(
                                                        dirPlugins,
                                                        file,
                                                        "package.json",
                                                    ),
                                                    JSON.stringify(
                                                        packageJson,
                                                        null,
                                                        4,
                                                    ),
                                                );
                                                resolveChild();
                                            }),
                                        );

                                        return Promise.all(rows).then(
                                            () => resolve(),
                                            (err) => reject(err),
                                        );
                                    })
                                    .on("error", (err) => reject(err));
                            }),
                        );
                    } else if (file === "README") {
                        fs.createReadStream(
                            path.resolve(pluginsDir, file),
                        ).pipe(
                            fs.createWriteStream(
                                path.resolve(dirPlugins, file),
                            ),
                        );
                    }
                });
        } else if (dir === "README") {
            fs.mkdirSync(path.resolve(homeDir, "dist", "plugins"), {
                recursive: true,
            });
            fs.createReadStream(path.resolve(homeDir, "plugins", dir)).pipe(
                fs.createWriteStream(
                    path.resolve(homeDir, "dist", "plugins", dir),
                ),
            );
        }
    });

    return Promise.all(rows);
});
gulp.task("server", () => {
    const sourceDir = path.resolve(homeDir, "server", "src");
    const tsProject = ts.createProject(
        path.join(homeDir, "server", "tsconfig.json"),
        {
            removeComments: !isDev,
            sourceMap: !isDev,
        },
    );

    fs.mkdirSync(path.join(homeDir, "dist", "server"), { recursive: true });

    return new Promise((resolve, reject) => {
        gulp.src(path.join(sourceDir, "**", "*.ts"))
            .pipe(tsProject())
            .pipe(gulp.dest(path.join(homeDir, "dist", "server")))
            .on("end", () => {
                const rows = [];

                rows.push(
                    cpy(
                        ["**/*.*", "**/*"],
                        path.join(homeDir, "dist", "server", "spec"),
                        {
                            cwd: path.join(sourceDir, "spec"),
                            parents: true,
                            dot: true,
                        },
                    ),
                );
                rows.push(
                    cpy(
                        ["**/*.*", "**/*"],
                        path.join(homeDir, "dist", "config"),
                        {
                            cwd: path.join(sourceDir, "config"),
                            parents: true,
                            dot: true,
                        },
                    ),
                );
                rows.push(
                    new Promise((resolveChild) => {
                        const packageJson = JSON.parse(
                            fs.readFileSync(
                                path.join(homeDir, "server", "package.json"),
                            ),
                        );

                        delete packageJson.devDependencies;
                        packageJson.scripts = {
                            start: "nodemon cluster.js",
                            "start:single": "nodemon index.js",
                        };
                        packageJson.main = "index.js";
                        packageJson.nodemonConfig = {
                            ignore: ["libs/**", "node_modules/**"],
                            env: {
                                NLS_LANG: "AMERICAN_AMERICA.AL32UTF8",
                                NLS_DATE_FORMAT: "dd.mm.yyyy",
                                NLS_TIMESTAMP_FORMAT: 'dd.mm.yyyy"T"hh:mi:ss',
                            },
                            delay: "10000",
                            watch: false,
                        };
                        fs.writeFileSync(
                            path.join(
                                homeDir,
                                "dist",
                                "server",
                                "package.json",
                            ),
                            JSON.stringify(packageJson, null, 4),
                        );
                        resolveChild();
                    }),
                );

                return Promise.all(rows).then(
                    () => resolve(),
                    (err) => reject(err),
                );
            })
            .on("error", (err) => reject(err));
    });
});

gulp.task("package", () => {
    const packageJson = JSON.parse(
        fs.readFileSync(path.join(homeDir, "package.json")),
    );

    delete packageJson.devDependencies;
    delete packageJson["lint-staged"];
    delete packageJson.husky;
    packageJson.scripts = {
        start: "yarn workspace @essence-report/server run start",
        "start:single":
            "yarn workspace @essence-report/server run start:single",
    };
    fs.writeFileSync(
        path.join(homeDir, "dist", "package.json"),
        JSON.stringify(packageJson, null, 4),
    );
    fs.writeFileSync(
        path.resolve(homeDir, "dist", "yarn.lock"),
        fs.readFileSync(path.resolve(homeDir, "yarn.lock")),
    );

    return Promise.resolve(true);
});
gulp.task("plugininf", () => {
    const rows = [];
    const plugininfDir = path.join(homeDir, "plugininf");

    if (
        fs.existsSync(path.join(plugininfDir, "tsconfig.json")) &&
        fs.existsSync(path.join(plugininfDir, "package.json"))
    ) {
        const tsProject = ts.createProject(
            path.join(plugininfDir, "tsconfig.json"),
            {
                removeComments: !isDev,
                sourceMap: !isDev,
            },
        );

        rows.push(
            new Promise((resolve, reject) => {
                gulp.src(path.join(plugininfDir, "lib", "**", "*.ts"))
                    .pipe(tsProject())
                    .pipe(
                        gulp.dest(
                            path.join(homeDir, "dist", "plugininf", "lib"),
                        ),
                    )
                    .on("end", () => {
                        const pluginInfJson = JSON.parse(
                            fs.readFileSync(
                                path.join(plugininfDir, "package.json"),
                            ),
                        );

                        delete pluginInfJson.devDependencies;
                        fs.writeFileSync(
                            path.join(
                                homeDir,
                                "dist",
                                "plugininf",
                                "package.json",
                            ),
                            JSON.stringify(pluginInfJson, null, 4),
                        );
                        resolve();
                    })
                    .on("error", (err) => reject(err));
            }),
        );
    }

    return Promise.all(rows);
});
gulp.task("all", gulp.series("plugininf", "plugins", "server", "package"));
