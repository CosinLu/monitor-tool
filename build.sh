#!/bin/bash
set -e

swift build -c release

rm -rf build/MonitorTool.app
mkdir -p build/MonitorTool.app/Contents/MacOS
mkdir -p build/MonitorTool.app/Contents/Resources
cp .build/release/MonitorTool build/MonitorTool.app/Contents/MacOS/
cp Info.plist build/MonitorTool.app/Contents/Info.plist
cp AppIcon.icns build/MonitorTool.app/Contents/Resources/

echo "Built build/MonitorTool.app"
