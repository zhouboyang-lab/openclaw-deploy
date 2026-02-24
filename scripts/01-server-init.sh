#!/bin/bash
# ============================================
# 第一阶段：Oracle Cloud 服务器初始化
# 需要 root 权限执行: sudo bash scripts/01-server-init.sh
# ============================================

set -euo pipefail

echo "=========================================="
echo " OpenClaw 服务器初始化"
echo "=========================================="

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then
  echo "[错误] 请使用 sudo 执行此脚本"
  exit 1
fi

# ---------- 系统更新 ----------
echo ""
echo "[1/6] 系统更新..."
apt update && apt upgrade -y

# ---------- 安装基础依赖 ----------
echo ""
echo "[2/6] 安装基础依赖..."
apt install -y \
  build-essential \
  curl \
  wget \
  git \
  unzip \
  htop \
  tmux \
  jq \
  ca-certificates \
  gnupg \
  lsb-release

# ---------- 安装 Docker ----------
echo ""
echo "[3/6] 安装 Docker..."
if command -v docker &> /dev/null; then
  echo "Docker 已安装，跳过"
else
  # 使用官方安装脚本
  curl -fsSL https://get.docker.com | bash
fi

# 安装 Docker Compose 插件
apt install -y docker-compose-plugin 2>/dev/null || true

# 如果没有 docker compose 插件，安装独立版 docker-compose
if ! docker compose version &> /dev/null; then
  echo "安装独立版 docker-compose..."
  ARCH=$(uname -m)
  if [ "$ARCH" = "aarch64" ]; then
    COMPOSE_ARCH="linux-aarch64"
  else
    COMPOSE_ARCH="linux-x86_64"
  fi
  curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-${COMPOSE_ARCH}" \
    -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
fi

# ---------- Docker 配置 ----------
echo ""
echo "[4/6] 配置 Docker..."
systemctl enable docker
systemctl start docker

# 将当前用户加入 docker 组（避免每次 sudo）
REAL_USER="${SUDO_USER:-ubuntu}"
usermod -aG docker "$REAL_USER"

# 启用 linger（允许用户服务在退出后继续运行）
loginctl enable-linger "$REAL_USER"

# ---------- 配置 iptables (Oracle Cloud 特有) ----------
echo ""
echo "[5/6] 配置 iptables（Oracle Cloud 需要额外放行端口）..."

# Oracle Cloud Ubuntu 镜像默认有 iptables 规则阻止流量
# 需要手动放行端口
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 3100 -j ACCEPT
iptables -I INPUT 6 -m state --state NEW -p tcp --dport 19990 -j ACCEPT

# 持久化 iptables 规则
apt install -y iptables-persistent
netfilter-persistent save

# ---------- 设置 swap（可选但推荐） ----------
echo ""
echo "[6/6] 配置 swap 空间..."
if [ ! -f /swapfile ]; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  echo "Swap 已配置: 4GB"
else
  echo "Swap 已存在，跳过"
fi

# ---------- 设置自动安全更新 ----------
echo ""
echo "[附加] 配置自动安全更新..."
apt install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades

# ---------- 完成 ----------
echo ""
echo "=========================================="
echo " 服务器初始化完成！"
echo "=========================================="
echo ""
echo "重要提醒："
echo "  1. 请重新登录 SSH 使 docker 组权限生效"
echo "  2. 确保 Oracle Cloud 安全列表已放行端口："
echo "     - 22   (SSH)"
echo "     - 3100 (OpenClaw Gateway)"
echo "     - 19990 (Dashboard, 建议仅允许你的 IP)"
echo ""
echo "下一步: bash scripts/02-install-openclaw.sh"
