#!/bin/bash
# ============================================
# 部署验证脚本
# 普通用户执行: bash scripts/05-verify.sh
# ============================================

set -euo pipefail

echo "=========================================="
echo " OpenClaw 部署验证"
echo "=========================================="

PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"

  if [ "$result" = "0" ]; then
    echo "  [PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

# ---------- 1. Docker 运行状态 ----------
echo ""
echo "[1/6] 检查 Docker 服务..."
docker info &> /dev/null 2>&1
check "Docker 服务运行正常" "$?"

# ---------- 2. OpenClaw 容器状态 ----------
echo ""
echo "[2/6] 检查 OpenClaw 容器..."
CONTAINER=$(docker ps --filter "name=openclaw" --format "{{.Names}}" | head -1)
if [ -n "$CONTAINER" ]; then
  check "OpenClaw 容器正在运行 ($CONTAINER)" "0"
else
  check "OpenClaw 容器正在运行" "1"
  echo "    提示: 运行 'docker compose up -d' 启动服务"
fi

# ---------- 3. Gateway 端口 ----------
echo ""
echo "[3/6] 检查 Gateway 端口..."
if command -v curl &> /dev/null; then
  curl -s --connect-timeout 5 http://localhost:3100/health &> /dev/null 2>&1
  check "Gateway 端口 3100 响应正常" "$?"
else
  # fallback: 检查端口是否监听
  ss -tlnp 2>/dev/null | grep -q ":3100" 2>/dev/null
  check "Gateway 端口 3100 正在监听" "$?"
fi

# ---------- 4. Dashboard 端口 ----------
echo ""
echo "[4/6] 检查 Dashboard..."
if command -v curl &> /dev/null; then
  curl -s --connect-timeout 5 http://localhost:19990 &> /dev/null 2>&1
  check "Dashboard 端口 19990 响应正常" "$?"
else
  ss -tlnp 2>/dev/null | grep -q ":19990" 2>/dev/null
  check "Dashboard 端口 19990 正在监听" "$?"
fi

# ---------- 5. 定时任务 ----------
echo ""
echo "[5/6] 检查定时任务..."
if [ -n "${CONTAINER:-}" ]; then
  CRON_COUNT=$(docker exec "$CONTAINER" openclaw cron list 2>/dev/null | grep -c "│" || echo "0")
  if [ "$CRON_COUNT" -gt 0 ]; then
    check "定时任务已配置 ($CRON_COUNT 个)" "0"
  else
    check "定时任务已配置" "1"
    echo "    提示: 运行 'bash scripts/03-setup-cron-jobs.sh' 配置定时任务"
  fi
else
  check "定时任务已配置" "1"
fi

# ---------- 6. 网络连通性 ----------
echo ""
echo "[6/6] 检查外网连通性..."
curl -s --connect-timeout 5 https://api.telegram.org &> /dev/null 2>&1
check "Telegram API 可访问" "$?"

# ---------- 5分钟测试提醒 ----------
echo ""
echo "=========================================="
echo " 验证结果: $PASS 通过 / $FAIL 失败"
echo "=========================================="

if [ "$FAIL" -eq 0 ]; then
  echo ""
  echo "所有检查通过！"
  echo ""

  # 发送测试提醒
  if [ -n "${CONTAINER:-}" ]; then
    echo "正在设置 5 分钟后的测试提醒..."
    FIVE_MIN_LATER=$(date -u -d "+5 minutes" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                     date -u -v+5M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                     echo "")

    if [ -n "$FIVE_MIN_LATER" ]; then
      docker exec "$CONTAINER" openclaw cron add \
        --name "部署测试" \
        --at "$FIVE_MIN_LATER" \
        --session main \
        --system-event "这是一条部署验证消息。如果你收到了这条消息，说明 OpenClaw 定时任务系统工作正常！恭喜！" \
        --wake now \
        --delete-after-run \
        2>/dev/null && echo "  -> 5 分钟后你会收到一条测试消息" || echo "  -> 测试提醒设置失败"
    else
      echo "  -> 无法计算时间，请手动测试"
    fi
  fi
else
  echo ""
  echo "有 $FAIL 项检查未通过，请根据提示修复。"
fi

echo ""
echo "后续步骤："
echo "  1. 在 Telegram 中找到你的 Bot，发送一条消息测试对话"
echo "  2. 等待 5 分钟测试提醒"
echo "  3. 验证明天早上 7:00 的早安播报"
echo "  4. 如需安全加固: sudo bash scripts/04-security-hardening.sh"
