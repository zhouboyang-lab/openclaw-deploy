#!/bin/bash
# ============================================
# 第六阶段：安全加固
# 需要 root 权限: sudo bash scripts/04-security-hardening.sh
# ============================================

set -euo pipefail

echo "=========================================="
echo " 安全加固"
echo "=========================================="

if [ "$EUID" -ne 0 ]; then
  echo "[错误] 请使用 sudo 执行此脚本"
  exit 1
fi

# ---------- 配置 UFW 防火墙 ----------
echo ""
echo "[1/4] 配置 UFW 防火墙..."

apt install -y ufw

# 默认策略
ufw default deny incoming
ufw default allow outgoing

# 放行 SSH
ufw allow 22/tcp comment 'SSH'

# 放行 OpenClaw Gateway
ufw allow 3100/tcp comment 'OpenClaw Gateway'

# Dashboard 建议通过 SSH 隧道访问，不对外开放
# 如果确实需要远程访问，取消下面的注释并替换为你的 IP
# ufw allow from YOUR_IP to any port 19990 proto tcp comment 'Dashboard - restricted'

# 启用防火墙
echo "y" | ufw enable
ufw status verbose

# ---------- SSH 加固 ----------
echo ""
echo "[2/4] SSH 安全加固..."

SSHD_CONFIG="/etc/ssh/sshd_config"

# 禁用密码登录（确保你已配置好 SSH 密钥！）
read -p "是否禁用 SSH 密码登录？确保你已配置好密钥登录！(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # 备份原配置
  cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak"

  # 禁用密码登录
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
  sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"

  # 禁用 root 登录
  sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"

  # 重启 SSH
  systemctl restart sshd
  echo "SSH 已加固：密码登录已禁用，root 登录已禁用"
else
  echo "跳过 SSH 加固"
fi

# ---------- Fail2Ban ----------
echo ""
echo "[3/4] 安装 Fail2Ban..."

apt install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = 7200
EOF

systemctl enable fail2ban
systemctl restart fail2ban

echo "Fail2Ban 已配置：SSH 暴力破解防护"

# ---------- 自动安全更新 ----------
echo ""
echo "[4/4] 确认自动安全更新..."

if dpkg -l | grep -q unattended-upgrades; then
  echo "自动安全更新已启用"
else
  apt install -y unattended-upgrades
  dpkg-reconfigure -plow unattended-upgrades
fi

# ---------- 完成 ----------
echo ""
echo "=========================================="
echo " 安全加固完成！"
echo "=========================================="
echo ""
echo "安全措施："
echo "  - UFW 防火墙: 仅开放 22, 3100"
echo "  - SSH: 密钥登录（密码登录已${REPLY:+禁用}${REPLY:-保留}）"
echo "  - Fail2Ban: SSH 暴力破解防护"
echo "  - 自动安全更新: 已启用"
echo ""
echo "Dashboard 访问建议通过 SSH 隧道："
echo "  ssh -L 19990:localhost:19990 ubuntu@<YOUR_SERVER_IP>"
echo "  然后浏览器访问 http://localhost:19990"
