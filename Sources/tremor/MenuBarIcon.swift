import AppKit

/// Three vertical rounded bars, drawn as a template image so macOS tints it.
enum MenuBarIcon {
    static func image(enabled: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            let heights: [CGFloat] = [6, 12, 8]
            let w: CGFloat = 2.5, gap: CGFloat = 2.5
            let total = w * 3 + gap * 2
            var x = (rect.width - total) / 2
            NSColor.black.withAlphaComponent(enabled ? 1 : 0.35).setFill()
            for h in heights {
                let r = NSRect(x: x, y: (rect.height - h) / 2, width: w, height: h)
                NSBezierPath(roundedRect: r, xRadius: w / 2, yRadius: w / 2).fill()
                x += w + gap
            }
            return true
        }
        img.isTemplate = true
        return img
    }
}
