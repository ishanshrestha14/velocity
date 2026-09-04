import Foundation
import Testing
@testable import Velocity

struct VelocitySettingsTests {
    @Test func decodingAPreAutomationFileFillsInDefaults() throws {
        // Shape of a settings object saved before Phase 6 added the
        // automation fields — no isBackgroundScanningEnabled, no
        // scanIntervalMinutes, no scanOnMenuOpen.
        let json = """
        {"targetDailyVelocity": 3.5, "gitAuthorEmail": "dev@example.com"}
        """
        let decoded = try JSONDecoder().decode(VelocitySettings.self, from: Data(json.utf8))

        #expect(decoded.targetDailyVelocity == 3.5)
        #expect(decoded.gitAuthorEmail == "dev@example.com")
        #expect(decoded.isBackgroundScanningEnabled == VelocitySettings.default.isBackgroundScanningEnabled)
        #expect(decoded.scanIntervalMinutes == VelocitySettings.defaultScanIntervalMinutes)
        #expect(decoded.scanOnMenuOpen == false)
        #expect(decoded.notifyOnScanResults == false)
    }

    @Test func roundTripsThroughJSON() throws {
        let original = VelocitySettings(
            targetDailyVelocity: 4,
            gitAuthorEmail: "me@example.com",
            isBackgroundScanningEnabled: false,
            scanIntervalMinutes: 15,
            scanOnMenuOpen: true,
            notifyOnScanResults: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VelocitySettings.self, from: data)

        #expect(decoded == original)
    }
}
