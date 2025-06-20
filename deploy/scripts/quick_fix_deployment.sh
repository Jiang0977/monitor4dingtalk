#!/bin/bash

# 快速修复当前部署问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 快速修复脚本${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 检测Python环境
PYTHON_FULL_PATH=$(which python)
echo -e "${YELLOW}检测到Python: $PYTHON_FULL_PATH${NC}"

# 验证应用
echo -e "${YELLOW}验证应用...${NC}"
cd /opt/monitor4dingtalk
if $PYTHON_FULL_PATH src/main.py --version; then
    echo -e "${GREEN}✅ 应用可以正常运行${NC}"
else
    echo -e "${RED}❌ 应用验证失败${NC}"
    exit 1
fi

# 验证配置文件
echo -e "${YELLOW}验证配置文件...${NC}"
if $PYTHON_FULL_PATH -c 'from src.services.config import config_manager; print("配置文件加载成功")'; then
    echo -e "${GREEN}✅ 配置文件验证通过${NC}"
else
    echo -e "${RED}❌ 配置文件验证失败${NC}"
    exit 1
fi

# 启动服务
echo -e "${YELLOW}启动服务...${NC}"
systemctl start monitor4dingtalk
sleep 3

if systemctl is-active --quiet monitor4dingtalk; then
    echo -e "${GREEN}✅ 服务启动成功${NC}"
    systemctl status monitor4dingtalk --no-pager
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    echo -e "${YELLOW}查看详细错误信息:${NC}"
    journalctl -u monitor4dingtalk -n 20 --no-pager
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 修复完成！Monitor4DingTalk已正常运行${NC}"
echo ""
echo -e "${YELLOW}常用命令:${NC}"
echo "  查看状态: sudo systemctl status monitor4dingtalk"
echo "  查看日志: sudo journalctl -u monitor4dingtalk -f"
echo "  测试功能: cd /opt/monitor4dingtalk && python src/main.py --test"
echo "  执行一次监控: cd /opt/monitor4dingtalk && python src/main.py --once" 