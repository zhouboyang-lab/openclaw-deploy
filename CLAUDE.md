# OpenClaw 部署指南

你是部署助手，负责在这台 Linux 服务器上部署 OpenClaw 个人 AI 助手。

## 项目仓库

```bash
git clone https://github.com/zhouboyang-lab/openclaw-deploy.git ~/openclaw-deploy
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
cd ~/openclaw
cp .env.example .env
```

然后编辑 `.env`，**必须**填写以下字段：
- `API_KEY` — AI 模型的 API Key
- `TELEGRAM_BOT_TOKEN` — Telegram Bot Token
- `MODEL_ID` / `BASE_URL` / `API_PROTOCOL` — 根据选择的模型方案取消注释

**向用户询问这些密钥，不要自己编造。**

### 第三步：安装 OpenClaw

```bash
bash scripts/02-install-openclaw.sh
```

等待 docker compose up -d 启动完成后，用 `docker ps` 确认容器正在运行。

### 第四步：配置 14 个定时任务

```bash
bash scripts/03-setup-cron-jobs.sh
```

如果脚本中的 `docker exec` 找不到容器，先用 `docker ps` 确认容器名，手动调整。

### 第五步：安全加固（可选）

```bash
sudo bash scripts/04-security-hardening.sh
```

### 第六步：验证

```bash
bash scripts/05-verify.sh
```

确保所有检查项 PASS。

## 注意事项

- 如果不是 Ubuntu 系统，01-server-init.sh 中的 `apt` 命令需要替换为对应的包管理器（yum/dnf）
- 如果 Docker 已经安装了，脚本会跳过安装步骤
- 如果端口 3100 或 19990 被占用，需要在 .env 中修改端口
- 遇到问题先看日志：`docker compose logs`
- 日常维护用：`bash scripts/maintenance.sh help`

## 定时任务列表（共 14 个）

| 时间 | 任务 |
|------|------|
| 每天 07:00 | 早安播报 |
| 每天 07:30 | AI 领域日报 |
| 周一四 08:00 | 申博信息追踪 |
| 每天 08:30 | 考公考编信息 |
| 每天 09:00 | 西安求职监控 |
| 每 3 小时 | AI 重大快讯 |
| 每周一 09:00 | 会议 DDL 提醒 |
| 周二五 21:00 | 论文推荐 |
| 每周三 10:00 | 校招专场监控 |
| 每周日 19:00 | 考编下周日历 |
| 每周日 20:00 | AI 周报 |
| 每天 21:00 | GitHub Trending |
| 每月 1 号 | 博导动态更新 |
| 每月 28 号 | 月度复盘提醒 |
