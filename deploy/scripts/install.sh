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

# 改进的Python检测逻辑
PYTHON_CMD=""
PYTHON_PATH=""

# 检测函数：验证Python版本是否>=3.6
check_python_version() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
        # 获取Python版本并检查是否>=3.6
        if $cmd -c "import sys; assert sys.version_info >= (3, 6), 'Python 3.6+ required'" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# 优先检查python3，然后检查python
for cmd in python3 python; do
    if check_python_version "$cmd"; then
        PYTHON_CMD="$cmd"
        PYTHON_PATH=$(which "$cmd")
        version=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✅ 使用Python: $cmd (版本: $version)${NC}"
        break
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    echo -e "${RED}❌ 未找到符合要求的Python版本 (需要Python 3.6+)${NC}"
    echo ""
    echo "当前系统中的Python版本："
    for cmd in python3 python python3.6 python3.7 python3.8 python3.9 python3.10 python3.11 python3.12; do
        if command -v "$cmd" &>/dev/null; then
            version=$($cmd --version 2>/dev/null || echo "未知版本")
            echo "  $cmd: $version"
        fi
    done
    echo ""
    echo "解决方案："
    echo "1. 确保已安装Python 3.6+: yum install python3 或 apt install python3"
    echo "2. 如果使用conda环境，请确保已激活: conda activate your_env"
    echo "3. 或手动指定Python路径: PYTHON_CMD=/path/to/python $0"
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
Description=Monitor4DingTalk Server Resource Monitor
Documentation=https://github.com/Jiang0977/monitor4dingtalk
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_PATH $INSTALL_DIR/src/main.py
ExecReload=/bin/kill -HUP \$MAINPID

# 重启策略
Restart=always
RestartSec=10
StartLimitInterval=60
StartLimitBurst=3

# 资源限制
LimitNOFILE=65536

# 环境变量
Environment=PYTHONPATH=$INSTALL_DIR
Environment=PYTHONUNBUFFERED=1

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
echo "  测试配置: cd $INSTALL_DIR && $PYTHON_PATH src/main.py --test" 