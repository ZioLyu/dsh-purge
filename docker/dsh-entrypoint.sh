#!/bin/sh
set -eu

RELAY_PORT="${RELAY_PORT:-3081}"
DSH_PORT="${DSH_PORT:-3080}"

# dsh 原生只绑定 127.0.0.1:3080（官方限制），Docker 端口发布经容器网卡送达，
# 无法命中 loopback，因此用 socat 在 0.0.0.0:RELAY_PORT 做一层中继
socat TCP-LISTEN:"${RELAY_PORT}",fork,reuseaddr TCP:127.0.0.1:"${DSH_PORT}" &

sleep 1
exec "$@"
