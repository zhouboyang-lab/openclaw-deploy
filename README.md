# OpenClaw 部署方案 — Oracle Cloud 免费实例

> 周博洋的 7x24 小时个人 AI 助手，部署在 Oracle Cloud 免费 ARM 实例上。

## 功能概览

| 功能 | 说明 | 接收人 |
|------|------|--------|
| AI 领域日报/周报 | 大模型、Agent、VLA、端侧部署动态 | 周博洋 |
| 西安求职监控 | AI/CS 岗位、校招实习信息 | 周博洋 |
| 申博信息追踪 | 博士招生、导师动态 | 周博洋 |
| 考公考编信息 | 西安/陕西公务员、事业单位、教编 | 女朋友 |
| 早安播报 | 天气、日程、励志语 | 周博洋 |
| 论文推荐 | arXiv 高质量论文 | 周博洋 |
| 会议 DDL | AI 顶会截稿提醒 | 周博洋 |
| GitHub Trending | AI/ML 热门开源项目 | 周博洋 |
| 月度复盘 | 结构化复盘提醒 | 周博洋 |

## 技术栈

- **服务器**: Oracle Cloud VM.Standard.A1.Flex (4 OCPU / 24GB RAM / 200GB)
- **系统**: Ubuntu 24.04 (aarch64)
- **核心**: [OpenClaw](https://github.com/openclaw/openclaw) + [CN-IM Docker](https://github.com/justlovemaki/OpenClaw-Docker-CN-IM)
- **AI 模型**: OpenRouter 免费模型 → DeepSeek V3 → Claude/GPT-4o
- **通讯渠道**: Telegram → 微信 → 钉钉

## 预估成本

| 项目 | 月费 |
|------|------|
| Oracle Cloud 服务器 | 免费 |
| OpenRouter 免费模型 | 免费 |
| DeepSeek V3（推荐） | ~$3-5/月 |

---

## 部署步骤

### 前提条件

1. 已创建 Oracle Cloud 账号并升级为 Pay As You Go（防止实例被回收）
2. 已创建 ARM 实例（VM.Standard.A1.Flex, 4 OCPU, 24GB RAM, Ubuntu 24.04）
3. 已下载 SSH 私钥，能 SSH 连接到实例
4. 已获取 Telegram Bot Token（@BotFather 创建）

### 第一步：上传部署脚本到服务器

```bash
# 在本地执行，将整个项目上传到服务器
scp -i ~/.ssh/oracle_key -r ./scripts ./env.example \
  ubuntu@<YOUR_SERVER_IP>:~/openclaw-deploy/
```

### 第二步：服务器初始化

```bash
ssh -i ~/.ssh/oracle_key ubuntu@<YOUR_SERVER_IP>
cd ~/openclaw-deploy
chmod +x scripts/*.sh
sudo bash scripts/01-server-init.sh
```

### 第三步：安装 OpenClaw

```bash
bash scripts/02-install-openclaw.sh
```

安装前需编辑 `.env` 文件配置 API Key 和 Bot Token：
```bash
cp .env.example .env
nano .env  # 填写你的密钥
```

### 第四步：配置定时任务

```bash
bash scripts/03-setup-cron-jobs.sh
```

### 第五步：安全加固

```bash
sudo bash scripts/04-security-hardening.sh
```

### 第六步：验证部署

```bash
bash scripts/05-verify.sh
```

---

## 定时任务总览

| 时间 | 任务 | 接收人 |
|------|------|--------|
| 每天 07:00 | 早安播报（天气+日程） | 周博洋 |
| 每天 07:30 | AI 领域日报 | 周博洋 |
| 周一、四 08:00 | 申博信息追踪 | 周博洋 |
| 每天 08:30 | 考公考编信息 | 女朋友 |
| 每天 09:00 | 西安求职信息 | 周博洋 |
| 每 3 小时 | AI 重大快讯（有才推） | 周博洋 |
| 每周一 09:00 | 会议 DDL 提醒 | 周博洋 |
| 周二、五 21:00 | 论文推荐 | 周博洋 |
| 每周三 10:00 | 校招专场监控 | 周博洋 |
| 每周日 19:00 | 考编下周日历 | 女朋友 |
| 每周日 20:00 | AI 周报 | 周博洋 |
| 每天 21:00 | GitHub Trending | 周博洋 |
| 每月 1 号 | 博导动态更新 | 周博洋 |
| 每月 28 号 | 月度复盘提醒 | 周博洋 |

---

## 日常维护

```bash
# 查看 OpenClaw 状态
bash scripts/maintenance.sh status

# 查看日志
bash scripts/maintenance.sh logs

# 重启服务
bash scripts/maintenance.sh restart

# 更新 OpenClaw
bash scripts/maintenance.sh update

# 备份配置
bash scripts/maintenance.sh backup
```

---

## 故障排查

1. **OpenClaw 无法启动**: 检查 `docker-compose logs` 输出
2. **Telegram 消息不通**: 确认 Bot Token 正确，服务器能访问 `api.telegram.org`
3. **定时任务不触发**: 运行 `openclaw cron list` 确认任务已注册
4. **服务器被回收**: 确保已升级为 Pay As You Go 账户

## 参考链接

- [OpenClaw 官方文档](https://docs.openclaw.ai/)
- [OpenClaw GitHub](https://github.com/openclaw/openclaw)
- [CN-IM Docker 版本](https://github.com/justlovemaki/OpenClaw-Docker-CN-IM)
- [Oracle Cloud 部署指南](https://docs.openclaw.ai/platforms/oracle)
- [Cron Jobs 文档](https://docs.openclaw.ai/automation/cron-jobs)
