# erpnext-web
FROM debian:buster-slim as frappe-base
RUN set -ex; \
    useradd -ms /bin/bash frappe; \
    # # cn mirrors
    # sed -i "s@http://.*.debian.org@http://mirrors.cloud.tencent.com@g" /etc/apt/sources.list; \
    # # https://askubuntu.com/questions/875213/apt-get-to-retry-downloading
    # printf '%s\n' 'APT::Acquire::Retries "100";' 'Acquire::http::Proxy "false";' > /etc/apt/apt.conf.d/80-retries; \
    apt-get update && apt-get install -y \
        # for translate support
        gettext-base \
        # for database support
        mariadb-client \
        # for PDF support
        libjpeg62-turbo \
        libx11-6 \
        libxcb1 \
        libxext6 \
        libxrender1 \
        libssl-dev \
        fonts-cantarell \
        xfonts-75dpi \
        xfonts-base \
        # # postgresql support
        # postgresql-client \
        # libpq-dev \
        #
        # for bench
        git \
        python3 \
        python3-pip \
        # utils for docker entrypoint script
        rsync \
        # for temporary use
        curl \
        ;\
    # install bench
    # pip3 install -i https://mirrors.cloud.tencent.com/pypi/simple frappe-bench; \
    pip3 install frappe-bench; \
    curl -LO https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.buster_amd64.deb; \
    dpkg -i wkhtmltox_0.12.5-1.buster_amd64.deb && rm wkhtmltox_0.12.5-1.buster_amd64.deb; \
    # clear cache
    apt-get purge -y curl && apt-get autoremove -y; \
    apt-get clean && rm -rf /var/lib/apt/lists/*;


FROM frappe-base as frappe-app-builder
ARG VERSION=12
ARG BRANCH=version-${VERSION}
ARG APPS="erpnext https://gitee.com/petel_zhang/EBCLocal"
RUN set -ex; \
    # for yarn
    apt-get update && apt-get install -y \
        gnupg2 \
        curl \
        cron \
        nodejs \
        redis-server \
        sudo \
        ; \
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add -; \
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list; \
    # install dev dependence
    apt-get update && apt-get install -y yarn ; \
    usermod -aG sudo frappe && sed -i /etc/sudoers -re 's/^%sudo.*/%sudo    ALL=(ALL:ALL) NOPASSWD: ALL/g';
WORKDIR /home/frappe
USER frappe
RUN set -ex; \
    # pip3 config set global.index-url https://mirrors.cloud.tencent.com/pypi/simple; \
    bench init --frappe-branch $BRANCH frappe-bench; \
    cd frappe-bench; \
    # get apps
    for app in $APPS; do bench get-app --branch $BRANCH $app; done; \
    # clean node_modules
    for app in $(ls apps); do \
        cd apps/$app; \
        yarn install --production --ignore-scripts --prefer-offline; \
        cd ../../; \
    done; \
    find apps -name '.git*' -print -exec rm -rf '{}' +; \
    rm -f sites/common_site_config.json;


# erpnext
FROM frappe-base as erpnext
ENV FRAPPE_BENCH_DIR="/home/frappe/frappe-bench"
ENV WEBSERVER_PORT=8000
ENV AUTO_MIGRATE=false
ENV DB_TYPE=mariadb
ENV MAX_WAIT_SECONDS=360
COPY --from=frappe-app-builder --chown=frappe:frappe ${FRAPPE_BENCH_DIR} ${FRAPPE_BENCH_DIR}
COPY ./erpnext/ /
# then backup for volume mount
RUN set -ex; \
    chown --from=root:root -R frappe:frappe "/home/frappe"; \
    su frappe --command "rsync -a \
        ${FRAPPE_BENCH_DIR}/sites/ ${FRAPPE_BENCH_DIR}/sites.original"; \
    rm -rf ${FRAPPE_BENCH_DIR}/sites/;
WORKDIR ${FRAPPE_BENCH_DIR}/sites
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["serve"]


# socketio
FROM node:lts-buster-slim AS erpnext-socketio
ENV FRAPPE_BENCH_DIR="/home/frappe/frappe-bench"
COPY ./socketio/ /
RUN set -ex; \
    useradd -ms /bin/bash frappe; \
    chown --from=root:root -R frappe:frappe "/home/frappe"; \
    cd $FRAPPE_BENCH_DIR/apps/frappe; \
    su frappe --command "npm install --only=production; npm cache clean --force";
COPY --from=frappe-app-builder --chown=frappe:frappe ${FRAPPE_BENCH_DIR}/apps/frappe/*.js $FRAPPE_BENCH_DIR/apps/frappe/
WORKDIR ${FRAPPE_BENCH_DIR}/sites
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]


# erpnext-nginx
FROM nginx:1.19 as erpnext-nginx
ENV MAX_WAIT_SECONDS=360
COPY --from=frappe-base /usr/local/lib/python3.7/dist-packages/bench/config/templates /etc/nginx/bench_templates
COPY ./nginx/ /
