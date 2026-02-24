#!/bin/bash
# ============================================
# 一键部署脚本（交互式）
# 在服务器上执行: bash scripts/deploy-all.sh
# ============================================

set -euo pipefail

echo "=========================================="
echo " OpenClaw 一键部署"
echo " Oracle Cloud ARM 免费实例"
echo "=========================================="
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- 第一步: 服务器初始化 ----------
echo "=== 第一步: 服务器初始化 ==="
read -p "是否执行服务器初始化（安装 Docker 等）？(Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  sudo bash "$SCRIPT_DIR/01-server-init.sh"
  echo ""
  echo "请重新登录 SSH 使 docker 权限生效，然后再次运行此脚本并跳过第一步。"
  echo "  ssh -i ~/.ssh/oracle_key ubuntu@<YOUR_SERVER_IP>"
  echo "  bash scripts/deploy-all.sh"
  exit 0
fi

# ---------- 第二步: 安装 OpenClaw ----------
echo ""
echo "=== 第二步: 安装 OpenClaw ==="
read -p "是否安装 OpenClaw？(Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  bash "$SCRIPT_DIR/02-install-openclaw.sh"
fi

# ---------- 第三步: 配置定时任务 ----------
echo ""
echo "=== 第三步: 配置定时任务 ==="
read -p "是否配置定时任务？(Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  bash "$SCRIPT_DIR/03-setup-cron-jobs.sh"
fi

# ---------- 第四步: 安全加固 ----------
echo ""
echo "=== 第四步: 安全加固 ==="
read -p "是否执行安全加固？(Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  sudo bash "$SCRIPT_DIR/04-security-hardening.sh"
fi

# ---------- 第五步: 验证 ----------
echo ""
echo "=== 第五步: 验证部署 ==="
bash "$SCRIPT_DIR/05-verify.sh"

echo ""
echo "=========================================="
echo " 部署完成！"
echo "=========================================="
echo ""
echo "后续操作："
echo "  1. 在 Telegram 中测试你的 Bot"
echo "  2. 等待明天早上 7:00 收第一条消息"
echo "  3. 日常维护: bash scripts/maintenance.sh help"
