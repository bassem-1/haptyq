import Foundation

/// Tuning for the "Geiger counter" effect: pulses get faster and stronger as the cursor nears a target.
public struct ProximityConfig: Codable, Equatable {
    /// Distance (points) at which pulses start.
    public var radius: Double = 140
    /// Pulse interval at the edge of the radius and when touching the target.
    public var slowestMs: Double = 220
    public var fastestMs: Double = 35
    /// >1 keeps it calm until close, <1 ramps up early.
    public var curve: Double = 2
    /// Actuator IDs from weakest to strongest; the band is picked by closeness.
    public var ids: [Int32] = [1, 3, 4, 6]
    /// Stop pulsing this long after the cursor stops moving.
    public var idleMs: Double = 250
    /// Light tick when the cursor enters any button (daemon only).
    public var hoverTick: Bool = true

    public init() {}

    public static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/trackpad-haptics/proximity.json")
    }

    public static func load() -> ProximityConfig {
        guard let data = try? Data(contentsOf: url),
              let cfg = try? JSONDecoder().decode(ProximityConfig.self, from: data) else { return ProximityConfig() }
        return cfg
    }

    public func save() throws {
        try FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: Self.url, options: .atomic)
    }

    /// Closeness 0...1 (1 = on the target), or nil when out of range.
    func closeness(_ distance: Double) -> Double? {
        guard radius > 0, distance < radius else { return nil }
        return min(1, max(0, 1 - max(0, distance) / radius))
    }
}

public final class ProximityEngine {
    private let actuator: Actuator
    private let queue = DispatchQueue(label: "haptics.proximity", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var _config: ProximityConfig
    private var distance: Double?
    private var lastUpdate: UInt64 = 0
    private var lastFire: UInt64 = 0

    public init(actuator: Actuator, config: ProximityConfig = .load()) {
        self.actuator = actuator
        self._config = config
    }

    deinit { timer?.cancel() }

    /// The 5 ms tick only runs while there is something to do, so an idle engine costs no wakeups. Queue-only.
    private func arm() {
        guard timer == nil, distance != nil else { return }
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: .milliseconds(5), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func disarm() {
        timer?.cancel()
        timer = nil
    }

    public var config: ProximityConfig {
        get { queue.sync { _config } }
        set { queue.async { self._config = newValue } }
    }

    /// Report the cursor's distance to the target (0 = on it), or nil when there is no target.
    public func update(distance: Double?) {
        let now = DispatchTime.now().uptimeNanoseconds
        queue.async {
            self.distance = distance
            self.lastUpdate = now
            self.arm()
        }
    }

    /// Like `update(distance:)`, and swaps the config in the same queue hop. A nil config keeps the stored one.
    public func update(distance: Double?, config: ProximityConfig?) {
        let now = DispatchTime.now().uptimeNanoseconds
        queue.async {
            if let config { self._config = config }
            self.distance = distance
            self.lastUpdate = now
            self.arm()
        }
    }

    /// Current (intervalMs, id) for a distance; exposed for UIs.
    public static func output(_ cfg: ProximityConfig, distance: Double) -> (intervalMs: Double, id: Int32)? {
        guard let c = cfg.closeness(distance), !cfg.ids.isEmpty else { return nil }
        let shaped = pow(c, cfg.curve)
        let interval = cfg.slowestMs - (cfg.slowestMs - cfg.fastestMs) * shaped
        let band = min(cfg.ids.count - 1, Int(c * Double(cfg.ids.count)))
        return (interval, cfg.ids[band])
    }

    private func tick() {
        let now = DispatchTime.now().uptimeNanoseconds
        guard let d = distance, Double(now &- lastUpdate) / 1e6 <= _config.idleMs else { return disarm() }
        guard let out = Self.output(_config, distance: d),
              Double(now &- lastFire) / 1e6 >= out.intervalMs else { return }
        lastFire = now
        actuator.fire(id: out.id)
    }
}
