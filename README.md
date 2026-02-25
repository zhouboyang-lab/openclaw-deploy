# OpenClaw Deploy

> 个人 AI 助手，部署在 Oracle Cloud 免费实例上。基于 [OpenClaw](https://github.com/openclaw/openclaw) + [CN-IM Docker](https://github.com/justlovemaki/OpenClaw-Docker-CN-IM)。

## 环境要求

| 项目 | 要求 |
|------|------|
| 系统 | Ubuntu 20.04+（其他 Linux 需改包管理器） |
| Docker | 20.10+（含 docker compose V2） |
| 内存 | 最低 1GB，推荐 2GB+ |
| 磁盘 | 最低 10GB 可用空间 |
| 网络 | 需访问 Telegram API、Google API、AI 模型 API |

### 必需的 API 密钥

| 密钥 | 用途 | 获取地址 |
|------|------|---------|
| `API_KEY` | AI 模型（DeepSeek/OpenRouter/Claude） | 对应平台官网 |
| `TELEGRAM_BOT_TOKEN` | Telegram Bot 通道 | [@BotFather](https://t.me/BotFather) |
| `GEMINI_API_KEY` | Web 搜索（Gemini Google Search） | [Google AI Studio](https://aistudio.google.com/apikey) |

## 项目结构

```
~/openclaw-deploy/
├── openclaw/                     ← git submodule（上游仓库，仅作参考）
├── Dockerfile                    ← 基于上游镜像 + 自动升级 OpenClaw
├── docker-compose.yml            ← 项目自有（基于上游，含自定义）
├── .env                          ← 实际配置（gitignored）
├── .env.example                  ← 配置模板
├── scripts/
│   ├── 01-server-init.sh         系统初始化（Docker、iptables、swap）
│   ├── 02-install-openclaw.sh    安装 OpenClaw
│   ├── 03-setup-cron-jobs.sh     配置定时任务
│   ├── 04-security-hardening.sh  安全加固（可选）
│   ├── 05-verify.sh              部署验证
│   └── maintenance.sh            日常维护
├── CLAUDE.md                     ← AI 助手部署指令
└── README.md
```

## 快速部署

```bash
# 1. 克隆仓库
git clone --recurse-submodules https://github.com/zhouboyang-lab/openclaw-deploy.git ~/openclaw-deploy
cd ~/openclaw-deploy

# 2. 系统初始化
chmod +x scripts/*.sh
sudo bash scripts/01-server-init.sh
newgrp docker

# 3. 配置环境变量
cp .env.example .env
nano .env  # 填写 API_KEY、TELEGRAM_BOT_TOKEN、GEMINI_API_KEY

# 4. 安装并启动（Dockerfile 自动升级 OpenClaw）
bash scripts/02-install-openclaw.sh

# 5. 启用 Gemini 搜索（首次部署时执行，配置持久化在 ~/.openclaw/ 中）
docker exec openclaw-gateway cat /home/node/.openclaw/openclaw.json | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
data['tools'] = {'web': {'search': {'provider': 'gemini'}}}
data.setdefault('gateway', {})['controlUi'] = {'dangerouslyAllowHostHeaderOriginFallback': True}
print(json.dumps(data, indent=2))
" > /tmp/oc.json && docker cp /tmp/oc.json openclaw-gateway:/home/node/.openclaw/openclaw.json
docker restart openclaw-gateway

# 6. 配置定时任务
bash scripts/03-setup-cron-jobs.sh

# 7. 验证
bash scripts/05-verify.sh
```

## 容器内配置

`Dockerfile` 基于上游镜像自动升级 OpenClaw 到最新版，无需手动操作。

首次部署时需启用 Gemini 搜索（写入 `~/.openclaw/openclaw.json`），详见快速部署第 5 步。该配置持久化在数据目录中，容器重建不受影响。

## 数据目录

所有运行时数据存储在 `~/.openclaw/`，独立于项目代码：

| 目录 | 内容 |
|------|------|
| `agents/` | 对话历史和会话数据 |
| `cron/` | 定时任务数据和执行记录 |
| `credentials/` | 凭证存储 |
| `workspace/` | 工作空间文件 |
| `openclaw.json` | 核心配置（搜索、模型、Gateway） |

**迁移服务器时，备份 `~/.openclaw/` 即可保留所有数据。**

## 定时任务（9 个）

| 时间 | 任务 |
|------|------|
| 每天 07:00 | 早安播报（天气+日程） |
| 周一四 08:00 | 申博追踪（含导师动态） |
| 周一三五 08:30 | 考公考编信息 |
| 每天 09:00 | 求职监控（校招+社招，重点央企国企） |
| 每周五 20:00 | GitHub Trending |
| 周二五 21:00 | 论文推荐 |
| 每周日 20:00 | AI 周报 |
| 每周一 09:00 | 会议 DDL 提醒 |
| 每月 28 号 | 月度复盘提醒 |

## 日常维护

```bash
bash scripts/maintenance.sh status      # 服务状态
bash scripts/maintenance.sh logs         # 查看日志
bash scripts/maintenance.sh restart      # 重启服务
bash scripts/maintenance.sh update       # 更新镜像
bash scripts/maintenance.sh backup       # 备份配置
bash scripts/maintenance.sh cron-list    # 查看定时任务
```

## 更新上游仓库

```bash
cd ~/openclaw-deploy
git submodule update --remote openclaw
git add openclaw
git commit -m "update: openclaw submodule to latest"
```

## 故障排查

1. **容器无法启动**: `docker compose logs` 查看日志
2. **Telegram 消息不通**: 确认 Bot Token 正确，服务器能访问 `api.telegram.org`
3. **Web 搜索不工作**: 确认 `GEMINI_API_KEY` 已配置，OpenClaw 已升级到 >= 2026.2.24，`openclaw.json` 中 `tools.web.search.provider` 为 `gemini`
4. **定时任务不触发**: `docker exec openclaw-gateway openclaw cron list` 确认任务已注册
5. **需要强制重新构建镜像**: `docker compose up -d --build --no-cache`

## 参考链接

- [OpenClaw 官方文档](https://docs.openclaw.ai/)
- [CN-IM Docker 版本](https://github.com/justlovemaki/OpenClaw-Docker-CN-IM)
- [Cron Jobs 文档](https://docs.openclaw.ai/automation/cron-jobs)
