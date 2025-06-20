#!/bin/bash

# 离线安装Python依赖

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}    Monitor4DingTalk 离线依赖安装${NC}"
echo -e "${BLUE}=================================================${NC}"

# 检查是否为root用户
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ 此脚本需要root权限运行${NC}"
    echo "请使用: sudo $0"
    exit 1
fi

# 创建临时目录
TEMP_DIR="/tmp/monitor4dingtalk_deps"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo -e "${YELLOW}创建最小依赖版本...${NC}"

# 创建基础版本的psutil（纯Python实现部分）
cat > psutil_basic.py << 'EOF'
"""
基础的系统信息获取模块
"""
import os
import time

def cpu_percent(interval=1):
    """获取CPU使用率"""
    try:
        with open('/proc/stat', 'r') as f:
            line = f.readline()
        cpu_times = [int(x) for x in line.split()[1:]]
        idle_time = cpu_times[3]
        total_time = sum(cpu_times)
        
        time.sleep(interval)
        
        with open('/proc/stat', 'r') as f:
            line = f.readline()
        cpu_times2 = [int(x) for x in line.split()[1:]]
        idle_time2 = cpu_times2[3]
        total_time2 = sum(cpu_times2)
        
        idle_delta = idle_time2 - idle_time
        total_delta = total_time2 - total_time
        
        if total_delta == 0:
            return 0.0
        return (1.0 - idle_delta / total_delta) * 100.0
    except:
        return 0.0

def virtual_memory():
    """获取内存信息"""
    class MemInfo:
        def __init__(self):
            self.total = 0
            self.available = 0
            self.used = 0
            self.percent = 0.0
            
        def _calculate(self):
            try:
                with open('/proc/meminfo', 'r') as f:
                    lines = f.readlines()
                
                mem_info = {}
                for line in lines:
                    parts = line.split()
                    if len(parts) >= 2:
                        key = parts[0].rstrip(':')
                        value = int(parts[1]) * 1024  # 转换为字节
                        mem_info[key] = value
                
                self.total = mem_info.get('MemTotal', 0)
                mem_free = mem_info.get('MemFree', 0)
                buffers = mem_info.get('Buffers', 0)
                cached = mem_info.get('Cached', 0)
                
                self.available = mem_free + buffers + cached
                self.used = self.total - self.available
                
                if self.total > 0:
                    self.percent = (self.used / self.total) * 100.0
                else:
                    self.percent = 0.0
            except:
                pass
    
    mem = MemInfo()
    mem._calculate()
    return mem

def disk_usage(path='/'):
    """获取磁盘使用情况"""
    class DiskInfo:
        def __init__(self):
            self.total = 0
            self.used = 0
            self.free = 0
            self.percent = 0.0
    
    try:
        statvfs = os.statvfs(path)
        disk = DiskInfo()
        disk.total = statvfs.f_frsize * statvfs.f_blocks
        disk.free = statvfs.f_frsize * statvfs.f_available
        disk.used = disk.total - disk.free
        
        if disk.total > 0:
            disk.percent = (disk.used / disk.total) * 100.0
        return disk
    except:
        return DiskInfo()
EOF

echo -e "${YELLOW}安装基础依赖到项目目录...${NC}"

# 检测Python版本
PYTHON_CMD=""
for cmd in python3.10 python3.9 python3.8 python3; do
    if command -v "$cmd" &>/dev/null; then
        PYTHON_CMD="$cmd"
        echo -e "${GREEN}使用Python: $cmd${NC}"
        break
    fi
done

if [[ -z "$PYTHON_CMD" ]]; then
    echo -e "${RED}❌ 未找到合适的Python版本${NC}"
    exit 1
fi

# 创建项目依赖目录
INSTALL_DIR="/opt/monitor4dingtalk"
DEP_DIR="$INSTALL_DIR/deps"
mkdir -p "$DEP_DIR"

# 复制基础psutil
cp psutil_basic.py "$DEP_DIR/psutil.py"

# 创建简化的requests模块（使用urllib）
cat > "$DEP_DIR/requests.py" << 'EOF'
"""
基础HTTP请求模块
"""
import urllib.request
import urllib.parse
import json

class Response:
    def __init__(self, data, status_code):
        self.text = data.decode('utf-8') if isinstance(data, bytes) else data
        self.content = data.encode('utf-8') if isinstance(data, str) else data
        self.status_code = status_code
    
    def json(self):
        return json.loads(self.text)

