import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for (name, size) in [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),("icon_512x512",512),("icon_512x512@2x",1024)] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let s = CGFloat(size)
    NSColor(red: 0.25, green: 0.36, blue: 0.27, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: s*0.06, y: s*0.06, width: s*0.88, height: s*0.88), xRadius: s*0.21, yRadius: s*0.21).fill()
    NSColor(red: 0.90, green: 0.95, blue: 0.82, alpha: 1).setStroke()
    let ring = NSBezierPath(ovalIn: NSRect(x: s*0.23, y: s*0.23, width: s*0.54, height: s*0.54)); ring.lineWidth = max(1, s*0.018); ring.stroke()
    let needle = NSBezierPath()
    needle.move(to: NSPoint(x: s*0.65, y: s*0.69)); needle.line(to: NSPoint(x: s*0.55, y: s*0.46)); needle.line(to: NSPoint(x: s*0.35, y: s*0.31)); needle.line(to: NSPoint(x: s*0.44, y: s*0.54)); needle.close()
    NSColor(red: 0.82, green: 0.91, blue: 0.66, alpha: 1).setFill(); needle.fill()
    NSColor(red: 0.25, green: 0.36, blue: 0.27, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: s*0.476, y: s*0.476, width: s*0.048, height: s*0.048)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent(name+".png"))
}

// Write the standard PNG-based ICNS container directly. This also works on
// Command Line Tools hosts where iconutil rejects AppKit-generated iconsets.
func uint32(_ value: Int) -> Data {
    var bigEndian = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bigEndian) { Data($0) }
}
let types = [("ic07", "icon_128x128"), ("ic08", "icon_256x256"), ("ic09", "icon_512x512"), ("ic10", "icon_512x512@2x"), ("ic11", "icon_16x16@2x"), ("ic12", "icon_32x32@2x"), ("ic13", "icon_128x128@2x"), ("ic14", "icon_256x256@2x")]
var table = Data(), chunks = Data()
for (type, name) in types {
    let png = try Data(contentsOf: directory.appendingPathComponent(name + ".png"))
    let header = Data(type.utf8) + uint32(png.count + 8)
    table += header; chunks += header + png
}
let body = Data("TOC ".utf8) + uint32(table.count + 8) + table + chunks
try (Data("icns".utf8) + uint32(body.count + 8) + body).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
