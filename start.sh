#!/bin/bash

# Monitor4DingTalk 启动脚本
# 服务器资源监控钉钉告警系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本信息
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="Monitor4DingTalk"

echo -e "${BLUE}===============================================${NC}"
echo -e "${BLUE}      $PROJECT_NAME 服务器资源监控系统${NC}"
echo -e "${BLUE}===============================================${NC}"

# 检查Python版本
check_python() {
    echo -e "${YELLOW}检查Python环境...${NC}"
    
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}❌ Python3 未安装${NC}"
        exit 1
    fi
    
    python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    required_version="3.8"
    
    if python3 -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        echo -e "${GREEN}✅ Python版本: $python_version${NC}"
    else
        echo -e "${RED}❌ Python版本过低: $python_version (需要 >= $required_version)${NC}"
        exit 1
    fi
}

# 显示使用帮助
show_help() {
    echo -e "${BLUE}使用方法:${NC}"
    echo "  ./start.sh [选项]"
    echo ""
    echo -e "${BLUE}选项:${NC}"
    echo "  start     启动监控服务"
    echo "  stop      停止监控服务"
    echo "  status    显示系统状态"
    echo "  test      测试钉钉连接"
    echo "  once      执行一次监控检查"
    echo "  logs      查看实时日志"
    echo "  help      显示此帮助信息"
    echo ""
}

# 主逻辑
main() {
    cd "$SCRIPT_DIR"
    
    case "${1:-help}" in
        "start")
            check_python
            echo -e "${YELLOW}启动监控服务...${NC}"
            python3 src/main.py
            ;;
        "status")
            check_python
            python3 src/main.py --status
            ;;
        "test")
            check_python
            python3 src/main.py --test
            ;;
        "once")
            check_python
            python3 src/main.py --once
            ;;
        "logs")
            if [ -f "logs/monitor.log" ]; then
                echo -e "${BLUE}实时日志 (按Ctrl+C退出):${NC}"
                tail -f logs/monitor.log
            else
                echo -e "${RED}❌ 日志文件不存在${NC}"
            fi
            ;;
        "help"|*)
            show_help
            ;;
    esac
}

# 执行主函数
main "$@"