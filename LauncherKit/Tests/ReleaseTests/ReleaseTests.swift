import Foundation
import Testing

@Suite struct ReleaseTests {
    struct Failure: Sendable, CustomTestStringConvertible {
        let name: String
        let patterns: [String]
        var autoupdateTeam: String?
        var rejectsVersionPush = false
        let message: String
        var testDescription: String { name }
    }

    @Test(arguments: [
        Failure(name: "notarising the app", patterns: ["notarize.zip"], message: "stubbed failure"),
        Failure(name: "validating the app's ticket", patterns: ["stapler validate"], message: "stubbed failure"),
        Failure(name: "the strict archive check", patterns: [], autoupdateTeam: "OTHERTEAM", message: "Sparkle's installer is not signed by team"),
        Failure(name: "the card contract", patterns: ["card-contract"], message: "an older copy's card would refuse"),
        Failure(name: "notarising the image", patterns: [".dmg --keychain-profile"], message: "stubbed failure"),
        Failure(name: "signing the update", patterns: ["sign_update /"], message: "cannot sign the update"),
        Failure(name: "pushing the version", patterns: [], rejectsVersionPush: true, message: "cannot push the version commit"),
    ])
    func aFailureBeforeThePublishLeavesNothingBehind(_ failure: Failure) throws {
        let harness = try ReleaseHarness()
        let head = try harness.head
        let refs = try harness.originRefs
        let feed = try harness.feedText
        try harness.failOn(failure.patterns)
        if let team = failure.autoupdateTeam { try harness.autoupdateIsSigned(by: team) }
        if failure.rejectsVersionPush { try harness.rejectPushes(.version) }

        let run = try harness.run("patch")

        #expect(run.status != 0)
        #expect(run.output.contains(failure.message), "\(run.output)")
        #expect(harness.logIndex(of: "gh release create") == nil)
        #expect(try harness.originRefs == refs)
        #expect(try harness.feedText == feed)
        #expect(try harness.treeIsClean)
        #expect(try harness.head == head)
    }

    @Test func archiveOnlyReportsAFailingCardContractAndSucceeds() throws {
        let harness = try ReleaseHarness()
        let app = harness.out.appending(path: "Trackpad App.app")
        try harness.makeApp(at: app)
        try harness.failOn("card-contract")

        let run = try harness.run("--archive-only", app.path)

        #expect(run.status == 0, "\(run.output)")
        #expect(run.output.contains("stubbed failure"))
        #expect(run.output.contains("an older copy's card would refuse"))
    }

    @Test func aBuildNumberEqualToTheFeedsHighestIsRefusedAndOneAboveIsReleased() throws {
        let harness = try ReleaseHarness()
        let item = "<item><title>1.0.10</title><sparkle:version>20</sparkle:version></item>\n"
        try harness.setFeed(Self.emptyFeed.replacingOccurrences(of: "</channel>", with: item + "</channel>"))
        try harness.setVersion("1.0.15", build: 20)

        let refused = try harness.run()
        #expect(refused.status != 0)
        #expect(refused.output.contains("build 20 is not above the feed's 20"), "\(refused.output)")
        #expect(harness.logIndex(of: "gh release create") == nil)

        try harness.setVersion("1.0.15", build: 21)
        let released = try harness.run()
        #expect(released.status == 0, "\(released.output)")
    }

    @Test func withAnEmptyFeedABuildNumberEqualToThePreviousTagsIsRefusedAndOneAboveIsReleased() throws {
        let harness = try ReleaseHarness()
        try harness.tag("v1.0.15")
        try harness.setVersion("1.0.16", build: 16)

        let refused = try harness.run()
        #expect(refused.status != 0)
        #expect(refused.output.contains("is not above v1.0.15's 16"), "\(refused.output)")
        #expect(harness.logIndex(of: "gh release create") == nil)

        try harness.setVersion("1.0.16", build: 17)
        let released = try harness.run()
        #expect(released.status == 0, "\(released.output)")
    }

    @Test func aFirstReleaseWithNoTagPassesTheBuildNumberCheck() throws {
        let harness = try ReleaseHarness()
        #expect(try harness.git("tag", "--list").isEmpty)

        let run = try harness.run()

        #expect(run.status == 0, "\(run.output)")
    }

