#!/bin/bash

# Monitor4DingTalk 自动化部署脚本
# 适用于生产环境快速部署

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置变量
APP_NAME="monitor4dingtalk"
APP_USER="monitor"
INSTALL_DIR="/opt/monitor4dingtalk"
LOG_DIR="/var/log/monitor4dingtalk"
SERVICE_FILE="/etc/systemd/system/monitor4dingtalk.service"

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 生产环境自动化部署脚本${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
        echo "请使用: sudo $0"
        exit 1
    fi
}

# 检查系统要求
check_requirements() {
    echo -e "${YELLOW}检查系统要求...${NC}"
    
    # 检查操作系统
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${RED}❌ 不支持的操作系统${NC}"
        exit 1
    fi
    
    # 检查Python版本
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python3 未安装${NC}"
        echo "请先安装Python3: apt install python3 python3-pip"
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        echo -e "${RED}❌ Python版本过低: $python_version (需要 >= 3.8)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Python版本: $python_version${NC}"
    
    # 检查网络连通性
    if ! curl -s --max-time 10 https://oapi.dingtalk.com > /dev/null; then
        echo -e "${YELLOW}⚠️  无法连接到钉钉API，请检查网络配置${NC}"
    else
        echo -e "${GREEN}✅ 网络连通性正常${NC}"
    fi
}

# 创建用户和目录
setup_user_and_dirs() {
    echo -e "${YELLOW}创建用户和目录...${NC}"
    
    # 创建应用用户
    if ! id "$APP_USER" &>/dev/null; then
        useradd -r -s /bin/bash -d "$INSTALL_DIR" "$APP_USER"
        echo -e "${GREEN}✅ 创建用户: $APP_USER${NC}"
    else
        echo -e "${GREEN}✅ 用户已存在: $APP_USER${NC}"
    fi
    
    # 创建目录
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$INSTALL_DIR/scripts"
    
    # 设置权限
    chown -R "$APP_USER:$APP_USER" "$INSTALL_DIR"
    chown -R "$APP_USER:$APP_USER" "$LOG_DIR"
    
    echo -e "${GREEN}✅ 目录创建完成${NC}"
}

# 部署应用代码
deploy_application() {
    echo -e "${YELLOW}部署应用代码...${NC}"
    
    # 获取当前脚本目录的父目录
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    SOURCE_DIR="$( cd "$SCRIPT_DIR/../.." && pwd )"
    
    # 复制代码到部署目录
    rsync -av --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
          "$SOURCE_DIR/" "$INSTALL_DIR/"
    
    # 设置权限
    chown -R "$APP_USER:$APP_USER" "$INSTALL_DIR"
    chmod +x "$INSTALL_DIR/start.sh"
    chmod 600 "$INSTALL_DIR/config/config.yaml"
    
    echo -e "${GREEN}✅ 应用代码部署完成${NC}"
}

# 安装依赖
install_dependencies() {
    echo -e "${YELLOW}安装Python依赖...${NC}"
    
    # 切换到应用用户安装依赖
    sudo -u "$APP_USER" bash -c "cd $INSTALL_DIR && pip3 install --user -r requirements.txt"
    
    echo -e "${GREEN}✅ 依赖安装完成${NC}"
}

# 配置系统服务
setup_systemd_service() {
    echo -e "${YELLOW}配置系统服务...${NC}"
    
    # 创建systemd服务文件
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Monitor4DingTalk Server Resource Monitor
Documentation=https://github.com/Jiang0977/monitor4dingtalk
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/src/main.py
ExecReload=/bin/kill -HUP \$MAINPID

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
ReadWritePaths=$INSTALL_DIR $LOG_DIR

# 环境变量
Environment=PYTHONPATH=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

    # 重新加载systemd配置
    systemctl daemon-reload
    systemctl enable "$APP_NAME"
    
    echo -e "${GREEN}✅ 系统服务配置完成${NC}"
}

# 配置日志轮转
setup_logrotate() {
    echo -e "${YELLOW}配置日志轮转...${NC}"
    
    cat > "/etc/logrotate.d/$APP_NAME" << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 $APP_USER $APP_USER
    postrotate
        /bin/systemctl reload $APP_NAME || true
    endscript
}
EOF

    echo -e "${GREEN}✅ 日志轮转配置完成${NC}"
}

