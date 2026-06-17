# macOS 轻量菜单栏系统监控工具开发说明书

## 1. 产品目标

开发一个只面向 Apple Silicon Mac 的超轻量菜单栏 App，用于替代频繁打开活动监视器和 CleanMyMac 查看电脑状态的场景。

第一版只做三类监控：

- CPU 使用率
- 内存使用情况
- 电池与温度状态

设计原则：

- 原生 macOS App，不使用 Electron、WebView 或跨平台 UI 框架。
- 常驻菜单栏，但不显示 Dock 图标。
- 菜单栏只显示一个图标，不显示文字。
- 点击菜单栏图标后展示详细状态窗口。
- 弹窗中必须提供“退出”功能，点击后直接结束 App 进程。
- 不做清理垃圾、杀进程、卸载 App、进程管理等 CleanMyMac 类功能。
- 不上传、不记录、不分析用户隐私数据。

## 2. 技术选型

### 2.1 推荐技术栈

- 语言：Swift
- UI：SwiftUI
- 菜单栏集成：AppKit `NSStatusItem`
- 弹窗容器：AppKit `NSPopover`
- 系统数据采集：
  - CPU：Mach API
  - 内存：Mach API + `sysctl`
  - 电池：IOKit Power Sources
  - 系统低电量模式：`ProcessInfo.processInfo.isLowPowerModeEnabled`
  - 系统热状态：`ProcessInfo.processInfo.thermalState`
  - 实时温度：优先 Apple Silicon HID 温度传感器；HID 不可用时低频短采样尝试 `powermetrics`
- 设置存储：`UserDefaults`

### 2.2 为什么不用 Electron

Electron 常驻菜单栏会额外引入 Chromium 和 Node.js 运行时。对于这个工具的目标，Electron 的基础内存占用和启动成本明显偏高，不适合“超轻量”目标。

### 2.3 为什么选择 AppKit + SwiftUI

`NSStatusItem` 和 `NSPopover` 是 macOS 菜单栏 App 的成熟原生方案。SwiftUI 负责弹窗内容可以减少 UI 代码量，同时 AppKit 保留对菜单栏行为、弹窗关闭、退出逻辑的精确控制。

## 3. App 结构

建议创建一个标准 macOS App 项目：

- Platform：macOS
- Interface：SwiftUI
- Language：Swift
- Minimum Deployment：macOS 13 或更高
- Target Device：Mac

建议模块划分：

```text
App/
  MonitorApp.swift
  AppDelegate.swift

StatusBar/
  StatusBarController.swift

Metrics/
  MetricsSampler.swift
  AppResourceMonitor.swift
  CPUMonitor.swift
  MemoryMonitor.swift
  BatteryMonitor.swift
  ThermalMonitor.swift
  HIDTemperatureMonitor.swift
  PowermetricsTemperatureMonitor.swift
  SystemSnapshot.swift

Settings/
  SettingsStore.swift

UI/
  PopoverRootView.swift
  DashboardView.swift
  MetricSectionView.swift
  TrendLineView.swift
  SettingsView.swift
```

## 4. App 生命周期设计

### 4.1 无 Dock 图标

在 `Info.plist` 中设置：

```xml
<key>LSUIElement</key>
<true/>
```

效果：

- App 启动后不出现在 Dock。
- App 不显示标准菜单栏应用菜单。
- 用户主要通过右上角菜单栏图标操作 App。

同时，`.app` Bundle 通过 `CFBundleIconFile` 引用 `AppIcon.icns`，使 App 在 Finder、启动台、Dock（若手动打开）等处显示监控风格应用图标（使用 `waveform.path.ecg` 生成）。

### 4.2 菜单栏入口

使用 `NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)` 创建菜单栏图标。

要求：

- 菜单栏只显示图标，不显示文字。
- 图标应使用 SF Symbols。

当前实现：

- 图标使用 `waveform.path.ecg`，保持恒定，不随系统状态变化。
- 图标使用系统模板色，适配深色/浅色菜单栏。

图标行为：

- 左键点击：打开或关闭详情弹窗。
- 点击弹窗外区域：自动关闭弹窗。
- 弹窗打开时，提高采样频率。
- 弹窗关闭时，降低采样频率。

### 4.3 退出功能

弹窗底部必须有“退出”按钮。

