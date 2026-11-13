import Foundation
import HapticCore

func usage() -> Never {
    print("""
    usage:
      haptic-lab sweep
      haptic-lab fire <id> [f1] [f2]
      haptic-lab play <patternName>
    """)
    exit(1)
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first, let actuator = Actuator() else { usage() }

switch cmd {
case "sweep":
    for id in Int32(0)...20 {
        print("id \(id)")
        fflush(stdout)
        actuator.fire(id: id, f1: 0, f2: 0)
        Thread.sleep(forTimeInterval: 0.7)
    }
case "fire":
    guard args.count >= 2, let id = Int32(args[1]) else { usage() }
    let f1 = args.count > 2 ? Float(args[2]) ?? 0 : 0
    let f2 = args.count > 3 ? Float(args[3]) ?? 0 : 0
    actuator.fire(id: id, f1: f1, f2: f2)
    Thread.sleep(forTimeInterval: 0.2)
case "play":
    guard args.count >= 2, let pattern = Library.load()[args[1]] else {
        print("patterns: \(Library.load().keys.sorted().joined(separator: ", "))")
        exit(1)
    }
    PatternPlayer(actuator: actuator).play(pattern)
    Thread.sleep(forTimeInterval: Double(pattern.pulses.reduce(0) { $0 + $1.delayMs }) / 1000 + 0.3)
default:
    usage()
}
