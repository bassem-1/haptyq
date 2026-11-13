import CoreGraphics
import HapticCore
import Testing
@testable import HaptyqKit

private let ladder: [Int32] = [1, 3, 4, 6]
private func zs(_ f: Feel, r: Double = 90, s: Int = 3) -> ZoneSetting { ZoneSetting(feel: f, radius: r, strength: s) }
private func cfg(_ f: Feel, r: Double = 90, s: Int = 3, _ l: [Int32] = ladder) -> ProximityConfig? {
    proximityConfig(for: zs(f, r: r, s: s), ladder: l)
}

@Test func offAndTickHaveNoRamp() {
    for s in 1...4 {
        #expect(cfg(.off, s: s) == nil)
        #expect(cfg(.tick, s: s) == nil)
    }
    #expect(tickTapID(setting: zs(.off), ladder: ladder) == nil)
}

@Test func tickTapFollowsStrength() {
    for (s, id) in [(1, Int32(1)), (2, 3), (3, 4), (4, 6)] {
        #expect(tickTapID(setting: zs(.tick, s: s), ladder: ladder) == id)
        #expect(buttonTapID(setting: zs(.calm, s: s), ladder: ladder) == id)
    }
}

@Test func calmRows() throws {
    let c = try #require(cfg(.calm, r: 40, s: 3))
    #expect(c.radius == 40 && c.slowestMs == 260 && c.fastestMs == 110 && c.curve == 2.2 && c.idleMs == 250)
    #expect(c.ids == [3, 4])
    #expect(try #require(cfg(.calm, s: 1)).ids == [1])
    #expect(try #require(cfg(.calm, s: 4)).ids == [4, 6])
}

@Test func rampRows() throws {
    let c = try #require(cfg(.ramp, r: 160, s: 4))
    #expect(c.radius == 160 && c.slowestMs == 200 && c.fastestMs == 45 && c.curve == 1.8)
    #expect(c.ids == ladder)
    #expect(try #require(cfg(.ramp, s: 1)).ids == [1])
    #expect(try #require(cfg(.ramp, s: 2)).ids == [1, 3])
}

@Test func frenzyRows() throws {
    let c = try #require(cfg(.frenzy, s: 4))
    #expect(c.radius == 90 && c.slowestMs == 120 && c.fastestMs == 16 && c.curve == 1.1)
    #expect(c.ids == [4, 6])
    #expect(try #require(cfg(.frenzy, s: 1)).ids == [1])
    #expect(try #require(cfg(.frenzy, s: 2)).ids == [1, 3])
}

@Test func radiusComesFromSetting() throws {
    #expect(try #require(cfg(.ramp, r: 250)).radius == 250)
    #expect(try #require(cfg(.calm, r: 10)).radius == 10)
}

@Test func shortLaddersClamp() throws {
    #expect(try #require(cfg(.calm, [5])).ids == [5])
    #expect(try #require(cfg(.calm, s: 4, [5, 7])).ids == [5, 7])
    #expect(try #require(cfg(.ramp, s: 4, [5, 7])).ids == [5, 7])
    #expect(try #require(cfg(.frenzy, s: 4, [5])).ids == [5])
    #expect(try #require(cfg(.frenzy, s: 4, [5, 7])).ids == [5, 7])
    #expect(cfg(.frenzy, []) == nil)
    #expect(tickTapID(setting: zs(.tick, s: 4), ladder: [5]) == 5)
    #expect(tickTapID(setting: zs(.tick, s: 4), ladder: []) == nil)
}

@Test func edgeRatchets() throws {
    #expect(edgeRatchet(setting: zs(.off), ladder: ladder) == nil)
    let expected: [(Feel, Double)] = [(.tick, 40), (.calm, 40), (.ramp, 25), (.frenzy, 14)]
    for (f, step) in expected {
        let r = try #require(edgeRatchet(setting: zs(f, s: 2), ladder: ladder))
        #expect(r.step == step && r.id == 3)
    }
    #expect(try #require(edgeRatchet(setting: zs(.tick, s: 4), ladder: ladder)).id == 6)
}

@Test func hoverTriggerRearms() {
    var t = HoverTrigger()
    let samples: [Double?] = [nil, 12, 0, 0, -1, 3, 0, nil, 0]
    let fired = samples.map { t.update(distance: $0) }
    #expect(fired == [false, false, true, false, false, false, true, false, true])
}

@Test func ratchetStepCounting() {
    #expect(ratchetSteps(accumulated: 39.9, step: 40) == 0)
    #expect(ratchetSteps(accumulated: 85, step: 40) == 2)
    #expect(ratchetSteps(accumulated: -3, step: 40) == 0)
    #expect(ratchetSteps(accumulated: 10, step: 0) == 0)
}

@Test func distanceMath() {
    let f = CGRect(x: 100, y: 100, width: 12, height: 12) // center (106,106), radius 6
    #expect(distanceToButton(cursor: CGPoint(x: 106, y: 106), frame: f) == 0)
    #expect(distanceToButton(cursor: CGPoint(x: 109, y: 106), frame: f) == 0)
    #expect(distanceToButton(cursor: CGPoint(x: 116, y: 106), frame: f) == 4)
    #expect(distanceToButton(cursor: CGPoint(x: 106, y: 86), frame: f) == 14)
}

@Test func edgeProximity() {
    let w = CGRect(x: 100, y: 100, width: 400, height: 300)
    #expect(isNearEdge(CGPoint(x: 103, y: 250), frame: w))
    #expect(isNearEdge(CGPoint(x: 97, y: 250), frame: w))
    #expect(!isNearEdge(CGPoint(x: 300, y: 250), frame: w))
    #expect(!isNearEdge(CGPoint(x: 90, y: 250), frame: w))
}

@Test func nearestWinsThenHigherFeel() {
    let a = TargetCandidate(zone: .close, feel: .calm, distance: 10)
    let b = TargetCandidate(zone: .minimize, feel: .frenzy, distance: 20)
    #expect(nearestTarget([b, a]) == a)
    let c = TargetCandidate(zone: .zoom, feel: .ramp, distance: 10)
    #expect(nearestTarget([a, c]) == c)
    #expect(nearestTarget([c, a]) == c)
    #expect(nearestTarget([]) == nil)
}

@Test func confirmPatterns() {
    #expect(confirmPatternName(zone: .close, documentModified: false) == "latch")
    #expect(confirmPatternName(zone: .close, documentModified: true) == "heartbeat")
    #expect(confirmPatternName(zone: .minimize, documentModified: false) == "sink")
    #expect(confirmPatternName(zone: .zoom, documentModified: false) == "inhale")
    #expect(confirmPatternName(zone: .edges, documentModified: false) == nil)
}
