# Monitor4DingTalk 部署指南

本目录包含了Monitor4DingTalk的简化部署脚本，专注于快速安装和使用。

## 快速安装

### 1. 环境检查
```bash
# 检查系统环境是否满足要求
bash deploy/scripts/check_env.sh
```

### 2. 一键安装
```bash
# 使用简化安装脚本（推荐）
sudo bash deploy/scripts/simple_install.sh

# 或使用原安装脚本
sudo bash deploy/scripts/install.sh
```

### 3. 配置钉钉
```bash
# 编辑配置文件
sudo vi /opt/monitor4dingtalk/config/config.yaml

# 修改以下配置：
# dingtalk:
#   webhook_url: "你的钉钉机器人webhook地址"
#   secret: "你的钉钉机器人密钥"

# 重启服务使配置生效
sudo systemctl restart monitor4dingtalk
```

## 常用命令

```bash
# 查看服务状态
sudo systemctl status monitor4dingtalk

# 查看服务日志
sudo journalctl -u monitor4dingtalk -f

# 重启服务
sudo systemctl restart monitor4dingtalk

# 停止服务
sudo systemctl stop monitor4dingtalk

# 启动服务
sudo systemctl start monitor4dingtalk
```

## 测试和调试

```bash
# 测试应用是否正常工作
cd /opt/monitor4dingtalk
python3 src/main.py --version

# 测试配置文件
python3 src/main.py --test

# 执行一次监控检查
python3 src/main.py --once

# 查看应用状态
python3 src/main.py --status
```

## 卸载

```bash
# 卸载Monitor4DingTalk
sudo bash deploy/scripts/simple_uninstall.sh
```

## 系统要求

- Python 3.8+
- 系统管理员权限（sudo）
- 网络连接（能访问钉钉API）

## 故障排查

1. **服务启动失败**：检查Python环境和依赖是否正常安装
2. **钉钉消息发送失败**：检查webhook_url和secret配置是否正确
3. **权限问题**：确保使用sudo权限运行安装脚本

## 文件位置

- 应用目录：`/opt/monitor4dingtalk`
- 配置文件：`/opt/monitor4dingtalk/config/config.yaml`
- 日志文件：`/opt/monitor4dingtalk/logs/monitor.log`
- 服务配置：`/etc/systemd/system/monitor4dingtalk.service` 