#!/bin/bash
# ============================================
# 日常维护脚本
# 用法: bash scripts/maintenance.sh <command>
# ============================================

set -euo pipefail

DEPLOY_DIR="$HOME/openclaw"
ACTION="${1:-help}"

cd "$DEPLOY_DIR" 2>/dev/null || {
  echo "[错误] OpenClaw 目录不存在: $DEPLOY_DIR"
  exit 1
}

# 优先使用 docker compose V2
DC="docker compose"
if ! docker compose version &> /dev/null 2>&1; then
  DC="docker-compose"
fi

case "$ACTION" in

  status)
    echo "=== OpenClaw 服务状态 ==="
    $DC ps
    echo ""
    echo "=== 系统资源 ==="
    echo "内存:"
    free -h
    echo ""
    echo "磁盘:"
    df -h /
    echo ""
    echo "Docker 磁盘占用:"
    docker system df
    ;;

  logs)
    echo "=== OpenClaw 日志 (最近 100 行) ==="
    $DC logs --tail=100 "${2:-}"
    ;;

  logs-follow)
    echo "=== OpenClaw 实时日志 (Ctrl+C 退出) ==="
    $DC logs -f "${2:-}"
    ;;

  restart)
    echo "重启 OpenClaw..."
    $DC restart
    echo "重启完成"
    $DC ps
    ;;

  stop)
    echo "停止 OpenClaw..."
    $DC down
    echo "已停止"
    ;;

  start)
    echo "启动 OpenClaw..."
    $DC up -d
    echo "已启动"
    $DC ps
    ;;

  update)
    echo "更新 OpenClaw..."
    echo ""
    echo "[1/3] 拉取最新镜像..."
    $DC pull
    echo ""
    echo "[2/3] 重建容器..."
    $DC up -d
    echo ""
    echo "[3/3] 清理旧镜像..."
    docker image prune -f
    echo ""
    echo "更新完成！"
    $DC ps
    ;;

  backup)
    BACKUP_DIR="$HOME/openclaw-backups"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_FILE="$BACKUP_DIR/openclaw_backup_$TIMESTAMP.tar.gz"

    mkdir -p "$BACKUP_DIR"
    echo "备份 OpenClaw 配置..."
    tar -czf "$BACKUP_FILE" \
      -C "$DEPLOY_DIR" \
      .env \
      docker-compose.yml \
      data/ \
      2>/dev/null || true
    echo "备份完成: $BACKUP_FILE"
    echo ""
    echo "现有备份:"
    ls -lh "$BACKUP_DIR/"
    ;;

  cron-list)
    CONTAINER=$(docker ps --filter "name=openclaw" --format "{{.Names}}" | head -1)
    if [ -n "$CONTAINER" ]; then
      docker exec "$CONTAINER" openclaw cron list
    else
      echo "[错误] OpenClaw 容器未运行"
    fi
    ;;

  cron-runs)
    CONTAINER=$(docker ps --filter "name=openclaw" --format "{{.Names}}" | head -1)
    if [ -n "$CONTAINER" ]; then
      docker exec "$CONTAINER" openclaw cron runs
    else
      echo "[错误] OpenClaw 容器未运行"
    fi
    ;;

  shell)
    CONTAINER=$(docker ps --filter "name=openclaw" --format "{{.Names}}" | head -1)
    if [ -n "$CONTAINER" ]; then
      echo "进入 OpenClaw 容器 (exit 退出)..."
      docker exec -it "$CONTAINER" /bin/bash
    else
      echo "[错误] OpenClaw 容器未运行"
    fi
    ;;

  cleanup)
    echo "清理 Docker 资源..."
    docker system prune -f
    docker volume prune -f
    echo "清理完成"
    docker system df
    ;;

  help|*)
    echo "OpenClaw 维护脚本"
    echo ""
    echo "用法: bash scripts/maintenance.sh <command>"
    echo ""
    echo "常用命令:"
    echo "  status      查看服务状态和系统资源"
    echo "  logs        查看最近日志"
    echo "  logs-follow 实时查看日志"
    echo "  restart     重启服务"
    echo "  start       启动服务"
    echo "  stop        停止服务"
    echo "  update      更新到最新版本"
    echo "  backup      备份配置和数据"
    echo "  cron-list   查看定时任务列表"
    echo "  cron-runs   查看定时任务执行记录"
    echo "  shell       进入容器终端"
    echo "  cleanup     清理 Docker 资源"
    ;;
esac
