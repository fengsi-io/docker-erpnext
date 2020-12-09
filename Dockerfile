FROM debian:buster-slim AS base
RUN set -ex; \
    groupadd --gid 1000 frappe; \
    useradd --uid 1000 --gid frappe --shell /bin/bash --create-home frappe; \
    if [ ! -z ${http_proxy+x} ]; then \
        sed -i "s@http://.*.debian.org@http://mirrors.aliyun.com@g" /etc/apt/sources.list; \
    fi; \
    # install python
    apt-get update && apt-get install -y \
        python3 \
        python3-pip \
        ; \
    apt-get clean && rm -rf /var/lib/apt/lists/*; \
    # install bench
    if [ ! -z ${http_proxy+x} ]; then \
        pip3 config --global set global.index-url https://mirrors.aliyun.com/pypi/simple; \
    fi; \
    pip3 install --quiet --no-cache-dir frappe-bench;


#
# installer
# default apps:
# 1. erpnext
# 2. EBCLocal
#
FROM base as installer
ARG VERSION=12
ARG APPS="erpnext \
    # https://gitee.com/petel_zhang/EBCLocal \
    "
RUN set -ex; \
    # for bench init dependence
    apt-get update && apt-get install -y \
        git \
        python3-venv \
        yarnpkg \
        cron \
        ; \
    ln -s $(which yarnpkg) /usr/local/bin/yarn; \
    apt-get clean && rm -rf /var/lib/apt/lists/*;
USER frappe
WORKDIR /home/frappe
RUN set -ex; \
    bench init --frappe-branch "version-${VERSION}" --no-procfile --skip-redis-config-generation frappe-bench;\
    # install apps
    cd frappe-bench && for app in $APPS; do \
        bench get-app --branch "version-${VERSION}" $app; \
    done; \
    # cleanup
    . $HOME/frappe-bench/env/bin/activate && pip cache purge; \
    apps=$(ls apps); for app in $apps; do \
        yarn --cwd ./apps/$app install --quiet --production --ignore-scripts --prefer-offline; \
    done;


# socketio
FROM node:14-buster-slim AS frappe-socketio
ENV FRAPPE_BENCH_DIR="/home/frappe/frappe-bench"
COPY --from=installer $FRAPPE_BENCH_DIR/apps/frappe/*.js $FRAPPE_BENCH_DIR/apps/frappe/
RUN set -ex; \
    if [ ! -z ${http_proxy+x} ]; then \
        npm config set registry https://registry.npm.taobao.org; \
    fi; \
    cd $FRAPPE_BENCH_DIR/apps/frappe/ && npm init -y --silent; \
    npm install --silent --production --cwd $FRAPPE_BENCH_DIR/apps/frappe \
        express@^4.17.1 \
        redis@^2.8.0 \
        socket.io@^2.3.0 \
        superagent@^5.1.0 \
        ;
COPY ./socketio/ /
WORKDIR ${FRAPPE_BENCH_DIR}
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]


# erpnext-nginx
FROM nginx:1.19 as frappe-nginx
ENV MAX_WAIT_SECONDS=360
COPY --from=installer /usr/local/lib/python3.7/dist-packages/bench/config/templates /etc/nginx/bench_templates
COPY ./nginx/ /


#
# base runtime package and libs
#
FROM base as erpnext
ENV FRAPPE_BENCH_DIR="/home/frappe/frappe-bench"
COPY --from=installer --chown=frappe:frappe /home/frappe /home/frappe
RUN set -ex; \
    apt-get update; \
    # install wkhtmltopdf and fonts
    apt-get install -y curl; \
    curl -LO https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb; \
    apt-get install -y fonts-noto fonts-noto-extra fonts-noto-color-emoji fonts-noto-cjk ./*.deb && rm ./*.deb; \
    apt-get purge -y curl; \
    # for envsubst
    apt-get install -y mariadb-client gettext; \
    su frappe --command "\
        rm -rf $FRAPPE_BENCH_DIR/sites/common_site_config.json; \
        cp -LR $FRAPPE_BENCH_DIR/sites $FRAPPE_BENCH_DIR/sites.origin; \
        rm -rf $FRAPPE_BENCH_DIR/sites; \
    "; \
    # final clean
    apt-get autoremove -y; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*;
COPY ./erpnext/ /
WORKDIR ${FRAPPE_BENCH_DIR}/sites
ENV WEBSERVER_PORT=8000
ENV AUTO_MIGRATE=false
ENV DB_TYPE=mariadb
ENV MAX_WAIT_SECONDS=360
ENV GIT_PYTHON_REFRESH=quiet
ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["serve"]
