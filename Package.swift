// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MonitorTool",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MonitorTool",
            path: "Sources/MonitorTool",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
