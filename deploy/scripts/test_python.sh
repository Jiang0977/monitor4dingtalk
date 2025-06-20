#!/bin/bash

# Python版本检测测试脚本

echo "=== Python版本检测测试 ==="

echo "当前系统可用的Python版本："
for cmd in python3 python python3.10 python3.9 python3.8; do
    if command -v "$cmd" &> /dev/null; then
        version=$($cmd -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo "检测失败")
        path=$(which $cmd)
        echo "  $cmd: $version ($path)"
        
        # 检查是否满足版本要求
        if $cmd -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)" &> /dev/null 2>&1; then
            echo "    ✅ 满足要求 (>= 3.8)"
        else
            echo "    ❌ 不满足要求 (< 3.8)"
        fi
    else
        echo "  $cmd: 未安装"
    fi
done

echo ""
echo "=== 自动选择最佳Python版本 ==="

PYTHON_CMD=""
for cmd in python3 python python3.10 python3.9 python3.8; do
    if command -v "$cmd" &> /dev/null; then
        if $cmd -c "import sys; exit(0 if sys.version_info >= (3, 8) else 1)" &> /dev/null 2>&1; then
            PYTHON_CMD="$cmd"
            break
        fi
    fi
done

if [[ -n "$PYTHON_CMD" ]]; then
    python_version=$($PYTHON_CMD -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
    python_path=$(which $PYTHON_CMD)
    echo "✅ 选择的Python命令: $PYTHON_CMD"
    echo "✅ 版本: $python_version"
    echo "✅ 路径: $python_path"
    
    # 测试pip是否可用
    if $PYTHON_CMD -m pip --version &> /dev/null; then
        pip_version=$($PYTHON_CMD -m pip --version)
        echo "✅ pip可用: $pip_version"
    else
        echo "❌ pip不可用"
    fi
else
    echo "❌ 未找到满足要求的Python版本 (>= 3.8)"
fi

echo ""
echo "=== 测试完成 ===" 