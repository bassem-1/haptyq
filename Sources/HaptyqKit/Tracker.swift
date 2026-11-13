import ApplicationServices
import CoreGraphics
import Foundation
import HapticCore

enum PointerEvent { case move, down, up, drag }

/// Everything that touches accessibility. All mutable state is confined to `queue`.
final class Tracker {
    private struct Target { var zone: Zone; var frame: CGRect }

    private let queue = DispatchQueue(label: "haptyq.tracker", qos: .userInteractive)
    private let proximity: ProximityEngine?
    private let player: PatternPlayer?
    private let actuator: Actuator?
    private let system = AXUIElementCreateSystemWide()
    private let patterns = Library.builtIn

    // queue-confined
    private var settings = Settings.defaults
    private var active = false
    private var targets: [Target] = []
    private var windowFrames: [CGRect] = []
    private var cursor: CGPoint = .zero
    private var lastLookup: UInt64 = 0
    private var refreshPending = false
    private var mouseDown = false
    private var insideTick = Set<Zone>()
    private var lastButton: AXUIElement?
    private var downButton: (zone: Zone, element: AXUIElement, window: AXUIElement?)?
    private var resizing = false
    private var lastDrag: CGPoint = .zero
    private var accumulated = 0.0
    private var firedSteps = 0

    init(actuator: Actuator?, proximity: ProximityEngine?, player: PatternPlayer?) {
        self.actuator = actuator; self.proximity = proximity; self.player = player
        AXUIElementSetMessagingTimeout(system, 0.05)
    }

    // MARK: entry points (any thread)

    func configure(_ s: Settings) { queue.async { self.settings = s } }

    func start() { queue.async { self.active = true } }

    /// Silences and forgets everything; events queued before this are processed first.
    func stop() {
        queue.async {
            self.active = false
            self.mouseDown = false
            self.resizing = false
            self.targets = []; self.windowFrames = []
            self.insideTick = []; self.lastButton = nil; self.downButton = nil
            self.proximity?.update(distance: nil, config: nil)
        }
    }

    /// Called from the event tap callback: copy and hand off, nothing else.
    func post(_ kind: PointerEvent, _ p: CGPoint) {
        queue.async { self.handle(kind, p) }
    }

    // MARK: events (queue)

    private func handle(_ kind: PointerEvent, _ p: CGPoint) {
        guard active, settings.enabled else { return }
        switch kind {
        case .move: move(p)
        case .drag: drag(p)
        case .down: down(p)
        case .up: up(p)
        }
    }

    private func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

    private func move(_ p: CGPoint) {
        cursor = p
        guard !mouseDown else { return }
        let elapsed = Double(now() &- lastLookup) / 1e6
        if elapsed >= 50 {
            _ = lookup(p)
        } else if !refreshPending {
            refreshPending = true
            queue.asyncAfter(deadline: .now() + .milliseconds(Int(50 - elapsed) + 1)) { [self] in
                refreshPending = false
                guard active, !mouseDown else { return }
                _ = lookup(cursor)
                evaluate(cursor)
            }
        }
        evaluate(p)
    }

    private func down(_ p: CGPoint) {
        mouseDown = true
        cursor = p
        proximity?.update(distance: nil, config: nil)
        let hit = lookup(p)
        downButton = nil
        if let el = hit.element, let zone = hit.trafficZone {
            downButton = (zone, el, hit.window)
        }
        resizing = false
        if downButton == nil, settings[.edges].feel != .off,
           windowFrames.contains(where: { isNearEdge(p, frame: $0) }) {
            resizing = true
            lastDrag = p; accumulated = 0; firedSteps = 0
        }
    }

    private func drag(_ p: CGPoint) {
        cursor = p
        guard resizing, let r = edgeRatchet(feel: settings[.edges].feel, ladder: settings.ladder) else { return }
        accumulated += hypot(Double(p.x - lastDrag.x), Double(p.y - lastDrag.y))
        lastDrag = p
        let steps = ratchetSteps(accumulated: accumulated, step: r.step)
        if steps > firedSteps {
            firedSteps = steps
            actuator?.fire(id: r.id)
        }
    }

    private func up(_ p: CGPoint) {
        mouseDown = false
        resizing = false
        cursor = p
        defer { downButton = nil }
        guard let d = downButton else { return }
        let s = settings[d.zone]
        guard s.confirmClick, s.feel != .off else { return }
        let hit = lookup(p)
        guard let el = hit.element, CFEqual(el, d.element) else { return }
        var modified = false
        if d.zone == .close, let w = d.window,
           let v = attribute(w, "AXModified"), CFGetTypeID(v) == CFBooleanGetTypeID() {
            modified = CFBooleanGetValue(unsafeBitCast(v, to: CFBoolean.self))
        }
        if let name = confirmPatternName(zone: d.zone, documentModified: modified), let pat = patterns[name] {
            player?.play(pat, afterMs: 60)
        }
    }

