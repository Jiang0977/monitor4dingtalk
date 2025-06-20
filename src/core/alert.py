"""
告警处理引擎
负责告警判断、去重处理和消息发送
"""

import time
from typing import Dict, List, Set
from datetime import datetime, timedelta

from .monitor import MonitorData
from ..services.config import config_manager
from ..services.logger import logger_manager
from ..services.dingtalk import dingtalk_notifier


class AlertEngine:
    """告警处理引擎"""
    
    def __init__(self):
        """初始化告警引擎"""
        self.alert_config = config_manager.get_alert_config()
        
        # 告警去重时间窗口（秒）
        self.dedup_window = self.alert_config.get('dedup_window', 300)
        
        # 存储已发送的告警，用于去重
        # 格式: {metric_name: timestamp}
        self._sent_alerts: Dict[str, float] = {}
        
        # 存储持续告警的指标，用于状态跟踪
        self._persistent_alerts: Set[str] = set()
    
    def should_send_alert(self, monitor_data: MonitorData) -> bool:
        """
        判断是否应该发送告警
        
        Args:
            monitor_data: 监控数据
            
        Returns:
            是否应该发送告警
        """
        # 检查是否超过阈值
        if not monitor_data.is_alert:
            # 如果指标恢复正常，从持续告警集合中移除
            if monitor_data.metric in self._persistent_alerts:
                self._persistent_alerts.remove(monitor_data.metric)
                logger_manager.info(f"告警恢复: {monitor_data.metric} 当前值: {monitor_data.value:.2f}%")
            return False
        
        # 检查去重时间窗口
        current_time = time.time()
        metric_name = monitor_data.metric
        
        if metric_name in self._sent_alerts:
            last_sent_time = self._sent_alerts[metric_name]
            if current_time - last_sent_time < self.dedup_window:
                # 在去重时间窗口内，不重复发送
                logger_manager.debug(f"告警去重: {metric_name} 在去重时间窗口内")
                return False
        
        return True
    
    def process_alert(self, monitor_data: MonitorData) -> bool:
        """
        处理单个告警
        
        Args:
            monitor_data: 监控数据
            
        Returns:
            告警处理是否成功
        """
        if not self.should_send_alert(monitor_data):
            return True
        
        # 发送告警
        success = dingtalk_notifier.send_alert(
            metric=monitor_data.metric,
            current_value=monitor_data.value,
            threshold=monitor_data.threshold,
            hostname=monitor_data.hostname
        )
        
        if success:
            # 记录告警发送时间
            self._sent_alerts[monitor_data.metric] = time.time()
            
            # 添加到持续告警集合
            self._persistent_alerts.add(monitor_data.metric)
            
            logger_manager.info(f"告警处理成功: {monitor_data.metric}")
        else:
            logger_manager.error(f"告警处理失败: {monitor_data.metric}")
        
        return success
    
    def process_alerts(self, alert_metrics: List[MonitorData]) -> Dict[str, bool]:
        """
        批量处理告警
        
        Args:
            alert_metrics: 需要告警的监控数据列表
            
        Returns:
            告警处理结果字典 {metric_name: success}
        """
        results = {}
        
        if not alert_metrics:
            logger_manager.debug("没有需要处理的告警")
            return results
        
        logger_manager.info(f"开始处理 {len(alert_metrics)} 个告警")
        
        for monitor_data in alert_metrics:
            try:
                success = self.process_alert(monitor_data)
                results[monitor_data.metric] = success
            except Exception as e:
                logger_manager.error(f"处理告警异常 {monitor_data.metric}: {str(e)}")
                results[monitor_data.metric] = False
        
        # 统计处理结果
        successful_count = sum(1 for success in results.values() if success)
        failed_count = len(results) - successful_count
        
        logger_manager.info(f"告警处理完成: 成功 {successful_count}, 失败 {failed_count}")
        
        return results
    
    def cleanup_old_alerts(self) -> None:
        """
        清理过期的告警记录
        """
        current_time = time.time()
        expired_alerts = []
        
        for metric_name, sent_time in self._sent_alerts.items():
            if current_time - sent_time > self.dedup_window * 2:  # 保留2倍去重时间的记录
                expired_alerts.append(metric_name)
        
        for metric_name in expired_alerts:
            del self._sent_alerts[metric_name]
        
        if expired_alerts:
            logger_manager.debug(f"清理了 {len(expired_alerts)} 个过期告警记录")
    
    def get_alert_status(self) -> Dict[str, any]:
        """
        获取告警状态信息
        
        Returns:
            告警状态字典
        """
        current_time = time.time()
        
        # 统计活跃告警（去重时间窗口内）
        active_alerts = []
        for metric_name, sent_time in self._sent_alerts.items():
            if current_time - sent_time < self.dedup_window:
                active_alerts.append({
                    'metric': metric_name,
                    'sent_time': datetime.fromtimestamp(sent_time).strftime('%Y-%m-%d %H:%M:%S'),
                    'remaining_time': int(self.dedup_window - (current_time - sent_time))
                })
        
        status = {
            'total_sent_alerts': len(self._sent_alerts),
            'active_alerts': active_alerts,
            'persistent_alerts': list(self._persistent_alerts),
            'dedup_window': self.dedup_window
        }
        
        return status
    
    def force_send_alert(self, monitor_data: MonitorData) -> bool:
        """
        强制发送告警（忽略去重）
        
        Args:
            monitor_data: 监控数据
            
        Returns:
            发送是否成功
        """
        logger_manager.info(f"强制发送告警: {monitor_data.metric}")
        
        success = dingtalk_notifier.send_alert(
            metric=monitor_data.metric,
            current_value=monitor_data.value,
            threshold=monitor_data.threshold,
            hostname=monitor_data.hostname
        )
        
        if success:
            self._sent_alerts[monitor_data.metric] = time.time()
            self._persistent_alerts.add(monitor_data.metric)
        
        return success
    
    def reset_alert_history(self) -> None:
        """重置告警历史记录"""
        self._sent_alerts.clear()
        self._persistent_alerts.clear()
        logger_manager.info("告警历史记录已重置")


# 全局告警引擎实例
alert_engine = AlertEngine() 