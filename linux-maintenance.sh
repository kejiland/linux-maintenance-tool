#!/usr/bin/env bash
# Linux maintenance menu: simple, safe, and intentionally excludes 12/14/16.
set -Eeuo pipefail

# ---------- terminal colors ----------
if [[ -t 1 ]]; then
  C_RESET='\033[0m'; C_CYAN='\033[1;36m'; C_GREEN='\033[1;32m'; C_YELLOW='\033[1;33m'; C_RED='\033[1;31m'; C_PURPLE='\033[1;35m'; C_BLUE='\033[1;34m'; C_GRAY='\033[90m'
else
  C_RESET=''; C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_PURPLE=''; C_BLUE=''; C_GRAY=''
fi

pause() { read -r -p $'\n按 Enter 返回菜单…' _ || true; }
header() { clear 2>/dev/null || true; printf '%b\n' "${C_CYAN}Linux 维护工具${C_RESET}"; printf '%s\n' '----------------------------------------'; }
need_root() { [[ ${EUID:-$(id -u)} -eq 0 ]] || { printf '%b\n' "${C_RED}请使用 root 运行此功能。${C_RESET}"; return 1; }; }
run() { printf '%b\n' "${C_BLUE}▶ $*${C_RESET}"; "$@"; }
confirm() { local a; read -r -p "$1 [y/N] " a; [[ "$a" =~ ^[Yy]$ ]]; }

pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then echo apt
  elif command -v dnf >/dev/null 2>&1; then echo dnf
  elif command -v yum >/dev/null 2>&1; then echo yum
  elif command -v apk >/dev/null 2>&1; then echo apk
  elif command -v pacman >/dev/null 2>&1; then echo pacman
  else echo unknown; fi
}
install_pkgs() {
  local pm; pm=$(pkg_manager)
  case "$pm" in
    apt) run apt-get update; run apt-get install -y "$@";;
    dnf) run dnf install -y "$@";;
    yum) run yum install -y "$@";;
    apk) run apk add "$@";;
    pacman) run pacman -Sy --needed --noconfirm "$@";;
    *) printf '%b\n' "${C_RED}未识别包管理器。${C_RESET}"; return 1;;
  esac
}
uninstall_pkgs() {
  local pm; pm=$(pkg_manager)
  case "$pm" in
    apt) run apt-get purge -y "$@"; run apt-get autoremove -y;;
    dnf|yum) run "$pm" remove -y "$@";;
    apk) run apk del "$@";;
    pacman) run pacman -Rns --noconfirm "$@";;
    *) return 1;;
  esac
}

show_info() {
  header; echo -e "${C_YELLOW}系统信息${C_RESET}"; echo
  printf '主机名: %s\n' "$(hostname 2>/dev/null || echo unknown)"
  printf '系统: %s\n' "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
  printf '内核: %s\n' "$(uname -srmo)"
  printf '架构: %s\n' "$(uname -m)"
  printf 'CPU: %s 核\n' "$(nproc 2>/dev/null || echo unknown)"
  printf '负载: %s\n' "$(uptime 2>/dev/null | sed 's/.*load average: //')"
  free -h 2>/dev/null || true; echo
  df -h / 2>/dev/null || true; echo
  ip -brief address 2>/dev/null || true
  echo; printf '运行时间: %s\n' "$(uptime -p 2>/dev/null || true)"
  pause
}

system_update() {
  header; need_root || { pause; return; }; local pm; pm=$(pkg_manager)
  case "$pm" in
    apt) run apt-get update; run apt-get upgrade -y; run apt-get autoremove -y;;
    dnf) run dnf upgrade -y;; yum) run yum update -y;;
    apk) run apk update; run apk upgrade;; pacman) run pacman -Syu --noconfirm;;
    *) echo '不支持的包管理器。';;
  esac; pause
}

cleanup() {
  header; need_root || { pause; return; }; local pm; pm=$(pkg_manager)
  case "$pm" in
    apt) run apt-get autoremove -y; run apt-get autoclean;;
    dnf|yum) run "$pm" clean all;;
    apk) run apk cache clean;;
    pacman) run pacman -Sc --noconfirm;;
  esac
  journalctl --vacuum-time=7d 2>/dev/null || true
  find /tmp -mindepth 1 -maxdepth 1 -type f -mtime +7 -delete 2>/dev/null || true
  pause
}

component_menu() {
  while true; do
    header; echo -e "${C_YELLOW}组件管理${C_RESET}"; cat <<'EOF'
1. 安装常用工具
2. 安装监控工具
3. 安装压缩/会话工具
4. 卸载常用工具
0. 返回主菜单
EOF
    read -r -p '请输入选择: ' c
    case "$c" in
      1) need_root && install_pkgs curl wget sudo unzip tar jq git; pause;;
      2) need_root && install_pkgs htop btop iftop iotop; pause;;
      3) need_root && install_pkgs tmux screen; pause;;
      4) need_root && uninstall_pkgs htop btop iftop iotop tmux screen; pause;;
      0) return;; *) echo '无效选择'; sleep 1;;
    esac
  done
}

