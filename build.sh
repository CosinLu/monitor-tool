#!/bin/bash
set -e

swift build -c release

rm -rf build/MonitorTool.app
mkdir -p build/MonitorTool.app/Contents/MacOS
mkdir -p build/MonitorTool.app/Contents/Resources
cp .build/release/MonitorTool build/MonitorTool.app/Contents/MacOS/
cp Info.plist build/MonitorTool.app/Contents/Info.plist
cp AppIcon.icns build/MonitorTool.app/Contents/Resources/
if [ -d .build/release/MonitorTool_MonitorTool.bundle ]; then
  cp -R .build/release/MonitorTool_MonitorTool.bundle build/MonitorTool.app/Contents/Resources/
fi

echo "Built build/MonitorTool.app"
