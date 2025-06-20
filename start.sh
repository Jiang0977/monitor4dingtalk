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

# 检查Python版本和选择最佳Python命令
check_python() {
    echo -e "${YELLOW}检查Python环境...${NC}"
    
    # 尝试多个Python命令，优先使用高版本
    PYTHON_CMD=""
    for cmd in python python3 python3.10 python3.9 python3.8 /root/miniconda3/bin/python /root/anaconda3/bin/python; do
        if command -v "$cmd" &> /dev/null; then
            version_output=$($cmd --version 2>&1)
            if [[ $version_output =~ Python\ ([0-9]+)\.([0-9]+) ]]; then
                major=${BASH_REMATCH[1]}
                minor=${BASH_REMATCH[2]}
                if [[ $major -gt 3 || ($major -eq 3 && $minor -ge 8) ]]; then
                    PYTHON_CMD="$cmd"
                    python_version="$major.$minor"
                    echo -e "${GREEN}✅ 使用Python: $python_version (路径: $(which $cmd 2>/dev/null || echo $cmd))${NC}"
                    break
                fi
            fi
        fi
    done
    
    if [[ -z "$PYTHON_CMD" ]]; then
        echo -e "${RED}❌ 未找到Python 3.8+版本${NC}"
        echo "当前系统可用的Python版本："
        for cmd in python python3; do
            if command -v "$cmd" &> /dev/null; then
                version=$($cmd --version 2>&1 | grep -o "[0-9]\+\.[0-9]\+")
                echo "  $cmd: $version"
            fi
        done
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
            $PYTHON_CMD src/main.py
            ;;
        "status")
            check_python
            $PYTHON_CMD src/main.py --status
            ;;
        "test")
            check_python
            $PYTHON_CMD src/main.py --test
            ;;
        "once")
            check_python
            $PYTHON_CMD src/main.py --once
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