    // MARK: proximity

    private func evaluate(_ p: CGPoint) {
        var candidates: [TargetCandidate] = []
        var configs: [Zone: ProximityConfig] = [:]
        var nowInside = Set<Zone>()
        for t in targets {
            let setting = settings[t.zone]
            guard setting.feel != .off else { continue }
            let d = distanceToButton(cursor: p, frame: t.frame)
            if setting.feel == .tick {
                if d <= 0 { nowInside.insert(t.zone) }
            } else if let cfg = proximityConfig(for: setting, ladder: settings.ladder), d < cfg.radius {
                candidates.append(TargetCandidate(zone: t.zone, feel: setting.feel, distance: d))
                configs[t.zone] = cfg
            }
        }
        for z in nowInside.subtracting(insideTick) {
            if let id = proximityTapID(ladder: settings.ladder) { actuator?.fire(id: id) }
            _ = z
        }
        insideTick = nowInside
        if let n = nearestTarget(candidates) {
            proximity?.update(distance: n.distance, config: configs[n.zone])
        } else {
            proximity?.update(distance: nil, config: nil)
        }
    }

    // MARK: accessibility

    private struct Hit {
        var element: AXUIElement?
        var window: AXUIElement?
        var trafficZone: Zone?
    }

    private func attribute(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
    }

    private func element(_ el: AXUIElement, _ name: String) -> AXUIElement? {
        guard let v = attribute(el, name), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(v, to: AXUIElement.self)
    }

    private func string(_ el: AXUIElement, _ name: String) -> String? { attribute(el, name) as? String }

    private func frame(_ el: AXUIElement) -> CGRect? {
        guard let pv = attribute(el, kAXPositionAttribute), let sv = attribute(el, kAXSizeAttribute),
              CFGetTypeID(pv) == AXValueGetTypeID(), CFGetTypeID(sv) == AXValueGetTypeID() else { return nil }
        var o = CGPoint.zero, s = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(pv, to: AXValue.self), .cgPoint, &o),
              AXValueGetValue(unsafeBitCast(sv, to: AXValue.self), .cgSize, &s) else { return nil }
        return CGRect(origin: o, size: s)
    }

    /// Refreshes cached targets from the window under `p` and the focused window, and fires button taps.
    private func lookup(_ p: CGPoint) -> Hit {
        lastLookup = now()
        var hit = Hit()
        var raw: AXUIElement?
        if AXUIElementCopyElementAtPosition(system, Float(p.x), Float(p.y), &raw) == .success { hit.element = raw }

        var windows: [AXUIElement] = []
        if let el = hit.element {
            let role = string(el, kAXRoleAttribute)
            let w = role == kAXWindowRole ? el : element(el, kAXWindowAttribute)
            hit.window = w
            if let w { windows.append(w) }
            if role == kAXButtonRole {
                switch string(el, kAXSubroleAttribute) {
                case kAXCloseButtonSubrole: hit.trafficZone = .close
                case kAXMinimizeButtonSubrole: hit.trafficZone = .minimize
                case kAXZoomButtonSubrole, kAXFullScreenButtonSubrole: hit.trafficZone = .zoom
                default: break
                }
            }
        }
        if let app = element(system, kAXFocusedApplicationAttribute),
           let fw = element(app, kAXFocusedWindowAttribute),
           !windows.contains(where: { CFEqual($0, fw) }) {
            windows.append(fw)
        }

        var newTargets: [Target] = []
        var frames: [CGRect] = []
        for w in windows {
            if let f = frame(w) { frames.append(f) }
            let list: [(Zone, [String])] = [
                (.close, [kAXCloseButtonAttribute]),
                (.minimize, [kAXMinimizeButtonAttribute]),
                (.zoom, [kAXFullScreenButtonAttribute, kAXZoomButtonAttribute]),
            ]
            for (zone, names) in list {
                for name in names {
                    if let b = element(w, name), let f = frame(b) {
                        if !newTargets.contains(where: { $0.frame == f }) { newTargets.append(Target(zone: zone, frame: f)) }
                        break
                    }
                }
            }
        }
        targets = newTargets
        windowFrames = frames

        // other buttons: once per entered element
        if let el = hit.element, string(el, kAXRoleAttribute) == kAXButtonRole, hit.trafficZone == nil {
            if lastButton == nil || !CFEqual(lastButton!, el) {
                lastButton = el
                if let id = buttonTapID(feel: settings[.buttons].feel, ladder: settings.ladder) { actuator?.fire(id: id) }
            }
        } else {
            lastButton = nil
        }
        return hit
    }
}
