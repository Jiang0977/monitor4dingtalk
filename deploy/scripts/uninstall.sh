#!/bin/bash

# Monitor4DingTalk 卸载脚本

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
echo -e "${BLUE}    Monitor4DingTalk 卸载脚本${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 确认卸载
echo -e "${YELLOW}⚠️  即将卸载Monitor4DingTalk，包括：${NC}"
echo "  - 停止并删除systemd服务"
echo "  - 删除应用目录: $INSTALL_DIR"
echo "  - 删除日志目录: $LOG_DIR"
echo "  - 删除用户: $APP_USER"
echo "  - 删除配置文件"
echo ""

read -p "确认要继续卸载吗？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}取消卸载${NC}"
    exit 0
fi

echo -e "${YELLOW}开始卸载...${NC}"

# 停止并禁用服务
echo -e "${YELLOW}停止服务...${NC}"
systemctl stop $APP_NAME 2>/dev/null || echo "服务未运行"
systemctl disable $APP_NAME 2>/dev/null || echo "服务未启用"

# 删除systemd服务文件
echo -e "${YELLOW}删除systemd服务文件...${NC}"
rm -f $SERVICE_FILE

# 删除日志轮转配置
echo -e "${YELLOW}删除日志轮转配置...${NC}"
rm -f /etc/logrotate.d/$APP_NAME

# 删除目录
echo -e "${YELLOW}删除应用目录...${NC}"
rm -rf $INSTALL_DIR

echo -e "${YELLOW}删除日志目录...${NC}"
rm -rf $LOG_DIR

# 删除用户
echo -e "${YELLOW}删除用户...${NC}"
if id $APP_USER &>/dev/null; then
    userdel $APP_USER 2>/dev/null || echo "用户删除失败，可能正在使用中"
else
    echo "用户不存在"
fi

# 重新加载systemd
systemctl daemon-reload

echo ""
echo -e "${GREEN}✅ Monitor4DingTalk卸载完成！${NC}"
echo ""
echo -e "${YELLOW}注意事项：${NC}"
echo "  - 备份文件（如有）需要手动删除"
echo "  - 如果有自定义配置，请手动检查并清理" 