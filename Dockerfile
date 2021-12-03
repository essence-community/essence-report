FROM pandoc/core:2.13 as pandoc

FROM node:14 as builder

COPY . /opt/report_server

ARG INCLUDE_PLUGINS=
ARG EXCLUDE_PLUGINS=
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV CHROME_BIN /usr/bin/chromium-browser

RUN printenv

RUN cd /opt/report_server && \
    find . -type d -name node_modules -exec rm -rf {} \; 2>/dev/null; \
    yarn install --force && \
    yarn build && \
    cd /opt/report_server/dist && \
    yarn install --force

FROM node:14-alpine3.13

ARG UID=1001
ARG GID=1001

COPY --from=pandoc \
  /usr/local/bin/pandoc \
  /usr/local/bin/pandoc-citeproc \
  /usr/local/bin/

ENV ESSENCE_PANDOC_EXEC /usr/local/bin/pandoc
COPY --from=builder /opt/report_server/dist /opt/report_server
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD true
ENV CHROME_BIN /usr/bin/chromium-browser

RUN adduser -u $UID -g $GID -s /bin/bash --disabled-password jreport; \
    apk upgrade --update-cache; \
    apk add --no-cache \
        tzdata \
        bash \
        font-misc-cyrillic \
        font-screen-cyrillic \
        chromium \
        ttf-freefont \
        ca-certificates \
        gmp \
        libffi \
        lua5.3 \
        lua5.3-lpeg; \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone; \
    rm -rf /tmp/* /var/cache/apk/*; \
    chown -R $UID:$GID /opt/report_server

ENV TZ=Europe/Moscow
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

USER $UID

CMD bash -c 'while !</dev/tcp/${DB_HOST:=postgres}/${DB_PORT:=5432}; do sleep 1; done;' && \
    cd /opt/report_server && \
    yarn start