import Cocoa

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

let iconset = "AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true, attributes: nil)

let symbolName = "battery.100"
guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
    print("Failed to load SF Symbol: \(symbolName)")
    exit(1)
}

for entry in sizes {
    let size = NSSize(width: entry.px, height: entry.px)
    let image = NSImage(size: size)

    image.lockFocus()

    // Background rounded rect
    let bgRect = NSRect(origin: .zero, size: size)
    let path = NSBezierPath(roundedRect: bgRect, xRadius: size.width * 0.22, yRadius: size.height * 0.22)
    NSColor.systemGreen.setFill()
    path.fill()

    // Draw symbol centered
    let symbolSize = NSSize(width: size.width * 0.6, height: size.height * 0.6)
    let symbolRect = NSRect(
        x: (size.width - symbolSize.width) / 2,
        y: (size.height - symbolSize.height) / 2,
        width: symbolSize.width,
        height: symbolSize.height
    )

    symbol.size = symbolSize
    symbol.isTemplate = false
    symbol.draw(in: symbolRect, from: NSRect(origin: .zero, size: symbol.size), operation: .sourceOver, fraction: 1.0)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG for \(entry.name)")
        exit(1)
    }

    let url = URL(fileURLWithPath: "\(iconset)/\(entry.name).png")
    try png.write(to: url)
    print("Generated \(url.path)")
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconset]
task.launch()
task.waitUntilExit()

if task.terminationStatus == 0 {
    print("Generated AppIcon.icns")
    try? FileManager.default.removeItem(atPath: iconset)
} else {
    print("iconutil failed")
    exit(1)
}
