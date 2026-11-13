import Foundation

// SKELETON: the public surface below is the contract the ui codes against.
// The engine agent replaces the bodies; signatures must not change.

/// Owns the event tap, accessibility lookups and the actuator. Main-thread API.
@MainActor
public final class TremorEngine {
    /// False when no force touch trackpad / private actuator could be opened.
    public private(set) var hardwareAvailable: Bool = false

    /// Called on the main thread (throttled to ~30 Hz) whenever a haptic pulse fires. Drives ui feedback.
    public var onPulse: (() -> Void)?

    public init() {}

    /// Apply new settings. Starts or stops the event tap based on `settings.enabled` and permission state.
    public func apply(_ settings: Settings) {}

    /// Try to (re)start after permissions change. Returns true if the tap is running.
    @discardableResult
    public func refresh() -> Bool { false }

    /// Play a ~1.2 s simulated approach for a zone/setting so the user can feel it from the ui.
    public func preview(_ zone: Zone, _ setting: ZoneSetting) {}

    /// Stop everything (app quitting).
    public func shutdown() {}
}

/// Accessibility permission helpers. Main-thread API.
public enum Permissions {
    public static var isTrusted: Bool { false }
    /// Shows the system prompt once.
    public static func request() {}
    /// Opens system settings > privacy & security > accessibility.
    public static func openSettings() {}
}

/// Launch-at-login via SMAppService. Fails gracefully for ad-hoc signed builds.
public enum LaunchAtLogin {
    public static var isEnabled: Bool { false }
    /// Returns an lowercase error message on failure, nil on success.
    @discardableResult
    public static func set(_ on: Bool) -> String? { nil }
}
