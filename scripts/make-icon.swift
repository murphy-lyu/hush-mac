import AppKit

// Export the selected image with a full-bleed, opaque background. macOS applies
// the outer icon mask; preserving the preview inset would create a second tile.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let source = root.appendingPathComponent("Hush/IconSources/AppIcon.png")
guard let image = NSImage(contentsOf: source) else { fatalError("Missing icon source: \(source.path)") }
let icons = root.appendingPathComponent("Hush/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: icons, withIntermediateDirectories: true)
var entries: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                  colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: pixels, height: pixels)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        NSColor.white.setFill()
        canvas.fill()
        // The selected preview's tile starts 5.5% inside its source canvas.
        // Crop only that outer margin, then flatten transparent corners to white.
        let crop = NSRect(x: image.size.width * 0.055, y: image.size.height * 0.055,
                          width: image.size.width * 0.89, height: image.size.height * 0.89)
        image.draw(in: canvas, from: crop, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        let name = "icon_\(size)@\(scale)x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: icons.appendingPathComponent(name))
        entries.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": entries, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: icons.appendingPathComponent("Contents.json"))
