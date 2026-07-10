import XCTest
import Foundation

/// Launch helpers for driving the compiled Rhea.app under XCUITest. Unlike the RheaTests
/// suites, these tests have no `@testable import Rhea` — they only see the app through the
/// accessibility tree and its process environment, so all injection happens via
/// `XCUIApplication.launchEnvironment` (read by `RheaApp`'s UI-test seam).
enum UITestApp {

    /// Launches Rhea pointed at a throwaway per-test vault directory, so tests never touch
    /// the real `~/Library/Application Support/Rhea` vault or a developer's own receipts.
    /// - Parameters:
    ///   - extractionServer: when set, points the app's extraction endpoint at the stub so
    ///     runs are deterministic and hit no real network / model server.
    ///   - importFixturePDF: when set, the app auto-imports this file on launch (the
    ///     `-AppleLaunchArguments`-style seam called for by the ticket), standing in for
    ///     driving the ⌘O / NSOpenPanel file picker, which XCUITest can't drive reliably headless.
    @MainActor
    static func launch(
        extractionServer: StubExtractionServer? = nil,
        importFixturePDF: URL? = nil
    ) -> (app: XCUIApplication, vaultDir: URL) {
        let vaultDir = FileManager.default.temporaryDirectory
            .appending(path: "RheaUITests-\(UUID().uuidString)", directoryHint: .isDirectory)

        var env: [String: String] = ["UITEST_VAULT_DIR": vaultDir.path]
        if let extractionServer {
            env["UITEST_EXTRACTION_ENDPOINT"] = extractionServer.endpoint
            env["UITEST_EXTRACTION_MODEL"]    = "stub-model"
        }
        if let importFixturePDF {
            env["UITEST_IMPORT_PDF"] = importFixturePDF.path
        }

        let app = XCUIApplication()
        app.launchEnvironment = env
        app.launch()
        return (app, vaultDir)
    }

    private static var fixturesBundle: Bundle { Bundle(for: StubExtractionServer.self) }

    static func fixtureURL(_ name: String, ext: String) -> URL? {
        fixturesBundle.url(forResource: name, withExtension: ext)
    }

    static func fixtureText(_ name: String, ext: String) throws -> String {
        let url = try XCTUnwrap(fixtureURL(name, ext: ext))
        return try String(contentsOf: url, encoding: .utf8)
    }
}

extension XCUIApplication {
    /// Finds an element by `accessibilityIdentifier` regardless of its accessibility role —
    /// SwiftUI Table rows / List rows on macOS surface as varying element types.
    func element(id: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Finds the first element whose identifier starts with `prefix` — used for elements
    /// (e.g. a receipt row) whose full identifier includes a UUID unknown ahead of time.
    func element(identifierPrefix prefix: String) -> XCUIElement {
        let predicate = NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        return descendants(matching: .any).matching(predicate).firstMatch
    }
}
