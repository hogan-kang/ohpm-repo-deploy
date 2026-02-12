#!/bin/sh
set -e

echo "Starting OHPM Repo Server..."
echo "Version: 5.4.4.0"
echo "Install directory: /opt/ohpm-repo"
echo "Deploy directory: /data/ohpm-repo"

# 以 root 执行：修改 EFS 目录权限
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, adjusting EFS permissions..."
    chown -R node:node /data/ohpm-repo 2>/dev/null || true
    chmod -R 755 /data/ohpm-repo 2>/dev/null || true
    echo "Switching to node user (UID 1000)..."
    exec su-exec node "$0" "$@"
fi

# 进入安装目录（程序文件）
cd /opt/ohpm-repo

# 修改配置文件，设置 deploy_root 和监听地址
if [ -f "conf/config.yaml" ]; then
    echo "Updating config.yaml..."
    sed -i 's|deploy_root:.*|deploy_root: /data/ohpm-repo|' conf/config.yaml
    sed -i 's/listen: localhost:8088/listen: 0.0.0.0:8088/' conf/config.yaml
fi

# 检查是否已初始化
if [ ! -d "/data/ohpm-repo/db" ] || [ ! -d "/data/ohpm-repo/storage" ]; then
    echo "Initializing OHPM repo..."
    ohpm-repo init
fi

# 启动 OHPM repo 服务器
echo "Starting OHPM repo server on port 8088..."
exec ohpm-repo run-server
