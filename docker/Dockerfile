# dsh 宿主 0.2.0-rc.2 + dsh-purge 1.1.71
# 0.2.0-rc.2 构建于 Node 24.21.0，且 0.2.2 线要求 node >= 24.9.0，因此基础镜像固定 node:24
# 直连 Docker Hub 不通时走国内镜像源；换源只需覆盖 NODE_IMAGE 构建参数
ARG NODE_IMAGE=docker.m.daocloud.io/library/node:24-bookworm-slim
FROM ${NODE_IMAGE}

ARG DSH_VERSION=0.2.0-rc.2
ARG PURGE_VERSION=1.1.71

# socat 用于中继：dsh 官方只监听容器内 127.0.0.1:3080，
# Docker 端口发布直达容器网卡，loopback 监听收不到外网映射，必须中转一层
# Debian 默认源 deb.debian.org 在境外，国内拉 Packages 索引会卡几分钟到十几分钟，换阿里云镜像
ARG APT_MIRROR=mirrors.aliyun.com
RUN set -eux; \
    for f in /etc/apt/sources.list /etc/apt/sources.list.d/debian.sources; do \
      if [ -f "$f" ]; then \
        sed -i -e "s|deb.debian.org|${APT_MIRROR}|g" \
               -e "s|security.debian.org/debian-security|${APT_MIRROR}/debian-security|g" "$f"; \
      fi; \
    done; \
    apt-get update && apt-get install -y --no-install-recommends \
      socat ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 公司网络/国内链路下 npmjs.org 常被限速，默认走 npmmirror，可用 NPM_REGISTRY 覆盖
ARG NPM_REGISTRY=https://registry.npmmirror.com
RUN npm i -g "@deepseek-ai/dsh@${DSH_VERSION}" --registry="${NPM_REGISTRY}"

# dsh 的插件管理是 pnpm 语义（dsh plugin --profile <name> <pnpm-args>），镜像内必须先有 pnpm
RUN npm i -g pnpm@10 --registry="${NPM_REGISTRY}"

WORKDIR /opt/dsh-purge
COPY . /opt/dsh-purge

# 构建期断言插件版本，防止源码漂移成非 1.1.71
RUN node -e "const p=require('/opt/dsh-purge/package.json'); \
    if (p.version !== '${PURGE_VERSION}') { \
      console.error('purge version mismatch: ' + p.version + ' != ${PURGE_VERSION}'); \
      process.exit(1); \
    }"

COPY docker/dsh-entrypoint.sh /usr/local/bin/dsh-entrypoint.sh
# Windows 检出可能带 CRLF，会让 shebang 失效，这里统一换行并赋执行权限
RUN sed -i 's/\r$//' /usr/local/bin/dsh-entrypoint.sh \
   && chmod +x /usr/local/bin/dsh-entrypoint.sh

VOLUME ["/root/.dsh"]
EXPOSE 3081

ENTRYPOINT ["/usr/local/bin/dsh-entrypoint.sh"]
CMD ["dsh"]
