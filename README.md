# MonitorTool

一个面向 Apple Silicon Mac 的超轻量菜单栏系统监控工具。

## 功能

- 菜单栏常驻图标（无 Dock 图标），使用 `waveform.path.ecg`。
- 点击图标展示系统状态弹窗，点击弹窗外区域自动关闭弹窗。
- CPU 使用率与最近 60 秒趋势。
- 内存已用 / 总量 / 可用 / 压力状态。
- 本 App 当前 CPU 使用率与内存占用。
- 电池电量、充电状态、剩余时间、系统低电量模式。
- 系统热状态与实时温度，优先读取 Apple Silicon HID 传感器。
- HID 不可用时低频短采样尝试 `sudo -n powermetrics`，失败则降级为热状态。
- 可切换刷新频率（省电 / 标准 / 实时），修改后立即生效。
- 弹窗底部一键退出。

## 技术栈

- 语言：Swift 6.3
- UI：SwiftUI + AppKit `NSStatusItem` / `NSPopover`
- 系统数据：Mach API、IOKit、`ProcessInfo`
- 构建：Swift Package Manager
- 最低系统：macOS 13

## 构建与运行

当前环境没有 `xcodebuild`，因此使用 Swift Package Manager 构建，并手动打包为标准 `.app` Bundle。

```bash
# 一键发布构建并打包成 .app（包含 AppIcon.icns）
./build.sh

# 运行 App（推荐，无 Dock 图标）
open build/MonitorTool.app
```

> 注意：直接运行 `.build/debug/MonitorTool` 或 `.build/release/MonitorTool` 原始可执行文件会出现 Dock 图标，因为 `LSUIElement` 与 `CFBundleIconFile` 仅包含在 `MonitorTool.app/Contents/Info.plist` 中。App 图标为监控样式（`waveform.path.ecg`），打包时通过 `generate-icon.swift` 生成 `AppIcon.icns`。

## 项目结构

```
Sources/MonitorTool/
├── App/
│   ├── MonitorApp.swift
│   └── AppDelegate.swift
├── StatusBar/
│   └── StatusBarController.swift
├── Metrics/
│   ├── MetricsSampler.swift
│   ├── AppResourceMonitor.swift
│   ├── CPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── BatteryMonitor.swift
│   ├── ThermalMonitor.swift
│   ├── HIDTemperatureMonitor.swift
│   ├── PowermetricsTemperatureMonitor.swift
│   └── SystemSnapshot.swift
├── Settings/
│   └── SettingsStore.swift
└── UI/
    ├── PopoverRootView.swift
    ├── DashboardView.swift
    ├── MetricSectionView.swift
    ├── TrendLineView.swift
    └── SettingsView.swift

Other files:
├── Package.swift
├── Info.plist
├── build.sh
├── generate-icon.swift
├── AppIcon.icns
└── README.md
```

## 开发环境

- macOS 版本：26.4 (25E246)
- Swift 版本：Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
- 架构：arm64-apple-macosx26.0
- 构建工具：Swift Package Manager（无 Xcode/xcodebuild）

## 菜单栏图标

- 使用 `NSStatusItem.squareLength`，只显示图标，不显示文字。
- 图标为 `waveform.path.ecg`，保持恒定，不随系统状态变化。
- 图标使用系统模板色，自动适配深色/浅色菜单栏。

## 弹窗交互

- 点击菜单栏图标：打开或关闭弹窗。
- 点击弹窗外区域：自动关闭弹窗（通过 `NSPopover` `.transient` 行为 + 全局鼠标事件监听双重保证）。
- 弹窗打开时采样频率提高，关闭时降低。

## 实时温度

App 默认会随每次采样尝试读取 Apple Silicon HID 温度传感器，不需要管理员权限。弹窗打开时按当前刷新频率实时更新温度，关闭后随采样降频。

如果 HID 温度不可用，App 会低频尝试一次短生命周期的 `sudo -n /usr/bin/powermetrics --samplers thermal -n 1 -i 1000` 作为兜底。这个进程不会常驻：最多 60 秒尝试一次，每次采样完成或超时后退出。若系统未给免密 sudo 或 `powermetrics` 输出里没有摄氏温度，温度显示为 `--°C`，并提示“需要权限或不可用，已降级”。

读取成功时，弹窗显示平均温度、最高温度、最低温度、来源和传感器数量。macOS 官方 `ProcessInfo.processInfo.thermalState` 仍会始终展示，因为它是系统公开的热状态信号。

温度更新频率：

- HID 温度随主采样刷新：弹窗打开时按当前刷新频率更新，关闭后降频。
- 自动 `powermetrics` 兜底最多 60 秒尝试一次，避免频繁启动 root 工具。
- 热状态行右侧的“授权刷新”按钮会手动触发一次系统管理员授权弹窗，通过 `osascript ... with administrator privileges` 短时运行 `powermetrics`。App 不保存密码，采样结束后进程退出。

## 电源与采样模式

电池区域会展示电量、充电状态、系统电源模式和 App 采样模式：

- 充电状态会显示为“充电中”“已连接电源”或“使用电池”。
- 系统低电量模式开启时，电池图标和“电源模式”显示为黄色。
- 采样模式显示当前刷新频率：省电、标准或实时。
- 切换刷新频率后，当前采样 Timer 会立即重建并生效。

## 本 App 占用

弹窗中会显示 MonitorTool 自身的 CPU 使用率和内存占用：

- CPU 使用率通过当前进程 user/system CPU time 的采样差值计算。
- 内存使用 Mach `task_vm_info.phys_footprint`，更接近当前进程实际内存足迹。
- 该采样在进程内完成，不额外启动命令行工具。

## 隐私

- 不上传、不记录、不分析用户数据
- 不请求辅助功能、全磁盘访问、网络、定位等权限
- 可选使用 `powermetrics` 需要系统授予 root 执行权限；App 不保存密码，不保留 root 后台进程
- 不采集进程列表或读取用户文件

## 退出方式

弹窗底部点击“退出”会调用 `NSApp.terminate(nil)`，正常结束 AppKit 事件循环并释放资源。
