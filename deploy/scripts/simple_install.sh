#!/bin/bash

# Monitor4DingTalk 简化安装脚本
# 专注于快速部署，减少复杂配置

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 快速安装${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 请使用root权限运行${NC}"
    echo "sudo $0"
    exit 1
fi

# 简单的Python检测
PYTHON_CMD=""
for cmd in python3 python; do
    if command -v "$cmd" &>/dev/null; then
        version=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "0.0")
        if [[ "$version" > "3.7" ]]; then
            PYTHON_CMD="$cmd"
            echo -e "${GREEN}✅ 使用Python: $cmd ($version)${NC}"
            break
        fi
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    echo -e "${RED}❌ 需要Python 3.8+${NC}"
    exit 1
fi

# 创建目录
INSTALL_DIR="/opt/monitor4dingtalk"
mkdir -p "$INSTALL_DIR"

# 复制代码
echo -e "${YELLOW}复制应用代码...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cp -r "$SOURCE_DIR"/* "$INSTALL_DIR/"

# 安装依赖
echo -e "${YELLOW}安装Python依赖...${NC}"
cd "$INSTALL_DIR"
$PYTHON_CMD -m pip install psutil PyYAML requests schedule

# 验证安装
echo -e "${YELLOW}验证安装...${NC}"
if $PYTHON_CMD src/main.py --version &>/dev/null; then
    echo -e "${GREEN}✅ 应用安装成功${NC}"
else
    echo -e "${RED}❌ 应用验证失败${NC}"
    exit 1
fi

# 创建systemd服务
echo -e "${YELLOW}创建系统服务...${NC}"
cat > /etc/systemd/system/monitor4dingtalk.service << EOF
[Unit]
Description=Monitor4DingTalk
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_CMD $INSTALL_DIR/src/main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 启用并启动服务
systemctl daemon-reload
systemctl enable monitor4dingtalk
systemctl start monitor4dingtalk

# 检查状态
sleep 3
if systemctl is-active --quiet monitor4dingtalk; then
    echo -e "${GREEN}✅ 服务启动成功${NC}"
else
    echo -e "${YELLOW}⚠️  服务可能需要配置，请检查：${NC}"
    echo "  配置文件: $INSTALL_DIR/config/config.yaml"
    echo "  查看日志: journalctl -u monitor4dingtalk -f"
fi

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    安装完成${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "${YELLOW}下一步：${NC}"
echo "1. 编辑配置: vi $INSTALL_DIR/config/config.yaml"
echo "2. 配置钉钉webhook和secret"
echo "3. 重启服务: systemctl restart monitor4dingtalk"
echo ""
echo -e "${YELLOW}常用命令：${NC}"
echo "  查看状态: systemctl status monitor4dingtalk"
echo "  查看日志: journalctl -u monitor4dingtalk -f"
echo "  测试配置: cd $INSTALL_DIR && $PYTHON_CMD src/main.py --test" 