#!/bin/bash
set -e

swift build -c release

rm -rf build/MonitorTool.app
mkdir -p build/MonitorTool.app/Contents/MacOS
cp .build/release/MonitorTool build/MonitorTool.app/Contents/MacOS/
cp Info.plist build/MonitorTool.app/Contents/Info.plist

echo "Built build/MonitorTool.app"