点击后直接结束 App：

```swift
NSApp.terminate(nil)
```

这是 macOS App 的标准退出方式。对于本工具的需求来说，验收结果必须等同于“全部关闭”：

- 菜单栏图标立即消失。
- 弹窗关闭。
- App 主进程从活动监视器中消失。
- 不保留后台 helper 进程。
- 不保留采样 Timer。
- 不保留 CPU、内存、电池、温度监控任务。

`NSApp.terminate(nil)` 与 `exit(0)` 的区别：

- `NSApp.terminate(nil)` 会走 AppKit 的正常退出流程，让系统有机会关闭窗口、释放菜单栏项、停止事件循环，并执行必要清理。
- `exit(0)` 会更直接地终止当前进程，基本绕过 AppKit 的正常退出流程，不保证 UI 和资源清理逻辑完整执行。

本工具推荐默认使用：

```swift
NSApp.terminate(nil)
```

如果后续开发中发现某些异常状态下 `NSApp.terminate(nil)` 不能让进程退出，才考虑加入兜底：

```swift
DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
    exit(0)
}
```

兜底逻辑只应作为异常保护，不应作为常规退出路径。

如果明确希望更“硬”的结束方式，可以使用：

```swift
exit(0)
```

但推荐使用 `NSApp.terminate(nil)`，因为它能让系统正常完成清理。

退出功能验收时，以活动监视器为准：点击退出后，该 App 进程必须消失。

## 4.4 菜单栏图标样式

菜单栏图标只显示符号，不显示文字。

推荐图标方向：

- 风格：系统原生、线性、轻量。
- 尺寸：使用 `NSStatusItem.squareLength`，让系统控制菜单栏占位。
- 颜色：默认使用系统模板色，适配深色/浅色模式。
- 形态：优先选择“监控/生命体征/仪表盘”意象，不使用复杂插画。

当前使用 SF Symbol：

```text
waveform.path.ecg
```

实现要点：

```swift
let image = NSImage(
    systemSymbolName: "waveform.path.ecg",
    accessibilityDescription: "System Monitor"
)

image?.isTemplate = true
statusItem.button?.image = image
```

图标状态：

- 正常：系统默认模板色。
- 推荐第一版保持菜单栏图标恒定，不做状态变色：
  - 更符合轻量工具定位。
  - 避免菜单栏视觉干扰。
  - 减少 UI 状态复杂度。
  - 详细状态已经在点击后的弹窗中展示。

菜单栏图标验收：

- 菜单栏只出现一个图标。
- 图标没有文字。
- 深色/浅色模式下都清晰可见。
- 图标点击区域稳定，不因状态变化改变宽度。
- 弹窗打开和关闭时图标不跳动。

## 5. 数据模型

核心快照模型：

```swift
struct SystemSnapshot {
    let cpu: CPUStatus
    let memory: MemoryStatus
    let battery: BatteryStatus?
    let thermal: ThermalStatus
    let appResource: AppResourceStatus
    let sampledAt: Date
}
```

CPU：

```swift
struct CPUStatus {
    let usagePercent: Double
    let userPercent: Double
    let systemPercent: Double
    let idlePercent: Double
}
```

内存：

```swift
struct MemoryStatus {
    let totalBytes: UInt64
    let usedBytes: UInt64
    let availableBytes: UInt64
    let pressure: MemoryPressure
}

enum MemoryPressure {
    case normal
    case elevated
    case high
}
```

电池：

```swift
struct BatteryStatus {
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let timeRemainingMinutes: Int?
    let isLowPowerModeEnabled: Bool
}
```

温度/热状态：

```swift
struct ThermalStatus {
    let state: ThermalState
    let averageTemperatureCelsius: Double?
    let minimumTemperatureCelsius: Double?
    let maximumTemperatureCelsius: Double?
    let temperatureSource: String?
    let temperatureSensorCount: Int
    let temperatureStatus: TemperatureStatus
    let temperatureSampledAt: Date?
}

enum ThermalState {
    case nominal
    case fair
    case serious
    case critical
}

enum TemperatureStatus {
    case available
    case needsPermission
    case unavailable
}

App 自身资源占用：

```swift
struct AppResourceStatus {
    let cpuUsagePercent: Double
    let memoryBytes: UInt64
}
```
```

## 6. 采样逻辑

