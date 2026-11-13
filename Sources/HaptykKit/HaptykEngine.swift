import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import HapticCore
import ServiceManagement

/// Throttles pulse notifications to ~30 Hz. Called from any queue.
private final class PulseGate {
    private let lock = NSLock()
    private var last: UInt64 = 0
    var deliver: (() -> Void)?

    func pulse() {
        let t = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        let ok = t &- last >= 33_000_000
        if ok { last = t }
        lock.unlock()
        guard ok else { return }
        DispatchQueue.main.async { [weak self] in self?.deliver?() }
    }
}

/// Handed to the tap callback. Only touched on the main thread (the tap source runs on the main run loop).
private final class TapContext {
    let tracker: Tracker
    var port: CFMachPort?
    init(tracker: Tracker) { self.tracker = tracker }
}

private let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let ctx = Unmanaged<TapContext>.fromOpaque(refcon).takeUnretainedValue()
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let port = ctx.port { CGEvent.tapEnable(tap: port, enable: true) }
    case .mouseMoved: ctx.tracker.post(.move, event.location)
    case .leftMouseDragged: ctx.tracker.post(.drag, event.location)
    case .leftMouseDown: ctx.tracker.post(.down, event.location)
    case .leftMouseUp: ctx.tracker.post(.up, event.location)
    default: break
    }
    return Unmanaged.passUnretained(event)
}

/// Owns the event tap, accessibility lookups and the actuator. Main-thread API.
@MainActor
public final class HaptykEngine {
    /// False when no force touch trackpad / private actuator could be opened.
    public private(set) var hardwareAvailable: Bool = false

    /// Called on the main thread (throttled to ~30 Hz) whenever a haptic pulse fires. Drives ui feedback.
    public var onPulse: (() -> Void)?

    private let actuator: Actuator?
    private let proximity: ProximityEngine?
    private let player: PatternPlayer?
    private let tracker: Tracker
    private let gate = PulseGate()
    private var settings = Settings.defaults

    private var context: TapContext?
    private var source: CFRunLoopSource?

    private var previewProximity: ProximityEngine?
    private var previewTimer: DispatchSourceTimer?

    public init() {
        let a = Actuator()
        actuator = a
        hardwareAvailable = a != nil
        proximity = a.map { ProximityEngine(actuator: $0, config: ProximityConfig()) }
        player = a.map { PatternPlayer(actuator: $0) }
        tracker = Tracker(actuator: a, proximity: proximity, player: player)
        gate.deliver = { [weak self] in
            MainActor.assumeIsolated { self?.onPulse?() }
        }
        let g = gate
        a?.onFire = { g.pulse() }
    }

    /// Apply new settings. Starts or stops the event tap based on `settings.enabled` and permission state.
    public func apply(_ settings: Settings) {
        self.settings = settings
        tracker.configure(settings)
        if !settings.enabled { cancelPreview() }
        reconcile()
    }

    /// Try to (re)start after permissions change. Returns true if the tap is running.
    @discardableResult
    public func refresh() -> Bool {
        reconcile()
        return context != nil
    }

    /// Play a ~1.2 s simulated approach for a zone/setting so the user can feel it from the ui.
    public func preview(_ zone: Zone, _ setting: ZoneSetting) {
        cancelPreview()
        guard let actuator, setting.feel != .off else { return }
        let ladder = settings.ladder

        if zone == .edges {
            guard let r = edgeRatchet(feel: setting.feel, ladder: ladder) else { return }
            var n = 0
            schedule(intervalMs: 70) { [weak self] in
                n += 1
                actuator.fire(id: r.id)
                if n >= 8 { self?.cancelPreview() }
            }
            return
        }
        if !zone.usesProximity || setting.feel == .tick {
            let id = zone.usesProximity ? proximityTapID(ladder: ladder) : buttonTapID(feel: setting.feel, ladder: ladder)
            if let id { actuator.fire(id: id) }
            return
        }
        guard let cfg = proximityConfig(for: setting, ladder: ladder) else { return }
        let engine = ProximityEngine(actuator: actuator, config: cfg)
        previewProximity = engine
        let start = DispatchTime.now().uptimeNanoseconds
        schedule(intervalMs: 16) { [weak self] in
            let t = Double(DispatchTime.now().uptimeNanoseconds &- start) / 1e6
            if t >= 1350 {
                engine.update(distance: nil, config: nil)
                self?.cancelPreview()
            } else {
                engine.update(distance: cfg.radius * max(0, 1 - t / 1200), config: cfg)
            }
        }
    }

    /// Stop everything (app quitting).
    public func shutdown() {
        cancelPreview()
        teardownTap()
        proximity?.update(distance: nil, config: nil)
    }

    // MARK: private

    private func reconcile() {
        if settings.enabled && Permissions.isTrusted && hardwareAvailable {
            if context == nil { startTap() }
        } else {
            teardownTap()
            proximity?.update(distance: nil, config: nil)
        }
    }

    private func startTap() {
        let ctx = TapContext(tracker: tracker)
        let mask: CGEventMask = [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged]
            .reduce(0) { $0 | (1 << $1.rawValue) }
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: tapCallback,
            userInfo: Unmanaged.passUnretained(ctx).toOpaque()
        ) else { return }
        ctx.port = port
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        context = ctx
        source = src
        tracker.start()
    }

    private func teardownTap() {
        if let ctx = context, let port = ctx.port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        if let src = source { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        context = nil
        source = nil
        tracker.stop()
    }

    private func schedule(intervalMs: Int, _ block: @escaping () -> Void) {
        previewTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(intervalMs))
        t.setEventHandler(handler: block)
        t.resume()
        previewTimer = t
    }

    private func cancelPreview() {
        previewTimer?.cancel()
        previewTimer = nil
        previewProximity?.update(distance: nil, config: nil)
        previewProximity = nil // its 5 ms timer stops with it
    }
}

/// Accessibility permission helpers. Main-thread API.
public enum Permissions {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt once.
    public static func request() {
        // literal key: the imported global is a mutable var and trips strict concurrency
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Opens system settings > privacy & security > accessibility.
    public static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Launch-at-login via SMAppService. Fails gracefully for ad-hoc signed builds.
public enum LaunchAtLogin {
    public static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Returns an lowercase error message on failure, nil on success.
    @discardableResult
    public static func set(_ on: Bool) -> String? {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription.lowercased()
        }
    }
}
