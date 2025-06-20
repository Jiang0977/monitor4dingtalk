#!/bin/bash

# Monitor4DingTalk 环境检查脚本

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 环境检查${NC}"
echo -e "${BLUE}=================================================${NC}"

echo -e "\n${YELLOW}1. 系统信息${NC}"
echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"')"
echo "当前用户: $(whoami)"

echo -e "\n${YELLOW}2. Python环境${NC}"
PYTHON_OK=false
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        version=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
        echo "$cmd: $version ($(which $cmd))"
        if [[ "$version" > "3.7" ]]; then
            echo -e "  ${GREEN}✅ 满足要求${NC}"
            PYTHON_OK=true
        else
            echo -e "  ${RED}❌ 版本过低${NC}"
        fi
    fi
done

if [[ "$PYTHON_OK" == "false" ]]; then
    echo -e "${RED}❌ 未找到合适的Python版本 (需要3.8+)${NC}"
else
    echo -e "${GREEN}✅ Python环境正常${NC}"
fi

echo -e "\n${YELLOW}3. 网络连接${NC}"
if curl -s --max-time 5 https://oapi.dingtalk.com >/dev/null; then
    echo -e "${GREEN}✅ 钉钉API连接正常${NC}"
else
    echo -e "${RED}❌ 无法连接钉钉API${NC}"
fi

echo -e "\n${YELLOW}4. 权限检查${NC}"
if [[ $EUID -eq 0 ]]; then
    echo -e "${GREEN}✅ 具有root权限${NC}"
else
    echo -e "${YELLOW}⚠️  当前不是root用户，安装时需要sudo${NC}"
fi

echo -e "\n${YELLOW}5. 应用状态${NC}"
if [[ -d "/opt/monitor4dingtalk" ]]; then
    echo -e "${GREEN}✅ 应用已安装${NC}"
    if systemctl is-active --quiet monitor4dingtalk; then
        echo -e "${GREEN}✅ 服务正在运行${NC}"
    else
        echo -e "${YELLOW}⚠️  服务未运行${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  应用未安装${NC}"
fi

echo ""
echo -e "${BLUE}环境检查完成${NC}" 