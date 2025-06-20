#!/bin/bash

# Monitor4DingTalk 简化卸载脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 卸载${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 请使用root权限运行${NC}"
    echo "sudo $0"
    exit 1
fi

# 确认卸载
echo -e "${YELLOW}⚠️  即将卸载Monitor4DingTalk${NC}"
read -p "确认要继续吗？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}取消卸载${NC}"
    exit 0
fi

echo -e "${YELLOW}开始卸载...${NC}"

# 停止服务
echo -e "${YELLOW}停止服务...${NC}"
systemctl stop monitor4dingtalk 2>/dev/null || echo "服务未运行"
systemctl disable monitor4dingtalk 2>/dev/null || echo "服务未启用"

# 删除服务文件
rm -f /etc/systemd/system/monitor4dingtalk.service
systemctl daemon-reload

# 删除应用目录
echo -e "${YELLOW}删除应用文件...${NC}"
rm -rf /opt/monitor4dingtalk

echo -e "${GREEN}✅ 卸载完成${NC}" 