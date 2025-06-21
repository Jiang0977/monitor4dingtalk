#!/bin/bash

# Monitor4DingTalk 生产环境修复脚本
# 解决Python环境不一致导致的问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 生产环境修复${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查安装目录
INSTALL_DIR="/opt/monitor4dingtalk"
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${RED}❌ 安装目录不存在: $INSTALL_DIR${NC}"
    exit 1
fi

# 检测当前服务使用的Python路径
echo -e "${YELLOW}检测服务配置...${NC}"
if [[ -f "/etc/systemd/system/monitor4dingtalk.service" ]]; then
    SERVICE_PYTHON=$(grep "ExecStart=" /etc/systemd/system/monitor4dingtalk.service | cut -d' ' -f1 | cut -d'=' -f2)
    echo -e "${GREEN}✅ 服务使用Python: $SERVICE_PYTHON${NC}"
else
    echo -e "${RED}❌ 服务文件不存在${NC}"
    exit 1
fi

# 验证Python环境
echo -e "${YELLOW}验证Python环境...${NC}"
if $SERVICE_PYTHON -c "import yaml, psutil, requests, schedule; print('所有依赖模块可用')" 2>/dev/null; then
    echo -e "${GREEN}✅ Python环境正常${NC}"
else
    echo -e "${YELLOW}⚠️  安装缺失的依赖...${NC}"
    $SERVICE_PYTHON -m pip install --user PyYAML psutil requests schedule
fi

# 创建测试别名脚本
echo -e "${YELLOW}创建测试脚本...${NC}"
cat > $INSTALL_DIR/test.sh << EOF
#!/bin/bash
# Monitor4DingTalk 测试脚本
cd $INSTALL_DIR
$SERVICE_PYTHON src/main.py --test
EOF

chmod +x $INSTALL_DIR/test.sh

# 创建便捷的管理脚本
cat > $INSTALL_DIR/manage.sh << EOF
#!/bin/bash
# Monitor4DingTalk 管理脚本

case "\$1" in
    start)
        sudo systemctl start monitor4dingtalk
        ;;
    stop)
        sudo systemctl stop monitor4dingtalk
        ;;
    restart)
        sudo systemctl restart monitor4dingtalk
        ;;
    status)
        systemctl status monitor4dingtalk
        ;;
    logs)
        journalctl -u monitor4dingtalk -f
        ;;
    test)
        cd $INSTALL_DIR
        $SERVICE_PYTHON src/main.py --test
        ;;
    config)
        vi $INSTALL_DIR/config/config.yaml
        ;;
    *)
        echo "用法: \$0 {start|stop|restart|status|logs|test|config}"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动服务"
        echo "  stop    - 停止服务"  
        echo "  restart - 重启服务"
        echo "  status  - 查看服务状态"
        echo "  logs    - 查看实时日志"
        echo "  test    - 测试配置"
        echo "  config  - 编辑配置文件"
        exit 1
        ;;
esac
EOF

chmod +x $INSTALL_DIR/manage.sh

# 测试配置
echo -e "${YELLOW}测试配置...${NC}"
if cd $INSTALL_DIR && $SERVICE_PYTHON src/main.py --test 2>/dev/null; then
    echo -e "${GREEN}✅ 配置测试成功${NC}"
else
    echo -e "${YELLOW}⚠️  配置可能需要调整，请检查配置文件${NC}"
fi

echo ""
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    修复完成${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""
echo -e "${YELLOW}修复内容：${NC}"
echo "1. ✅ 验证了Python环境和依赖包"
echo "2. ✅ 创建了测试脚本: $INSTALL_DIR/test.sh"
echo "3. ✅ 创建了管理脚本: $INSTALL_DIR/manage.sh"
echo ""
echo -e "${YELLOW}推荐使用方式：${NC}"
echo "  测试配置: $INSTALL_DIR/test.sh"
echo "  管理服务: $INSTALL_DIR/manage.sh [start|stop|restart|status|logs|test|config]"
echo ""
echo -e "${YELLOW}或者使用绝对路径：${NC}"
echo "  测试配置: cd $INSTALL_DIR && $SERVICE_PYTHON src/main.py --test" 