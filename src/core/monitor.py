"""
资源监控引擎
负责采集服务器各项资源指标，包括CPU、内存、磁盘等
"""

import psutil
import socket
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime

from ..services.config import config_manager
from ..services.logger import logger_manager


@dataclass
class MonitorData:
    """监控数据结构"""
    metric: str           # 监控指标名称
    value: float          # 当前值
    threshold: float      # 阈值
    unit: str            # 单位
    timestamp: datetime   # 时间戳
    hostname: str        # 主机名
    
    @property
    def is_alert(self) -> bool:
        """是否需要告警"""
        return self.value >= self.threshold


class ResourceMonitor:
    """资源监控器"""
    
    def __init__(self):
        """初始化资源监控器"""
        self.hostname = socket.gethostname()
        self.monitor_config = config_manager.get_monitor_config()
    
    def get_cpu_usage(self) -> Optional[MonitorData]:
        """
        获取CPU使用率
        
        Returns:
            CPU监控数据，如果监控未启用则返回None
        """
        if not config_manager.is_metric_enabled('cpu'):
            return None
        
        try:
            # 获取CPU使用率（1秒采样）
            cpu_percent = psutil.cpu_percent(interval=1)
            threshold = config_manager.get_metric_threshold('cpu')
            
            monitor_data = MonitorData(
                metric='cpu',
                value=cpu_percent,
                threshold=threshold,
                unit='%',
                timestamp=datetime.now(),
                hostname=self.hostname
            )
            
            logger_manager.log_monitor_data('cpu', cpu_percent, threshold)
            return monitor_data
            
        except Exception as e:
            logger_manager.error(f"获取CPU使用率失败: {str(e)}")
            return None
    
    def get_memory_usage(self) -> Optional[MonitorData]:
        """
        获取内存使用率
        
        Returns:
            内存监控数据，如果监控未启用则返回None
        """
        if not config_manager.is_metric_enabled('memory'):
            return None
        
        try:
            # 获取内存信息
            memory = psutil.virtual_memory()
            memory_percent = memory.percent
            threshold = config_manager.get_metric_threshold('memory')
            
            monitor_data = MonitorData(
                metric='memory',
                value=memory_percent,
                threshold=threshold,
                unit='%',
                timestamp=datetime.now(),
                hostname=self.hostname
            )
            
            logger_manager.log_monitor_data('memory', memory_percent, threshold)
            return monitor_data
            
        except Exception as e:
            logger_manager.error(f"获取内存使用率失败: {str(e)}")
            return None
    
    def get_disk_usage(self) -> List[MonitorData]:
        """
        获取磁盘使用率
        
        Returns:
            磁盘监控数据列表
        """
        disk_data = []
        
        if not config_manager.is_metric_enabled('disk'):
            return disk_data
        
        try:
            # 获取配置的磁盘路径
            disk_paths = self.monitor_config.get('disk', {}).get('paths', ['/'])
            threshold = config_manager.get_metric_threshold('disk')
            
            for path in disk_paths:
                try:
                    # 检查路径是否存在
                    if not psutil.disk_usage(path):
                        continue
                    
                    # 获取磁盘使用信息
                    disk_usage = psutil.disk_usage(path)
                    disk_percent = (disk_usage.used / disk_usage.total) * 100
                    
                    monitor_data = MonitorData(
                        metric=f'disk_{path.replace("/", "_").strip("_") or "root"}',
                        value=disk_percent,
                        threshold=threshold,
                        unit='%',
                        timestamp=datetime.now(),
                        hostname=self.hostname
                    )
                    
                    disk_data.append(monitor_data)
                    logger_manager.log_monitor_data(f'disk({path})', disk_percent, threshold)
                    
                except Exception as e:
                    logger_manager.error(f"获取磁盘使用率失败 {path}: {str(e)}")
                    continue
            
        except Exception as e:
            logger_manager.error(f"获取磁盘使用率失败: {str(e)}")
        
        return disk_data
    
    def get_network_io(self) -> Optional[MonitorData]:
        """
        获取网络IO信息（当前版本为占位实现）
        
        Returns:
            网络监控数据，如果监控未启用则返回None
        """
        if not config_manager.is_metric_enabled('network'):
            return None
        
        try:
            # 获取网络IO统计
            net_io = psutil.net_io_counters()
            
            # 这里简化实现，实际应该计算速率
            # 需要保存上一次的值来计算差值
            total_bytes = net_io.bytes_sent + net_io.bytes_recv
            threshold = config_manager.get_metric_threshold('network')
            
            monitor_data = MonitorData(
                metric='network',
                value=float(total_bytes),
                threshold=threshold,
                unit='bytes',
                timestamp=datetime.now(),
                hostname=self.hostname
            )
            
            logger_manager.log_monitor_data('network', float(total_bytes), threshold)
            return monitor_data
            
        except Exception as e:
            logger_manager.error(f"获取网络IO失败: {str(e)}")
            return None
    
    def get_system_info(self) -> Dict[str, str]:
        """
        获取系统基本信息
        
        Returns:
            系统信息字典
        """
        try:
            info = {
                'hostname': self.hostname,
                'platform': psutil.LINUX,
                'boot_time': datetime.fromtimestamp(psutil.boot_time()).strftime('%Y-%m-%d %H:%M:%S'),
                'cpu_count': str(psutil.cpu_count()),
                'memory_total': f"{psutil.virtual_memory().total / (1024**3):.2f} GB"
            }
            return info
        except Exception as e:
            logger_manager.error(f"获取系统信息失败: {str(e)}")
            return {'hostname': self.hostname}
    
    def collect_all_metrics(self) -> List[MonitorData]:
        """
        收集所有启用的监控指标
        
        Returns:
            所有监控数据列表
        """
        all_metrics = []
        
        # 收集CPU数据
        cpu_data = self.get_cpu_usage()
        if cpu_data:
            all_metrics.append(cpu_data)
        
        # 收集内存数据
        memory_data = self.get_memory_usage()
        if memory_data:
            all_metrics.append(memory_data)
        
        # 收集磁盘数据
        disk_data = self.get_disk_usage()
        all_metrics.extend(disk_data)
        
        # 收集网络数据（如果启用）
        network_data = self.get_network_io()
        if network_data:
            all_metrics.append(network_data)
        
        return all_metrics
    
    def get_alert_metrics(self) -> List[MonitorData]:
        """
        获取需要告警的监控指标
        
        Returns:
            需要告警的监控数据列表
        """
        all_metrics = self.collect_all_metrics()
        alert_metrics = [metric for metric in all_metrics if metric.is_alert]
        
        if alert_metrics:
            logger_manager.warning(f"发现 {len(alert_metrics)} 个告警指标")
        
        return alert_metrics


# 全局资源监控器实例
resource_monitor = ResourceMonitor() 