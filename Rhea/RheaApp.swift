import SwiftUI
import AppKit

@main
struct RheaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = RheaApp.makeViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(\.scenePhase) private var scenePhase
    private let updaterService = UpdaterService()
    @StateObject private var updaterViewModel: UpdaterViewModel

    init() {
        let service = updaterService
        _updaterViewModel = StateObject(wrappedValue: UpdaterViewModel(updater: service.updater))
    }

    var body: some Scene {
        WindowGroup {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(viewModel: viewModel)
            } content: {
                ReceiptListView(viewModel: viewModel)
            } detail: {
                ReceiptDetailView(viewModel: viewModel)
            }
            .frame(minWidth: 1050, minHeight: 600)
            .task {
                await viewModel.loadFromDisk()
                await RheaApp.importUITestFixtureIfNeeded(into: viewModel)
            }
            .onChange(of: scenePhase) { _, phase in
                // Backstop: flush all records when the app leaves the foreground.
                if phase != .active { viewModel.saveAll() }
            }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterService.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }
    }

    // MARK: - XCUITest seam
    //
    // XCUITest drives the compiled app as a black box (no @testable access), so it can't
    // reach into ReceiptsViewModel directly the way the unit/integration suites do. These
    // keys are read only from the launched process's environment, so a normal launch (no
    // keys set) is unaffected:
    //   UITEST_VAULT_DIR          — isolated LocalStore root instead of Application Support
    //   UITEST_EXTRACTION_ENDPOINT / UITEST_EXTRACTION_MODEL — point at an in-process stub
    //   UITEST_IMPORT_PDF         — auto-import this file on launch, bypassing NSOpenPanel
    //                               (which XCUITest can drive but only flakily/headlessly)

    @MainActor
    private static func makeViewModel() -> ReceiptsViewModel {
        let env = ProcessInfo.processInfo.environment
        let vm: ReceiptsViewModel
        if let vaultPath = env["UITEST_VAULT_DIR"] {
            vm = ReceiptsViewModel(store: LocalStore(rootURL: URL(fileURLWithPath: vaultPath)))
        } else {
            vm = ReceiptsViewModel()
        }
        if let endpoint = env["UITEST_EXTRACTION_ENDPOINT"] { vm.extractionEndpoint = endpoint }
        if let model = env["UITEST_EXTRACTION_MODEL"] { vm.extractionModel = model }
        return vm
    }

    @MainActor
    private static func importUITestFixtureIfNeeded(into viewModel: ReceiptsViewModel) async {
        guard let path = ProcessInfo.processInfo.environment["UITEST_IMPORT_PDF"] else { return }
        await viewModel.importReceipt(from: URL(fileURLWithPath: path))
    }
}

/// SwiftPM executables launch as background command-line tools (no app bundle /
/// Info.plist), so the window never becomes key and text fields can't accept input.
/// Promoting the process to a regular foreground app fixes keyboard focus and
/// restores standard window/cursor behavior.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