### 6.1 MetricsSampler

`MetricsSampler` 是唯一负责定时采样的模块。

职责：

- 持有 `CPUMonitor`、`MemoryMonitor`、`BatteryMonitor`、`ThermalMonitor`。
- 持有 `AppResourceMonitor`，采样 MonitorTool 自身 CPU 与内存占用。
- 定时采样并生成 `SystemSnapshot`。
- 向 SwiftUI 发布最新状态。
- 根据弹窗状态切换刷新频率。
- 监听刷新频率设置变更，设置修改后立即重建 Timer。
- 每次采样都尝试读取温度；弹窗打开时按高频实时更新，弹窗关闭时降频。

推荐刷新频率：

- 弹窗关闭：每 8 秒采样一次。
- 弹窗打开：每 1 秒采样一次。
- 系统休眠：停止采样。
- 系统唤醒：恢复采样并立即刷新一次。

验证标准：

- 弹窗关闭后，App CPU 占用应长期接近 0。
- 弹窗打开后，数据每秒刷新。
- 关闭弹窗后，不应继续每秒采样。

### 6.2 CPU 采样

使用 Mach 的 `host_processor_info` 获取每个 CPU 核心 tick。

实现逻辑：

1. 首次采样时保存 CPU tick，不计算使用率。
2. 第二次采样开始，与上一次 tick 做差。
3. 根据 user、system、nice、idle 的 delta 计算占比。
4. 输出总 CPU 使用率。

计算公式：

```text
totalDelta = userDelta + systemDelta + niceDelta + idleDelta
usage = (totalDelta - idleDelta) / totalDelta
```

验证方法：

- 打开活动监视器，对比 CPU 总使用率趋势。
- 启动一个高负载任务，例如视频转码或编译项目，确认数值上升。
- 结束高负载任务，确认数值回落。

### 6.3 内存采样

使用：

- `sysctlbyname("hw.memsize")` 获取物理内存总量。
- `host_statistics64` 获取内存页信息。

需要关注：

- free
- active
- inactive
- wired
- compressed

推荐计算：

```text
used = active + wired + compressed
available = free + inactive
```

内存压力建议规则：

- used / total < 70%：normal
- 70% - 85%：elevated
- > 85%：high

验证方法：

- 与活动监视器内存页对比，总量必须一致。
- 已用内存不要求完全一致，但趋势应接近。
- 打开大型 App 后，已用内存应上升。
- 关闭大型 App 后，可用内存应逐渐恢复。

### 6.4 App 自身资源采样

使用：

- `getrusage(RUSAGE_SELF)` 获取当前进程 user/system CPU time。
- `ProcessInfo.processInfo.systemUptime` 计算采样时间差。
- `task_info(TASK_VM_INFO)` 获取当前进程 `phys_footprint`。

计算：

```text
appCPUPercent = deltaProcessCPUTime / deltaWallClockTime * 100
appMemory = task_vm_info.phys_footprint
```

验证方法：

- 弹窗打开时，“本 App 占用”中 CPU 与内存有数值。
- CPU 低负载时应接近 0。
- 内存值应与活动监视器中 MonitorTool 的内存趋势接近。

### 6.5 电池采样

使用 IOKit Power Sources：

- `IOPSCopyPowerSourcesInfo`
- `IOPSCopyPowerSourcesList`
- `IOPSGetPowerSourceDescription`

读取字段：

- `kIOPSCurrentCapacityKey`
- `kIOPSMaxCapacityKey`
- `kIOPSIsChargingKey`
- `kIOPSPowerSourceStateKey`
- `kIOPSTimeToEmptyKey`
- `kIOPSTimeToFullChargeKey`

同时读取：

- `ProcessInfo.processInfo.isLowPowerModeEnabled`

无电池设备处理：

- `BatteryStatus` 返回 `nil`。
- UI 显示“未检测到电池”或隐藏电池百分比。
- App 不崩溃。

验证方法：

- 与系统菜单栏电池百分比对比。
- 与系统菜单栏低电量模式颜色/状态对比。
- 插拔电源，确认充电状态更新。
- UI 中必须独立展示充电状态：充电中 / 已连接电源 / 使用电池。
- 满电、低电量、低电量模式、充电中都应正常显示。

### 6.6 温度/热状态

热状态：

