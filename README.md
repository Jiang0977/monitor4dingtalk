# Monitor4DingTalk

![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**[English](README_EN.md) | 中文**

服务器资源监控钉钉告警系统 - 提供7×24小时服务器资源监控，及时发现系统异常并通过钉钉机器人推送告警信息。

## ✨ 功能特性

- 🖥️ **多指标监控**: CPU、内存、磁盘使用率实时监控
- 📱 **钉钉告警**: 支持钉钉机器人消息推送，支持加密签名
- ⚙️ **灵活配置**: YAML配置文件，支持自定义阈值和监控频率
- 🔄 **智能去重**: 避免重复告警，支持告警恢复通知
- 📊 **详细日志**: 完整的监控日志和告警历史记录
- 🎯 **轻量级**: 基于Python，资源占用低，部署简单

## 🏗️ 系统架构

```
Monitor4DingTalk/
├── src/
│   ├── core/                 # 核心监控模块
│   │   ├── monitor.py        # 资源监控引擎
│   │   └── alert.py          # 告警处理引擎
│   ├── services/             # 应用服务层
│   │   ├── config.py         # 配置管理服务
│   │   ├── dingtalk.py       # 钉钉推送服务
│   │   └── logger.py         # 日志记录服务
│   ├── utils/                # 工具模块
│   │   └── scheduler.py      # 调度器
│   └── main.py               # 程序入口
├── config/
│   └── config.yaml           # 配置文件
├── deploy/                   # 部署配置
│   ├── scripts/              # 部署脚本
│   ├── docker/               # Docker配置
│   └── systemd/              # 系统服务配置
├── logs/                     # 日志目录
└── requirements.txt          # 依赖管理
```

## 🚀 快速开始

### 环境要求

- Python 3.6+
- Linux/macOS/Windows (推荐Linux)

### 开发环境安装

1. **克隆项目**
```bash
git clone https://github.com/Jiang0977/monitor4dingtalk.git
cd monitor4dingtalk
```

2. **安装依赖**
```bash
pip install -r requirements.txt
```

3. **配置钉钉机器人**
   
   在钉钉群中添加自定义机器人：
   - 打开钉钉群 → 群设置 → 机器人 → 添加机器人
   - 选择"自定义"机器人
   - 复制Webhook地址和加密secret

4. **修改配置文件**
```bash
cp config/config.yaml config/config.yaml.bak
vim config/config.yaml
```

更新钉钉配置：
```yaml
dingtalk:
  webhook_url: "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  secret: "YOUR_SECRET"
```

### 使用方法

#### 1. 测试钉钉连接
```bash
python src/main.py --test
# 或使用启动脚本
./start.sh test
```

#### 2. 查看系统状态
```bash
python src/main.py --status
# 或使用启动脚本
./start.sh status
```

#### 3. 执行一次监控检查
```bash
python src/main.py --once
# 或使用启动脚本
./start.sh once
```

#### 4. 启动监控服务
```bash
python src/main.py
# 或使用启动脚本
./start.sh start
```

#### 5. 后台运行（开发环境）
```bash
nohup python src/main.py > /dev/null 2>&1 &
# 或使用启动脚本
./start.sh daemon
```

## 📋 生产环境部署

### 方式一：自动化脚本部署（推荐）

```bash
# 1. 下载项目代码
git clone https://github.com/Jiang0977/monitor4dingtalk.git
cd monitor4dingtalk

# 2. 运行自动化部署脚本
sudo bash deploy/scripts/install.sh

# 3. 编辑配置文件
sudo vim /opt/monitor4dingtalk/config/config.yaml

# 4. 重启服务
sudo systemctl restart monitor4dingtalk
```

### 方式二：手动部署

详细的手动部署步骤请参考 [生产环境部署指南](deploy/README.md)

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

### 部署后验证

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

### 常用管理命令

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

## ⚙️ 配置说明

### 基础配置

```yaml
# 钉钉机器人配置
dingtalk:
  webhook_url: "你的钉钉Webhook地址"
  secret: "你的加密secret"
  timeout: 10

# 服务器信息配置
server:
  ip_mode: "auto"           # IP获取模式：auto/public/private/manual
  manual_ip: ""             # 手动指定的IP地址
  public_ip_timeout: 5      # 外网IP获取超时时间（秒）

# 监控配置
monitor:
  interval: 60  # 监控间隔（秒）
  
  cpu:
    enabled: true
    threshold: 80.0  # CPU使用率告警阈值
    
  memory:
    enabled: true
    threshold: 85.0  # 内存使用率告警阈值
    
  disk:
    enabled: true
    threshold: 90.0  # 磁盘使用率告警阈值
    paths:
      - "/"
      - "/home"
```

### 告警配置

```yaml
alert:
  dedup_window: 300  # 告警去重时间窗口（秒）
  message_template: |  # 自定义告警消息模板
    🚨 服务器资源告警
    
    **服务器**: {hostname}
    **IP地址**: {server_ip}
    **时间**: {timestamp}
    **告警项**: {metric_name}
    **当前值**: {current_value}
    **告警阈值**: {threshold}
    **告警级别**: {level}
```

### IP地址获取模式说明

- **auto（自动模式）**: 先尝试获取外网IP，失败则使用内网IP（推荐）
- **public（强制外网IP）**: 仅获取外网IP，无法获取则报错
- **private（强制内网IP）**: 仅获取内网IP
- **manual（手动指定）**: 使用配置文件中手动指定的IP地址

### 生产环境配置建议

- **监控间隔**: 30-60秒（避免过于频繁）
- **告警阈值**: CPU 80%、内存 85%、磁盘 90%
- **去重窗口**: 10分钟（避免告警轰炸）
- **日志级别**: INFO（生产环境）
- **IP模式**: auto（推荐）或 public（如需外网IP）

## 📊 监控指标

| 指标 | 说明 | 单位 | 默认阈值 | 生产环境建议 |
|------|------|------|----------|--------------|
| CPU使用率 | 系统CPU平均使用率 | % | 80% | 0-70%正常，>80%告警 |
| 内存使用率 | 物理内存使用率 | % | 85% | 0-75%正常，>85%告警 |
| 磁盘使用率 | 指定路径磁盘使用率 | % | 90% | 0-80%正常，>90%告警 |
| 网络IO | 网络流量统计（规划中） | bytes/s | - | - |

## 🔧 命令行参数

```bash
python src/main.py [选项]

选项:
  -h, --help            显示帮助信息
  -c, --config FILE     指定配置文件路径 (默认: config/config.yaml)
  --test                测试钉钉连接
  --once                执行一次监控检查后退出
  --status              显示系统状态
  --version             显示版本信息
```

## 📝 日志管理

系统自动生成详细的运行日志：

- **日志文件**: `logs/monitor.log`
- **日志轮转**: 单文件最大10MB，保留5个历史文件
- **日志级别**: DEBUG、INFO、WARNING、ERROR、CRITICAL

查看实时日志：
```bash
tail -f logs/monitor.log
```

## 🔍 故障排查

### 常见问题

1. **钉钉消息发送失败**
   ```bash
   # 测试钉钉连接
   ./start.sh test
   # 或
   python src/main.py --test
   ```
   - 检查Webhook地址和secret配置
   - 确认网络连接正常
   - 查看日志文件中的错误信息

2. **监控数据异常**
   ```bash
   # 查看系统状态
   ./start.sh status
   ```
   - 检查系统权限
   - 确认psutil库安装正确
   - 验证配置文件格式

3. **服务无法启动**
   ```bash
   # 生产环境
   sudo journalctl -u monitor4dingtalk -n 50
   
   # 开发环境
   python src/main.py --status
   ```
   - 检查Python版本和依赖
   - 确认配置文件路径正确
   - 查看详细错误日志

4. **资源使用过高**
   ```bash
   # 生产环境
   top -p $(pgrep -f monitor4dingtalk)
   
   # 调整日志级别
   sed -i 's/level: "INFO"/level: "WARNING"/' config/config.yaml
   ```

### 调试模式

修改配置文件中的日志级别为DEBUG：
```yaml
logging:
  level: "DEBUG"
```

### 获取支持

如遇到问题，请收集以下信息：
- 系统版本: `cat /etc/os-release`
- Python版本: `python3 --version`
- 服务状态: `sudo systemctl status monitor4dingtalk` (生产环境)
- 错误日志: `sudo journalctl -u monitor4dingtalk -n 100` (生产环境)
- 配置文件: `cat config/config.yaml` (注意隐藏敏感信息)

## 🚀 系统服务部署

### systemd服务配置

对于生产环境，推荐使用systemd服务：

```bash
# 使用自动化脚本部署
sudo bash deploy/scripts/install.sh

# 或手动配置服务
sudo cp deploy/systemd/monitor4dingtalk.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable monitor4dingtalk
sudo systemctl start monitor4dingtalk
```

## 📈 性能优化

### 系统级优化
- 调整系统文件句柄限制
- 合理配置资源限制
- 定期清理日志文件

### 应用级优化
- 适当调整监控间隔（30-60秒）
- 合理设置告警去重时间窗口
- 监控应用自身的资源使用

## 🔒 安全建议

### 文件权限
- 保护配置文件权限 (600)
- 使用专用用户运行服务
- 设置正确的目录权限

### 网络安全
- 使用HTTPS连接钉钉API
- 定期更新钉钉机器人secret
- 监控异常网络请求

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork项目
2. 创建特性分支
3. 提交代码
4. 发起Pull Request

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 📞 联系方式

如有问题或建议，请提交[Issue](https://github.com/Jiang0977/monitor4dingtalk/issues)。

---

**Monitor4DingTalk** - 让服务器监控变得简单高效！ 🚀 