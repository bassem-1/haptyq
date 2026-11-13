import Foundation

public enum Library {
    // Placeholder IDs, tune with `haptic-lab sweep`.
    static let strong: Int32 = 6, medium: Int32 = 4, soft: Int32 = 3, weakest: Int32 = 1

    public static let builtIn: [String: Pattern] = {
        func p(_ name: String, _ pulses: [(Int32, Int)]) -> Pattern {
            Pattern(name: name, pulses: pulses.map { Pulse(id: $0.0, delayMs: $0.1) })
        }
        let all = [
            p("latch", [(strong, 0), (soft, 45)]),
            p("inhale", [(soft, 0), (medium, 70), (strong, 45)]),
            p("sink", [(strong, 0), (medium, 50), (soft, 80), (weakest, 120)]),
            p("heartbeat", [(medium, 0), (strong, 110), (medium, 450), (strong, 110)]),
            p("ratchet", [(weakest, 0)]),
        ]
        return Dictionary(uniqueKeysWithValues: all.map { ($0.name, $0) })
    }()

    /// Built-ins overridden by name from ~/.config/trackpad-haptics/patterns.json ([Pattern]) if present.
    public static func load() -> [String: Pattern] {
        var result = builtIn
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/trackpad-haptics/patterns.json")
        if let data = try? Data(contentsOf: url) {
            if let custom = try? JSONDecoder().decode([Pattern].self, from: data) {
                for pattern in custom { result[pattern.name] = pattern }
            } else {
                FileHandle.standardError.write(Data("warning: could not parse \(url.path)\n".utf8))
            }
        }
        return result
    }
}
