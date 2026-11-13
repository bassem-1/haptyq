import CoreGraphics
import Foundation
import HapticCore

// Pure functions: feel semantics (spec 4.3), distance math and target selection. No AX, no hardware.

private func clamped(_ ladder: [Int32], _ i: Int) -> Int32? {
    ladder.isEmpty ? nil : ladder[min(max(i, 0), ladder.count - 1)]
}

/// Ramping config for a proximity zone. nil for `.off` and for `.tick` (a tick is a single tap, see `proximityTapID`).
public func proximityConfig(for setting: ZoneSetting, ladder: [Int32]) -> ProximityConfig? {
    guard !ladder.isEmpty else { return nil }
    var c = ProximityConfig()
    c.radius = setting.reach.points
    c.idleMs = 250
    c.hoverTick = false
    switch setting.feel {
    case .off, .tick:
        return nil
    case .calm:
        c.slowestMs = 260; c.fastestMs = 110; c.curve = 2.2
        c.ids = Array(ladder[0...min(1, ladder.count - 1)])
    case .ramp:
        c.slowestMs = 200; c.fastestMs = 45; c.curve = 1.8
        c.ids = ladder
    case .frenzy:
        c.slowestMs = 120; c.fastestMs = 16; c.curve = 1.1
        c.ids = Array(ladder[(ladder.count / 2)...])
    }
    return c
}

/// Id of the single tap played when the cursor enters a tick-feel traffic-light button.
public func proximityTapID(ladder: [Int32]) -> Int32? { clamped(ladder, 1) }

/// Id of the tap played when entering a generic button.
public func buttonTapID(feel: Feel, ladder: [Int32]) -> Int32? {
    switch feel {
    case .off: nil
    case .tick: clamped(ladder, 0)
    case .calm: clamped(ladder, 1)
    case .ramp: clamped(ladder, 2)
    case .frenzy: ladder.last
    }
}

/// Resize ratchet: one pulse of `id` per `step` points dragged.
public func edgeRatchet(feel: Feel, ladder: [Int32]) -> (step: Double, id: Int32)? {
    guard let id = buttonTapID(feel: feel, ladder: ladder) else { return nil }
    switch feel {
    case .off: return nil
    case .tick, .calm: return (40, id)
    case .ramp: return (25, id)
    case .frenzy: return (14, id)
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
