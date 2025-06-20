# Monitor4DingTalk

![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

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
├── logs/                     # 日志目录
└── requirements.txt          # 依赖管理
```

## 🚀 快速开始

### 环境要求

- Python 3.8+
- Linux/macOS/Windows (推荐Linux)

### 安装

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
```

#### 2. 查看系统状态
```bash
python src/main.py --status
```

#### 3. 执行一次监控检查
```bash
python src/main.py --once
```

#### 4. 启动监控服务
```bash
python src/main.py
```

#### 5. 后台运行（推荐）
```bash
nohup python src/main.py > /dev/null 2>&1 &
```

## ⚙️ 配置说明

### 基础配置

```yaml
# 钉钉机器人配置
dingtalk:
  webhook_url: "你的钉钉Webhook地址"
  secret: "你的加密secret"
  timeout: 10

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
    **时间**: {timestamp}
    **告警项**: {metric_name}
    **当前值**: {current_value}
    **告警阈值**: {threshold}
    **告警级别**: {level}
```

## 📊 监控指标

| 指标 | 说明 | 单位 | 默认阈值 |
|------|------|------|----------|
| CPU使用率 | 系统CPU平均使用率 | % | 80% |
| 内存使用率 | 物理内存使用率 | % | 85% |
| 磁盘使用率 | 指定路径磁盘使用率 | % | 90% |
| 网络IO | 网络流量统计（规划中） | bytes/s | - |

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

## 🚀 系统服务部署

### systemd服务配置

创建服务文件 `/etc/systemd/system/monitor4dingtalk.service`：

```ini
[Unit]
Description=Monitor4DingTalk Server Resource Monitor
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/monitor4dingtalk
ExecStart=/usr/bin/python3 /path/to/monitor4dingtalk/src/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

启动和管理服务：
```bash
sudo systemctl daemon-reload
sudo systemctl enable monitor4dingtalk
sudo systemctl start monitor4dingtalk
sudo systemctl status monitor4dingtalk
```

## 🔍 故障排查

### 常见问题

1. **钉钉消息发送失败**
   - 检查Webhook地址和secret配置
   - 确认网络连接正常
   - 查看日志文件中的错误信息

2. **监控数据异常**
   - 检查系统权限
   - 确认psutil库安装正确
   - 验证配置文件格式

3. **服务无法启动**
   - 检查Python版本和依赖
   - 确认配置文件路径正确
   - 查看详细错误日志

### 调试模式

修改配置文件中的日志级别为DEBUG：
```yaml
logging:
  level: "DEBUG"
```

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