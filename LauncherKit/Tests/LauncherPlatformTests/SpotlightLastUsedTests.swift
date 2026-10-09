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
        return installed.recent + installed.others
    }()

    private static let hasSpotlightData = mdlsDates(for: listed.map(\.url)).contains { $0 != nil }

    @Test(.enabled(if: hasSpotlightData, "Spotlight has no last-used dates on this Mac"))
    func readerAgreesWithMdlsAndTheNewestLaunchIsFirst() throws {
        let dates = Self.mdlsDates(for: Self.listed.map(\.url))
        try #require(dates.count == Self.listed.count)

        for (entry, expected) in zip(Self.listed, dates) {
            let read = AppCatalog.spotlightLastUsed(entry.url)
            #expect(read.map { Int($0.timeIntervalSince1970) } == expected.map { Int($0.timeIntervalSince1970) }, "\(entry.name)")
        }

        let recent = AppCatalog.system.installedApps().recent
        let newest = dates.compactMap { $0 }.max()
        let first = try #require(recent.first)
        let firstDate = try #require(Self.listed.firstIndex(of: first).flatMap { dates[$0] })
        #expect(firstDate == newest)
    }
}
