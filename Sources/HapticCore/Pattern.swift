import Foundation

public struct Pulse: Codable {
    public var id: Int32
    public var f1: Float
    public var f2: Float
    /// Delay in ms after the previous pulse (or after play start for the first).
    public var delayMs: Int

    public init(id: Int32, f1: Float = 0, f2: Float = 0, delayMs: Int = 0) {
        self.id = id; self.f1 = f1; self.f2 = f2; self.delayMs = delayMs
    }
}

public struct Pattern: Codable {
    public var name: String
    public var pulses: [Pulse]

    public init(name: String, pulses: [Pulse]) {
        self.name = name; self.pulses = pulses
    }
}

public final class PatternPlayer {
    private let actuator: Actuator
    private let queue = DispatchQueue(label: "haptics.player", qos: .userInteractive)

    public init(actuator: Actuator) { self.actuator = actuator }

    /// Schedules all pulses against one start time using cumulative delays (no drift).
    public func play(_ pattern: Pattern, afterMs offset: Int = 0) {
        let start = DispatchTime.now() + .milliseconds(offset)
        var cumulative = 0
        for pulse in pattern.pulses {
            cumulative += pulse.delayMs
            queue.asyncAfter(deadline: start + .milliseconds(cumulative)) { [actuator] in
                actuator.fire(id: pulse.id, f1: pulse.f1, f2: pulse.f2)
            }
        }
    }
}
