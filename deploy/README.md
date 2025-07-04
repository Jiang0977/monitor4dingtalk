# Monitor4DingTalk 部署指南

本目录包含了Monitor4DingTalk的简化部署脚本，专注于快速安装和使用。

## 系统要求

- **操作系统**: Linux (推荐 CentOS 7+/Ubuntu 16.04+)
- **Python版本**: 3.6+ (兼容Python 3.6、3.7、3.8、3.9、3.10等)
- **权限**: root 或 sudo 权限（用于系统服务安装）
- **网络**: 需要访问钉钉API和外网（用于安装依赖包）

## 快速部署

### 方法一：自动安装脚本（推荐）

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

# 如果使用conda环境（推荐）
conda activate your_env  # 先激活conda环境
sudo -E bash deploy/scripts/install_conda.sh
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

## 配置说明

编辑配置文件时，主要需要修改以下内容：

```yaml
# 钉钉机器人配置（必须配置）
dingtalk:
  webhook_url: "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  secret: "YOUR_SECRET_KEY"

# 监控阈值（可选调整）
monitor:
  interval: 30        # 监控间隔（秒）
  cpu:
    threshold: 80.0   # CPU告警阈值（%）
  memory:
    threshold: 85.0   # 内存告警阈值（%）
  disk:
    threshold: 90.0   # 磁盘告警阈值（%）
```

## Conda环境部署

如果您的生产环境使用conda管理Python环境，请按以下步骤操作：

### 1. 准备conda环境
```bash
# 检查当前conda环境
conda info --envs

# 激活您想要使用的conda环境
conda activate your_env_name

# 确认Python版本
python --version
```

### 2. 安装应用
```bash
# 使用专门的conda安装脚本
sudo -E bash deploy/scripts/install_conda.sh
```

### 3. 验证安装
```bash
# 检查服务状态
sudo systemctl status monitor4dingtalk

# 手动测试
cd /opt/monitor4dingtalk
sudo -u monitor python src/main.py --test
```

### 注意事项
- 使用 `sudo -E` 保持环境变量
- 确保conda环境在安装时处于激活状态
- 如果conda安装路径不是默认的 `/root/miniconda3`，需要修改 `start_conda.sh` 脚本

## 故障排查

1. **Python版本检测失败**
   ```bash
   # 查看系统中所有Python版本
   which -a python python3
   
   # 测试Python版本
   python -c "import sys; print(sys.version)"
   python3 -c "import sys; print(sys.version)"
   ```

2. **服务启动失败**
   ```bash
   # 检查Python环境
   bash deploy/scripts/check_env.sh
   
   # 查看详细错误
   sudo journalctl -u monitor4dingtalk -n 20
   ```

3. **钉钉消息发送失败**
   ```bash
   # 测试钉钉连接
   cd /opt/monitor4dingtalk
   python3 src/main.py --test
   ```

4. **Conda环境问题**
   ```bash
   # 检查conda环境是否正确激活
   echo $CONDA_DEFAULT_ENV
   which python
   
   # 重新创建启动脚本
   sudo vim /opt/monitor4dingtalk/start_conda.sh
   ```

5. **权限问题**：确保使用sudo权限运行安装脚本

## 文件位置

- 应用目录：`/opt/monitor4dingtalk`
- 配置文件：`/opt/monitor4dingtalk/config/config.yaml`
- 日志文件：`/opt/monitor4dingtalk/logs/monitor.log`
- 服务配置：`/etc/systemd/system/monitor4dingtalk.service`

## 高级配置

### 日志轮转
系统会自动管理日志文件，如需自定义可创建：
```bash
sudo vim /etc/logrotate.d/monitor4dingtalk
```

### 开机自启
安装后服务会自动设置开机启动，如需禁用：
```bash
sudo systemctl disable monitor4dingtalk
``` 