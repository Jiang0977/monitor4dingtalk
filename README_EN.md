# Monitor4DingTalk

![Python](https://img.shields.io/badge/python-3.8+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**English | [中文](README.md)**

Server resource monitoring and DingTalk alert system - Provides 24/7 server resource monitoring, timely detection of system anomalies, and push alert messages through DingTalk robot.

## ✨ Features

- 🖥️ **Multi-metric Monitoring**: Real-time monitoring of CPU, memory, and disk usage
- 📱 **DingTalk Alerts**: Support for DingTalk robot message push with encryption signature
- ⚙️ **Flexible Configuration**: YAML configuration file with customizable thresholds and monitoring frequency
- 🔄 **Smart Deduplication**: Avoid duplicate alerts with alert recovery notifications
- 📊 **Detailed Logging**: Complete monitoring logs and alert history
- 🎯 **Lightweight**: Python-based, low resource usage, simple deployment

## 🏗️ System Architecture

```
Monitor4DingTalk/
├── src/
│   ├── core/                 # Core monitoring modules
│   │   ├── monitor.py        # Resource monitoring engine
│   │   └── alert.py          # Alert processing engine
│   ├── services/             # Application service layer
│   │   ├── config.py         # Configuration management service
│   │   ├── dingtalk.py       # DingTalk push service
│   │   └── logger.py         # Logging service
│   ├── utils/                # Utility modules
│   │   └── scheduler.py      # Scheduler
│   └── main.py               # Program entry point
├── config/
│   └── config.yaml           # Configuration file
├── deploy/                   # Deployment configuration
│   ├── scripts/              # Deployment scripts
│   ├── docker/               # Docker configuration
│   └── systemd/              # System service configuration
├── logs/                     # Log directory
└── requirements.txt          # Dependency management
```

## 🚀 Quick Start

### Requirements

- Python 3.8+
- Linux/macOS/Windows (Linux recommended)

### Development Environment Installation

1. **Clone Project**
```bash
git clone https://github.com/Jiang0977/monitor4dingtalk.git
cd monitor4dingtalk
```

2. **Install Dependencies**
```bash
pip install -r requirements.txt
```

3. **Configure DingTalk Robot**
   
   Add a custom robot in DingTalk group:
   - Open DingTalk group → Group settings → Robot → Add robot
   - Select "Custom" robot
   - Copy Webhook URL and encryption secret

4. **Modify Configuration File**
```bash
cp config/config.yaml config/config.yaml.bak
vim config/config.yaml
```

Update DingTalk configuration:
```yaml
dingtalk:
  webhook_url: "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  secret: "YOUR_SECRET"
```

### Usage

#### 1. Test DingTalk Connection
```bash
python src/main.py --test
# Or use startup script
./start.sh test
```

#### 2. View System Status
```bash
python src/main.py --status
# Or use startup script
./start.sh status
```

#### 3. Execute One-time Monitoring Check
```bash
python src/main.py --once
# Or use startup script
./start.sh once
```

#### 4. Start Monitoring Service
```bash
python src/main.py
# Or use startup script
./start.sh start
```

#### 5. Run in Background (Development Environment)
```bash
nohup python src/main.py > /dev/null 2>&1 &
# Or use startup script
./start.sh daemon
```

## 📋 Production Deployment

### Method 1: Automated Script Deployment (Recommended)

```bash
# 1. Download project code
git clone https://github.com/Jiang0977/monitor4dingtalk.git
cd monitor4dingtalk

# 2. Run automated deployment script
sudo bash deploy/scripts/install.sh

# 3. Edit configuration file
sudo vim /opt/monitor4dingtalk/config/config.yaml

# 4. Restart service
sudo systemctl restart monitor4dingtalk
```

### Method 2: Manual Deployment

For detailed manual deployment steps, please refer to [Production Deployment Guide](deploy/production-deployment.md)

### Method 3: Docker Deployment

```bash
# 1. Enter Docker directory
cd deploy/docker

# 2. Copy configuration file
cp ../../config/config.yaml ./config.yaml

# 3. Edit configuration file
vim config.yaml

# 4. Start container
docker-compose up -d

# 5. View logs
docker-compose logs -f
```

### Post-deployment Verification

```bash
# Check service status
sudo systemctl status monitor4dingtalk

# Test functionality
cd /opt/monitor4dingtalk
sudo -u monitor ./start.sh test
sudo -u monitor ./start.sh once

# View logs
sudo journalctl -u monitor4dingtalk -f
```

### Common Management Commands

```bash
# Service management
sudo systemctl start monitor4dingtalk     # Start service
sudo systemctl stop monitor4dingtalk      # Stop service
sudo systemctl restart monitor4dingtalk   # Restart service
sudo systemctl status monitor4dingtalk    # View status

# Configuration management
sudo systemctl reload monitor4dingtalk    # Reload configuration

# Log viewing
sudo journalctl -u monitor4dingtalk -f    # View real-time logs
sudo journalctl -u monitor4dingtalk -n 100 # View last 100 lines
```

## ⚙️ Configuration

### Basic Configuration

```yaml
# DingTalk robot configuration
dingtalk:
  webhook_url: "Your DingTalk Webhook URL"
  secret: "Your encryption secret"
  timeout: 10

# Server information configuration
server:
  ip_mode: "auto"           # IP acquisition mode: auto/public/private/manual
  manual_ip: ""             # Manually specified IP address
  public_ip_timeout: 5      # Public IP acquisition timeout (seconds)

# Monitoring configuration
monitor:
  interval: 60  # Monitoring interval (seconds)
  
  cpu:
    enabled: true
    threshold: 80.0  # CPU usage alert threshold
    
  memory:
    enabled: true
    threshold: 85.0  # Memory usage alert threshold
    
  disk:
    enabled: true
    threshold: 90.0  # Disk usage alert threshold
    paths:
      - "/"
      - "/home"
```

### Alert Configuration

```yaml
alert:
  dedup_window: 300  # Alert deduplication time window (seconds)
  message_template: |  # Custom alert message template
    🚨 Server Resource Alert
    
    **Server**: {hostname}
    **IP Address**: {server_ip}
    **Time**: {timestamp}
    **Alert Item**: {metric_name}
    **Current Value**: {current_value}
    **Alert Threshold**: {threshold}
    **Alert Level**: {level}
```

### IP Address Acquisition Mode Description

- **auto (Auto Mode)**: Try to get public IP first, use private IP if failed (recommended)
- **public (Force Public IP)**: Only get public IP, error if unable to obtain
- **private (Force Private IP)**: Only get private IP
- **manual (Manual Specification)**: Use manually specified IP address in configuration

### Production Environment Configuration Recommendations

- **Monitoring Interval**: 30-60 seconds (avoid too frequent)
- **Alert Thresholds**: CPU 80%, Memory 85%, Disk 90%
- **Deduplication Window**: 10 minutes (avoid alert bombardment)
- **Log Level**: INFO (production environment)
- **IP Mode**: auto (recommended) or public (if public IP needed)

## 📊 Monitoring Metrics

| Metric | Description | Unit | Default Threshold | Production Recommendation |
|--------|-------------|------|-------------------|---------------------------|
| CPU Usage | System CPU average usage | % | 80% | 0-70% normal, >80% alert |
| Memory Usage | Physical memory usage | % | 85% | 0-75% normal, >85% alert |
| Disk Usage | Disk usage for specified paths | % | 90% | 0-80% normal, >90% alert |
| Network IO | Network traffic statistics (planned) | bytes/s | - | - |

## 🔧 Command Line Arguments

```bash
python src/main.py [options]

Options:
  -h, --help            Show help information
  -c, --config FILE     Specify configuration file path (default: config/config.yaml)
  --test                Test DingTalk connection
  --once                Execute one monitoring check and exit
  --status              Show system status
  --version             Show version information
```

## 📝 Log Management

The system automatically generates detailed runtime logs:

- **Log File**: `logs/monitor.log`
- **Log Rotation**: Maximum 10MB per file, keep 5 historical files
- **Log Levels**: DEBUG, INFO, WARNING, ERROR, CRITICAL

View real-time logs:
```bash
tail -f logs/monitor.log
```

## 🔍 Troubleshooting

### Common Issues

1. **DingTalk Message Send Failure**
   ```bash
   # Test DingTalk connection
   ./start.sh test
   # Or
   python src/main.py --test
   ```
   - Check Webhook URL and secret configuration
   - Confirm network connection is normal
   - Check error information in log files

2. **Abnormal Monitoring Data**
   ```bash
   # View system status
   ./start.sh status
   ```
   - Check system permissions
   - Confirm psutil library is installed correctly
   - Verify configuration file format

3. **Service Cannot Start**
   ```bash
   # Production environment
   sudo journalctl -u monitor4dingtalk -n 50
   
   # Development environment
   python src/main.py --status
   ```
   - Check Python version and dependencies
   - Confirm configuration file path is correct
   - View detailed error logs

4. **High Resource Usage**
   ```bash
   # Production environment
   top -p $(pgrep -f monitor4dingtalk)
   
   # Adjust log level
   sed -i 's/level: "INFO"/level: "WARNING"/' config/config.yaml
   ```

### Debug Mode

Modify the log level in the configuration file to DEBUG:
```yaml
logging:
  level: "DEBUG"
```

### Get Support

If you encounter problems, please collect the following information:
- System version: `cat /etc/os-release`
- Python version: `python3 --version`
- Service status: `sudo systemctl status monitor4dingtalk` (production environment)
- Error logs: `sudo journalctl -u monitor4dingtalk -n 100` (production environment)
- Configuration file: `cat config/config.yaml` (note to hide sensitive information)

## 🚀 System Service Deployment

### systemd Service Configuration

For production environments, systemd service is recommended:

```bash
# Use automated script deployment
sudo bash deploy/scripts/install.sh

# Or manually configure service
sudo cp deploy/systemd/monitor4dingtalk.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable monitor4dingtalk
sudo systemctl start monitor4dingtalk
```

## 📈 Performance Optimization

### System-level Optimization
- Adjust system file handle limits
- Configure reasonable resource limits
- Regularly clean up log files

### Application-level Optimization
- Appropriately adjust monitoring intervals (30-60 seconds)
- Set reasonable alert deduplication time windows
- Monitor the application's own resource usage

## 🔒 Security Recommendations

### File Permissions
- Protect configuration file permissions (600)
- Use dedicated users to run services
- Set correct directory permissions

### Network Security
- Use HTTPS connections to DingTalk API
- Regularly update DingTalk robot secret
- Monitor abnormal network requests

## 🤝 Contributing

Welcome to submit Issues and Pull Requests!

1. Fork the project
2. Create a feature branch
3. Submit code
4. Initiate a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Contact

For questions or suggestions, please submit an [Issue](https://github.com/Jiang0977/monitor4dingtalk/issues).

---

**Monitor4DingTalk** - Making server monitoring simple and efficient! 🚀 