    @Test func twoReleasesLeaveAFeedWithBothItemsAndTheOlderOneKept() throws {
        let harness = try ReleaseHarness()

        let first = try harness.run("patch")
        #expect(first.status == 0, "\(first.output)")
        let second = try harness.run("patch")
        #expect(second.status == 0, "\(second.output)")

        let url = "https://github.com/domasgru/trackpad-launcher/releases/download"
        func item(_ version: String, build: Int) -> String {
            "<item><title>\(version)</title><pubDate>DATE</pubDate><sparkle:version>\(build)</sparkle:version>"
                + "<sparkle:shortVersionString>\(version)</sparkle:shortVersionString>"
                + "<sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>"
                + "<enclosure url=\"\(url)/v\(version)/TrackpadLauncher-\(version)-macOS-26.0.aar\" "
                + "sparkle:edSignature=\"SIGNATURE\" length=\"LENGTH\" type=\"application/octet-stream\"/></item>"
        }
        let expected = """
            <?xml version="1.0" encoding="utf-8"?>
            <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
            <title>Trackpad App</title>
            \(item("1.0.16", build: 17))
            \(item("1.0.17", build: 18))
            </channel>
            </rss>

            """
        let feed = try harness.feedText
        #expect(try Self.normalised(feed) == expected)
        #expect(try harness.originFeedText == feed)
    }

    @Test func theSignatureVerifiesAndTheReleaseCarriesTheImageAndOneArchiveUnderTheContractName() throws {
        let harness = try ReleaseHarness()

        let run = try harness.run("patch")
        #expect(run.status == 0, "\(run.output)")

        #expect(try harness.publishedAssets(of: "1.0.16") == ["TrackpadApp.dmg", "TrackpadLauncher-1.0.16-macOS-26.0.aar"])
        let feed = try harness.feedText
        let signature = try #require(feed.firstMatch(of: /edSignature="([^"]+)"/)?.1)
        #expect(try harness.verifies(signature: String(signature), of: harness.publishedArchive(of: "1.0.16")))
        #expect(try !harness.verifies(signature: String(signature), of: harness.state.appending(path: "ed-key")))
    }

    @Test func aPreReleaseVersionIsRefusedAndTheFeedIsUnchanged() throws {
        let harness = try ReleaseHarness()
        try harness.setVersion("1.1.0-beta", build: 17)
        let feed = try harness.feedText

        let run = try harness.run()

        #expect(run.status != 0)
        #expect(run.output.contains("not dotted whole numbers"), "\(run.output)")
        #expect(try harness.feedText == feed)
        #expect(try harness.originFeedText == feed)
        #expect(harness.logIndex(of: "gh release create") == nil)
    }

    @Test func theReleaseIsPublishedBeforeTheFeedIsPushed() throws {
        let harness = try ReleaseHarness()

        let run = try harness.run("patch")
        #expect(run.status == 0, "\(run.output)")

        let versionPush = try #require(harness.logIndex(of: "push Version"))
        let create = try #require(harness.logIndex(of: "gh release create"))
        let feedPush = try #require(harness.logIndex(of: "push Feed"))
        #expect(versionPush < create)
        #expect(create < feedPush)
    }

    @Test func aRejectedFeedPushNamesFeedOnlyAndLeavesTheReleasePublicAndTheFeedOld() throws {
        let harness = try ReleaseHarness()
        let feed = try harness.feedText
        try harness.rejectPushes(.feed)

        let run = try harness.run("patch")

        #expect(run.status != 0)
        #expect(run.output.contains("--feed-only 1.0.16"), "\(run.output)")
        #expect(try harness.publishedAssets(of: "1.0.16").count == 2)
        #expect(try harness.originFeedText == feed)
        #expect(try harness.feedText == feed)
        #expect(try harness.treeIsClean)
        #expect(try harness.head == harness.git("rev-parse", "origin/main"))

        try harness.acceptPushes(.feed)
        let retry = try harness.run("--feed-only", "1.0.16")
        #expect(retry.status == 0, "\(retry.output)")
        #expect(try harness.originFeedText.contains("<title>1.0.16</title>"))
        #expect(try harness.treeIsClean)
    }

