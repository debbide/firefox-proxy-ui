ARG BASE_IMAGE=ghcr.io/eooce/firefox:latest@sha256:07c4aa7314a1f155085aea45030c0838d02a47c879fabd0a59abd44178845d19
FROM ${BASE_IMAGE}

USER root

RUN apk add --no-cache \
        bash \
        python3 \
        py3-pip \
        nodejs \
        npm \
        curl \
        ca-certificates \
        tar

RUN set -eux; \
    version="$(python3 -c "import json,urllib.request;data=json.load(urllib.request.urlopen('https://api.github.com/repos/SagerNet/sing-box/releases/latest'));print((data.get('tag_name') or '').lstrip('v'))")"; \
    arch="$(uname -m)"; \
    case "$arch" in \
        x86_64|amd64) arch="amd64" ;; \
        aarch64|arm64) arch="arm64" ;; \
        *) echo "Unsupported arch: $arch"; exit 1 ;; \
    esac; \
    url="https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-${arch}-musl.tar.gz"; \
    curl -fsSL "$url" -o /tmp/sing-box.tgz; \
    tar -xzf /tmp/sing-box.tgz -C /tmp; \
    install -m 755 /tmp/sing-box-${version}-linux-${arch}-musl/sing-box /usr/local/bin/sing-box; \
    rm -rf /tmp/sing-box.tgz /tmp/sing-box-${version}-linux-${arch}-musl

WORKDIR /app

COPY app.py /app/app.py
COPY main.py /app/main.py
COPY requirements.txt /app/requirements.txt
COPY package.json /app/package.json
COPY base-start.sh /app/base-start.sh
COPY proxy /app/proxy
COPY templates /app/templates

RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir -r /app/requirements.txt \
    && npm install --omit=dev

ENV PATH="/opt/venv/bin:$PATH"

RUN chmod -R a+rX /opt/venv

RUN mkdir -p /app/data \
    && chown -R vncuser:vncuser /app

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh /app/base-start.sh

ENV DATA_DIR=/app/data \
    PROXY_LISTEN=127.0.0.1 \
    PROXY_BASE_PORT=20000 \
    FIREFOX_PROXY_HOST=127.0.0.1 \
    FIREFOX_PROXY_PORT=20000

EXPOSE 5000

USER vncuser

ENTRYPOINT ["/app/start.sh"]
