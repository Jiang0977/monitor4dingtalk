"""
配置管理服务
负责配置文件的解析、验证和管理
"""

import os
import yaml
from typing import Dict, Any, Optional
from pathlib import Path


class ConfigManager:
    """配置管理器"""
    
    def __init__(self, config_path: str = "config/config.yaml"):
        """
        初始化配置管理器
        
        Args:
            config_path: 配置文件路径
        """
        self.config_path = Path(config_path)
        self._config: Optional[Dict[str, Any]] = None
        self.load_config()
    
    def load_config(self) -> None:
        """
        加载配置文件
        
        Raises:
            FileNotFoundError: 配置文件不存在
            yaml.YAMLError: 配置文件格式错误
            ValueError: 配置验证失败
        """
        if not self.config_path.exists():
            raise FileNotFoundError(f"配置文件不存在: {self.config_path}")
        
        try:
            with open(self.config_path, 'r', encoding='utf-8') as file:
                self._config = yaml.safe_load(file)
        except yaml.YAMLError as e:
            raise yaml.YAMLError(f"配置文件解析失败: {e}")
        
        # 验证配置
        self._validate_config()
    
    def _validate_config(self) -> None:
        """
        验证配置文件的完整性和正确性
        
        Raises:
            ValueError: 配置验证失败
        """
        if not self._config:
            raise ValueError("配置文件为空")
        
        # 验证必需的配置项
        required_sections = ['dingtalk', 'monitor', 'alert', 'logging']
        for section in required_sections:
            if section not in self._config:
                raise ValueError(f"缺少必需的配置节: {section}")
        
        # 验证钉钉配置
        dingtalk_config = self._config['dingtalk']
        if 'webhook_url' not in dingtalk_config:
            raise ValueError("缺少钉钉webhook_url配置")
        
        # 验证监控配置
        monitor_config = self._config['monitor']
        if 'interval' not in monitor_config:
            raise ValueError("缺少监控间隔配置")
        
        # 验证阈值配置
        for metric in ['cpu', 'memory', 'disk']:
            if metric in monitor_config and monitor_config[metric].get('enabled', False):
                if 'threshold' not in monitor_config[metric]:
                    raise ValueError(f"缺少{metric}阈值配置")
    
    def get(self, key: str, default: Any = None) -> Any:
        """
        获取配置值，支持点号分隔的嵌套键
        
        Args:
            key: 配置键，支持 'section.subsection.key' 格式
            default: 默认值
            
        Returns:
            配置值
        """
        if not self._config:
            return default
        
        keys = key.split('.')
        value = self._config
        
        try:
            for k in keys:
                value = value[k]
            return value
        except (KeyError, TypeError):
            return default
    
    def get_dingtalk_config(self) -> Dict[str, Any]:
        """获取钉钉配置"""
        return self.get('dingtalk', {})
    
    def get_monitor_config(self) -> Dict[str, Any]:
        """获取监控配置"""
        return self.get('monitor', {})
    
    def get_alert_config(self) -> Dict[str, Any]:
        """获取告警配置"""
        return self.get('alert', {})
    
    def get_logging_config(self) -> Dict[str, Any]:
        """获取日志配置"""
        return self.get('logging', {})
    
    def reload_config(self) -> None:
        """重新加载配置文件"""
        self.load_config()
    
    def is_metric_enabled(self, metric: str) -> bool:
        """
        检查指定的监控指标是否启用
        
        Args:
            metric: 监控指标名称 (cpu, memory, disk, network)
            
        Returns:
            是否启用
        """
        return self.get(f'monitor.{metric}.enabled', False)
    
    def get_metric_threshold(self, metric: str) -> float:
        """
        获取指定监控指标的阈值
        
        Args:
            metric: 监控指标名称
            
        Returns:
            阈值
        """
        return self.get(f'monitor.{metric}.threshold', 0.0)


# 全局配置管理器实例
config_manager = ConfigManager() 