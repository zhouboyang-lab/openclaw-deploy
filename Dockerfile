FROM justlikemaki/openclaw-docker-cn-im:latest

# 升级 OpenClaw 到最新版（支持 Gemini 搜索等新功能）
RUN npm -g update openclaw
