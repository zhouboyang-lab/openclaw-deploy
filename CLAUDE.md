# OpenClaw 部署指南

你是部署助手，负责在这台 Linux 服务器上部署 OpenClaw 个人 AI 助手。

## 项目结构

```
~/openclaw-deploy/
├── openclaw/                     ← git submodule（上游仓库，仅作参考）
│   ├── docker-compose.yml        （上游原版，不直接使用）
│   ├── init.sh
│   ├── .env.example
│   └── ...
├── docker-compose.yml            ← 项目自有（基于上游，含自定义）
├── .env                          ← 实际配置（gitignored）
├── .env.example                  ← 配置模板
├── CLAUDE.md
├── scripts/
│   ├── 01-server-init.sh
│   ├── 02-install-openclaw.sh
│   ├── 03-setup-cron-jobs.sh
│   ├── 04-security-hardening.sh
│   ├── 05-verify.sh
│   └── maintenance.sh
└── README.md
```

上游仓库通过 git submodule 管理（跟踪更新参考），项目根目录维护独立的 `docker-compose.yml`。

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

### 容器内额外配置

Docker 镜像自带的 OpenClaw 版本可能较旧，部署后需在容器内完成：

1. **升级 OpenClaw 到 >= 2026.2.24**（支持 Gemini 搜索）：
```bash
docker exec openclaw-gateway npm -g update openclaw
docker restart openclaw-gateway
```

2. **启用 Gemini Web 搜索**（写入 `~/.openclaw/openclaw.json`）：
```json
{
  "tools": {
    "web": {
      "search": {
        "provider": "gemini"
      }
    }
  }
}
```
可用 `python3` 脚本合并到现有配置：
```bash
docker exec openclaw-gateway cat /home/node/.openclaw/openclaw.json | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
data['tools'] = {'web': {'search': {'provider': 'gemini'}}}
print(json.dumps(data, indent=2))
" > /tmp/oc.json && docker cp /tmp/oc.json openclaw-gateway:/home/node/.openclaw/openclaw.json
docker restart openclaw-gateway
```

3. **Gateway controlUi 配置**（2026.2.24+ 非 localhost 绑定时必需）：
```json
{
  "gateway": {
    "controlUi": {
      "dangerouslyAllowHostHeaderOriginFallback": true
    }
  }
}
```

### 数据目录

所有运行时数据存储在 `~/.openclaw/`，独立于项目代码目录：

| 目录 | 内容 |
|------|------|
| `agents/` | 对话历史和会话数据 |
| `cron/` | 定时任务数据和执行记录 |
| `credentials/` | 凭证存储 |
| `workspace/` | 工作空间文件 |
| `openclaw.json` | 核心配置（搜索、模型、Gateway 等） |

迁移服务器时，备份 `~/.openclaw/` 即可保留所有数据。

## 项目仓库

```bash
git clone --recurse-submodules https://github.com/zhouboyang-lab/openclaw-deploy.git ~/openclaw-deploy
```

## 部署流程

按顺序执行以下步骤，每步完成后确认状态再进下一步。

### 第一步：系统初始化

```bash
cd ~/openclaw-deploy
chmod +x scripts/*.sh
sudo bash scripts/01-server-init.sh
```

这个脚本会：安装 Docker、配置 iptables、创建 swap、启用自动安全更新。

执行完后需要**重新加载 docker 组权限**：
```bash
newgrp docker
```

### 第二步：配置环境变量

```bash
cd ~/openclaw-deploy
cp .env.example .env
```

然后编辑 `.env`，**必须**填写以下字段：
- `API_KEY` — AI 模型的 API Key
- `TELEGRAM_BOT_TOKEN` — Telegram Bot Token
- `GEMINI_API_KEY` — Google AI Studio API Key（用于 Web 搜索）
- `MODEL_ID` / `BASE_URL` / `API_PROTOCOL` — 根据选择的模型方案取消注释

**向用户询问这些密钥，不要自己编造。**

### 第三步：安装 OpenClaw

```bash
bash scripts/02-install-openclaw.sh
```

脚本会自动初始化 submodule 并启动容器。等待完成后，用 `docker ps` 确认容器正在运行。

### 第四步：升级 OpenClaw 并启用 Gemini 搜索

```bash
# 升级到最新版
docker exec openclaw-gateway npm -g update openclaw

# 启用 Gemini 搜索 + Gateway controlUi
docker exec openclaw-gateway cat /home/node/.openclaw/openclaw.json | \
python3 -c "
import sys, json
data = json.load(sys.stdin)
data['tools'] = {'web': {'search': {'provider': 'gemini'}}}
data.setdefault('gateway', {})['controlUi'] = {'dangerouslyAllowHostHeaderOriginFallback': True}
print(json.dumps(data, indent=2))
" > /tmp/oc.json && docker cp /tmp/oc.json openclaw-gateway:/home/node/.openclaw/openclaw.json

# 重启生效
docker restart openclaw-gateway
```

### 第五步：配置 9 个定时任务

```bash
bash scripts/03-setup-cron-jobs.sh
```

如果脚本中的 `docker exec` 找不到容器，先用 `docker ps` 确认容器名，手动调整。

### 第六步：安全加固（可选）

```bash
sudo bash scripts/04-security-hardening.sh
```

### 第七步：验证

```bash
bash scripts/05-verify.sh
```

确保所有检查项 PASS。

## 更新上游仓库

```bash
cd ~/openclaw-deploy
git submodule update --remote openclaw
git add openclaw
git commit -m "update: openclaw submodule to latest"
```

## 注意事项

- 如果不是 Ubuntu 系统，01-server-init.sh 中的 `apt` 命令需要替换为对应的包管理器（yum/dnf）
- 如果 Docker 已经安装了，脚本会跳过安装步骤
- 如果端口 18789 或 18790 被占用，需要在 .env 中修改端口
- 遇到问题先看日志：`docker compose logs`
- 日常维护用：`bash scripts/maintenance.sh help`
- 项目根目录的 `docker-compose.yml` 是独立维护的，不依赖上游 compose 文件
- 容器内 `npm -g update openclaw` 在容器重建后需要重新执行

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
