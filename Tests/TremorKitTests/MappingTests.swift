import CoreGraphics
import HapticCore
import Testing
@testable import TremorKit

private let ladder: [Int32] = [1, 3, 4, 6]
private func cfg(_ f: Feel, _ r: Reach = .mid, _ l: [Int32] = ladder) -> ProximityConfig? {
    proximityConfig(for: ZoneSetting(feel: f, reach: r), ladder: l)
}

@Test func offAndTickHaveNoRamp() {
    #expect(cfg(.off) == nil)
    #expect(cfg(.tick) == nil)
    #expect(proximityTapID(ladder: ladder) == 3)
}

@Test func calmRow() throws {
    let c = try #require(cfg(.calm, .near))
    #expect(c.radius == 40 && c.slowestMs == 260 && c.fastestMs == 110 && c.curve == 2.2)
    #expect(c.ids == [1, 3] && c.idleMs == 250)
}

@Test func rampRow() throws {
    let c = try #require(cfg(.ramp, .far))
    #expect(c.radius == 160 && c.slowestMs == 200 && c.fastestMs == 45 && c.curve == 1.8)
    #expect(c.ids == ladder)
}

@Test func frenzyRow() throws {
    let c = try #require(cfg(.frenzy, .mid))
    #expect(c.radius == 90 && c.slowestMs == 120 && c.fastestMs == 16 && c.curve == 1.1)
    #expect(c.ids == [4, 6])
}

@Test func shortLaddersClamp() throws {
    #expect(try #require(cfg(.calm, .mid, [5])).ids == [5])
    #expect(try #require(cfg(.calm, .mid, [5, 7])).ids == [5, 7])
    #expect(try #require(cfg(.ramp, .mid, [5, 7])).ids == [5, 7])
    #expect(try #require(cfg(.frenzy, .mid, [5])).ids == [5])
    #expect(try #require(cfg(.frenzy, .mid, [5, 7])).ids == [7])
    #expect(cfg(.frenzy, .mid, []) == nil)
    #expect(proximityTapID(ladder: [5]) == 5)
    #expect(buttonTapID(feel: .ramp, ladder: [5, 7]) == 7)
    #expect(buttonTapID(feel: .ramp, ladder: []) == nil)
}

@Test func buttonTapIDs() {
    #expect(buttonTapID(feel: .off, ladder: ladder) == nil)
    #expect(buttonTapID(feel: .tick, ladder: ladder) == 1)
    #expect(buttonTapID(feel: .calm, ladder: ladder) == 3)
    #expect(buttonTapID(feel: .ramp, ladder: ladder) == 4)
    #expect(buttonTapID(feel: .frenzy, ladder: ladder) == 6)
}

@Test func edgeRatchets() throws {
    #expect(edgeRatchet(feel: .off, ladder: ladder) == nil)
    let expected: [(Feel, Double, Int32)] = [(.tick, 40, 1), (.calm, 40, 3), (.ramp, 25, 4), (.frenzy, 14, 6)]
    for (f, step, id) in expected {
        let r = try #require(edgeRatchet(feel: f, ladder: ladder))
        #expect(r.step == step && r.id == id)
    }
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