- 使用 `ProcessInfo.processInfo.thermalState`。
- 始终显示系统热状态。

映射关系：

```text
.nominal  -> 正常
.fair     -> 略热
.serious  -> 偏热
.critical -> 过热
```

实时温度：

- 默认随每次采样尝试读取 Apple Silicon HID 温度传感器。
- HID 读取失败时，可低频尝试 `sudo -n /usr/bin/powermetrics --samplers thermal -n 1 -i 1000` 作为兜底。
- `powermetrics` 兜底必须是短生命周期进程，不能常驻；当前建议至少 60 秒限流，并设置 4 秒以内超时。
- UI 可在热状态行提供“授权刷新”按钮，手动触发 `osascript` 管理员授权弹窗，短时运行 `powermetrics`。
- 读取成功时填充 `averageTemperatureCelsius`、`minimumTemperatureCelsius`、`maximumTemperatureCelsius`、`temperatureSource`、`temperatureSensorCount` 与 `temperatureSampledAt`，`temperatureStatus` 为 `.available`。
- 需要权限或读取失败时温度返回 `nil`，UI 显示“需要权限或不可用，已降级”。
- 不保存 sudo 密码。
- 不保留 root 后台命令行工具。

实时温度是 best-effort 本机读取：成功时展示摄氏温度，失败时必须安静降级，不影响热状态展示和 App 可用性。即使允许权限，也必须保持低内存设计，不能为了温度常驻高占用 helper 或长时间运行 `powermetrics`。

验证方法：

- 弹窗打开时温度按当前刷新频率更新。
- 自动 `powermetrics` 兜底不应比限流间隔更频繁。
- 点击热状态行的“授权刷新”按钮时可以弹出系统管理员授权窗口，并在采样后退出子进程。
- 如读取成功，显示温度、来源和传感器数量。
- 如需要权限或读取失败，App 不崩溃，UI 正常显示热状态，并明确提示已降级。

## 7. UI 设计说明

### 7.1 弹窗尺寸

推荐：

- 宽度：340 px
- 高度：420-480 px
- 样式：紧凑仪表盘

要求：

- 信息密度高。
- 不做大面积装饰。
- 不使用复杂动画。
- 不使用半透明模糊重特效。

### 7.2 弹窗布局

结构：

```text
顶部状态摘要

CPU
  当前使用率
  用户态 / 系统态
  小型趋势线

内存
  已用 / 总量
  可用
  压力状态
  进度条

本 App 占用
  CPU
  内存

电池与温度
  电量
  充电状态
  电源模式（标准模式 / 低电量模式）
  采样模式（省电 / 标准 / 实时）
  剩余时间
  热状态
  平均温度
  最高温度
  最低温度
  温度来源（读取成功 / 不可用，已降级为热状态）

底部操作
  设置
  最后刷新时间
  退出
```

### 7.3 视觉状态

整体状态建议：

- 正常：绿色或系统默认色
- 负载偏高：黄色
- 严重压力或过热：红色

不要让菜单栏图标一直闪烁，也不要使用频繁动画。

### 7.4 退出按钮

底部右侧放置“退出”按钮。

点击行为：

```swift
NSApp.terminate(nil)
```

验证方法：

- 点击退出后，菜单栏图标立即消失。
- 活动监视器中 App 进程消失。
- 重新启动 App 后能正常运行。

## 8. 设置项

第一版建议只做必要设置：

- 刷新频率：
  - 省电：弹窗关闭 15 秒，打开 2 秒
  - 标准：弹窗关闭 8 秒，打开 1 秒
  - 实时：弹窗关闭 5 秒，打开 0.5 秒

菜单栏显示模式不需要做，因为你的要求是菜单栏只显示图标。

开机启动第一版暂不提供设置入口，避免在没有登录项 Helper 的情况下出现“看似开启但实际无效”的伪状态。后续若要实现，应先补齐 `SMAppService` 登录项 Helper 与打包结构，再开放 UI。

设置存储：

```swift
UserDefaults.standard
```

验证方法：

- 修改刷新频率后，当前采样 Timer 立即按新频率生效。
- 修改设置后退出 App。
- 重新打开 App，设置仍然保留。

## 9. 权限与隐私

默认模式不请求任何额外权限。

不需要：

