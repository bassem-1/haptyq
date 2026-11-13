// usage: swift scripts/make-icon.swift <out.png>
// renders the 1024x1024 app icon: black squircle on the macOS grid (824pt, r185,
// centered, transparent margin) with three neon yellow bars at heights 6:12:8.
import AppKit

let canvas = 1024
let tile = 824.0
let tileOrigin = (Double(canvas) - tile) / 2
let tileRadius = 185.0

let unit = 40.0                       // one height step; 12 units = 480pt tallest bar
let barHeights = [6.0 * unit, 12.0 * unit, 8.0 * unit]
let barWidth = 112.0
let barGap = 80.0
let barCorner = barWidth / 2

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 2 else { fail("usage: swift scripts/make-icon.swift <out.png>") }

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else { fail("could not allocate bitmap") }
rep.size = NSSize(width: canvas, height: canvas)

guard let context = NSGraphicsContext(bitmapImageRep: rep) else { fail("could not create graphics context") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: canvas, height: canvas).fill()

let black = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
let yellow = NSColor(srgbRed: 0xE4 / 255.0, green: 1.0, blue: 0x1A / 255.0, alpha: 1)

black.setFill()
NSBezierPath(
    roundedRect: NSRect(x: tileOrigin, y: tileOrigin, width: tile, height: tile),
    xRadius: tileRadius,
    yRadius: tileRadius
).fill()

let groupWidth = Double(barHeights.count) * barWidth + Double(barHeights.count - 1) * barGap
let groupLeft = (Double(canvas) - groupWidth) / 2
let centerY = Double(canvas) / 2

yellow.setFill()
for (index, height) in barHeights.enumerated() {
    let x = groupLeft + Double(index) * (barWidth + barGap)
    let rect = NSRect(x: x, y: centerY - height / 2, width: barWidth, height: height)
    NSBezierPath(roundedRect: rect, xRadius: barCorner, yRadius: barCorner).fill()
}

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else { fail("could not encode png") }
do {
    try png.write(to: URL(fileURLWithPath: args[1]))
} catch {
    fail("could not write \(args[1]): \(error.localizedDescription)")
}
