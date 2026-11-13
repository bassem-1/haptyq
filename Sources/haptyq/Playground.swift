import SwiftUI
import HapticCore
import HaptyqKit

/// A mock window you can sweep the cursor over to feel the current settings. Distances are 1:1 points.
struct Playground: View {
    @ObservedObject var model: AppModel
    @State private var cursor: CGPoint?
    @State private var target: Target?

    struct Target: Equatable {
        var zone: Zone
        var distance: Double
    }

    // geometry in the playground's own 300x300 space
    private static let canvas: CGFloat = 300
    private static let window = CGRect(x: 24, y: 24, width: 252, height: 252)
    private static let titleBar: CGFloat = 28
    private static let buttonRadius: CGFloat = 6
    private static let centers: [Zone: CGPoint] = [
        .close: CGPoint(x: 42, y: 38), .minimize: CGPoint(x: 66, y: 38), .zoom: CGPoint(x: 90, y: 38),
    ]
    private static let capsule = CGRect(x: 110, y: 150, width: 80, height: 26)
    private static let strip = CGRect(x: window.maxX - 6, y: window.minY + titleBar,
                                      width: 6, height: window.height - titleBar)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                mockWindow
                rings
                mockButtons
            }
            .frame(width: Self.canvas, height: Self.canvas, alignment: .topLeading)
            .clipped()
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): moved(to: p)
                case .ended: left()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("playground")

            Text(readout)
                .font(Theme.font(11))
                .foregroundColor(target == nil ? Theme.fg2 : Theme.fg)
                .lineLimit(1)
                .frame(width: Self.canvas, height: 16, alignment: .leading)
                .accessibilityLabel("readout")
        }
        .onDisappear { left() }
    }

    // MARK: drawing

    private var mockWindow: some View {
        let w = Self.window
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.bg)
            RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.line, lineWidth: 1)
            Rectangle().fill(Theme.line).frame(height: 1).offset(y: Self.titleBar)
            // grab strip on the right edge
            Rectangle().fill(edgeHairline).frame(width: 1, height: Self.strip.height)
                .offset(x: Self.strip.midX - w.minX, y: Self.strip.minY - w.minY)
            capsuleView
        }
        .frame(width: w.width, height: w.height, alignment: .topLeading)
        .offset(x: w.minX, y: w.minY)
        .overlay(alignment: .topLeading) {
            Color.clear
                .frame(width: Self.strip.width + 8, height: Self.strip.height)
                .contentShape(Rectangle())
                .onTapGesture { model.selected = .edges }
                .offset(x: Self.strip.minX - 4, y: Self.strip.minY)
                .accessibilityLabel("select window edges")
                .accessibilityAddTraits(.isButton)
        }
    }

    private var edgeHairline: Color {
        if cursor.map({ Self.strip.insetBy(dx: -4, dy: 0).contains($0) }) == true { return Theme.fg }
        return model.selected == .edges ? Theme.fg2 : .clear
    }

    private var capsuleView: some View {
        let c = Self.capsule
        let sel = model.selected == .buttons
        let on = model.settings[.buttons].feel != .off
        return Text("button")
            .font(Theme.font(11))
            .foregroundColor(on ? Theme.fg : Theme.fg2)
            .frame(width: c.width, height: c.height)
            .overlay(Capsule().strokeBorder(sel ? Theme.fg : Theme.line, lineWidth: 1))
            .contentShape(Capsule())
            .onTapGesture { model.selected = .buttons }
            .offset(x: c.minX - Self.window.minX, y: c.minY - Self.window.minY)
            .accessibilityLabel("select other buttons")
            .accessibilityAddTraits(.isButton)
    }

    private var rings: some View {
        ZStack(alignment: .topLeading) {
            ForEach([Zone.close, .minimize, .zoom]) { z in
                let s = model.settings[z]
                if s.feel != .off, let c = Self.centers[z] {
                    let d = (s.radius + Self.buttonRadius) * 2
                    let chosen = model.selected == z
                    Circle()
                        .strokeBorder(chosen ? Theme.fg : Theme.line,
                                      style: StrokeStyle(lineWidth: 1, dash: chosen ? [] : [3, 3]))
                        .frame(width: d, height: d)
                        .offset(x: c.x - d / 2, y: c.y - d / 2)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var mockButtons: some View {
        ZStack(alignment: .topLeading) {
            ForEach([Zone.close, .minimize, .zoom]) { z in
                if let c = Self.centers[z] {
                    let hot = cursor.map { distance($0, c) == 0 } ?? false
                    ZStack {
                        Circle().fill(Theme.fg.opacity(opacity(z)))
                        if hot { Text(glyph(z)).font(Theme.font(9, .medium)).foregroundColor(Theme.bg) }
                    }
                    .frame(width: 12, height: 12)
                    .frame(width: 20, height: 20)
                    .contentShape(Circle())
                    .onTapGesture { model.selected = z }
                    .offset(x: c.x - 10, y: c.y - 10)
                    .accessibilityLabel("select \(z.title)")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func opacity(_ z: Zone) -> Double { z == .close ? 1 : z == .minimize ? 0.55 : 0.32 }
    private func glyph(_ z: Zone) -> String { z == .close ? "×" : z == .minimize ? "–" : "+" }

    // MARK: hover

    private func distance(_ p: CGPoint, _ c: CGPoint) -> Double {
        max(0, hypot(p.x - c.x, p.y - c.y) - Self.buttonRadius)
    }

    private func nearest(to p: CGPoint) -> Target? {
        var found: [TargetCandidate] = []
        for z in [Zone.close, .minimize, .zoom] {
            let s = model.settings[z]
            guard s.feel != .off, let c = Self.centers[z] else { continue }
            let d = distance(p, c)
            if d < s.radius { found.append(TargetCandidate(zone: z, feel: s.feel, distance: d)) }
        }
        let b = model.settings[.buttons]
        if b.feel != .off, Self.capsule.contains(p) {
            found.append(TargetCandidate(zone: .buttons, feel: b.feel, distance: 0))
        }
        return nearestTarget(found).map { Target(zone: $0.zone, distance: $0.distance) }
    }

    private func moved(to p: CGPoint) {
        // no throttle: pointer events already arrive at display rate, hover() only enqueues, and dropping
        // samples would leave a stale distance behind when the cursor stops
        cursor = p
        let next = nearest(to: p)
        let was = target
        if next != was { target = next }
        if let next {
            model.engine.hover(next.zone, distance: next.distance)
        } else if was != nil {
            model.engine.hover(nil, distance: nil) // only on the way out of range
        }
    }

    private func left() {
        cursor = nil
        target = nil
        model.engine.hover(nil, distance: nil)
    }

    // MARK: readout

    private var readout: String {
        if let t = target {
            let s = model.settings[t.zone]
            let d = Int(t.distance.rounded())
            if t.zone == .buttons { return "\(t.zone.title) · 1 tap" }
            if let cfg = proximityConfig(for: s, ladder: model.settings.ladder),
               let out = ProximityEngine.output(cfg, distance: t.distance), out.intervalMs > 0 {
                return "\(t.zone.title) · \(d) pt · \(Int((1000 / out.intervalMs).rounded())) taps/s"
            }
            return "\(t.zone.title) · \(d) pt · \(d == 0 ? "1 tap" : "tap on arrival")"
        }
        if let c = cursor, Self.strip.insetBy(dx: -4, dy: 0).contains(c) {
            return "window edges · use feel it"
        }
        return "move toward a button"
    }
}
