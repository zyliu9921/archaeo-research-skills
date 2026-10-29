#!/usr/bin/env bash
# MinerU 访问方式探测（POSIX / macOS / Linux）
# 用法: bash check_env.sh [port ...]
# 退出码: 0 至少一条路可用；1 无可用路径（应停下来问人）
set -u
ENV_NAME="${MINERU_ENV_NAME:-MINERU_API_KEY}"
PORTS=("$@")
if [ ${#PORTS[@]} -eq 0 ]; then PORTS=(8000 18000); fi
usable=0

val="${!ENV_NAME:-}"
if [ -n "$val" ]; then
  echo "[1] 环境变量 $ENV_NAME : ok（长度 ${#val}，值不回显）"
  usable=1
else
  echo "[1] 环境变量 $ENV_NAME : missing"
fi

for p in "${PORTS[@]}"; do
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 1 127.0.0.1 "$p" >/dev/null 2>&1 && open=1 || open=0
  elif command -v bash >/dev/null 2>&1; then
    (exec 3<>"/dev/tcp/127.0.0.1/$p") >/dev/null 2>&1 && open=1 || open=0
  else
    open=0
  fi
  if [ "$open" -eq 1 ]; then
    echo "[2] 本地服务 127.0.0.1:$p : reachable"
    usable=1
  else
    echo "[2] 本地服务 127.0.0.1:$p : closed"
  fi
done

echo "[3] 宿主插件 : unknown（脚本无法读取宿主插件配置，需向使用者确认）"

if [ "$usable" -eq 1 ]; then
  echo "VERDICT: usable - 可继续，若走宿主插件路径请人工再确认一次"
  exit 0
else
  echo "VERDICT: no-path - 停止提交，按 SKILL.md 第 0 步向使用者索取凭据"
  exit 1
fi