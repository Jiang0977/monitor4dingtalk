"""
任务调度器
负责定时执行监控任务和系统维护任务
"""

import schedule
import time
import threading
from typing import Callable, Optional
from datetime import datetime

from ..services.config import config_manager
from ..services.logger import logger_manager
from ..core.monitor import resource_monitor
from ..core.alert import alert_engine


class MonitorScheduler:
    """监控任务调度器"""
    
    def __init__(self):
        """初始化调度器"""
        self.monitor_config = config_manager.get_monitor_config()
        self.running = False
        self.scheduler_thread: Optional[threading.Thread] = None
        
        # 监控间隔（秒）
        self.monitor_interval = self.monitor_config.get('interval', 60)
    
    def setup_jobs(self) -> None:
        """设置定时任务"""
        # 清空现有任务
        schedule.clear()
        
        # 主监控任务
        schedule.every(self.monitor_interval).seconds.do(self._monitor_job)
        
        # 清理过期告警记录任务（每小时执行一次）
        schedule.every().hour.do(self._cleanup_job)
        
        # 系统健康检查任务（每10分钟执行一次）
        schedule.every(10).minutes.do(self._health_check_job)
        
        logger_manager.info(f"调度器已设置 - 监控间隔: {self.monitor_interval}秒")
    
    def _monitor_job(self) -> None:
        """主监控任务"""
        try:
            logger_manager.debug("开始执行监控任务")
            
            # 收集所有指标
            all_metrics = resource_monitor.collect_all_metrics()
            
            # 交由告警引擎处理
            alert_engine.check_and_process(all_metrics)
            
            logger_manager.debug("监控任务执行完成")
            
        except Exception as e:
            logger_manager.error(f"监控任务执行异常: {str(e)}")
    
    def _cleanup_job(self) -> None:
        """清理任务"""
        try:
            logger_manager.debug("开始执行清理任务")
            
            # 清理过期告警记录
            alert_engine.cleanup_old_alerts()
            
            logger_manager.debug("清理任务执行完成")
            
        except Exception as e:
            logger_manager.error(f"清理任务执行异常: {str(e)}")
    
    def _health_check_job(self) -> None:
        """系统健康检查任务"""
        try:
            logger_manager.debug("开始执行健康检查")
            
            # 获取系统信息
            system_info = resource_monitor.get_system_info()
            
            # 检查配置是否有效
            try:
                config_manager.load_config()
                logger_manager.debug("配置文件检查正常")
            except Exception as e:
                logger_manager.error(f"配置文件检查失败: {str(e)}")
            
            # 获取告警状态
            alert_status = alert_engine.get_alert_status()
            if alert_status['persistent_alerts']:
                logger_manager.warning(f"持续告警指标: {alert_status['persistent_alerts']}")
            
            logger_manager.debug("健康检查完成")
            
        except Exception as e:
            logger_manager.error(f"健康检查异常: {str(e)}")
    
    def start(self) -> None:
        """启动调度器"""
        if self.running:
            logger_manager.warning("调度器已在运行中")
            return
        
        self.setup_jobs()
        self.running = True
        
        # 在单独线程中运行调度器
        self.scheduler_thread = threading.Thread(target=self._run_scheduler, daemon=True)
        self.scheduler_thread.start()
        
        logger_manager.info("监控调度器已启动")
    
    def stop(self) -> None:
        """停止调度器"""
        if not self.running:
            return
        
        self.running = False
        schedule.clear()
        
        if self.scheduler_thread and self.scheduler_thread.is_alive():
            self.scheduler_thread.join(timeout=5)
        
        logger_manager.info("监控调度器已停止")
    
    def _run_scheduler(self) -> None:
        """运行调度器主循环"""
        logger_manager.info("调度器主循环开始")
        
        while self.running:
            try:
                schedule.run_pending()
                time.sleep(1)  # 每秒检查一次
            except Exception as e:
                logger_manager.error(f"调度器运行异常: {str(e)}")
                time.sleep(5)  # 发生异常时等待5秒后继续
        
        logger_manager.info("调度器主循环结束")
    
    def run_once(self) -> None:
        """手动执行一次监控任务"""
        logger_manager.info("手动执行监控任务")
        self._monitor_job()
    
    def get_next_run_time(self) -> Optional[str]:
        """获取下次运行时间"""
        try:
            next_run = schedule.next_run()
            if next_run:
                return next_run.strftime('%Y-%m-%d %H:%M:%S')
        except Exception:
            pass
        return None
    
    def get_jobs_info(self) -> list:
        """获取任务信息"""
        jobs_info = []
        
        for job in schedule.jobs:
            try:
                next_run = job.next_run.strftime('%Y-%m-%d %H:%M:%S') if job.next_run else 'N/A'
                jobs_info.append({
                    'job_func': str(job.job_func),
                    'interval': str(job.interval),
                    'unit': job.unit,
                    'next_run': next_run
                })
            except Exception as e:
                logger_manager.error(f"获取任务信息失败: {str(e)}")
        
        return jobs_info
    
    def reload_config(self) -> None:
        """重新加载配置并重新设置任务"""
        if self.running:
            logger_manager.info("重新加载配置...")
            
            # 重新加载配置
            config_manager.reload_config()
            self.monitor_config = config_manager.get_monitor_config()
            self.monitor_interval = self.monitor_config.get('interval', 60)
            
            # 重新设置任务
            self.setup_jobs()
            
            logger_manager.info("配置已重新加载")


# 全局调度器实例
monitor_scheduler = MonitorScheduler() 