# Linux Maintenance Tool

一个简单易用的 Linux 服务器维护菜单脚本，适合 Debian、Ubuntu、CentOS、Rocky、AlmaLinux、Fedora、Alpine 和 Arch Linux 等常见发行版。

## 一键运行

```bash
curl -fsSL https://raw.githubusercontent.com/kejiland/linux-maintenance-tool/main/install.sh | bash
```

或：

```bash
wget -qO- https://raw.githubusercontent.com/kejiland/linux-maintenance-tool/main/install.sh | bash
```

安装后运行：

```bash
sudo linux-maintenance
```

## 直接运行

```bash
curl -fsSL https://raw.githubusercontent.com/kejiland/linux-maintenance-tool/main/linux-maintenance.sh -o linux-maintenance.sh
chmod +x linux-maintenance.sh
sudo ./linux-maintenance.sh
```

## 功能

- 本机信息查看
- 系统更新
- 系统清理
- 常用组件安装
- Docker 管理
- Python、Node.js、Go、Java 环境管理
- SSH 端口、服务、时区、防火墙和用户工具
- 交互式菜单和危险操作确认

## 注意事项

部分操作需要 root 权限。修改 SSH 端口、清理 Docker 资源、卸载软件和重启服务器前，请确认当前环境及远程连接方式。

本项目不包含 12、14、16 等菜单功能，保持菜单简单。

## License

MIT
