#!/bin/sh
set -e

# 以 node 用户运行的入口脚本
# 此脚本不执行任何逻辑，只是为了避免递归调用
# 实际逻辑在 docker-entrypoint.sh 中处理

# 执行原始脚本
exec /usr/local/bin/docker-entrypoint.sh "$@"
