#!/usr/bin/env python3
"""
Python 3.6 兼容性测试
验证项目代码是否能在Python 3.6环境下正常运行
"""

import sys
import unittest
from pathlib import Path

# 确保能导入项目模块
sys.path.insert(0, str(Path(__file__).parent.parent))

class TestPython36Compatibility(unittest.TestCase):
    """Python 3.6 兼容性测试"""

    def test_python_version(self):
        """测试Python版本是否满足最低要求"""
        major, minor = sys.version_info[:2]
        self.assertGreaterEqual(
            (major, minor), (3, 6),
            f"Python版本{major}.{minor}不满足最低要求3.6"
        )

    def test_f_string_support(self):
        """测试f-string语法支持（Python 3.6+）"""
        name = "Test"
        version = 3.6
        result = f"Python {version} 支持 {name}"
        expected = "Python 3.6 支持 Test"
        self.assertEqual(result, expected)

    def test_pathlib_import(self):
        """测试pathlib模块导入"""
        try:
            from pathlib import Path
            p = Path(".")
            self.assertTrue(p.exists())
        except ImportError:
            self.fail("pathlib模块导入失败")

    def test_typing_module(self):
        """测试typing模块支持"""
        try:
            from typing import Dict, List, Optional
            # 测试类型注解
            def test_func(data: Dict[str, List[Optional[str]]]) -> bool:
                return isinstance(data, dict)
            
            self.assertTrue(test_func({"test": ["a", None]}))
        except ImportError:
            self.fail("typing模块导入失败")

    def test_monitor_data_class(self):
        """测试MonitorData类的正常工作"""
        try:
            from src.core.monitor import MonitorData
            from datetime import datetime
            
            # 创建MonitorData实例
            data = MonitorData(
                metric="cpu",
                value=85.5,
                threshold=80.0,
                unit="%",
                timestamp=datetime.now(),
                hostname="test-host"
            )
            
            # 验证属性
            self.assertEqual(data.metric, "cpu")
            self.assertEqual(data.value, 85.5)
            self.assertEqual(data.threshold, 80.0)
            self.assertTrue(data.is_alert)
            
        except Exception as e:
            self.fail(f"MonitorData类测试失败: {str(e)}")

    def test_config_manager_import(self):
        """测试配置管理器导入"""
        try:
            from src.services.config import ConfigManager
            # 测试类是否能正常实例化（不加载配置文件）
            self.assertTrue(ConfigManager)
        except ImportError as e:
            self.fail(f"ConfigManager导入失败: {str(e)}")

    def test_required_packages(self):
        """测试必需的第三方包是否可用"""
        required_packages = [
            'psutil',
            'yaml', 
            'requests',
            'schedule'
        ]
        
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                self.fail(f"必需的包 {package} 导入失败")

    def test_string_formatting(self):
        """测试各种字符串格式化方式的兼容性"""
        name = "Monitor4DingTalk"
        version = "1.0"
        
        # 测试f-string
        f_result = f"{name} v{version}"
        
        # 测试format方法
        format_result = "{} v{}".format(name, version)
        
        # 测试%格式化
        percent_result = "%s v%s" % (name, version)
        
        expected = "Monitor4DingTalk v1.0"
        self.assertEqual(f_result, expected)
        self.assertEqual(format_result, expected) 
        self.assertEqual(percent_result, expected)

if __name__ == "__main__":
    print(f"运行Python 3.6兼容性测试 (当前版本: {sys.version})")
    print("=" * 60)
    
    unittest.main(verbosity=2) 