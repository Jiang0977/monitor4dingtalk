"""
日志记录服务
提供统一的日志管理功能，支持不同级别的日志记录和文件轮转
"""

import logging
import logging.handlers
import os
from pathlib import Path
from typing import Optional

from .config import config_manager


class LoggerManager:
    """日志管理器"""
    
    def __init__(self):
        """初始化日志管理器"""
        self._logger: Optional[logging.Logger] = None
        self._setup_logger()
    
    def _setup_logger(self) -> None:
        """设置日志配置"""
        logging_config = config_manager.get_logging_config()
        
        # 获取日志配置参数
        level = logging_config.get('level', 'INFO')
        log_file = logging_config.get('file', 'logs/monitor.log')
        max_size = logging_config.get('max_size', 10485760)  # 10MB
        backup_count = logging_config.get('backup_count', 5)
        
        # 创建日志目录
        log_path = Path(log_file)
        log_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 创建logger
        self._logger = logging.getLogger('monitor4dingtalk')
        self._logger.setLevel(getattr(logging, level.upper()))
        
        # 避免重复添加handler
        if self._logger.handlers:
            return
        
        # 创建文件handler（支持文件轮转）
        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=max_size,
            backupCount=backup_count,
            encoding='utf-8'
        )
        file_handler.setLevel(getattr(logging, level.upper()))
        
        # 创建控制台handler
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        
        # 创建格式化器
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        # 添加handler到logger
        self._logger.addHandler(file_handler)
        self._logger.addHandler(console_handler)
    
    def get_logger(self) -> logging.Logger:
        """获取logger实例"""
        if self._logger is None:
            self._setup_logger()
        return self._logger
    
    def debug(self, message: str) -> None:
        """记录调试日志"""
        self.get_logger().debug(message)
    
    def info(self, message: str) -> None:
        """记录信息日志"""
        self.get_logger().info(message)
    
    def warning(self, message: str) -> None:
        """记录警告日志"""
        self.get_logger().warning(message)
    
    def error(self, message: str) -> None:
        """记录错误日志"""
        self.get_logger().error(message)
    
    def critical(self, message: str) -> None:
        """记录严重错误日志"""
        self.get_logger().critical(message)
    
    def log_monitor_data(self, metric: str, value: float, threshold: float) -> None:
        """
        记录监控数据
        
        Args:
            metric: 监控指标名称
            value: 当前值
            threshold: 阈值
        """
        self.info(f"监控数据 - {metric}: {value:.2f}% (阈值: {threshold:.2f}%)")
    
    def log_alert_sent(self, metric: str, value: float, threshold: float) -> None:
        """
        记录告警发送
        
        Args:
            metric: 监控指标名称
            value: 当前值
            threshold: 阈值
        """
        self.warning(f"告警已发送 - {metric}: {value:.2f}% 超过阈值 {threshold:.2f}%")
    
    def log_alert_failed(self, metric: str, error: str) -> None:
        """
        记录告警发送失败
        
        Args:
            metric: 监控指标名称
            error: 错误信息
        """
        self.error(f"告警发送失败 - {metric}: {error}")
    
    def log_system_start(self) -> None:
        """记录系统启动"""
        self.info("Monitor4DingTalk 监控系统启动")
    
    def log_system_stop(self) -> None:
        """记录系统停止"""
        self.info("Monitor4DingTalk 监控系统停止")
    
    def log_config_reload(self) -> None:
        """记录配置重载"""
        self.info("配置文件已重新加载")


# 全局日志管理器实例
logger_manager = LoggerManager() 