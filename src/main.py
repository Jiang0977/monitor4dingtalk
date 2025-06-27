"""
Monitor4DingTalk 主程序
服务器资源监控钉钉告警系统
"""

import sys
import signal
import argparse
from pathlib import Path

# 添加项目根目录到Python路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.services.config import config_manager
from src.services.logger import logger_manager
from src.services.dingtalk import dingtalk_notifier
from src.core.monitor import resource_monitor
from src.core.alert import alert_engine
from src.utils.scheduler import monitor_scheduler


class Monitor4DingTalk:
    """Monitor4DingTalk 主应用类"""
    
    def __init__(self):
        """初始化应用"""
        self.running = False
    
    def signal_handler(self, signum, frame):
        """信号处理器"""
        logger_manager.info(f"接收到信号 {signum}，准备退出...")
        self.stop()
        sys.exit(0)
    
    def setup_signal_handlers(self):
        """设置信号处理器"""
        signal.signal(signal.SIGINT, self.signal_handler)
        signal.signal(signal.SIGTERM, self.signal_handler)
    
    def start(self):
        """启动监控服务"""
        try:
            logger_manager.log_system_start()
            
            # 显示系统信息
            system_info = resource_monitor.get_system_info()
            logger_manager.info(f"系统信息: {system_info}")
            
            # 启动调度器
            monitor_scheduler.start()
            self.running = True
            
            logger_manager.info("Monitor4DingTalk 启动成功，按 Ctrl+C 退出")
            
            # 主循环
            self._main_loop()
            
        except Exception as e:
            logger_manager.critical(f"启动失败: {str(e)}")
            sys.exit(1)
    
    def stop(self):
        """停止监控服务"""
        if self.running:
            logger_manager.info("正在停止监控服务...")
            monitor_scheduler.stop()
            self.running = False
            logger_manager.log_system_stop()
    
    def _main_loop(self):
        """主循环"""
        try:
            import time
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            logger_manager.info("接收到键盘中断信号")
            self.stop()
    
    def test_dingtalk(self):
        """测试钉钉连接"""
        logger_manager.info("开始测试钉钉连接...")
        
        success = dingtalk_notifier.test_connection()
        if success:
            print("✅ 钉钉连接测试成功")
            return True
        else:
            print("❌ 钉钉连接测试失败，请检查配置")
            return False
    
    def run_monitor_once(self):
        """执行一次监控检查"""
        logger_manager.info("执行一次监控检查...")
        
        # 收集所有监控数据
        all_metrics = resource_monitor.collect_all_metrics()
        
        print("📊 当前系统资源状态:")
        print("-" * 50)
        
        alert_candidates = []
        for metric_data in all_metrics:
            status = "🔴 关注" if metric_data.is_alert else "✅ 正常"
            print(f"{metric_data.metric}: {metric_data.value:.2f}{metric_data.unit} "
                  f"(阈值: {metric_data.threshold:.2f}{metric_data.unit}) - {status}")
            if metric_data.is_alert:
                alert_candidates.append(metric_data)

        # 即使是单次运行，也通过告警引擎处理，以应用连续次数和恢复逻辑
        print("\n⚙️  正在通过告警引擎分析...")
        # 注意：在--once模式下，连续检测和恢复通知可能不会按预期工作，
        # 因为它只执行一次。但为了逻辑统一，我们仍然使用新流程。
        results = alert_engine.check_and_process(all_metrics)

        if results:
            success_count = sum(1 for success in results.values() if success)
            print(f"\n🚨 告警发送完成: 成功 {success_count}/{len(results)}")
        else:
            # 需要检查是否有恢复的告警
            if not any(m.is_alert for m in all_metrics):
                 print("\n✅ 所有指标正常，无需告警")
            else:
                 print("\n🟡 指标超标，但未达到连续告警阈值，本次不发送告警")
    
    def show_status(self):
        """显示系统状态"""
        print("📈 Monitor4DingTalk 系统状态")
        print("=" * 60)
        
        # 系统信息
        system_info = resource_monitor.get_system_info()
        print(f"主机名: {system_info.get('hostname', 'Unknown')}")
        print(f"CPU核心数: {system_info.get('cpu_count', 'Unknown')}")
        print(f"总内存: {system_info.get('memory_total', 'Unknown')}")
        print(f"系统启动时间: {system_info.get('boot_time', 'Unknown')}")
        
        # 监控配置
        monitor_config = config_manager.get_monitor_config()
        print(f"\n监控间隔: {monitor_config.get('interval', 60)}秒")
        
        enabled_metrics = []
        for metric in ['cpu', 'memory', 'disk', 'network']:
            if config_manager.is_metric_enabled(metric):
                threshold = config_manager.get_metric_threshold(metric)
                enabled_metrics.append(f"{metric}({threshold}%)")
        
        print(f"启用的监控项: {', '.join(enabled_metrics) if enabled_metrics else '无'}")
        
        # 告警状态
        alert_status = alert_engine.get_alert_status()
        print(f"\n告警去重窗口: {alert_status['dedup_window']}秒")
        print(f"历史告警数量: {alert_status['total_sent_alerts']}")
        print(f"持续告警指标: {alert_status['persistent_alerts'] if alert_status['persistent_alerts'] else '无'}")
        
        # 调度器状态
        if monitor_scheduler.running:
            next_run = monitor_scheduler.get_next_run_time()
            print(f"\n调度器状态: 运行中")
            print(f"下次执行时间: {next_run if next_run else '未知'}")
        else:
            print(f"\n调度器状态: 已停止")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description='Monitor4DingTalk - 服务器资源监控钉钉告警系统')
    parser.add_argument('--config', '-c', default='config/config.yaml', 
                       help='配置文件路径 (默认: config/config.yaml)')
    parser.add_argument('--test', action='store_true', 
                       help='测试钉钉连接')
    parser.add_argument('--once', action='store_true', 
                       help='执行一次监控检查后退出')
    parser.add_argument('--status', action='store_true', 
                       help='显示系统状态')
    parser.add_argument('--version', action='version', version='Monitor4DingTalk 1.0.0')
    
    args = parser.parse_args()
    
    # 初始化配置管理器
    try:
        config_manager.config_path = Path(args.config)
        config_manager.load_config()
    except Exception as e:
        print(f"❌ 配置文件加载失败: {e}")
        sys.exit(1)
    
    # 创建应用实例
    app = Monitor4DingTalk()
    
    # 根据参数执行不同功能
    if args.test:
        # 测试钉钉连接
        success = app.test_dingtalk()
        sys.exit(0 if success else 1)
    
    elif args.once:
        # 执行一次监控
        app.run_monitor_once()
        sys.exit(0)
    
    elif args.status:
        # 显示状态
        app.show_status()
        sys.exit(0)
    
    else:
        # 启动监控服务
        app.setup_signal_handlers()
        app.start()


if __name__ == '__main__':
    main() 