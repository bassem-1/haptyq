import CoreGraphics
import Foundation
import HapticCore

// Pure functions: feel semantics (spec 4.3), distance math and target selection. No AX, no hardware.

private func clamped(_ ladder: [Int32], _ i: Int) -> Int32? {
    ladder.isEmpty ? nil : ladder[min(max(i, 0), ladder.count - 1)]
}

/// Index of the strongest ladder rung a setting may use (strength 1...4 -> 0...3, clamped to the ladder).
private func topIndex(_ setting: ZoneSetting, _ ladder: [Int32]) -> Int {
    min(max(setting.strength - 1, 0), max(ladder.count - 1, 0))
}

/// Ramping config for a proximity zone. nil for `.off` and for `.tick` (a tick is a single tap, see `tickTapID`).
public func proximityConfig(for setting: ZoneSetting, ladder: [Int32]) -> ProximityConfig? {
    guard !ladder.isEmpty else { return nil }
    let hi = topIndex(setting, ladder)
    var c = ProximityConfig()
    c.radius = setting.radius
    c.idleMs = 250
    c.hoverTick = false
    switch setting.feel {
    case .off, .tick:
        return nil
    case .calm:
        c.slowestMs = 260; c.fastestMs = 110; c.curve = 2.2
        c.ids = Array(ladder[max(0, hi - 1)...hi])
    case .ramp:
        c.slowestMs = 200; c.fastestMs = 45; c.curve = 1.8
        c.ids = Array(ladder[0...hi])
    case .frenzy:
        c.slowestMs = 120; c.fastestMs = 16; c.curve = 1.1
        c.ids = Array(ladder[max(0, hi - 1)...hi])
    }
    return c
}

/// Id of the single tap played when the cursor enters a button (tick feel, or any button tap). nil when off.
public func tickTapID(setting: ZoneSetting, ladder: [Int32]) -> Int32? {
    guard setting.feel != .off else { return nil }
    return clamped(ladder, setting.strength - 1)
}

/// Id of the tap played when entering a generic button.
public func buttonTapID(setting: ZoneSetting, ladder: [Int32]) -> Int32? {
    tickTapID(setting: setting, ladder: ladder)
}

/// Resize ratchet: one pulse of `id` per `step` points dragged.
public func edgeRatchet(setting: ZoneSetting, ladder: [Int32]) -> (step: Double, id: Int32)? {
    guard let id = tickTapID(setting: setting, ladder: ladder) else { return nil }
    switch setting.feel {
    case .off: return nil
    case .tick, .calm: return (40, id)
    case .ramp: return (25, id)
    case .frenzy: return (14, id)
    }
}

/// Re-arming trigger for hover previews of tap-style zones: fires once when the distance reaches 0,
/// and again only after it has gone back above 0 (or to nil).
public struct HoverTrigger: Equatable {
    private var armed = true
    public init() {}

    /// Returns true when a tap should fire for this distance sample.
    public mutating func update(distance: Double?) -> Bool {
        guard let d = distance, d <= 0 else { armed = true; return false }
        guard armed else { return false }
        armed = false
        return true
    }
}

/// Number of whole steps in an accumulated drag length.
public func ratchetSteps(accumulated: Double, step: Double) -> Int {
    guard step > 0, accumulated > 0 else { return 0 }
    return Int(accumulated / step)
}

/// Distance from the cursor to the edge of a round-ish button (0 when on it). Global top-left coordinates.
public func distanceToButton(cursor: CGPoint, frame: CGRect) -> Double {
    let d = hypot(Double(cursor.x - frame.midX), Double(cursor.y - frame.midY))
    return max(0, d - Double(min(frame.width, frame.height)) / 2)
}

/// True when `point` lies within `tolerance` of the frame's border, inside or out.
public func isNearEdge(_ point: CGPoint, frame: CGRect, tolerance: Double = 6) -> Bool {
    frame.insetBy(dx: -tolerance, dy: -tolerance).contains(point)
        && !frame.insetBy(dx: tolerance, dy: tolerance).contains(point)
}

public struct TargetCandidate: Equatable {
    public var zone: Zone
    public var feel: Feel
    public var distance: Double
    public init(zone: Zone, feel: Feel, distance: Double) {
        self.zone = zone; self.feel = feel; self.distance = distance
    }
}

/// Nearest wins; ties go to the higher feel, then to zone order so the result is stable.
public func nearestTarget(_ candidates: [TargetCandidate]) -> TargetCandidate? {
    let order = Zone.allCases
    return candidates.min { a, b in
        if a.distance != b.distance { return a.distance < b.distance }
        if a.feel != b.feel { return a.feel > b.feel }
        return order.firstIndex(of: a.zone)! < order.firstIndex(of: b.zone)!
    }
}

/// Pattern played after a click on a traffic-light button (nil when the zone has none).
public func confirmPatternName(zone: Zone, documentModified: Bool) -> String? {
    switch zone {
    case .close: documentModified ? "heartbeat" : "latch"
    case .minimize: "sink"
    case .zoom: "inhale"
    default: nil
    }
}
