import Sparkle
import SwiftUI

/// Thin wrapper around Sparkle's standard updater controller so `RheaApp` can expose a
/// "Check for Updates…" menu command. Automatic background checks and first-run consent
/// are handled entirely by Sparkle itself (driven by the `SUFeedURL`/`SUPublicEDKey`
/// Info.plist keys) — this type just gives SwiftUI something to bind the menu item to.
@MainActor
final class UpdaterService {
    let updater: SPUUpdater
    private let controller: SPUStandardUpdaterController

    init() {
        // XCUITest drives the compiled app as a black box and always sets UITEST_VAULT_DIR
        // (see RheaApp's UI-test seam); Sparkle's first-run consent alert is an app-modal
        // sheet that would otherwise block every UI test waiting on the main window's
        // accessibility elements, so the updater is never started under test.
        let isUITest = ProcessInfo.processInfo.environment["UITEST_VAULT_DIR"] != nil
        controller = SPUStandardUpdaterController(
            startingUpdater: !isUITest,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updater = controller.updater
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}

/// Mirrors Sparkle's own `CheckForUpdatesViewModel` sample: `canCheckForUpdates` is a
/// KVO-compliant property on `SPUUpdater`, published here so the menu item can disable
/// itself while a check is already in flight.
@MainActor
final class UpdaterViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