# 创建管理脚本
create_management_scripts() {
    echo -e "${YELLOW}创建管理脚本...${NC}"
    
    # 健康检查脚本
    cat > "$INSTALL_DIR/scripts/health_check.sh" << 'EOF'
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
EOF

    # 备份脚本
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'EOF'
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
EOF

    # 性能监控脚本
    cat > "$INSTALL_DIR/scripts/performance_monitor.sh" << 'EOF'
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
EOF

    # 设置脚本权限
    chmod +x "$INSTALL_DIR/scripts/"*.sh
    chown -R "$APP_USER:$APP_USER" "$INSTALL_DIR/scripts/"
    
    echo -e "${GREEN}✅ 管理脚本创建完成${NC}"
}

# 验证部署
verify_deployment() {
    echo -e "${YELLOW}验证部署...${NC}"
    
    # 检查应用是否能正常启动
    sudo -u "$APP_USER" bash -c "cd $INSTALL_DIR && python3 src/main.py --version"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 应用可以正常运行${NC}"
    else
        echo -e "${RED}❌ 应用无法正常运行${NC}"
        exit 1
    fi
    
    # 检查配置文件
    sudo -u "$APP_USER" bash -c "cd $INSTALL_DIR && python3 -c 'from src.services.config import config_manager; print(\"配置文件加载成功\")'"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 配置文件验证通过${NC}"
    else
        echo -e "${RED}❌ 配置文件验证失败${NC}"
        exit 1
    fi
}

# 启动服务
start_service() {
    echo -e "${YELLOW}启动服务...${NC}"
    
    systemctl start "$APP_NAME"
    sleep 3
    
    if systemctl is-active --quiet "$APP_NAME"; then
        echo -e "${GREEN}✅ 服务启动成功${NC}"
        systemctl status "$APP_NAME" --no-pager
    else
        echo -e "${RED}❌ 服务启动失败${NC}"
        echo -e "${YELLOW}查看详细错误信息:${NC}"
        journalctl -u "$APP_NAME" -n 20 --no-pager
        exit 1
    fi
}

# 显示部署后信息
show_post_deployment_info() {
    echo ""
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}            部署完成！${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo ""
    echo -e "${GREEN}📁 安装目录: $INSTALL_DIR${NC}"
    echo -e "${GREEN}📄 日志目录: $LOG_DIR${NC}"
    echo -e "${GREEN}⚙️  配置文件: $INSTALL_DIR/config/config.yaml${NC}"
    echo ""
    echo -e "${YELLOW}🔧 常用命令:${NC}"
    echo "  启动服务: sudo systemctl start $APP_NAME"
    echo "  停止服务: sudo systemctl stop $APP_NAME"
    echo "  重启服务: sudo systemctl restart $APP_NAME"
    echo "  查看状态: sudo systemctl status $APP_NAME"
    echo "  查看日志: sudo journalctl -u $APP_NAME -f"
    echo ""
    echo -e "${YELLOW}📋 下一步操作:${NC}"
    echo "1. 编辑配置文件: $INSTALL_DIR/config/config.yaml"
    echo "2. 配置钉钉Webhook URL和secret"
    echo "3. 调整监控阈值和间隔"
    echo "4. 测试钉钉连接: cd $INSTALL_DIR && ./start.sh test"
    echo "5. 执行一次监控: cd $INSTALL_DIR && ./start.sh once"
    echo ""
    echo -e "${GREEN}🎉 Monitor4DingTalk部署完成！${NC}"
}

# 主函数
main() {
    check_root
    check_requirements
    setup_user_and_dirs
    deploy_application
    install_dependencies
    setup_systemd_service
    setup_logrotate
    create_management_scripts
    verify_deployment
    start_service
    show_post_deployment_info
}

# 处理脚本参数
case "${1:-install}" in
    "install")
        main
        ;;
    "uninstall")
        echo -e "${YELLOW}卸载Monitor4DingTalk...${NC}"
        systemctl stop $APP_NAME || true
        systemctl disable $APP_NAME || true
        rm -f $SERVICE_FILE
        rm -f /etc/logrotate.d/$APP_NAME
        rm -rf $INSTALL_DIR
        rm -rf $LOG_DIR
        userdel $APP_USER || true
        systemctl daemon-reload
        echo -e "${GREEN}✅ 卸载完成${NC}"
        ;;
    "help")
        echo "用法: $0 [install|uninstall|help]"
        echo "  install   - 安装Monitor4DingTalk (默认)"
        echo "  uninstall - 卸载Monitor4DingTalk"
        echo "  help      - 显示帮助信息"
        ;;
    *)
        echo "未知参数: $1"
        echo "使用 '$0 help' 查看帮助信息"
        exit 1
        ;;
esac 