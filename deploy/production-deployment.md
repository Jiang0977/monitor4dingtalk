# Monitor4DingTalk 生产环境部署指南

## 📋 部署前准备

### 系统要求
- **操作系统**: Linux (Ubuntu 18.04+, CentOS 7+, RHEL 8+)
- **Python版本**: 3.8+
- **内存**: 最小512MB，推荐1GB+
- **磁盘空间**: 最小1GB，推荐5GB+
- **网络**: 能访问钉钉API（oapi.dingtalk.com）

### 环境检查
```bash
# 检查Python版本
python3 --version

# 检查网络连通性
curl -I https://oapi.dingtalk.com

# 检查系统资源
free -h
df -h
```

## 🚀 部署步骤

### 1. 创建专用用户
```bash
# 创建monitor用户
sudo useradd -r -s /bin/bash -d /opt/monitor4dingtalk monitor

# 创建应用目录
sudo mkdir -p /opt/monitor4dingtalk
sudo chown monitor:monitor /opt/monitor4dingtalk
```

### 2. 部署应用代码
```bash
# 切换到monitor用户
sudo su - monitor

# 克隆或复制代码到部署目录
cd /opt/monitor4dingtalk
# 将代码复制到此目录

# 安装Python依赖
pip3 install --user -r requirements.txt

# 验证安装
python3 src/main.py --version
```

### 3. 配置文件调整
```bash
# 复制配置文件
cp config/config.yaml config/config.yaml.bak

# 编辑生产配置
vim config/config.yaml
```

**生产环境配置建议**:
```yaml
# 钉钉机器人配置
dingtalk:
  webhook_url: "YOUR_PRODUCTION_WEBHOOK_URL"
  secret: "YOUR_PRODUCTION_SECRET"
  timeout: 15  # 生产环境建议稍长

# 监控配置
monitor:
  interval: 30  # 生产环境建议30秒
  
  cpu:
    enabled: true
    threshold: 80.0
    
  memory:
    enabled: true
    threshold: 85.0  # 恢复正常阈值
    
  disk:
    enabled: true
    threshold: 90.0
    paths:
      - "/"
      - "/var"
      - "/opt"

# 告警配置
alert:
  dedup_window: 600  # 生产环境建议10分钟去重

# 日志配置
logging:
  level: "INFO"  # 生产环境使用INFO级别
  file: "/var/log/monitor4dingtalk/monitor.log"
  max_size: 52428800  # 50MB
  backup_count: 10    # 保留更多历史日志
```

### 4. 创建日志目录
```bash
# 创建日志目录
sudo mkdir -p /var/log/monitor4dingtalk
sudo chown monitor:monitor /var/log/monitor4dingtalk

# 创建应用日志目录
mkdir -p /opt/monitor4dingtalk/logs
```

### 5. 配置系统服务

创建systemd服务文件：
```bash
sudo vim /etc/systemd/system/monitor4dingtalk.service
```

服务配置内容：
```ini
[Unit]
Description=Monitor4DingTalk Server Resource Monitor
Documentation=https://github.com/Jiang0977/monitor4dingtalk
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=monitor
Group=monitor
WorkingDirectory=/opt/monitor4dingtalk
ExecStart=/usr/bin/python3 /opt/monitor4dingtalk/src/main.py
ExecReload=/bin/kill -HUP $MAINPID

# 重启策略
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# 资源限制
LimitNOFILE=65536
MemoryMax=256M

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/monitor4dingtalk /var/log/monitor4dingtalk

# 环境变量
Environment=PYTHONPATH=/opt/monitor4dingtalk
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

### 6. 启动和配置服务
```bash
# 重新加载systemd配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable monitor4dingtalk

# 启动服务
sudo systemctl start monitor4dingtalk

# 检查服务状态
sudo systemctl status monitor4dingtalk

# 查看服务日志
sudo journalctl -u monitor4dingtalk -f
```

## 🔧 生产环境优化

### 1. 日志轮转配置
创建logrotate配置：
```bash
sudo vim /etc/logrotate.d/monitor4dingtalk
```

```
/var/log/monitor4dingtalk/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 monitor monitor
    postrotate
        /bin/systemctl reload monitor4dingtalk || true
    endscript
}
```

### 2. 防火墙配置
```bash
# 如果使用iptables
sudo iptables -A OUTPUT -p tcp --dport 443 -d oapi.dingtalk.com -j ACCEPT

# 如果使用ufw
sudo ufw allow out 443
```

### 3. 监控脚本
创建健康检查脚本：
```bash
vim /opt/monitor4dingtalk/scripts/health_check.sh
```

```bash
#!/bin/bash

SERVICE_NAME="monitor4dingtalk"
LOG_FILE="/var/log/monitor4dingtalk/health_check.log"

check_service() {
    if systemctl is-active --quiet $SERVICE_NAME; then
        echo "$(date): Service is running" >> $LOG_FILE
        return 0
    else
        echo "$(date): Service is not running, attempting restart" >> $LOG_FILE
        systemctl restart $SERVICE_NAME
        return 1
    fi
}

check_service
```

添加到crontab：
```bash
# 每5分钟检查一次服务状态
*/5 * * * * /opt/monitor4dingtalk/scripts/health_check.sh
```

## 📊 监控和维护

### 1. 服务状态检查
```bash
# 检查服务状态
sudo systemctl status monitor4dingtalk

# 查看实时日志
sudo journalctl -u monitor4dingtalk -f

# 查看应用日志
tail -f /var/log/monitor4dingtalk/monitor.log

# 检查资源使用
top -p $(pgrep -f monitor4dingtalk)
```

### 2. 配置更新
```bash
# 修改配置后重新加载
sudo systemctl reload monitor4dingtalk

