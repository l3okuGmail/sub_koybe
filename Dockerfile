FROM alpine

WORKDIR /opt/app

# 安装依赖：nodejs、curl、tzdata、supervisor、unzip
RUN apk add --no-cache nodejs curl tzdata supervisor unzip

# 设置时区
ENV TIME_ZONE=Asia/Shanghai
RUN cp /usr/share/zoneinfo/$TIME_ZONE /etc/localtime && echo $TIME_ZONE > /etc/timezone

# 下载 Sub-Store 后端 bundle
ADD https://github.com/sub-store-org/Sub-Store/releases/latest/download/sub-store.bundle.js /opt/app/sub-store.bundle.js

# 下载并解压 Sub-Store 前端文件
ADD https://github.com/sub-store-org/Sub-Store-Front-End/releases/latest/download/dist.zip /opt/app/dist.zip
RUN unzip dist.zip && mv dist frontend && rm dist.zip

# 下载 http-meta 相关文件
ADD https://github.com/xream/http-meta/releases/latest/download/http-meta.bundle.js /opt/app/http-meta.bundle.js
ADD https://github.com/xream/http-meta/releases/latest/download/tpl.yaml /opt/app/http-meta/tpl.yaml

# 下载 mihomo 二进制文件并解压
RUN version=$(curl -s -L --connect-timeout 5 --max-time 10 --retry 2 --retry-delay 0 --retry-max-time 20 'https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt') && \
    arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64-compatible/) && \
    url="https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/mihomo-linux-$arch-$version.gz" && \
    curl -s -L --connect-timeout 5 --max-time 10 --retry 2 --retry-delay 0 --retry-max-time 20 "$url" -o /opt/app/http-meta/http-meta.gz && \
    gunzip /opt/app/http-meta/http-meta.gz && \
    rm -f /opt/app/http-meta/http-meta.gz

# 修改文件权限，并创建数据目录
RUN chmod 777 -R /opt/app && mkdir -p /opt/app/data

# 创建 supervisord 配置文件，管理 http-meta 和 sub-store 两个进程
RUN echo "[supervisord]
nodaemon=true

[program:http-meta]
command=node /opt/app/http-meta.bundle.js
directory=/opt/app/data
autostart=true
autorestart=true
environment=META_FOLDER=\"/opt/app/http-meta\",HOST=\"0.0.0.0\"

[program:sub-store]
command=node /opt/app/sub-store.bundle.js
directory=/opt/app/data
autostart=true
autorestart=true
environment=SUB_STORE_BACKEND_API_HOST=\"0.0.0.0\",SUB_STORE_FRONTEND_HOST=\"0.0.0.0\",SUB_STORE_FRONTEND_PORT=\"3001\",SUB_STORE_FRONTEND_PATH=\"/opt/app/frontend\",SUB_STORE_DATA_BASE_PATH=\"/opt/app/data\"
" > /etc/supervisord.conf

# 暴露服务端口
EXPOSE 3001

# 使用 supervisord 启动所有服务
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
