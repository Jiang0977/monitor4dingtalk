# Monitor4DingTalk Docker 镜像
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    procps \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 创建非root用户
RUN useradd -r -u 1000 monitor

# 复制依赖文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY src/ ./src/
COPY config/ ./config/
COPY start.sh ./

# 创建日志目录
RUN mkdir -p /var/log/monitor4dingtalk && \
    chown -R monitor:monitor /var/log/monitor4dingtalk && \
    chown -R monitor:monitor /app && \
    chmod +x start.sh

# 切换到非root用户
USER monitor

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python3 src/main.py --status || exit 1

# 暴露端口（如果需要）
# EXPOSE 8080

# 设置环境变量
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# 启动命令
CMD ["python3", "src/main.py"] 