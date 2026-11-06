import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

/// The app's Spotlight reader against `mdls`, Spotlight's own command-line reader.
@Suite struct SpotlightLastUsedTests {
    /// Each path's `mdls` date, nil for `(null)`; whole seconds, as `mdls` prints them.
    private static func mdlsDates(for urls: [URL]) -> [Date?] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
        process.arguments = ["-raw", "-name", "kMDItemLastUsedDate"] + urls.map(\.path)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try? process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let format = DateFormatter()
        format.locale = Locale(identifier: "en_US_POSIX")
        format.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return output.split(separator: 0, omittingEmptySubsequences: false).map {
            format.date(from: String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    private static let listed: [AppEntry] = {
        let installed = AppCatalog.system.installedApps()
        return installed.all
    }()

    private static let hasSpotlightData = mdlsDates(for: listed.map(\.url)).contains { $0 != nil }

    @Test(.enabled(if: hasSpotlightData, "Spotlight has no last-used dates on this Mac"))
    func readerAgreesWithMdlsAndTheNewestLaunchIsFirst() throws {
        // An app in use moves its own date, so each read is held to `mdls` on either side of it.
        let seconds = { (date: Date?) in date.map { Int($0.timeIntervalSince1970) } }
        let before = Self.mdlsDates(for: Self.listed.map(\.url))
        let reads = Self.listed.map { AppCatalog.spotlightLastUsed($0.url) }
        let after = Self.mdlsDates(for: Self.listed.map(\.url))
        try #require(before.count == Self.listed.count)
        try #require(after.count == Self.listed.count)

        for index in Self.listed.indices {
            let read = seconds(reads[index])
            #expect(read == seconds(before[index]) || read == seconds(after[index]), "\(Self.listed[index].name)")
        }

        let recent = AppCatalog.system.installedApps().recent
        let dates = Self.mdlsDates(for: Self.listed.map(\.url))
        let newest = dates.compactMap { $0 }.max()
        let first = try #require(recent.first)
        let firstDate = try #require(Self.listed.firstIndex(of: first).flatMap { dates[$0] })
        #expect(firstDate == newest)
    }
}
