# MonitorTool

一个面向 Apple Silicon Mac 的超轻量菜单栏系统监控工具，按照 `mac-system-monitor-development-spec.md` 开发。

## 功能

- 菜单栏常驻图标（无 Dock 图标）
- 点击图标展示系统状态弹窗
- CPU 使用率与最近 60 秒趋势
- 内存已用 / 总量 / 可用 / 压力状态
- 电池电量、充电状态、剩余时间、系统低电量模式
- 系统热状态与传感器温度（可选高级 SMC 温度读取）
- 高级温度读取结果提示（未开启 / 读取成功 / 读取失败并降级）
- 可切换刷新频率（省电 / 标准 / 实时），修改后立即生效
- 弹窗底部一键退出

## 技术栈

- 语言：Swift 6.3
- UI：SwiftUI + AppKit `NSStatusItem` / `NSPopover`
- 系统数据：Mach API、IOKit、`ProcessInfo`
- 构建：Swift Package Manager
- 最低系统：macOS 13

## 构建与运行

当前环境没有 `xcodebuild`，因此使用 Swift Package Manager 构建，并手动打包为标准 `.app` Bundle。

```bash
# 一键发布构建并打包成 .app
./build.sh

# 运行 App（推荐，无 Dock 图标）
open build/MonitorTool.app
```

> 注意：直接运行 `.build/debug/MonitorTool` 或 `.build/release/MonitorTool` 原始可执行文件会出现 Dock 图标，因为 `LSUIElement` 仅包含在 `MonitorTool.app/Contents/Info.plist` 中。

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
│   ├── CPUMonitor.swift
│   ├── MemoryMonitor.swift
│   ├── BatteryMonitor.swift
│   ├── ThermalMonitor.swift
│   ├── SMCMonitor.swift
│   └── SystemSnapshot.swift
├── Settings/
│   ├── SettingsStore.swift
│   └── LaunchAtLoginManager.swift  # 预留，第一版 UI 未启用
└── UI/
    ├── PopoverRootView.swift
    ├── DashboardView.swift
    ├── MetricSectionView.swift
    ├── TrendLineView.swift
    └── SettingsView.swift
```

## 开发环境

- macOS 版本：26.4 (25E246)
- Swift 版本：Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
- 架构：arm64-apple-macosx26.0
- 构建工具：Swift Package Manager（无 Xcode/xcodebuild）

## 高级温度模式

已实现但默认关闭。开启后 `SMCMonitor` 会尝试从 IOKit Registry 读取温度传感器；读取成功时弹窗显示传感器温度和来源，读取失败时显示“读取失败，已降级”，并继续展示系统热状态，不会请求管理员权限或崩溃。

macOS 官方 `ProcessInfo.processInfo.thermalState` 只提供热状态，不提供摄氏温度。因此具体温度仅在高级温度读取成功时显示；读取不可用时温度显示为 `--°C`。

## 电源与采样模式

电池区域会展示电量、充电状态、系统电源模式和 App 采样模式：

- 充电状态会显示为“充电中”“已连接电源”或“使用电池”。
- 系统低电量模式开启时，电池图标和“电源模式”显示为黄色。
- 采样模式显示当前刷新频率：省电、标准或实时。
- 切换刷新频率后，当前采样 Timer 会立即重建并生效。

## 隐私

- 不上传、不记录、不分析用户数据
- 不请求辅助功能、全磁盘访问、网络、定位等权限
- 不采集进程列表或读取用户文件

## 退出方式

弹窗底部点击“退出”会调用 `NSApp.terminate(nil)`，正常结束 AppKit 事件循环并释放资源。
