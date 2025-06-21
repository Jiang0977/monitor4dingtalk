# Monitor4DingTalk Conda环境部署快速指南

## 问题描述

如果您在生产环境中使用conda管理Python环境，可能会遇到安装脚本无法正确识别Python版本的问题。即使您有Python 3.12.4，脚本仍可能报告"需要Python 3.6+"。

## 解决方案

### 方法一：使用专用conda安装脚本（推荐）

```bash
# 1. 首先激活您的conda环境
conda activate base  # 或您的具体环境名

# 2. 确认Python版本
python --version

# 3. 使用专用conda安装脚本
sudo -E bash deploy/scripts/install_conda.sh
```

### 方法二：修复原安装脚本

如果您想继续使用原安装脚本，现在已经修复了Python版本检测逻辑：

```bash
# 直接使用修复后的安装脚本
sudo bash deploy/scripts/install.sh
```

### 方法三：手动指定Python路径

```bash
# 如果以上方法都不行，可以手动指定Python路径
export PYTHON_CMD=$(which python)
sudo -E bash deploy/scripts/install.sh
```

## conda环境特殊配置

### 1. conda路径检测

如果您的conda安装在非标准路径，需要修改启动脚本：

```bash
# 编辑conda启动脚本
sudo vim /opt/monitor4dingtalk/start_conda.sh

# 修改conda路径（根据您的实际路径）
source /path/to/your/conda/etc/profile.d/conda.sh
```

### 2. 常见conda路径

- miniconda: `/root/miniconda3/etc/profile.d/conda.sh`
- anaconda: `/root/anaconda3/etc/profile.d/conda.sh`
- 自定义安装: `/opt/conda/etc/profile.d/conda.sh`

## 验证安装

```bash
# 1. 检查服务状态
sudo systemctl status monitor4dingtalk

# 2. 查看服务日志
sudo journalctl -u monitor4dingtalk -f

# 3. 手动测试
cd /opt/monitor4dingtalk
sudo -u monitor python src/main.py --test
```

## 常见问题

### Q: 为什么需要使用 `sudo -E`？
A: `-E` 参数保持环境变量，确保conda环境信息传递给sudo进程。

### Q: 服务启动后Python环境不对怎么办？
A: 检查并修改 `/opt/monitor4dingtalk/start_conda.sh` 中的conda路径。

### Q: 如何确认使用的是正确的Python版本？
A: 运行 `sudo -u monitor /path/to/python --version` 检查。

## 技术细节

修复的主要内容：

1. **改进Python版本检测**：从字符串比较改为Python内置版本检查
2. **增强错误提示**：显示所有可用的Python版本和解决方案
3. **支持conda环境**：专用的conda环境安装脚本
4. **环境变量保持**：确保conda环境正确传递

## 如果仍有问题

请提供以下信息：

```bash
# 系统信息
cat /etc/os-release

# Python版本信息
python --version
python3 --version
which python
which python3

# conda环境信息
conda info --envs
echo $CONDA_DEFAULT_ENV

# 错误日志
sudo journalctl -u monitor4dingtalk -n 20
```

联系方式：提交[Issue](https://github.com/Jiang0977/monitor4dingtalk/issues) 