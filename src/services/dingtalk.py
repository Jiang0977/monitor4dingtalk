"""
钉钉推送服务
负责向钉钉机器人发送告警消息，包含消息签名和推送状态跟踪
"""

import time
import hmac
import hashlib
import base64
import urllib.parse
import requests
import socket
from typing import Dict, Any, Optional, TYPE_CHECKING
from datetime import datetime

from .config import config_manager
from .logger import logger_manager

if TYPE_CHECKING:
    from ..core.monitor import MonitorData


class DingTalkNotifier:
    """钉钉通知器"""
    
    def __init__(self):
        """初始化钉钉通知器"""
        self.config = config_manager.get_dingtalk_config()
        self.webhook_url = self.config.get('webhook_url', '')
        self.secret = self.config.get('secret', '')
        self.timeout = self.config.get('timeout', 10)
    
    def _generate_signature(self, timestamp: int) -> str:
        """
        生成钉钉机器人签名
        
        Args:
            timestamp: 时间戳（毫秒）
            
        Returns:
            签名字符串
        """
        if not self.secret:
            return ''
        
        # 构造签名字符串
        string_to_sign = f"{timestamp}\n{self.secret}"
        string_to_sign_enc = string_to_sign.encode('utf-8')
        secret_enc = self.secret.encode('utf-8')
        
        # 计算HMAC-SHA256签名
        hmac_code = hmac.new(secret_enc, string_to_sign_enc, digestmod=hashlib.sha256).digest()
        
        # Base64编码
        sign = urllib.parse.quote_plus(base64.b64encode(hmac_code))
        
        return sign
    
    def _build_webhook_url(self) -> str:
        """
        构建带签名的Webhook URL
        
        Returns:
            完整的Webhook URL
        """
        if not self.secret:
            return self.webhook_url
        
        # 生成时间戳（毫秒）
        timestamp = int(round(time.time() * 1000))
        
        # 生成签名
        sign = self._generate_signature(timestamp)
        
        # 构建完整URL
        webhook_url = f"{self.webhook_url}&timestamp={timestamp}&sign={sign}"
        
        return webhook_url
    
    def _format_alert_message(self, metric: str, current_value: float, 
                            threshold: float, hostname: str) -> Dict[str, Any]:
        """
        格式化告警消息
        
        Args:
            metric: 监控指标名称
            current_value: 当前值
            threshold: 阈值
            hostname: 主机名
            
        Returns:
            格式化的消息体
        """
        # 获取告警消息模板
        alert_config = config_manager.get_alert_config()
        template = alert_config.get('message_template', '')
        
        # 格式化时间戳
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # 获取服务器IP地址
        server_ip = self._get_server_ip()
        
        # 确定告警级别
        level = self._determine_alert_level(current_value, threshold)
        
        # 替换模板变量
        message_text = template.format(
            hostname=hostname,
            server_ip=server_ip,
            timestamp=timestamp,
            metric_name=self._get_metric_display_name(metric),
            current_value=f"{current_value:.2f}%",
            threshold=f"{threshold:.2f}%",
            level=level
        )
        
        # 构建钉钉消息体
        message = {
            "msgtype": "markdown",
            "markdown": {
                "title": f"服务器资源告警 - {hostname}",
                "text": message_text
            },
            "at": {
                "atAll": False
            }
        }
        
        return message
    
    def _format_recovery_message(self, monitor_data: 'MonitorData') -> Dict[str, Any]:
        """
        格式化告警恢复消息
        
        Args:
            monitor_data: 监控数据
            
        Returns:
            格式化的消息体
        """
        alert_config = config_manager.get_alert_config()
        template = alert_config.get('recovery_message_template', '')
        
        # 如果没有配置恢复模板，则使用默认模板
        if not template:
            template = """
✅ **告警恢复通知**

**服务器**: {hostname}
**IP 地址**: {server_ip}
**恢复时间**: {timestamp}
**监控项**: {metric_name}
**当前值**: {current_value} (已恢复正常)
"""
        
        # 格式化时间戳
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        # 获取服务器IP地址
        server_ip = self._get_server_ip()
        
        # 替换模板变量
        message_text = template.format(
            hostname=monitor_data.hostname,
            server_ip=server_ip,
            timestamp=timestamp,
            metric_name=self._get_metric_display_name(monitor_data.metric),
            current_value=f"{monitor_data.value:.2f}{monitor_data.unit}",
            threshold=f"{monitor_data.threshold:.2f}{monitor_data.unit}"
        )
        
        # 构建钉钉消息体
        message = {
            "msgtype": "markdown",
            "markdown": {
                "title": f"告警恢复 - {monitor_data.hostname}",
                "text": message_text
            }
        }
        
        return message
    
    def _determine_alert_level(self, current_value: float, threshold: float) -> str:
        """
        确定告警级别
        
        Args:
            current_value: 当前值
            threshold: 阈值
            
        Returns:
            告警级别
        """
        if current_value >= threshold * 1.2:  # 超过阈值20%
            return "🔴 严重"
        elif current_value >= threshold * 1.1:  # 超过阈值10%
            return "🟠 警告"
        else:
            return "🟡 注意"
    
    def _get_metric_display_name(self, metric: str) -> str:
        """
        获取监控指标的显示名称
        
        Args:
            metric: 监控指标名称
            
        Returns:
            显示名称
        """
        metric_names = {
            'cpu': 'CPU使用率',
            'memory': '内存使用率',
            'disk': '磁盘使用率',
            'network': '网络IO'
        }
        return metric_names.get(metric, metric)
    
    def _get_server_ip(self) -> str:
        """
        获取服务器IP地址（支持外网IP）
        
        Returns:
            服务器IP地址
        """
        server_config = config_manager.get_server_config()
        ip_mode = server_config.get('ip_mode', 'auto')
        
        # 手动指定IP模式
        if ip_mode == 'manual':
            manual_ip = server_config.get('manual_ip', '').strip()
            if manual_ip:
                logger_manager.debug(f"使用手动指定的IP地址: {manual_ip}")
                return manual_ip
            else:
                logger_manager.warning("手动IP模式但未指定IP地址，切换到自动模式")
                ip_mode = 'auto'
        
        # 强制获取外网IP
        if ip_mode == 'public':
            public_ip = self._get_public_ip()
            if public_ip:
                return public_ip
            else:
                logger_manager.warning("无法获取外网IP，切换到内网IP")
                return self._get_private_ip()
        
        # 强制获取内网IP
        if ip_mode == 'private':
            return self._get_private_ip()
        
        # 自动模式：先尝试外网IP，失败则用内网IP
        if ip_mode == 'auto':
            public_ip = self._get_public_ip()
            if public_ip:
                logger_manager.debug(f"获取到外网IP: {public_ip}")
                return public_ip
            else:
                private_ip = self._get_private_ip()
                logger_manager.debug(f"外网IP获取失败，使用内网IP: {private_ip}")
                return private_ip
        
        # 默认返回内网IP
        return self._get_private_ip()
    
    def _get_public_ip(self) -> str:
        """
        获取外网IP地址
        
        Returns:
            外网IP地址，获取失败返回空字符串
        """
        server_config = config_manager.get_server_config()
        services = server_config.get('public_ip_services', [
            "https://ipv4.icanhazip.com",
            "https://api.ipify.org",
            "https://checkip.amazonaws.com"
        ])
        timeout = server_config.get('public_ip_timeout', 5)
        
        for service_url in services:
            try:
                logger_manager.debug(f"尝试从 {service_url} 获取外网IP")
                response = requests.get(service_url, timeout=timeout)
                if response.status_code == 200:
                    # 处理不同服务的响应格式
                    if 'httpbin.org' in service_url:
                        # httpbin返回JSON格式: {"origin": "1.2.3.4"}
                        ip = response.json().get('origin', '').strip()
                    else:
                        # 其他服务直接返回IP地址
                        ip = response.text.strip()
                    
                    # 验证IP格式
                    if self._is_valid_ip(ip):
                        logger_manager.debug(f"成功获取外网IP: {ip}")
                        return ip
                    else:
                        logger_manager.debug(f"无效的IP格式: {ip}")
                        
            except requests.exceptions.Timeout:
                logger_manager.debug(f"请求超时: {service_url}")
                continue
            except requests.exceptions.RequestException as e:
                logger_manager.debug(f"请求失败: {service_url}, 错误: {str(e)}")
                continue
            except Exception as e:
                logger_manager.debug(f"获取外网IP异常: {service_url}, 错误: {str(e)}")
                continue
        
        logger_manager.debug("所有外网IP服务都无法访问")
        return ""
    
    def _get_private_ip(self) -> str:
        """
        获取内网IP地址
        
        Returns:
            内网IP地址
        """
        try:
            # 通过连接到外部地址来获取本机IP（不会真正发送数据）
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                # 使用Google的DNS服务器地址
                s.connect(("8.8.8.8", 80))
                ip = s.getsockname()[0]
                return ip
        except Exception:
            try:
                # 备用方法：获取本机hostname对应的IP
                hostname = socket.gethostname()
                ip = socket.gethostbyname(hostname)
                return ip
            except Exception:
                # 最后备用：返回127.0.0.1
                return "127.0.0.1"
    
    def _is_valid_ip(self, ip: str) -> bool:
        """
        验证IP地址格式
        
        Args:
            ip: IP地址字符串
            
        Returns:
            是否为有效的IP地址
        """
        try:
            parts = ip.split('.')
            if len(parts) != 4:
                return False
            for part in parts:
                if not (0 <= int(part) <= 255):
                    return False
            return True
        except (ValueError, AttributeError):
            return False
    
    def _send_message(self, message: Dict[str, Any], metric_name: str) -> bool:
        """
        通用消息发送方法
        
        Args:
            message: 消息体
            metric_name: 监控指标名称 (用于日志)
        
        Returns:
            发送是否成功
        """
        try:
            if not self.webhook_url:
                logger_manager.error("钉钉Webhook URL未配置")
                return False

            url = self._build_webhook_url()
            logger_manager.debug(f"发送钉钉消息: {message}")

            response = requests.post(
                url,
                json=message,
                timeout=self.timeout,
                headers={'Content-Type': 'application/json'}
            )

            if response.status_code == 200:
                result = response.json()
                if result.get('errcode') == 0:
                    return True
                else:
                    error_msg = result.get('errmsg', '未知错误')
                    logger_manager.log_alert_failed(metric_name, f"钉钉API错误: {error_msg}")
                    return False
            else:
                logger_manager.log_alert_failed(metric_name, f"HTTP错误: {response.status_code}")
                return False

        except requests.exceptions.Timeout:
            logger_manager.log_alert_failed(metric_name, "请求超时")
            return False
        except requests.exceptions.RequestException as e:
            logger_manager.log_alert_failed(metric_name, f"网络错误: {str(e)}")
            return False
        except Exception as e:
            logger_manager.log_alert_failed(metric_name, f"发送失败: {str(e)}")
            return False

    def send_alert(self, monitor_data: 'MonitorData') -> bool:
        """
        发送告警消息
        
        Args:
            monitor_data: 监控数据对象
            
        Returns:
            发送是否成功
        """
        message = self._format_alert_message(
            metric=monitor_data.metric,
            current_value=monitor_data.value,
            threshold=monitor_data.threshold,
            hostname=monitor_data.hostname
        )
        success = self._send_message(message, monitor_data.metric)
        if success:
            logger_manager.log_alert_sent(
                monitor_data.metric, monitor_data.value, monitor_data.threshold
            )
        return success

    def send_recovery_notification(self, monitor_data: 'MonitorData') -> bool:
        """
        发送告警恢复通知
        
        Args:
            monitor_data: 监控数据对象
            
        Returns:
            发送是否成功
        """
        message = self._format_recovery_message(monitor_data)
        success = self._send_message(message, monitor_data.metric)
        if success:
            logger_manager.info(f"告警恢复通知已发送 - {monitor_data.metric}")
        return success

    def test_connection(self) -> bool:
        """
        测试钉钉连接
        
        Returns:
            连接是否成功
        """
        try:
            hostname = socket.gethostname()
            server_ip = self._get_server_ip()
            
            # 发送测试消息
            test_message = {
                "msgtype": "text",
                "text": {
                    "content": f"Monitor4DingTalk 测试消息\n主机: {hostname}\nIP地址: {server_ip}\n时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
                }
            }
            
            url = self._build_webhook_url()
            response = requests.post(
                url,
                json=test_message,
                timeout=self.timeout,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                result = response.json()
                if result.get('errcode') == 0:
                    logger_manager.info("钉钉连接测试成功")
                    return True
                else:
                    logger_manager.error(f"钉钉连接测试失败: {result.get('errmsg', '未知错误')}")
                    return False
            else:
                logger_manager.error(f"钉钉连接测试失败: HTTP {response.status_code}")
                return False
                
        except Exception as e:
            logger_manager.error(f"钉钉连接测试异常: {str(e)}")
            return False


# 全局钉钉通知器实例
dingtalk_notifier = DingTalkNotifier() 