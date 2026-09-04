import Foundation
import Testing
@testable import Velocity

@MainActor
struct BackgroundScanningTests {
    @Test func restartingWithBackgroundScanningDisabledStartsNoLoop() {
        let store = VelocityStore()
        store.settings.isBackgroundScanningEnabled = false

        store.restartBackgroundScanning()

        #expect(store.isBackgroundScanning == false)
    }

    @Test func restartingWithBackgroundScanningEnabledStartsALoop() {
        let store = VelocityStore()
        store.settings.isBackgroundScanningEnabled = true

        store.restartBackgroundScanning()

        #expect(store.isBackgroundScanning)
    }

    @Test func togglingTheSettingAfterLoadRestartsTheLoop() async {
        let store = VelocityStore()
        await store.load()
        #expect(store.isBackgroundScanning)

        store.settings.isBackgroundScanningEnabled = false
        #expect(store.isBackgroundScanning == false)

        store.settings.isBackgroundScanningEnabled = true
        #expect(store.isBackgroundScanning)
    }

    @Test func changingTheIntervalRestartsTheLoop() async {
        let store = VelocityStore()
        await store.load()
        #expect(store.isBackgroundScanning)

        // Restarting is idempotent from the outside — still running, just
        // with a fresh sleep — so this only confirms the didSet path does
        // not tear the loop down without restarting it.
        store.settings.scanIntervalMinutes = 10
        #expect(store.isBackgroundScanning)
    }

    @Test func mutatingUnrelatedSettingsDoesNotToggleTheLoop() async {
        let store = VelocityStore()
        await store.load()
        store.settings.isBackgroundScanningEnabled = false
        #expect(store.isBackgroundScanning == false)

        store.settings.targetDailyVelocity = 5
        #expect(store.isBackgroundScanning == false)
    }

    @Test func lastScanAtStaysNilWithoutAScanner() async {
        let store = VelocityStore()
        #expect(store.lastScanAt == nil)

        await store.scanRepositories()
        // No scanner configured in this store, so the scan reports nothing
        // to run rather than producing a report at all.
        #expect(store.lastScanAt == nil)
    }

    @Test func scanOnMenuOpenDoesNothingWhenDisabled() {
        let store = VelocityStore()
        store.settings.scanOnMenuOpen = false

        store.scanOnMenuOpenIfEnabled()

        #expect(store.isScanning == false)
    }
}
