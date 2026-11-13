import Foundation
import Testing
@testable import HaptyqKit

@Test func defaultsAreSane() {
    #expect(Settings.defaults[.close].feel == .frenzy)
    #expect(Settings.defaults[.zoom].feel == .tick)
    #expect(Settings.defaults.enabled)
    #expect(Settings.defaults.ladder == [1, 3, 4, 6])
}

@Test func jsonRoundTrip() throws {
    var s = Settings.defaults
    s.enabled = false
    s[.close] = ZoneSetting(feel: .ramp, radius: 200, strength: 2, confirmClick: false)
    s.gadgetOrigin = CGPoint(x: 10, y: 20)
    s.ladder = [2, 5]
    let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
    #expect(back == s)
}

@Test func emptyObjectDecodesToDefaults() throws {
    let s = try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))
    #expect(s == Settings.defaults)
}

@Test func garbageFieldsFallBack() throws {
    let json = #"{"enabled":"yes","zones":{"close":{"feel":"bogus"}},"ladder":[],"mystery":1}"#
    let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(s.enabled == Settings.defaults.enabled)
    #expect(s.ladder == Settings.defaults.ladder)
    #expect(s[.minimize] == Settings.defaults[.minimize])
}

@Test func partialZonesMergeWithDefaults() throws {
    let json = #"{"zones":{"zoom":{"feel":"frenzy","radius":120,"strength":2,"confirmClick":false}}}"#
    let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(s[.zoom] == ZoneSetting(feel: .frenzy, radius: 120, strength: 2, confirmClick: false))
    #expect(s[.close] == Settings.defaults[.close])
}

@Test func storeRoundTrip() throws {
    let suite = "haptyq.tests.\(UUID().uuidString)"
    let d = try #require(UserDefaults(suiteName: suite))
    defer { d.removePersistentDomain(forName: suite) }
    var s = Settings.defaults
    s.showGadget = false
    SettingsStore.save(s, d)
    #expect(SettingsStore.load(d) == s)
}

private func zone(_ json: String) throws -> ZoneSetting {
    try JSONDecoder().decode(ZoneSetting.self, from: Data(json.utf8))
}

@Test func legacyReachMigratesToRadius() throws {
    #expect(try zone(#"{"feel":"ramp","reach":"near"}"#).radius == 40)
    #expect(try zone(#"{"feel":"ramp","reach":"mid"}"#).radius == 90)
    #expect(try zone(#"{"feel":"ramp","reach":"far"}"#).radius == 160)
    #expect(try zone(#"{"feel":"ramp","reach":"bogus"}"#).radius == 90)
    #expect(try zone(#"{"feel":"ramp","reach":"far","radius":55}"#).radius == 55)
}

@Test func outOfRangeValuesClamp() throws {
    let hi = try zone(#"{"feel":"calm","radius":9999,"strength":99}"#)
    #expect(hi.radius == 300 && hi.strength == 4)
    let lo = try zone(#"{"feel":"calm","radius":-5,"strength":-2}"#)
    #expect(lo.radius == 10 && lo.strength == 1)
    var z = ZoneSetting(feel: .tick)
    z.radius = 1000; z.strength = 0
    #expect(z.radius == 300 && z.strength == 1)
}

@Test func missingStrengthGetsFeelDefault() throws {
    #expect(try zone(#"{"feel":"frenzy"}"#).strength == 4)
    #expect(try zone(#"{"feel":"calm"}"#).strength == 3)
    #expect(try zone(#"{"feel":"tick","strength":1}"#).strength == 1)
}
