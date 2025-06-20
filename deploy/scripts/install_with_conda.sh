 #!/bin/bash

# Monitor4DingTalk Conda环境专用部署脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk Conda环境专用部署脚本${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查conda环境
check_conda_env() {
    echo -e "${YELLOW}检查conda环境...${NC}"
    
    if [[ -z "$CONDA_DEFAULT_ENV" ]]; then
        echo -e "${RED}❌ 未检测到conda环境${NC}"
        echo "请先激活conda环境："
        echo "  conda activate base"
        exit 1
    fi
    
    echo -e "${GREEN}✅ 当前conda环境: $CONDA_DEFAULT_ENV${NC}"
    echo -e "${GREEN}✅ Python路径: $(which python)${NC}"
    echo -e "${GREEN}✅ Python版本: $(python --version)${NC}"
    
    # 检查Python版本
    if ! python -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)"; then
        echo -e "${RED}❌ Python版本不满足要求 (需要 >= 3.8)${NC}"
        exit 1
    fi
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
        echo "请使用: sudo -E $0  (保持环境变量)"
        exit 1
    fi
}

# 保存当前Python环境信息
save_python_env() {
    export CONDA_PYTHON=$(which python)
    export CONDA_PIP=$(which pip)
    echo -e "${GREEN}✅ 保存Python环境信息${NC}"
    echo "  Python: $CONDA_PYTHON"
    echo "  Pip: $CONDA_PIP"
}

# 运行原安装脚本，但使用conda环境的Python
run_installation() {
    echo -e "${YELLOW}使用conda环境的Python运行安装...${NC}"
    
    # 设置环境变量强制使用conda的Python
    export PYTHON_CMD="$CONDA_PYTHON"
    export PYTHON_FULL_PATH="$CONDA_PYTHON"
    
    # 调用原安装脚本的主要功能
    source "$(dirname "$0")/install.sh"
    
    # 不执行主函数，而是手动执行各个步骤
    setup_user_and_dirs
    deploy_application
    
    # 使用conda环境安装依赖
    install_conda_dependencies
    
    setup_systemd_service
    setup_logrotate
    create_management_scripts
    verify_deployment
    start_service
    show_post_deployment_info
}

# conda环境依赖安装
install_conda_dependencies() {
    echo -e "${YELLOW}使用conda环境安装Python依赖...${NC}"
    
    # 使用conda环境的pip安装
    echo -e "${YELLOW}升级pip...${NC}"
    $CONDA_PIP install --upgrade pip
    
    # 安装依赖
    echo -e "${YELLOW}安装项目依赖...${NC}"
    if $CONDA_PIP install -r "$INSTALL_DIR/requirements.txt"; then
        echo -e "${GREEN}✅ 依赖安装完成${NC}"
    else
        echo -e "${YELLOW}⚠️  使用兼容模式安装...${NC}"
        $CONDA_PIP install psutil PyYAML requests schedule
    fi
    
    # 验证依赖
    echo -e "${YELLOW}验证依赖安装...${NC}"
    for pkg in psutil yaml requests schedule; do
        if python -c "import $pkg" 2>/dev/null; then
            echo -e "${GREEN}  ✅ $pkg${NC}"
        else
            echo -e "${RED}  ❌ $pkg${NC}"
        fi
    done
}

# 主函数
main() {
    check_conda_env
    check_root
    save_python_env
    run_installation
}

# 运行主函数
main