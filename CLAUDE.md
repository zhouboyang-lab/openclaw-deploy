# OpenClaw 部署指南

你是部署助手，负责在这台 Linux 服务器上部署 OpenClaw 个人 AI 助手。

## 项目结构

```
~/openclaw-deploy/
├── openclaw/                     ← git submodule（上游仓库，仅作参考）
├── Dockerfile                    ← 基于上游镜像 + 自动升级 OpenClaw
├── docker-compose.yml            ← 项目自有（基于上游，含自定义）
├── .env                          ← 实际配置（gitignored）
├── .env.example                  ← 配置模板
├── scripts/                      ← 部署脚本
└── README.md                     ← 环境要求和部署文档
```

## 部署流程

按顺序执行，每步确认后再进下一步。详细环境要求见 `README.md`。

### 第一步：系统初始化

```bash
cd ~/openclaw-deploy
chmod +x scripts/*.sh
sudo bash scripts/01-server-init.sh
newgrp docker
```

### 第二步：配置环境变量

```bash
cp .env.example .env
```

编辑 `.env`，**必须**填写：
- `API_KEY` — AI 模型的 API Key
- `TELEGRAM_BOT_TOKEN` — Telegram Bot Token
- `GEMINI_API_KEY` — Google AI Studio API Key（Web 搜索）

**向用户询问这些密钥，不要自己编造。**

### 第三步：安装 OpenClaw

```bash
bash scripts/02-install-openclaw.sh
```

Dockerfile 会自动升级 OpenClaw 到最新版，无需手动操作。

### 第四步：启用 Gemini 搜索

首次部署时需写入搜索配置（后续容器重建不影响，配置在 `~/.openclaw/` 中持久化）：

```bash
docker exec openclaw-gateway cat /home/node/.openclaw/openclaw.json | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
data['tools'] = {'web': {'search': {'provider': 'gemini'}}}
data.setdefault('gateway', {})['controlUi'] = {'dangerouslyAllowHostHeaderOriginFallback': True}
print(json.dumps(data, indent=2))
" > /tmp/oc.json && docker cp /tmp/oc.json openclaw-gateway:/home/node/.openclaw/openclaw.json
docker restart openclaw-gateway
```

### 第五步：配置定时任务

```bash
bash scripts/03-setup-cron-jobs.sh
```

### 第六步：验证

```bash
bash scripts/05-verify.sh
```

## 注意事项

- 端口：Gateway 18789，Dashboard 18790
- 数据目录：`~/.openclaw/`（独立于项目代码，迁移时备份此目录）
- 日志：`docker compose logs`
- 维护：`bash scripts/maintenance.sh help`
- Dockerfile 自动升级 OpenClaw，容器重建无需手动操作
- `~/.openclaw/openclaw.json` 中的搜索配置持久化，只需首次部署时写入
- 项目根目录的 `docker-compose.yml` 是独立维护的，不依赖上游 compose 文件

## 定时任务列表（共 9 个）

| 时间 | 任务 |
|------|------|
| 每天 07:00 | 早安播报 |
| 周一四 08:00 | 申博追踪（含导师动态） |
| 周一三五 08:30 | 考公考编信息 |
| 每天 09:00 | 求职监控（含校招+社招） |
| 每周五 20:00 | GitHub Trending |
| 周二五 21:00 | 论文推荐 |
| 每周日 20:00 | AI 周报 |
| 每周一 09:00 | 会议 DDL 提醒 |
| 每月 28 号 | 月度复盘提醒 |
