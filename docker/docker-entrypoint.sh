#!/bin/sh
set -e

echo "Starting OHPM Repo Server..."
echo "Version: 5.4.4.0"
echo "Install directory: /opt/ohpm-repo"
echo "Deploy directory: /data/ohpm-repo"

# 以 root 执行：修改 EFS 目录权限并切换到 node 用户
if [ "$(id -u)" = "0" ]; then
    echo "Running as root, adjusting EFS permissions..."
    chown -R node:node /data/ohpm-repo 2>/dev/null || true
    chmod -R 755 /data/ohpm-repo 2>/dev/null || true
    echo "Switching to node user (UID 1000)..."
    # 传递一个标志参数告诉脚本已经是 node 用户
    exec su-exec node "$0" --as-node "$@"
fi

# 检查是否是以 node 用户身份运行
if [ "$1" != "--as-node" ]; then
    echo "Error: Script should be called with --as-node flag when running as node user"
    exit 1
fi

# 移除 --as-node 参数
shift

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
