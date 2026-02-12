# 构建阶段
FROM node:18-alpine AS builder

# 安装解压工具
RUN apk add --no-cache unzip

# 解压安装包
COPY ohpm-repo-5.4.4.0.zip /tmp/
RUN unzip -q /tmp/ohpm-repo-5.4.4.0.zip -d /tmp/ohpm-repo && \
    rm /tmp/ohpm-repo-5.4.4.0.zip

# 运行阶段 - 使用更小的基础镜像
FROM alpine:3.19

# 安装运行时依赖
RUN apk add --no-cache nodejs npm unzip su-exec

# 创建 node 用户（UID 1000）
RUN addgroup -g 1000 node && \
    adduser -D -u 1000 -G node node

# 复制 OHPM repo 文件
COPY --from=builder /tmp/ohpm-repo /opt/ohpm-repo/

# 复制启动脚本
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# 将 ohpm-repo 添加到系统 PATH
ENV PATH="/opt/ohpm-repo/bin:${PATH}"

# 暴露端口 8088
EXPOSE 8088

# 数据目录（使用 EFS 挂载）
VOLUME ["/data/ohpm-repo"]

# 以 root 启动，在 entrypoint 中切换到 node 用户
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