# 如果需要重启
sudo systemctl restart monitor4dingtalk
```

### 3. 备份和恢复
```bash
# 创建备份脚本
vim /opt/monitor4dingtalk/scripts/backup.sh
```

```bash
#!/bin/bash

BACKUP_DIR="/backup/monitor4dingtalk"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份配置文件
cp /opt/monitor4dingtalk/config/config.yaml $BACKUP_DIR/config_$DATE.yaml

# 备份日志文件
tar -czf $BACKUP_DIR/logs_$DATE.tar.gz /var/log/monitor4dingtalk/

# 清理7天前的备份
find $BACKUP_DIR -name "*.yaml" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

### 4. 性能监控
创建性能监控脚本：
```bash
vim /opt/monitor4dingtalk/scripts/performance_monitor.sh
```

```bash
#!/bin/bash

PID=$(pgrep -f monitor4dingtalk)
if [ -n "$PID" ]; then
    echo "=== Monitor4DingTalk Performance Report ===" 
    echo "Date: $(date)"
    echo "PID: $PID"
    echo "CPU Usage: $(ps -p $PID -o %cpu --no-headers)%"
    echo "Memory Usage: $(ps -p $PID -o %mem --no-headers)%"
    echo "Memory (RSS): $(ps -p $PID -o rss --no-headers) KB"
    echo "Uptime: $(ps -p $PID -o etime --no-headers)"
    echo "============================================"
fi
```

## 🔍 故障排除

### 常见问题和解决方案

#### 1. 服务启动失败
```bash
# 查看详细错误信息
sudo journalctl -u monitor4dingtalk -n 50

# 检查配置文件语法
python3 -c "import yaml; yaml.safe_load(open('config/config.yaml'))"

# 检查权限
ls -la /opt/monitor4dingtalk/
ls -la /var/log/monitor4dingtalk/
```

#### 2. 钉钉消息发送失败
```bash
# 测试钉钉连接
cd /opt/monitor4dingtalk
python3 src/main.py --test

# 检查网络连通性
curl -X POST "YOUR_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  -d '{"msgtype": "text", "text": {"content": "test"}}'
```

#### 3. 内存或CPU使用过高
```bash
# 查看详细资源使用
ps aux | grep monitor4dingtalk
top -p $(pgrep -f monitor4dingtalk)

# 调整日志级别
sed -i 's/level: "INFO"/level: "WARNING"/' config/config.yaml
sudo systemctl reload monitor4dingtalk
```

#### 4. 日志文件过大
```bash
# 手动轮转日志
sudo logrotate -f /etc/logrotate.d/monitor4dingtalk

# 检查磁盘空间
df -h /var/log
```

## 🔒 安全建议

### 1. 文件权限
```bash
# 设置正确的文件权限
sudo chown -R monitor:monitor /opt/monitor4dingtalk
sudo chmod 755 /opt/monitor4dingtalk
sudo chmod 600 /opt/monitor4dingtalk/config/config.yaml
sudo chmod +x /opt/monitor4dingtalk/start.sh
```

### 2. 配置文件保护
```bash
# 保护敏感配置信息
sudo chmod 600 /opt/monitor4dingtalk/config/config.yaml

# 或者使用环境变量
export DINGTALK_WEBHOOK_URL="your_webhook_url"
export DINGTALK_SECRET="your_secret"
```

### 3. 网络安全
- 使用HTTPS连接钉钉API
- 定期更新钉钉机器人的secret
- 监控异常的网络请求

## 📈 性能优化

### 1. 系统级优化
```bash
# 调整系统文件句柄限制
echo "monitor soft nofile 65536" >> /etc/security/limits.conf
echo "monitor hard nofile 65536" >> /etc/security/limits.conf
```

### 2. 应用级优化
- 适当调整监控间隔（30-60秒）
- 合理设置告警去重时间窗口
- 定期清理过期日志文件

### 3. 资源监控
```bash
# 创建资源监控脚本
vim /opt/monitor4dingtalk/scripts/resource_monitor.sh
```

```bash
#!/bin/bash

LOG_FILE="/var/log/monitor4dingtalk/resource_usage.log"
PID=$(pgrep -f monitor4dingtalk)

if [ -n "$PID" ]; then
    CPU=$(ps -p $PID -o %cpu --no-headers)
    MEM=$(ps -p $PID -o %mem --no-headers)
    echo "$(date '+%Y-%m-%d %H:%M:%S') - CPU: ${CPU}% MEM: ${MEM}%" >> $LOG_FILE
fi
```

## 🎯 部署验证

### 验证清单
- [ ] 服务正常启动并运行
- [ ] 日志文件正常写入
- [ ] 钉钉连接测试通过
- [ ] 监控数据采集正常
- [ ] 告警功能测试通过
- [ ] 开机自启动配置正确
- [ ] 日志轮转配置生效
- [ ] 资源使用在合理范围内

### 最终测试
```bash
# 1. 服务状态检查
sudo systemctl status monitor4dingtalk

# 2. 功能测试
cd /opt/monitor4dingtalk
./start.sh test
./start.sh once

# 3. 压力测试（可选）
# 临时调低内存阈值触发告警
sed -i 's/threshold: 85.0/threshold: 5.0/' config/config.yaml
sudo systemctl reload monitor4dingtalk
# 观察告警是否正常发送，然后恢复配置
```

## 📞 技术支持

如遇到部署问题，请收集以下信息：
- 系统版本: `cat /etc/os-release`
- Python版本: `python3 --version`
- 服务状态: `sudo systemctl status monitor4dingtalk`
- 错误日志: `sudo journalctl -u monitor4dingtalk -n 100`
- 配置文件: `cat config/config.yaml` (注意隐藏敏感信息)

---

🎉 **恭喜！您的Monitor4DingTalk生产环境部署完成！** 