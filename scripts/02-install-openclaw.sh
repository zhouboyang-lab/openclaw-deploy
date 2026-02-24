#!/bin/bash
# ============================================
# 第二阶段：安装 OpenClaw (CN-IM Docker 版)
# 普通用户执行: bash scripts/02-install-openclaw.sh
# ============================================

set -euo pipefail

DEPLOY_DIR="$HOME/openclaw"
REPO_URL="https://github.com/justlovemaki/OpenClaw-Docker-CN-IM.git"

echo "=========================================="
echo " OpenClaw 安装 (CN-IM Docker 版)"
echo "=========================================="

# ---------- 检查 Docker ----------
if ! command -v docker &> /dev/null; then
  echo "[错误] Docker 未安装，请先运行 01-server-init.sh"
  exit 1
fi

if ! docker info &> /dev/null 2>&1; then
  echo "[错误] Docker 无权限，请重新登录 SSH 或执行: newgrp docker"
  exit 1
fi

# ---------- 克隆仓库 ----------
echo ""
echo "[1/4] 克隆 OpenClaw-Docker-CN-IM..."
if [ -d "$DEPLOY_DIR" ]; then
  echo "目录已存在，拉取最新代码..."
  cd "$DEPLOY_DIR"
  git pull
else
  git clone "$REPO_URL" "$DEPLOY_DIR"
  cd "$DEPLOY_DIR"
fi

# ---------- 配置环境变量 ----------
echo ""
echo "[2/4] 配置环境变量..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -f "$DEPLOY_DIR/.env" ]; then
  echo ".env 已存在，跳过（如需重新配置请手动编辑）"
elif [ -f "$SCRIPT_DIR/.env" ]; then
  cp "$SCRIPT_DIR/.env" "$DEPLOY_DIR/.env"
  echo "已从部署目录复制 .env"
else
  if [ -f "$DEPLOY_DIR/.env.example" ]; then
    cp "$DEPLOY_DIR/.env.example" "$DEPLOY_DIR/.env"
  elif [ -f "$SCRIPT_DIR/.env.example" ]; then
    cp "$SCRIPT_DIR/.env.example" "$DEPLOY_DIR/.env"
  fi
  echo ""
  echo "================================================"
  echo " 请编辑 .env 文件填写你的配置："
  echo "   nano $DEPLOY_DIR/.env"
  echo ""
  echo " 至少需要配置："
  echo "   - API_KEY (AI 模型的 API Key)"
  echo "   - TELEGRAM_BOT_TOKEN (Telegram Bot Token)"
  echo "================================================"
  echo ""
  read -p "配置完成后按回车继续（或 Ctrl+C 退出后手动配置）..."
fi

# ---------- 创建数据目录 ----------
echo ""
echo "[3/4] 创建持久化数据目录..."
mkdir -p "$DEPLOY_DIR/data/config"
mkdir -p "$DEPLOY_DIR/data/workspace"

# ---------- 启动服务 ----------
echo ""
echo "[4/4] 启动 OpenClaw..."

cd "$DEPLOY_DIR"

# 优先使用 docker compose（V2），回退到 docker-compose（V1）
if docker compose version &> /dev/null 2>&1; then
  docker compose pull
  docker compose up -d
else
  docker-compose pull
  docker-compose up -d
fi

# ---------- 等待启动 ----------
echo ""
echo "等待服务启动..."
sleep 10

# 检查容器状态
if docker compose ps 2>/dev/null | grep -q "Up" || docker-compose ps 2>/dev/null | grep -q "Up"; then
  echo ""
  echo "=========================================="
  echo " OpenClaw 安装成功！"
  echo "=========================================="
  echo ""
  echo "服务状态:"
  docker compose ps 2>/dev/null || docker-compose ps 2>/dev/null
  echo ""
  echo "访问 Dashboard: http://<YOUR_SERVER_IP>:19990"
  echo ""
  echo "下一步："
  echo "  1. 在 Telegram 中找到你的 Bot，发送一条消息测试"
  echo "  2. 运行 bash scripts/03-setup-cron-jobs.sh 配置定时任务"
else
  echo ""
  echo "[警告] 服务可能未正常启动，请检查日志："
  echo "  docker compose logs"
fi