- 辅助功能权限
- 全磁盘访问权限
- 网络权限
- 定位权限
- 通讯录权限

可选权限：

- 若用户明确允许，可通过系统配置让 `/usr/bin/powermetrics` 以 root 权限短时运行。
- App 不保存 sudo 密码，不弹伪密码输入框，不保留 root helper。
- `powermetrics` 只能作为低频、短生命周期兜底温度源。

隐私原则：

- 所有数据只在本机内存中使用。
- 不写入历史数据库。
- 不上传服务器。
- 不采集进程列表。
- 不读取用户文件。

## 10. 性能要求

目标：

- 弹窗关闭时 CPU 长期接近 0。
- 弹窗打开时 CPU 不应持续超过 2%。
- 常驻内存尽量低于 50 MB。
- 不出现稳定增长的内存泄漏。

实现要求：

- 采样不要放在主线程执行。
- UI 更新回到主线程。
- Timer 必须能在弹窗关闭时降频。
- App 退出时释放 Timer。
- 避免 Combine、Timer、闭包产生循环引用。

验证方法：

1. 启动 App，关闭弹窗，等待 5 分钟。
2. 使用活动监视器查看 App CPU 和内存。
3. 打开弹窗 1 分钟，确认数据刷新正常。
4. 关闭弹窗，再观察 CPU 是否回落。
5. 连续运行 1-2 小时，确认内存没有持续增长。

## 11. 开发步骤

### 第一步：创建基础菜单栏 App

实现内容：

- 创建 macOS SwiftUI App。
- 设置 `LSUIElement = true`。
- 配置 `CFBundleIconFile` 与 `AppIcon.icns`，为 `.app` Bundle 提供应用图标。
- 创建 `NSStatusItem`。
- 菜单栏显示单个图标（`waveform.path.ecg`，保持恒定）。
- 点击图标显示 `NSPopover`。
- 点击弹窗外区域自动关闭弹窗。
- 弹窗中放一个占位 SwiftUI 页面。
- 弹窗底部实现“退出”按钮。

验收：

- App 启动后不出现在 Dock。
- 菜单栏出现图标。
- 点击图标能打开弹窗。
- 点击外部区域弹窗关闭。
- 点击退出后 App 进程结束。

### 第二步：实现 CPU 监控

实现内容：

- 新建 `CPUMonitor`。
- 使用 Mach API 读取 CPU tick。
- 计算总 CPU 使用率。
- UI 展示当前 CPU 百分比。
- 保存最近 60 个采样点用于趋势线。

验收：

- CPU 数值每秒刷新。
- 与活动监视器趋势一致。
- 高负载任务开始后数值上升。
- 高负载任务停止后数值下降。

### 第三步：实现内存监控

实现内容：

- 新建 `MemoryMonitor`。
- 读取总内存。
- 读取 active、inactive、wired、compressed、free。
- 计算 used、available、pressure。
- UI 展示已用 / 总量、可用内存、压力状态。

验收：

- 总内存显示正确。
- 已用内存趋势与活动监视器接近。
- 打开大型 App 后内存使用上升。
- UI 不因数值变化跳动。

### 第四步：实现电池监控

实现内容：

- 新建 `BatteryMonitor`。
- 使用 IOKit 读取电量、充电状态、剩余时间。
- 使用 `ProcessInfo.processInfo.isLowPowerModeEnabled` 读取系统低电量模式。
- 无电池时返回 `nil`。
- UI 展示电量、充电状态、剩余时间、电源模式和当前采样模式。

验收：

- 电量与系统菜单栏一致。
- 系统低电量模式开启时，App 内电源模式和电池颜色同步变为低电量状态。
- 插拔电源后状态变化。
- 无电池设备不崩溃。

### 第五步：实现热状态与实时温度

实现内容：

- 新建 `ThermalMonitor`。
- 始终读取 `ProcessInfo.thermalState`。
- 新建 `HIDTemperatureMonitor`，默认随采样尝试读取 Apple Silicon HID 温度传感器。
- 新建 `PowermetricsTemperatureMonitor`，仅在 HID 不可用时低频短采样尝试 `powermetrics` 兜底。
- 温度读取成功时返回平均、最高、最低摄氏温度、来源和传感器数量。
- 需要权限或温度读取失败时返回 `nil`，并将温度状态标记为需要权限或不可用。
- UI 展示热状态、平均温度、最高温度、最低温度和温度来源/降级状态。

