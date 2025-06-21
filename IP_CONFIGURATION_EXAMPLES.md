# Monitor4DingTalk IP地址配置示例

本文档提供了不同场景下的IP地址配置示例，帮助您选择最适合的配置方式。

## 配置示例

### 1. 自动模式（推荐）

```yaml
# 配置文件：config/config.yaml
server:
  ip_mode: "auto"
  public_ip_timeout: 5
```

**说明**：
- 自动尝试获取外网IP，失败则使用内网IP
- 适合大多数生产环境
- 网络故障时自动降级到内网IP

**告警消息示例**：
```
🚨 服务器资源告警

**服务器**: web-server-01
**IP地址**: 120.230.122.77
**时间**: 2025-06-21 17:00:00
**告警项**: CPU使用率
**当前值**: 85.50%
**告警阈值**: 80.00%
**告警级别**: 🟠 警告
```

### 2. 强制外网IP模式

```yaml
# 配置文件：config/config.yaml
server:
  ip_mode: "public"
  public_ip_timeout: 3
  public_ip_services:
    - "https://ipv4.icanhazip.com"
    - "https://api.ipify.org"
    - "https://checkip.amazonaws.com"
```

**说明**：
- 仅使用外网IP，无法获取时报错
- 适合云服务器或有公网IP的环境
- 提供备用的IP获取服务列表

**适用场景**：
- 云服务器（阿里云、腾讯云、AWS等）
- 有固定公网IP的物理服务器
- 需要明确区分不同服务器的场景

### 3. 强制内网IP模式

```yaml
# 配置文件：config/config.yaml
server:
  ip_mode: "private"
```

**说明**：
- 仅使用内网IP
- 适合内网环境或无公网访问的服务器
- 获取速度最快，无外网依赖

**适用场景**：
- 企业内网服务器
- 无公网访问权限的环境
- 对获取速度要求较高的场景

**告警消息示例**：
```
🚨 服务器资源告警

**服务器**: db-server-01
**IP地址**: 192.168.1.100
**时间**: 2025-06-21 17:00:00
**告警项**: 内存使用率
**当前值**: 88.20%
**告警阈值**: 85.00%
**告警级别**: 🟠 警告
```

### 4. 手动指定IP模式

```yaml
# 配置文件：config/config.yaml
server:
  ip_mode: "manual"
  manual_ip: "203.0.113.100"
```

**说明**：
- 使用手动指定的IP地址
- 适合有特殊网络环境的场景
- 获取速度最快，结果可控

**适用场景**：
- 复杂网络环境（多网卡、VPN等）
- 需要使用特定IP标识的场景
- 自动获取结果不准确的环境

## 网络环境适配建议

### 云服务器环境

**阿里云ECS**：
```yaml
server:
  ip_mode: "auto"  # 推荐
  public_ip_timeout: 5
```

**腾讯云CVM**：
```yaml
server:
  ip_mode: "public"  # 强制外网IP
  public_ip_timeout: 3
```

**AWS EC2**：
```yaml
server:
  ip_mode: "auto"
  public_ip_services:
    - "https://checkip.amazonaws.com"  # AWS专用服务优先
    - "https://ipv4.icanhazip.com"
```

### 企业内网环境

**纯内网环境**：
```yaml
server:
  ip_mode: "private"
```

**内网+有限外网访问**：
```yaml
server:
  ip_mode: "auto"
  public_ip_timeout: 2  # 缩短超时时间
```

### 特殊网络环境

**多网卡服务器**：
```yaml
server:
  ip_mode: "manual"
  manual_ip: "10.0.1.100"  # 指定业务网卡IP
```

**负载均衡环境**：
```yaml
server:
  ip_mode: "manual"
  manual_ip: "负载均衡器IP"
```

## 故障排查

### 外网IP获取失败

**问题**：配置为`public`模式但无法获取外网IP

**解决方案**：
1. 检查网络连接：`curl -s https://ipv4.icanhazip.com`
2. 调整超时时间：增加`public_ip_timeout`值
3. 更换IP服务：修改`public_ip_services`列表
4. 切换到auto模式：设置`ip_mode: "auto"`

### IP地址显示异常

**问题**：获取的IP地址不是期望的

**解决方案**：
1. 确认网络环境：使用`ifconfig`或`ip addr`查看网卡
2. 手动指定IP：切换到`manual`模式
3. 查看调试日志：设置日志级别为DEBUG

### 获取速度较慢

**问题**：IP获取耗时过长

**解决方案**：
1. 缩短超时时间：减少`public_ip_timeout`值
2. 优化服务列表：将响应快的服务排在前面
3. 切换到private模式：如果不需要外网IP

## 性能对比

| 模式 | 获取速度 | 网络依赖 | 准确性 | 推荐度 |
|------|----------|----------|--------|--------|
| auto | 中等 | 中等 | 高 | ⭐⭐⭐⭐⭐ |
| public | 较慢 | 高 | 高 | ⭐⭐⭐⭐ |
| private | 极快 | 无 | 中等 | ⭐⭐⭐ |
| manual | 极快 | 无 | 最高 | ⭐⭐⭐⭐ |

## 最佳实践

1. **生产环境推荐使用auto模式**，确保服务稳定性
2. **调整合适的超时时间**，平衡速度和成功率
3. **在配置文件中添加注释**，说明选择的原因
4. **定期测试IP获取功能**，确保服务正常
5. **监控告警消息中的IP信息**，验证配置效果

## 示例配置文件

完整的生产环境配置示例：

```yaml
# Monitor4DingTalk 生产环境配置
dingtalk:
  webhook_url: "https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"
  secret: "YOUR_SECRET"
  timeout: 10

# 服务器信息配置 - 根据环境选择
server:
  ip_mode: "auto"           # 推荐：自动模式
  public_ip_timeout: 5      # 适中的超时时间
  public_ip_services:
    - "https://ipv4.icanhazip.com"
    - "https://checkip.amazonaws.com"
    - "https://api.ipify.org"

monitor:
  interval: 30
  cpu:
    enabled: true
    threshold: 80.0
  memory:
    enabled: true
    threshold: 85.0
  disk:
    enabled: true
    threshold: 90.0
    paths: ["/", "/home"]

alert:
  dedup_window: 600  # 10分钟去重
```

---

**提示**：配置修改后无需重启服务，系统会自动重新读取配置。 