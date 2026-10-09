import Foundation
import LauncherCore

/// TrackpadPreferences over the two cfprefs domains. KVO fires on the main thread when another process
/// (System Settings, `defaults`) writes a key, so nothing polls.
@MainActor public final class SystemTrackpadPreferences: NSObject, TrackpadPreferences {
    public static let systemDomains: [TrackpadKind: String] = [
        .builtIn: "com.apple.AppleMultitouchTrackpad",
        .external: "com.apple.driver.AppleBluetoothMultitouch.trackpad",
    ]

    public var onChange: (@MainActor () -> Void)?
    private let suites: [TrackpadKind: UserDefaults]

    /// Domains are injectable so the adapter can be pointed at throwaway domains in its own test.
    public init(domains: [TrackpadKind: String] = systemDomains) {
        suites = domains.compactMapValues { UserDefaults(suiteName: $0) }
        super.init()
        for suite in suites.values {
            for setting in ConflictingSetting.allCases {
                suite.addObserver(self, forKeyPath: setting.preferenceKey, options: [], context: nil)
            }
        }
    }

    isolated deinit {
        for suite in suites.values {
            for setting in ConflictingSetting.allCases {
                suite.removeObserver(self, forKeyPath: setting.preferenceKey)
            }
        }
    }

    /// Every table key in every domain, regardless of what is connected. Reads only.
    public func current() -> [TrackpadKind: TrackpadPreferenceValues] {
        suites.mapValues { suite in
            var values: TrackpadPreferenceValues = [:]
            for setting in ConflictingSetting.allCases {
                values[setting] = suite.object(forKey: setting.preferenceKey) as? Int
            }
            return values
        }
    }

    nonisolated public override func observeValue(
        forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        Task { @MainActor [weak self] in self?.onChange?() }
    }
}
