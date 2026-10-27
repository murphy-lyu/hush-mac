import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let assets = root.appendingPathComponent("Hush/Assets.xcassets")
let icons = assets.appendingPathComponent("AppIcon.appiconset")
try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
try Data("{\"info\":{\"author\":\"xcode\",\"version\":1}}".utf8).write(to: assets.appendingPathComponent("Contents.json"))
var entries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: 1024, height: 1024)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let background = NSBezierPath(roundedRect: NSRect(x: 76, y: 76, width: 872, height: 872), xRadius: 200, yRadius: 200)
        NSGradient(starting: NSColor(srgbRed: 0.47, green: 0.44, blue: 0.74, alpha: 1),
                   ending: NSColor(srgbRed: 0.25, green: 0.23, blue: 0.46, alpha: 1))!.draw(in: background, angle: -60)
        // A quiet crescent, built as one path so the gradient stays intact.
        let moon = NSBezierPath()
        moon.move(to: NSPoint(x: 565, y: 760))
        moon.curve(to: NSPoint(x: 730, y: 335), controlPoint1: NSPoint(x: 302, y: 770), controlPoint2: NSPoint(x: 270, y: 312))
        moon.curve(to: NSPoint(x: 565, y: 760), controlPoint1: NSPoint(x: 475, y: 276), controlPoint2: NSPoint(x: 421, y: 610))
        moon.close()
        NSColor(srgbRed: 0.97, green: 0.95, blue: 0.90, alpha: 1).setFill()
        moon.fill()
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 666, y: 657)); line.line(to: NSPoint(x: 748, y: 657))
        line.move(to: NSPoint(x: 694, y: 604)); line.line(to: NSPoint(x: 776, y: 604))
        line.lineWidth = 23; line.lineCapStyle = .round
        NSColor(srgbRed: 0.86, green: 0.83, blue: 0.98, alpha: 1).setStroke(); line.stroke()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)@\(scale)x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: icons.appendingPathComponent(filename))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
let json: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: icons.appendingPathComponent("Contents.json"))
