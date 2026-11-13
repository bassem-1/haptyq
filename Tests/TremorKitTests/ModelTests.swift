import Testing
@testable import TremorKit

@Test func defaultsAreSane() {
    #expect(Settings.defaults[.close].feel == .frenzy)
}
