"""
基础功能测试
"""

import sys
import pytest
from pathlib import Path
from unittest.mock import patch, MagicMock

# 添加项目根目录到Python路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.services.config import ConfigManager
from src.core.monitor import ResourceMonitor, MonitorData
from src.core.alert import AlertEngine


class TestConfigManager:
    """配置管理器测试"""
    
    def test_config_validation(self):
        """测试配置验证"""
        config_manager = ConfigManager('config/config.yaml')
        
        # 测试必需配置项
        assert config_manager.get('dingtalk.webhook_url') is not None
        assert config_manager.get('monitor.interval') is not None
        
    def test_metric_enabled_check(self):
        """测试监控指标启用检查"""
        config_manager = ConfigManager('config/config.yaml')
        
        # 测试默认启用的指标
        assert config_manager.is_metric_enabled('cpu') == True
        assert config_manager.is_metric_enabled('memory') == True
        assert config_manager.is_metric_enabled('disk') == True


class TestResourceMonitor:
    """资源监控器测试"""
    
    def test_monitor_data_creation(self):
        """测试监控数据创建"""
        data = MonitorData(
            metric='cpu',
            value=85.5,
            threshold=80.0,
            unit='%',
            timestamp=None,
            hostname='test-host'
        )
        
        assert data.metric == 'cpu'
        assert data.value == 85.5
        assert data.threshold == 80.0
        assert data.is_alert == True  # 85.5 >= 80.0
    
    @patch('psutil.cpu_percent')
    def test_cpu_monitoring(self, mock_cpu):
        """测试CPU监控"""
        mock_cpu.return_value = 75.0
        
        monitor = ResourceMonitor()
        cpu_data = monitor.get_cpu_usage()
        
        assert cpu_data is not None
        assert cpu_data.metric == 'cpu'
        assert cpu_data.value == 75.0
        assert cpu_data.unit == '%'
    
    @patch('psutil.virtual_memory')
    def test_memory_monitoring(self, mock_memory):
        """测试内存监控"""
        mock_memory.return_value = MagicMock(percent=82.3)
        
        monitor = ResourceMonitor()
        memory_data = monitor.get_memory_usage()
        
        assert memory_data is not None
        assert memory_data.metric == 'memory'
        assert memory_data.value == 82.3
        assert memory_data.unit == '%'


class TestAlertEngine:
    """告警引擎测试"""
    
    def test_alert_threshold_check(self):
        """测试告警阈值检查"""
        alert_engine = AlertEngine()
        
        # 创建告警数据
        alert_data = MonitorData(
            metric='cpu',
            value=85.0,
            threshold=80.0,
            unit='%',
            timestamp=None,
            hostname='test-host'
        )
        
        # 创建正常数据
        normal_data = MonitorData(
            metric='memory',
            value=70.0,
            threshold=80.0,
            unit='%',
            timestamp=None,
            hostname='test-host'
        )
        
        assert alert_data.is_alert == True
        assert normal_data.is_alert == False
    
    def test_alert_deduplication(self):
        """测试告警去重"""
        alert_engine = AlertEngine()
        alert_engine._sent_alerts.clear()  # 清空历史记录
        
        alert_data = MonitorData(
            metric='cpu',
            value=85.0,
            threshold=80.0,
            unit='%',
            timestamp=None,
            hostname='test-host'
        )
        
        # 第一次应该发送告警
        should_send_1 = alert_engine.should_send_alert(alert_data)
        assert should_send_1 == True
        
        # 模拟已发送告警
        import time
        alert_engine._sent_alerts['cpu'] = time.time()
        
        # 第二次应该被去重
        should_send_2 = alert_engine.should_send_alert(alert_data)
        assert should_send_2 == False


def test_system_integration():
    """系统集成测试"""
    # 测试系统各组件能否正常初始化
    try:
        from src.services.config import config_manager
        from src.services.logger import logger_manager
        from src.core.monitor import resource_monitor
        from src.core.alert import alert_engine
        
        # 测试配置加载
        assert config_manager._config is not None
        
        # 测试日志管理器
        assert logger_manager._logger is not None
        
        # 测试监控器
        assert resource_monitor.hostname is not None
        
        # 测试告警引擎
        assert alert_engine.dedup_window > 0
        
        print("✅ 系统集成测试通过")
        
    except Exception as e:
        pytest.fail(f"系统集成测试失败: {str(e)}")


if __name__ == '__main__':
    # 运行测试
    test_system_integration()
    print("所有测试执行完成") 