    @Test func feedOnlyRunTwiceLeavesOneItemAndACleanTree() throws {
        let harness = try ReleaseHarness()
        let release = try harness.run("patch")
        #expect(release.status == 0, "\(release.output)")

        let first = try harness.run("--feed-only", "1.0.16")
        let second = try harness.run("--feed-only", "1.0.16")

        #expect(first.status == 0, "\(first.output)")
        #expect(second.status == 0, "\(second.output)")
        let feed = try harness.originFeedText
        #expect(feed.components(separatedBy: "<title>1.0.16</title>").count == 2)
        #expect(try harness.treeIsClean)
        #expect(try harness.head == harness.git("rev-parse", "origin/main"))
    }

    @Test func feedOnlyForAVersionThatIsNotPublishedFails() throws {
        let harness = try ReleaseHarness()
        let feed = try harness.feedText

        let run = try harness.run("--feed-only", "9.9.9")

        #expect(run.status != 0)
        #expect(try harness.feedText == feed)
        #expect(try harness.treeIsClean)
    }

    @Test func aLeftoverDraftIsDeletedBeforeTheRetry() throws {
        let harness = try ReleaseHarness()
        try harness.leaveDraft("1.0.16")

        let run = try harness.run("patch")

        #expect(run.status == 0, "\(run.output)")
        #expect(harness.logIndex(of: "gh release delete v1.0.16") != nil)
        #expect(try harness.publishedAssets(of: "1.0.16").count == 2)
    }

    struct Refusal: Sendable, CustomTestStringConvertible {
        let name: String
        let message: String
        let arrange: @Sendable (ReleaseHarness) throws -> Void
        var testDescription: String { name }
    }

    @Test(arguments: [
        Refusal(name: "a keychain key that is not the shipped one", message: "update key is not the one project.yml ships") {
            try $0.setKeychainKey("someOtherKey=")
        },
        Refusal(name: "an empty shipped key", message: "update key is not the one project.yml ships") {
            try $0.setShippedKey("\"\"")
        },
        Refusal(name: "missing Sparkle tools", message: "Sparkle's tools are missing") {
            try $0.removeSparkleTool("sign_update")
        },
        Refusal(name: "a malformed feed", message: "appcast.xml is not well-formed") {
            try $0.setFeed("<rss><channel>\n")
        },
    ])
    func preflightRefusesWithNothingChanged(_ refusal: Refusal) throws {
        let harness = try ReleaseHarness()
        try refusal.arrange(harness)
        let head = try harness.head
        let refs = try harness.originRefs

        let run = try harness.run("patch")

        #expect(run.status != 0)
        #expect(run.output.contains(refusal.message), "\(run.output)")
        #expect(harness.logIndex(of: "swift test") == nil)
        #expect(harness.logIndex(of: "xcodebuild") == nil)
        #expect(harness.logIndex(of: "gh release create") == nil)
        #expect(try harness.head == head)
        #expect(try harness.originRefs == refs)
        #expect(try harness.treeIsClean)
    }

    @Test func theStrictCheckRefusesAnInstallerSignedByAnotherTeam() throws {
        let harness = try ReleaseHarness()
        try harness.autoupdateIsSigned(by: "OTHERTEAM")

        let run = try harness.run("patch")

        #expect(run.status != 0)
        #expect(run.output.contains("Sparkle's installer is not signed by team CQK27876UL"), "\(run.output)")
        #expect(harness.logIndex(of: "gh release create") == nil)
    }

    private static let emptyFeed = """
        <?xml version="1.0" encoding="utf-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
        <channel>
        <title>Trackpad App</title>
        </channel>
        </rss>

        """

    private static func normalised(_ feed: String) throws -> String {
        var text = feed
        for (pattern, replacement) in [
            (#"<pubDate>[^<]*</pubDate>"#, "<pubDate>DATE</pubDate>"),
            (#"edSignature="[^"]*""#, #"edSignature="SIGNATURE""#),
            (#"length="[^"]*""#, #"length="LENGTH""#),
        ] {
            text = text.replacing(try Regex(pattern), with: replacement)
        }
        return text
    }
}
