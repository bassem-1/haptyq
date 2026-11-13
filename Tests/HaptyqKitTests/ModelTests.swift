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
    s[.close] = ZoneSetting(feel: .ramp, reach: .far, confirmClick: false)
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
    let json = #"{"zones":{"zoom":{"feel":"frenzy","reach":"far","confirmClick":false}}}"#
    let s = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(s[.zoom] == ZoneSetting(feel: .frenzy, reach: .far, confirmClick: false))
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
