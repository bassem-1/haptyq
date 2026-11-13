import CoreGraphics
import Foundation

// Shared contract between the engine (TremorKit) and the ui (tremor). Change only with care.

/// A place on screen tremor reacts to.
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

    /// Reach is meaningless for zones without proximity.
    public var allowsReach: Bool { usesProximity }
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

/// How far from a target the effect starts (proximity zones only).
public enum Reach: String, Codable, CaseIterable, Identifiable, Sendable {
    case near, mid, far

    public var id: String { rawValue }
    public var title: String { rawValue }

    /// Radius in screen points around the button's edge.
    public var points: Double {
        switch self {
        case .near: 40
        case .mid: 90
        case .far: 160
        }
    }
}

public struct ZoneSetting: Codable, Equatable, Sendable {
    public var feel: Feel
    public var reach: Reach
    /// Play a short confirmation pattern when the button is actually clicked.
    public var confirmClick: Bool

    public init(feel: Feel, reach: Reach = .mid, confirmClick: Bool = true) {
        self.feel = feel; self.reach = reach; self.confirmClick = confirmClick
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
            .close: ZoneSetting(feel: .frenzy, reach: .mid),
            .minimize: ZoneSetting(feel: .calm, reach: .near),
            .zoom: ZoneSetting(feel: .tick, reach: .near),
            .buttons: ZoneSetting(feel: .off, confirmClick: false),
            .edges: ZoneSetting(feel: .tick, confirmClick: false),
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
