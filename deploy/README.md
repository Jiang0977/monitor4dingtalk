# Monitor4DingTalk 生产环境部署指南

## 📋 快速部署

### 方式一：自动化脚本部署（推荐）

```bash
# 1. 下载项目代码
git clone <your-repo-url>
cd monitor4dingtalk

# 2. 运行自动化部署脚本
sudo bash deploy/scripts/install.sh

# 3. 编辑配置文件
sudo vim /opt/monitor4dingtalk/config/config.yaml

# 4. 重启服务
sudo systemctl restart monitor4dingtalk
```

### 方式二：手动部署

详细的手动部署步骤请参考 [生产环境部署指南](production-deployment.md)

### 方式三：Docker部署

```bash
# 1. 进入Docker目录
cd deploy/docker

# 2. 复制配置文件
cp ../../config/config.yaml ./config.yaml

# 3. 编辑配置文件
vim config.yaml

# 4. 启动容器
docker-compose up -d

# 5. 查看日志
docker-compose logs -f
```

## 🚀 部署后验证

```bash
# 检查服务状态
sudo systemctl status monitor4dingtalk

# 测试功能
cd /opt/monitor4dingtalk
sudo -u monitor ./start.sh test
sudo -u monitor ./start.sh once

# 查看日志
sudo journalctl -u monitor4dingtalk -f
```

## 🔧 常用管理命令

```bash
# 服务管理
sudo systemctl start monitor4dingtalk     # 启动服务
sudo systemctl stop monitor4dingtalk      # 停止服务
sudo systemctl restart monitor4dingtalk   # 重启服务
sudo systemctl status monitor4dingtalk    # 查看状态

# 配置管理
sudo systemctl reload monitor4dingtalk    # 重新加载配置

# 日志查看
sudo journalctl -u monitor4dingtalk -f    # 查看实时日志
sudo journalctl -u monitor4dingtalk -n 100 # 查看最近100行日志
```

## 📊 生产环境建议

### 配置优化
- **监控间隔**: 30-60秒（避免过于频繁）
- **告警阈值**: CPU 80%、内存 85%、磁盘 90%
- **去重窗口**: 10分钟（避免告警轰炸）
- **日志级别**: INFO（生产环境）

### 安全配置
- 保护配置文件权限 (600)
- 使用专用用户运行服务
- 定期更新钉钉机器人secret
- 监控异常网络请求

### 性能优化
- 设置合理的资源限制
- 定期清理日志文件
- 监控应用自身的资源使用

## 🔍 故障排查

### 常见问题

1. **服务启动失败**
   ```bash
   sudo journalctl -u monitor4dingtalk -n 50
   ```

2. **钉钉消息发送失败**
   ```bash
   cd /opt/monitor4dingtalk
   sudo -u monitor python3 src/main.py --test
   ```

3. **资源使用过高**
   ```bash
   top -p $(pgrep -f monitor4dingtalk)
   ```

### 获取支持

如遇到问题，请收集以下信息：
- 系统版本: `cat /etc/os-release`
- Python版本: `python3 --version`
- 服务状态: `sudo systemctl status monitor4dingtalk`
- 错误日志: `sudo journalctl -u monitor4dingtalk -n 100`

## 📈 监控指标

| 指标 | 正常范围 | 告警阈值 | 说明 |
|------|----------|----------|------|
| CPU使用率 | 0-70% | >80% | 持续高CPU可能影响性能 |
| 内存使用率 | 0-75% | >85% | 内存不足可能导致系统卡顿 |
| 磁盘使用率 | 0-80% | >90% | 磁盘空间不足影响系统稳定性 |
| 应用内存 | <100MB | >200MB | 监控应用自身资源使用 |

---

🎉 **祝您部署顺利！** 