#!/bin/bash

# Monitor4DingTalk 系统诊断脚本
# 用于排查部署和运行问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 系统诊断${NC}"
echo -e "${BLUE}=================================================${NC}"

echo -e "\n${YELLOW}=== 1. 系统环境检查 ===${NC}"
echo "操作系统: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)"
echo "内核版本: $(uname -r)"
echo "当前用户: $(whoami)"
echo "系统时间: $(date)"

echo -e "\n${YELLOW}=== 2. Python环境检查 ===${NC}"
echo "当前PATH: $PATH"
echo ""

# 检查各种Python版本
for python_cmd in python python3 python3.10 python3.9 python3.8 /root/miniconda3/bin/python /root/anaconda3/bin/python; do
    if command -v "$python_cmd" &>/dev/null || [[ -f "$python_cmd" ]]; then
        echo -e "${GREEN}✅ $python_cmd${NC}"
        echo "  路径: $(which $python_cmd 2>/dev/null || echo $python_cmd)"
        echo "  版本: $($python_cmd --version 2>&1 || echo '获取失败')"
        echo "  权限: $(ls -la $(which $python_cmd 2>/dev/null || echo $python_cmd) 2>/dev/null || echo '检查失败')"
        echo "  可执行: $(if [[ -x "$(which $python_cmd 2>/dev/null || echo $python_cmd)" ]]; then echo 'YES'; else echo 'NO'; fi)"
    else
        echo -e "${RED}❌ $python_cmd (不存在)${NC}"
    fi
    echo ""
done

echo -e "\n${YELLOW}=== 3. 应用文件检查 ===${NC}"
APP_DIR="/opt/monitor4dingtalk"
if [[ -d "$APP_DIR" ]]; then
    echo -e "${GREEN}✅ 应用目录存在${NC}"
    echo "目录权限: $(ls -ld $APP_DIR)"
    echo ""
    echo "主要文件："
    for file in "src/main.py" "config/config.yaml" "start.sh"; do
        full_path="$APP_DIR/$file"
        if [[ -f "$full_path" ]]; then
            echo -e "  ${GREEN}✅ $file${NC}"
            echo "    权限: $(ls -la $full_path)"
        else
            echo -e "  ${RED}❌ $file (不存在)${NC}"
        fi
    done
else
    echo -e "${RED}❌ 应用目录不存在: $APP_DIR${NC}"
fi

echo -e "\n${YELLOW}=== 4. 用户和权限检查 ===${NC}"
if id monitor &>/dev/null; then
    echo -e "${GREEN}✅ monitor用户存在${NC}"
    echo "用户信息: $(id monitor)"
    echo "Home目录: $(eval echo ~monitor)"
    echo "Home权限: $(ls -ld $(eval echo ~monitor) 2>/dev/null || echo '不存在')"
else
    echo -e "${RED}❌ monitor用户不存在${NC}"
fi

echo -e "\n${YELLOW}=== 5. systemd服务检查 ===${NC}"
SERVICE_FILE="/etc/systemd/system/monitor4dingtalk.service"
if [[ -f "$SERVICE_FILE" ]]; then
    echo -e "${GREEN}✅ 服务文件存在${NC}"
    echo "文件权限: $(ls -la $SERVICE_FILE)"
    echo ""
    echo "服务文件内容:"
    cat "$SERVICE_FILE"
    echo ""
    echo "服务状态:"
    systemctl status monitor4dingtalk --no-pager -l 2>&1 || echo "获取状态失败"
else
    echo -e "${RED}❌ 服务文件不存在${NC}"
fi

echo -e "\n${YELLOW}=== 6. 网络连接检查 ===${NC}"
if command -v curl &>/dev/null; then
    if curl -s --max-time 5 https://oapi.dingtalk.com >/dev/null; then
        echo -e "${GREEN}✅ 钉钉API连接正常${NC}"
    else
        echo -e "${RED}❌ 无法连接钉钉API${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  curl未安装，无法测试网络连接${NC}"
fi

echo -e "\n${YELLOW}=== 7. 依赖库检查 ===${NC}"
if [[ -d "$APP_DIR" ]]; then
    cd "$APP_DIR"
    for lib in psutil yaml requests schedule; do
        if python -c "import $lib" 2>/dev/null; then
            echo -e "  ${GREEN}✅ $lib${NC}"
        else
            echo -e "  ${RED}❌ $lib${NC}"
        fi
    done
else
    echo "应用目录不存在，跳过依赖检查"
fi

echo -e "\n${YELLOW}=== 8. 手动执行测试 ===${NC}"
if [[ -d "$APP_DIR" ]]; then
    cd "$APP_DIR"
    echo "测试1: 直接执行应用"
    timeout 5 python src/main.py --version 2>&1 || echo "执行失败或超时"
    
    echo ""
    echo "测试2: monitor用户执行"
    sudo -u monitor bash -c "cd $APP_DIR && python src/main.py --version" 2>&1 || echo "monitor用户执行失败"
else
    echo "应用目录不存在，跳过执行测试"
fi

echo -e "\n${YELLOW}=== 9. 最近系统日志 ===${NC}"
echo "systemd日志 (最近10条):"
journalctl -u monitor4dingtalk -n 10 --no-pager 2>&1 || echo "无法获取日志"

echo -e "\n${YELLOW}=== 10. 建议解决方案 ===${NC}"
echo -e "${GREEN}常见问题解决方案:${NC}"
echo "1. 如果Python路径问题 → 使用: bash deploy/scripts/test_python.sh"
echo "2. 如果权限问题 → 检查文件所有者和执行权限"
echo "3. 如果服务启动失败 → 尝试重新部署: sudo bash deploy/scripts/install.sh"
echo "4. 如果依赖缺失 → 重新安装依赖: pip install -r requirements.txt"
echo "5. 如果配置问题 → 检查config/config.yaml格式和内容"

echo -e "\n${BLUE}=================================================${NC}"
echo -e "${BLUE}    诊断完成${NC}"
echo -e "${BLUE}=================================================${NC}" 