验收：

- 弹窗打开时实时温度按当前刷新频率更新。
- 温度读取成功时显示摄氏温度。
- 需要权限或温度读取失败也不影响 App，并提示“需要权限或不可用，已降级”。
- 不出现长期运行的 `powermetrics` 进程。
- 热状态始终有可展示结果。

### 第六步：实现刷新频率切换

实现内容：

- 新建 `MetricsSampler`。
- 弹窗打开时使用高频采样。
- 弹窗关闭时使用低频采样。
- 刷新频率设置变更后立即重建 Timer。
- 监听休眠和唤醒通知。
- 休眠时暂停采样，唤醒后恢复。

验收：

- 弹窗打开时每秒刷新。
- 弹窗关闭时不再高频刷新。
- 设置从省电 / 标准 / 实时之间切换时立即生效。
- 休眠唤醒后数据恢复。
- 活动监视器中 CPU 占用符合轻量目标。

### 第七步：完善 UI

实现内容：

- 顶部增加整体状态摘要。
- CPU、内存、电池温度分区展示。
- 本 App 占用分区展示 MonitorTool 自身 CPU 与内存。
- 电池区域展示电量、充电状态、系统电源模式和 App 采样模式。
- 温度区域展示热状态、平均温度、最高温度、最低温度和温度来源/降级状态。
- 增加趋势线。
- 增加最后刷新时间。
- 增加设置入口。
- 底部固定显示退出按钮。

验收：

- 弹窗宽度 340 px 左右。
- 所有文字不重叠。
- 深色和浅色模式都清晰。
- 小屏幕和外接显示器下弹窗位置正常。

### 第八步：实现设置

实现内容：

- 使用 `UserDefaults` 保存设置。
- 支持刷新频率切换。
- 暂不提供开机启动入口。

验收：

- 设置修改后立即生效。
- 退出重启后设置仍保留。
- 没有展示无法真实生效的开机启动开关。

## 12. 最终验收清单

功能：

- App 无 Dock 图标，`.app` Bundle 有应用图标。
- 菜单栏只显示图标，图标为 `waveform.path.ecg` 并保持恒定。
- 点击图标展示详细状态，点击弹窗外区域自动关闭。
- 弹窗内显示 CPU、内存、本 App CPU/内存占用、电池电量、充电状态、电源模式、采样模式、热状态、平均温度、最高温度、最低温度和温度来源。
- 弹窗内有退出按钮。
- 点击退出后 App 进程结束。
- 无电池或温度读取失败时 App 不崩溃。
- 实时温度读取成功时显示平均、最高、最低摄氏温度。
- 实时温度读取失败时明确提示已降级。
- `powermetrics` 兜底不常驻，不导致长期内存升高。
- 系统低电量模式开启时，App 内电池状态与系统状态一致。

性能：

- 弹窗关闭时 CPU 接近 0。
- 弹窗打开时 CPU 不长期超过 2%。
- 常驻内存尽量低于 50 MB。
- 弹窗内“本 App 占用”应能帮助核对轻量目标。
- 长时间运行无明显内存增长。

体验：

- 弹窗打开速度快。
- 数据刷新平稳。
- UI 不跳动、不遮挡、不拥挤。
- 深色/浅色模式可读。

安全：

- 不请求不必要权限。
- 不上传数据。
- 不读取用户文件。
- 不采集进程列表。

## 13. 开发完成后的审查方式

开发完成后，把项目交给我审查时，重点提供：

- 完整源码
- 运行方式
- macOS 版本
- Xcode 版本
- 温度读取是否成功，以及显示的温度来源
- 你本机观察到的 CPU/内存占用

我会重点审查：

- 采样 API 是否使用正确。
- CPU 计算是否有 delta 错误。
- 内存计算是否存在明显误导。
- Timer 是否在弹窗关闭后降频。
- 是否有循环引用。
- 是否有主线程阻塞。
- 温度读取失败是否安全降级。
- 实时温度是否按当前采样频率更新。
- 系统低电量模式和采样模式是否在 UI 中准确展示。
- 点击弹窗外区域是否能稳定关闭弹窗。
- 退出按钮是否能稳定结束进程。
- UI 是否符合轻量菜单栏工具的目标。
