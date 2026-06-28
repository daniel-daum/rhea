import SwiftUI
import AppKit

@main
struct RheaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var viewModel = ReceiptsViewModel()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @Environment(\.scenePhase) private var scenePhase

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
            .task { await viewModel.loadFromDisk() }
            .onChange(of: scenePhase) { _, phase in
                // Backstop: flush all records when the app leaves the foreground.
                if phase != .active { viewModel.saveAll() }
            }
        }
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
