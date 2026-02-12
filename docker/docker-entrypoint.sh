#!/bin/sh
set -e

echo "Starting OHPM Repo Server..."
echo "Version: 5.4.4.0"
echo "Install directory: /opt/ohpm-repo"
echo "Deploy directory: /data/ohpm-repo"

# 以 root 执行：修改权限并切换到 node 用户
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, adjusting permissions..."
    # 如果数据目录不存在，创建它
    mkdir -p /data/ohpm-repo
    chown -R node:node /data/ohpm-repo
    chmod -R 755 /data/ohpm-repo
    echo "Switching to node user (UID 1000)..."
    exec su-exec node "$0" "$@"
fi

# 以 node 用户执行
cd /opt/ohpm-repo

# 修改配置文件
if [ -f "conf/config.yaml" ]; then
    echo "Updating config.yaml..."
    sed -i 's|deploy_root:.*|deploy_root: /data/ohpm-repo|' conf/config.yaml
    sed -i 's/listen: localhost:8088/listen: 0.0.0.0:8088/' conf/config.yaml
fi

# 初始化（如果需要）
if [ ! -d "/data/ohpm-repo/db" ] || [ ! -d "/data/ohpm-repo/storage" ]; then
    echo "Initializing OHPM repo..."
    ohpm-repo init
fi

# 启动服务
echo "Starting OHPM repo server on port 8088..."
exec ohpm-repo run-server
