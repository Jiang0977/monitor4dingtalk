#!/bin/bash

# Monitor4DingTalk Conda环境安装脚本
# 专门针对使用conda的生产环境

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk Conda环境安装${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查root权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 请使用root权限运行${NC}"
    echo "sudo $0"
    exit 1
fi

# 检测conda环境
if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    echo -e "${GREEN}✅ 检测到conda环境: $CONDA_DEFAULT_ENV${NC}"
else
    echo -e "${YELLOW}⚠️  未检测到激活的conda环境${NC}"
    echo "建议先激活conda环境，然后再运行此脚本"
fi

# 强制使用当前Python (通常是conda环境中的Python)
PYTHON_CMD="python"
if ! command -v python &>/dev/null; then
    PYTHON_CMD="python3"
fi

if ! command -v "$PYTHON_CMD" &>/dev/null; then
    echo -e "${RED}❌ 未找到Python命令${NC}"
    exit 1
fi

# 获取Python版本和路径
PYTHON_PATH=$(which "$PYTHON_CMD")
PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
echo -e "${GREEN}✅ 使用Python: $PYTHON_PATH${NC}"
echo -e "${GREEN}   版本: $PYTHON_VERSION${NC}"

# 验证Python版本是否>=3.6
if ! $PYTHON_CMD -c "import sys; assert sys.version_info >= (3, 6), 'Python 3.6+ required'" 2>/dev/null; then
    echo -e "${RED}❌ Python版本不符合要求 (需要3.6+)${NC}"
    exit 1
fi

# 创建目录
INSTALL_DIR="/opt/monitor4dingtalk"
echo -e "${YELLOW}创建安装目录: $INSTALL_DIR${NC}"
mkdir -p "$INSTALL_DIR"

# 复制代码
echo -e "${YELLOW}复制应用代码...${NC}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
cp -r "$SOURCE_DIR"/* "$INSTALL_DIR/"

# 创建专用用户
echo -e "${YELLOW}创建系统用户...${NC}"
if ! id "monitor" &>/dev/null; then
    useradd -r -s /bin/false -d "$INSTALL_DIR" monitor
    echo -e "${GREEN}✅ 创建用户: monitor${NC}"
else
    echo -e "${GREEN}✅ 用户已存在: monitor${NC}"
fi

# 设置权限
chown -R monitor:monitor "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/start.sh"

# 安装依赖
echo -e "${YELLOW}安装Python依赖...${NC}"
cd "$INSTALL_DIR"

# 检查并安装pip
if ! $PYTHON_CMD -m pip --version &>/dev/null; then
    echo -e "${YELLOW}安装pip...${NC}"
    $PYTHON_CMD -m ensurepip --default-pip
fi

# 安装依赖包
$PYTHON_CMD -m pip install psutil PyYAML requests schedule

# 验证安装
echo -e "${YELLOW}验证安装...${NC}"
if sudo -u monitor $PYTHON_CMD "$INSTALL_DIR/src/main.py" --version &>/dev/null; then
    echo -e "${GREEN}✅ 应用安装成功${NC}"
else
    echo -e "${RED}❌ 应用验证失败${NC}"
    echo "尝试手动测试: sudo -u monitor $PYTHON_CMD $INSTALL_DIR/src/main.py --version"
    exit 1
fi

# 创建启动脚本包装器（用于conda环境）
echo -e "${YELLOW}创建conda环境启动脚本...${NC}"
cat > "$INSTALL_DIR/start_conda.sh" << EOF
#!/bin/bash
# Monitor4DingTalk Conda环境启动脚本

# 如果有conda环境，激活它
if [[ -n "$CONDA_DEFAULT_ENV" ]] && [[ -f "/root/miniconda3/etc/profile.d/conda.sh" ]]; then
    source /root/miniconda3/etc/profile.d/conda.sh
    conda activate $CONDA_DEFAULT_ENV
fi

# 启动应用
exec $PYTHON_PATH "$INSTALL_DIR/src/main.py" "\$@"
EOF

chmod +x "$INSTALL_DIR/start_conda.sh"
chown monitor:monitor "$INSTALL_DIR/start_conda.sh"

# 创建systemd服务
echo -e "${YELLOW}创建系统服务...${NC}"
cat > /etc/systemd/system/monitor4dingtalk.service << EOF
[Unit]
Description=Monitor4DingTalk Server Resource Monitor (Conda)
Documentation=https://github.com/Jiang0977/monitor4dingtalk
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=monitor
Group=monitor
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/start_conda.sh
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
$(if [[ -n "$CONDA_DEFAULT_ENV" ]]; then echo "Environment=CONDA_DEFAULT_ENV=$CONDA_DEFAULT_ENV"; fi)

[Install]
WantedBy=multi-user.target
EOF

# 重新加载systemd配置
systemctl daemon-reload
systemctl enable monitor4dingtalk

echo -e "${YELLOW}启动服务...${NC}"
systemctl start monitor4dingtalk

# 等待服务启动
sleep 5

# 检查服务状态
if systemctl is-active --quiet monitor4dingtalk; then
    echo -e "${GREEN}✅ 服务启动成功${NC}"
    systemctl status monitor4dingtalk --no-pager
else
    echo -e "${RED}❌ 服务启动失败${NC}"
    echo ""
    echo "查看错误日志:"
    journalctl -u monitor4dingtalk --no-pager -n 20
    echo ""
    echo "手动测试:"
    echo "sudo -u monitor $PYTHON_PATH $INSTALL_DIR/src/main.py --test"
fi

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    安装完成${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "${YELLOW}下一步操作：${NC}"
echo "1. 编辑配置文件:"
echo "   vi $INSTALL_DIR/config/config.yaml"
echo ""
echo "2. 配置钉钉webhook和secret"
echo ""
echo "3. 重启服务:"
echo "   systemctl restart monitor4dingtalk"
echo ""
echo "4. 测试配置:"
echo "   cd $INSTALL_DIR && sudo -u monitor $PYTHON_PATH src/main.py --test"
echo ""
echo -e "${YELLOW}常用命令：${NC}"
echo "  查看状态: systemctl status monitor4dingtalk"
echo "  查看日志: journalctl -u monitor4dingtalk -f"
echo "  停止服务: systemctl stop monitor4dingtalk"
echo "  启动服务: systemctl start monitor4dingtalk" 