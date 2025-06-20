#!/bin/bash

# 修复Python SSL模块问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    修复Python SSL模块问题${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 检查系统版本
if [[ -f /etc/redhat-release ]]; then
    OS_TYPE="redhat"
    echo -e "${YELLOW}检测到RedHat/CentOS系统${NC}"
elif [[ -f /etc/debian_version ]]; then
    OS_TYPE="debian"
    echo -e "${YELLOW}检测到Debian/Ubuntu系统${NC}"
else
    echo -e "${RED}❌ 不支持的操作系统${NC}"
    exit 1
fi

# 安装SSL开发库
echo -e "${YELLOW}安装SSL开发库...${NC}"
if [[ "$OS_TYPE" == "redhat" ]]; then
    yum install -y openssl-devel libffi-devel
elif [[ "$OS_TYPE" == "debian" ]]; then
    apt-get update
    apt-get install -y libssl-dev libffi-dev
fi

# 检查Python 3.10的SSL支持
PYTHON310="/usr/local/bin/python3.10"
echo -e "${YELLOW}检查Python 3.10的SSL支持...${NC}"

if $PYTHON310 -c "import ssl; print('SSL模块可用')" 2>/dev/null; then
    echo -e "${GREEN}✅ Python 3.10 SSL模块正常${NC}"
else
    echo -e "${RED}❌ Python 3.10 SSL模块不可用${NC}"
    echo -e "${YELLOW}需要重新编译Python或使用系统包管理器安装${NC}"
    
    # 尝试安装系统Python 3.8+
    echo -e "${YELLOW}尝试安装系统Python...${NC}"
    if [[ "$OS_TYPE" == "redhat" ]]; then
        # CentOS 7 需要启用EPEL和SCL
        yum install -y epel-release centos-release-scl
        yum install -y python38 python38-pip python38-devel
        
        # 创建软链接
        if [[ -f /opt/rh/python38/root/usr/bin/python3.8 ]]; then
            ln -sf /opt/rh/python38/root/usr/bin/python3.8 /usr/local/bin/python3.8
            ln -sf /opt/rh/python38/root/usr/bin/pip3.8 /usr/local/bin/pip3.8
            echo -e "${GREEN}✅ 已安装Python 3.8${NC}"
        fi
    elif [[ "$OS_TYPE" == "debian" ]]; then
        apt-get install -y python3.8 python3.8-pip python3.8-dev
    fi
fi

# 测试可用的Python版本
echo -e "${YELLOW}测试可用的Python版本...${NC}"
for python_cmd in python3.10 python3.9 python3.8 python3; do
    if command -v "$python_cmd" &>/dev/null; then
        if $python_cmd -c "import ssl; print('$python_cmd: SSL OK')" 2>/dev/null; then
            echo -e "${GREEN}✅ $python_cmd 可用且支持SSL${NC}"
        else
            echo -e "${RED}❌ $python_cmd 不支持SSL${NC}"
        fi
    fi
done

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    修复完成${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "${YELLOW}请重新运行部署脚本:${NC}"
echo "bash deploy/scripts/install.sh" 