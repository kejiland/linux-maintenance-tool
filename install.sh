#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://raw.githubusercontent.com/kejiland/linux-maintenance-tool/main/linux-maintenance.sh"
INSTALL_DIR="/usr/local/bin"
TARGET="$INSTALL_DIR/linux-maintenance"

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

command -v curl >/dev/null 2>&1 || {
  echo "错误：需要 curl 才能安装。请先安装 curl 后重试。" >&2
  exit 1
}

mkdir -p "$INSTALL_DIR"
tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

curl -fL --retry 3 --connect-timeout 10 "$REPO_URL" -o "$tmp_file"
[[ -s "$tmp_file" ]] || { echo "错误：下载的脚本为空。" >&2; exit 1; }

install -m 0755 "$tmp_file" "$TARGET"
echo "安装完成：$TARGET"
echo "启动维护工具..."
exec "$TARGET" "$@"
