# 构建阶段
FROM node:18-alpine AS builder

# 安装解压工具并解压安装包
RUN apk add --no-cache unzip
COPY ohpm-repo-5.4.4.0.zip /tmp/
RUN unzip -q /tmp/ohpm-repo-5.4.4.0.zip -d /tmp/ohpm-repo && \
    rm /tmp/ohpm-repo-5.4.4.0.zip

# 运行阶段
FROM alpine:3.19

# 安装运行时依赖、创建 node 用户
RUN apk add --no-cache nodejs npm su-exec && \
    addgroup -g 1000 node && \
    adduser -D -u 1000 -G node node

# 复制文件并设置权限
COPY --from=builder /tmp/ohpm-repo /opt/ohpm-repo/
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 设置环境变量
ENV PATH="/opt/ohpm-repo/bin:${PATH}"

# 暴露端口
EXPOSE 8088

# 以 root 启动，entrypoint 中切换到 node 用户
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
