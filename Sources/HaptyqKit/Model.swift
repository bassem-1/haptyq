import CoreGraphics
import Foundation

// Shared contract between the engine (HaptyqKit) and the ui (haptyq). Change only with care.

/// A place on screen haptyq reacts to.
public enum Zone: String, Codable, CaseIterable, Identifiable, CodingKeyRepresentable, Sendable {
    case close, minimize, zoom, buttons, edges

    public var id: String { rawValue }

    /// Lowercase ui label.
    public var title: String {
        switch self {
        case .close: "close"
        case .minimize: "minimize"
        case .zoom: "full screen"
        case .buttons: "other buttons"
        case .edges: "window edges"
        }
    }

    /// Lowercase one-line explanation.
    public var detail: String {
        switch self {
        case .close: "the red one. approach with care."
        case .minimize: "the yellow one."
        case .zoom: "the green one."
        case .buttons: "a tap when you land on any button."
        case .edges: "a ratchet while you drag to resize."
        }
    }

    /// Traffic-light zones react to distance; the others react to entering or dragging.
    public var usesProximity: Bool { self == .close || self == .minimize || self == .zoom }

    /// Radius is meaningless for zones without proximity.
    public var allowsRadius: Bool { usesProximity }
}

/// How strongly a zone reacts. Ordered from nothing to everything.
public enum Feel: String, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case off, tick, calm, ramp, frenzy

    public var id: String { rawValue }
    public var title: String { rawValue }

    /// 0...4, used by the signal-bar control.
    public var level: Int { Feel.allCases.firstIndex(of: self)! }

    public init(level: Int) {
        let all = Feel.allCases
        self = all[min(max(level, 0), all.count - 1)]
    }

    public var detail: String {
        switch self {
        case .off: "nothing."
        case .tick: "one tap when you arrive."
        case .calm: "slow pulses that build gently."
        case .ramp: "pulses that speed up as you close in."
        case .frenzy: "like crazy."
        }
    }

    public static func < (a: Feel, b: Feel) -> Bool { a.level < b.level }
}

/// Legacy (v0.1) reach presets. Only used to migrate old saves to `ZoneSetting.radius`.
enum LegacyReach: String, Codable {
    case near, mid, far
    var points: Double {
        switch self {
        case .near: 40
        case .mid: 90
        case .far: 160
        }
    }
}

/// Per-zone tuning. `feel` is the rhythm, `strength` how hard, `radius` how far out it starts.
public struct ZoneSetting: Codable, Equatable, Sendable {
    public static let radiusRange: ClosedRange<Double> = 10...300
    public static let strengthRange: ClosedRange<Int> = 1...4

    public var feel: Feel
    /// Points from the button's edge at which proximity starts (proximity zones only).
    public var radius: Double { didSet { radius = ZoneSetting.clampRadius(radius) } }
    /// 1...4: the strongest rung of the ladder this zone may use.
    public var strength: Int { didSet { strength = ZoneSetting.clampStrength(strength) } }
    /// Play a short confirmation pattern when the button is actually clicked.
    public var confirmClick: Bool

    public init(feel: Feel, radius: Double = 90, strength: Int = 3, confirmClick: Bool = true) {
        self.feel = feel
        self.radius = ZoneSetting.clampRadius(radius)
        self.strength = ZoneSetting.clampStrength(strength)
        self.confirmClick = confirmClick
    }

    static func clampRadius(_ r: Double) -> Double {
        r.isFinite ? min(max(r, radiusRange.lowerBound), radiusRange.upperBound) : 90
    }

    static func clampStrength(_ s: Int) -> Int { min(max(s, strengthRange.lowerBound), strengthRange.upperBound) }

    private enum CodingKeys: String, CodingKey { case feel, radius, strength, confirmClick, reach }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let feel = try c.decode(Feel.self, forKey: .feel)
        let legacy = (try? c.decodeIfPresent(LegacyReach.self, forKey: .reach))?.points
        let radius = (try? c.decodeIfPresent(Double.self, forKey: .radius)) ?? legacy ?? 90
        let strength = (try? c.decodeIfPresent(Int.self, forKey: .strength)) ?? (feel == .frenzy ? 4 : 3)
        let confirm = (try? c.decodeIfPresent(Bool.self, forKey: .confirmClick)) ?? true
        self.init(feel: feel, radius: radius, strength: strength, confirmClick: confirm)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(feel, forKey: .feel)
        try c.encode(radius, forKey: .radius)
        try c.encode(strength, forKey: .strength)
        try c.encode(confirmClick, forKey: .confirmClick)
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var zones: [Zone: ZoneSetting]
    public var showGadget: Bool
    /// Gadget sits on the desktop behind windows (false) or floats above them (true).
    public var gadgetFloats: Bool
    /// Bottom-left origin in screen coordinates; nil = default placement.
    public var gadgetOrigin: CGPoint?
    /// Actuator ids from weakest to strongest. Placeholder until calibrated with haptic-web.
    public var ladder: [Int32]

    public static let defaults = Settings(
        enabled: true,
        zones: [
            .close: ZoneSetting(feel: .frenzy, radius: 90, strength: 4),
            .minimize: ZoneSetting(feel: .calm, radius: 40, strength: 2),
            .zoom: ZoneSetting(feel: .tick, radius: 40, strength: 2),
            .buttons: ZoneSetting(feel: .off, strength: 1, confirmClick: false),
            .edges: ZoneSetting(feel: .tick, strength: 2, confirmClick: false),
        ],
        showGadget: true,
        gadgetFloats: false,
        gadgetOrigin: nil,
        ladder: [1, 3, 4, 6]
    )

    public init(enabled: Bool, zones: [Zone: ZoneSetting], showGadget: Bool, gadgetFloats: Bool,
                gadgetOrigin: CGPoint?, ladder: [Int32]) {
        self.enabled = enabled; self.zones = zones; self.showGadget = showGadget
        self.gadgetFloats = gadgetFloats; self.gadgetOrigin = gadgetOrigin; self.ladder = ladder
    }

    /// Always returns a setting; missing zones fall back to defaults.
    public subscript(zone: Zone) -> ZoneSetting {
        get { zones[zone] ?? Settings.defaults.zones[zone]! }
        set { zones[zone] = newValue }
    }

    // Tolerant decoding: unknown/missing keys fall back to defaults so old saves never crash or reset.
    private enum CodingKeys: String, CodingKey { case enabled, zones, showGadget, gadgetFloats, gadgetOrigin, ladder }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Settings.defaults
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? d.enabled
        let decoded = try? c.decodeIfPresent([Zone: ZoneSetting].self, forKey: .zones)
        zones = d.zones.merging(decoded ?? [:]) { _, new in new }
        showGadget = (try? c.decodeIfPresent(Bool.self, forKey: .showGadget)) ?? d.showGadget
        gadgetFloats = (try? c.decodeIfPresent(Bool.self, forKey: .gadgetFloats)) ?? d.gadgetFloats
        gadgetOrigin = try? c.decodeIfPresent(CGPoint.self, forKey: .gadgetOrigin)
        let l = try? c.decodeIfPresent([Int32].self, forKey: .ladder)
        ladder = (l?.isEmpty == false) ? l! : d.ladder
    }
}

/// Persists Settings as JSON in UserDefaults.
public enum SettingsStore {
    public static let key = "settings.v1"

    public static func load(_ defaults: UserDefaults = .standard) -> Settings {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(Settings.self, from: data) else { return .defaults }
        return s
    }

    public static func save(_ s: Settings, _ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: key) }
    }
}