def post(url, json=None, headers=None, timeout=30):
    """发送POST请求"""
    try:
        if headers is None:
            headers = {'Content-Type': 'application/json'}
        
        data = None
        if json is not None:
            data = json.dumps(json).encode('utf-8')
        
        req = urllib.request.Request(url, data=data, headers=headers, method='POST')
        
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return Response(response.read(), response.getcode())
    except Exception as e:
        return Response('', 500)

def get(url, headers=None, timeout=30):
    """发送GET请求"""
    try:
        if headers is None:
            headers = {}
        
        req = urllib.request.Request(url, headers=headers)
        
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return Response(response.read(), response.getcode())
    except Exception as e:
        return Response('', 500)
EOF

# 创建简化的schedule模块
cat > "$DEP_DIR/schedule.py" << 'EOF'
"""
基础任务调度模块
"""
import time
import threading

class Job:
    def __init__(self, interval, job_func):
        self.interval = interval
        self.job_func = job_func
        self.next_run = time.time() + interval
    
    def should_run(self):
        return time.time() >= self.next_run
    
    def run(self):
        ret = self.job_func()
        self.next_run = time.time() + self.interval
        return ret

class Scheduler:
    def __init__(self):
        self.jobs = []
    
    def every(self, interval):
        class EveryJob:
            def __init__(self, scheduler, interval):
                self.scheduler = scheduler
                self.interval = interval
            
            def seconds(self):
                class SecondsJob:
                    def __init__(self, scheduler, interval):
                        self.scheduler = scheduler
                        self.interval = interval
                    
                    def do(self, job_func):
                        job = Job(self.interval, job_func)
                        self.scheduler.jobs.append(job)
                        return job
                
                return SecondsJob(self.scheduler, self.interval)
        
        return EveryJob(self, interval)
    
    def run_pending(self):
        for job in self.jobs:
            if job.should_run():
                threading.Thread(target=job.run).start()

# 创建默认调度器实例
default_scheduler = Scheduler()

def every(interval):
    return default_scheduler.every(interval)

def run_pending():
    return default_scheduler.run_pending()
EOF

# 创建yaml模块（基础实现）
cat > "$DEP_DIR/yaml.py" << 'EOF'
"""
基础YAML解析模块
"""
import re

def safe_load(stream):
    """简化的YAML解析"""
    if hasattr(stream, 'read'):
        content = stream.read()
    else:
        content = str(stream)
    
    result = {}
    current_dict = result
    stack = [result]
    
    lines = content.split('\n')
    for line in lines:
        line = line.rstrip()
        if not line or line.startswith('#'):
            continue
        
        # 计算缩进级别
        indent = len(line) - len(line.lstrip())
        
        # 简单的键值对解析
        if ':' in line:
            key_part, value_part = line.split(':', 1)
            key = key_part.strip()
            value = value_part.strip()
            
            # 处理不同的值类型
            if value == '':
                # 空值，可能是字典开始
                new_dict = {}
                current_dict[key] = new_dict
            elif value.lower() in ['true', 'false']:
                current_dict[key] = value.lower() == 'true'
            elif value.isdigit():
                current_dict[key] = int(value)
            elif '.' in value and value.replace('.', '').isdigit():
                current_dict[key] = float(value)
            else:
                # 去掉引号
                value = value.strip('\'"')
                current_dict[key] = value
    
    return result

# 兼容性别名
load = safe_load
EOF

echo -e "${GREEN}✅ 基础依赖安装完成${NC}"

# 修改Python路径，使其可以找到我们的依赖
echo -e "${YELLOW}修改Python模块搜索路径...${NC}"
cat > "$INSTALL_DIR/src/deps_init.py" << EOF
"""
初始化依赖模块路径
"""
import sys
import os

# 添加本地依赖目录到Python路径
deps_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'deps')
if deps_dir not in sys.path:
    sys.path.insert(0, deps_dir)
EOF

# 修改main.py以加载本地依赖
MAIN_PY="$INSTALL_DIR/src/main.py"
if [[ -f "$MAIN_PY" ]]; then
    # 在文件开头添加依赖初始化
    sed -i '1i\import deps_init  # 加载本地依赖' "$MAIN_PY"
fi

echo -e "${GREEN}✅ 离线依赖配置完成${NC}"
echo ""
echo -e "${YELLOW}现在可以测试应用:${NC}"
echo "cd $INSTALL_DIR && $PYTHON_CMD src/main.py --version"

# 清理临时目录
rm -rf "$TEMP_DIR" 