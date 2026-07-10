import Testing
import Foundation

/// Guards the Sparkle wiring that isn't otherwise exercised by an automated end-to-end update
/// (that's verified manually against the real appcast — see ticket #27): the merged Info.plist
/// keys Sparkle reads at launch, and that the feed points at the stable `appcast-feed` branch
/// rather than a per-release asset URL (which changes every tag and can't serve as `SUFeedURL`).
struct SparkleConfigurationTests {
    private var infoPlist: [String: Any] {
        get throws {
            let thisFile = URL(fileURLWithPath: #filePath)
            let repoRoot = thisFile
                .deletingLastPathComponent() // RheaTests
                .deletingLastPathComponent() // Tests
                .deletingLastPathComponent() // repo root
            let infoPlistURL = repoRoot.appending(path: "Rhea/Info.plist")
            let data = try Data(contentsOf: infoPlistURL)
            let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
            return try #require(plist as? [String: Any])
        }
    }

    @Test func feedURLPointsAtTheStableAppcastFeedBranchNotAReleaseAsset() throws {
        let feedURL = try #require(infoPlist["SUFeedURL"] as? String)
        #expect(feedURL == "https://git.danieldaum.net/daniel-daum/rhea/raw/branch/appcast-feed/appcast.xml")
        #expect(!feedURL.contains("/releases/download/"))
    }

    @Test func publicEDKeyIsPresentAndNonEmpty() throws {
        let publicKey = try #require(infoPlist["SUPublicEDKey"] as? String)
        #expect(!publicKey.isEmpty)
    }
}
