#!/bin/bash

# Conda环境测试脚本

echo "=== Conda环境检测 ==="

# 检查是否在conda环境中
if [ -n "$CONDA_DEFAULT_ENV" ]; then
    echo "✅ 当前conda环境: $CONDA_DEFAULT_ENV"
else
    echo "❌ 未检测到conda环境"
fi

echo ""
echo "=== Python命令测试 ==="

for cmd in python python3; do
    if command -v "$cmd" &> /dev/null; then
        path=$(which $cmd)
        version=$($cmd --version 2>&1)
        echo "$cmd:"
        echo "  路径: $path"
        echo "  版本: $version"
        
        # 检查是否为conda版本
        if [[ "$path" == *"conda"* ]] || [[ "$path" == *"miniconda"* ]] || [[ "$path" == *"anaconda"* ]]; then
            echo "  ✅ conda环境"
        else
            echo "  ⚠️  系统环境"
        fi
        echo ""
    fi
done

echo "=== 环境变量 ==="
echo "PATH前几个目录: $(echo $PATH | cut -d: -f1-3)"
echo ""
echo "CONDA_PREFIX: ${CONDA_PREFIX:-未设置}"
echo "CONDA_DEFAULT_ENV: ${CONDA_DEFAULT_ENV:-未设置}"

echo ""
echo "=== 建议 ==="
if [ -n "$CONDA_DEFAULT_ENV" ]; then
    echo "✅ 您正在使用conda环境，部署脚本应该可以正常工作"
else
    echo "⚠️  建议激活conda环境后再运行部署脚本："
    echo "   conda activate base"
    echo "   sudo bash deploy/scripts/install.sh"
fi
