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
from typing import Dict, Any, Optional
from datetime import datetime

from .config import config_manager
from .logger import logger_manager


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
        获取服务器IP地址
        
        Returns:
            服务器IP地址
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
    
    def send_alert(self, metric: str, current_value: float, 
                   threshold: float, hostname: str) -> bool:
        """
        发送告警消息
        
        Args:
            metric: 监控指标名称
            current_value: 当前值
            threshold: 阈值
            hostname: 主机名
            
        Returns:
            发送是否成功
        """
        try:
            # 检查配置
            if not self.webhook_url:
                logger_manager.error("钉钉Webhook URL未配置")
                return False
            
            # 构建请求URL
            url = self._build_webhook_url()
            
            # 格式化消息
            message = self._format_alert_message(metric, current_value, threshold, hostname)
            
            # 发送请求
            logger_manager.debug(f"发送钉钉告警消息: {message}")
            
            response = requests.post(
                url,
                json=message,
                timeout=self.timeout,
                headers={'Content-Type': 'application/json'}
            )
            
            # 检查响应
            if response.status_code == 200:
                result = response.json()
                if result.get('errcode') == 0:
                    logger_manager.log_alert_sent(metric, current_value, threshold)
                    return True
                else:
                    error_msg = result.get('errmsg', '未知错误')
                    logger_manager.log_alert_failed(metric, f"钉钉API错误: {error_msg}")
                    return False
            else:
                logger_manager.log_alert_failed(metric, f"HTTP错误: {response.status_code}")
                return False
                
        except requests.exceptions.Timeout:
            logger_manager.log_alert_failed(metric, "请求超时")
            return False
        except requests.exceptions.RequestException as e:
            logger_manager.log_alert_failed(metric, f"网络错误: {str(e)}")
            return False
        except Exception as e:
            logger_manager.log_alert_failed(metric, f"发送失败: {str(e)}")
            return False
    
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