docker_menu() {
  while true; do
    header; echo -e "${C_YELLOW}Docker 管理${C_RESET}"; cat <<'EOF'
1. 安装/更新 Docker
2. 查看 Docker 状态
3. 查看容器
4. 查看镜像
5. 查看网络与卷
6. 清理无用资源
7. 卸载 Docker
0. 返回主菜单
EOF
    read -r -p '请输入选择: ' c
    case "$c" in
      1) need_root && { command -v docker >/dev/null 2>&1 && docker version || install_pkgs ca-certificates curl; command -v docker >/dev/null 2>&1 || curl -fsSL https://get.docker.com | sh; }; pause;;
      2) systemctl status docker --no-pager 2>/dev/null || docker info 2>/dev/null || true; pause;;
      3) docker ps -a 2>/dev/null || true; pause;;
      4) docker images 2>/dev/null || true; pause;;
      5) docker network ls 2>/dev/null || true; docker volume ls 2>/dev/null || true; pause;;
      6) need_root && confirm '确认清理未使用的容器、镜像、网络和卷？' && docker system prune -af --volumes; pause;;
      7) need_root && confirm '确认卸载 Docker？这不会自动删除 /var/lib/docker。' && uninstall_pkgs docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin; pause;;
      0) return;; *) echo '无效选择'; sleep 1;;
    esac
  done
}

runtime_menu() {
  while true; do
    header; echo -e "${C_YELLOW}常用环境管理${C_RESET}"; cat <<'EOF'
1. 安装 Python
2. 安装 Node.js
3. 安装 Go
4. 安装 Java
5. 卸载 Python
6. 卸载 Node.js
7. 卸载 Go
8. 卸载 Java
0. 返回主菜单
EOF
    read -r -p '请输入选择: ' c
    case "$c" in
      1) need_root && install_pkgs python3 python3-pip; pause;;
      2) need_root && install_pkgs nodejs npm; pause;;
      3) need_root && install_pkgs golang; pause;;
      4) need_root && install_pkgs default-jre; pause;;
      5) need_root && uninstall_pkgs python3 python3-pip; pause;;
      6) need_root && uninstall_pkgs nodejs npm; pause;;
      7) need_root && uninstall_pkgs golang; pause;;
      8) need_root && uninstall_pkgs default-jre; pause;;
      0) return;; *) echo '无效选择'; sleep 1;;
    esac
  done
}

system_tools() {
  while true; do
    header; echo -e "${C_YELLOW}系统工具${C_RESET}"; cat <<'EOF'
1. 设置脚本快捷键
2. 修改 SSH 端口
3. 查看端口占用
4. 查看服务状态
5. 设置时区
6. 防火墙状态
7. 创建用户
8. 重启服务器
0. 返回主菜单
EOF
    read -r -p '请输入选择: ' c
    case "$c" in
      1) printf '在 ~/.bashrc 中加入 alias maint="%s"\n' "$(realpath "$0")"; pause;;
      2) need_root && { read -r -p '新 SSH 端口: ' port; [[ "$port" =~ ^[0-9]+$ ]] && sed -i -E "s/^#?Port .*/Port $port/" /etc/ssh/sshd_config && systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null; }; pause;;
      3) ss -tulpen 2>/dev/null || netstat -tulpen 2>/dev/null || true; pause;;
      4) systemctl --type=service --state=running --no-pager 2>/dev/null || true; pause;;
      5) need_root && { timedatectl list-timezones 2>/dev/null | grep -E 'Asia/Shanghai|Asia/Tokyo|UTC|America/New_York' | head -20; read -r -p '输入时区（留空不修改）: ' tz; [[ -n "$tz" ]] && timedatectl set-timezone "$tz"; }; pause;;
      6) ufw status 2>/dev/null || firewall-cmd --state 2>/dev/null || iptables -L -n 2>/dev/null | head -30; pause;;
      7) need_root && { read -r -p '用户名: ' u; [[ "$u" =~ ^[a-z_][a-z0-9_-]*$ ]] && useradd -m -s /bin/bash "$u" && passwd "$u"; }; pause;;
      8) need_root && confirm '确认重启服务器？' && reboot;;
      0) return;; *) echo '无效选择'; sleep 1;;
    esac
  done
}

main() {
  while true; do
    header; echo -e "${C_GREEN}操作简单的 Linux 维护脚本${C_RESET}"; cat <<'EOF'
1. 本机信息
2. 系统更新
3. 系统清理
4. 组件管理  ▶
5. Docker 管理 ▶
6. 常用环境管理 ▶
7. 系统工具 ▶
8. 退出脚本

说明：已按要求不包含 12、14、16 等高风险/无关菜单。
EOF
    read -r -p '请输入选择: ' c
    case "$c" in
      1) show_info;; 2) system_update;; 3) cleanup;; 4) component_menu;; 5) docker_menu;; 6) runtime_menu;; 7) system_tools;; 8|q|Q) echo '已退出。'; exit 0;; *) echo '无效选择'; sleep 1;;
    esac
  done
}

main "$@"
