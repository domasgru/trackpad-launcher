import Foundation

/// Everything persisted besides the implicit "launched before".
///
/// Decoding rule, for every field present and future: a key missing from the record decodes as that field's default;
/// a key this build does not know is ignored; a key whose value does not decode fails the whole record.
public struct Settings: Codable, Equatable, Sendable {
    /// Saved under the key `handMode`, as the hand whose thumb anchors, exactly as every version has written it.
    private var handMode: HandMode = .right

    /// Whether the thumb anchors at the bottom edge. A build without bottom corners ignores this key and anchors in the
    /// top corner on the same side. The key is this field's name, permanently.
    private var isThumbAtBottom = false

    /// The corner the thumb anchors in.
    public var thumbCorner: ThumbCorner {
        // `right` is the hand whose thumb rests on the left.
        get { ThumbCorner(isLeft: handMode == .right, isBottom: isThumbAtBottom) }
        set {
            handMode = newValue.isLeft ? .right : .left
            isThumbAtBottom = newValue.isBottom
        }
    }

    /// Absent = unassigned. The key and each entry's first-app keys are permanent (see `Assignment`'s wire form).
    public var assignments: [Gesture: Assignment] = [:]
    /// Whether a gesture plays the launch animation. The key is this field's name, permanently.
    public var isLaunchAnimationOn = true
    /// Whether two fingers sliding under the thumb switch apps. The key is this field's name, permanently.
    public var isSwipeOn = true
    /// Whether a thumb tap under two resting fingers swaps apps. The key is this field's name, permanently.
    public var isSwapOn = true
    /// Whether two fingers sliding up or down under the thumb switch windows. The key is this field's name, permanently.
    public var isWindowSwipeOn = false
    /// Whether the screen recording hint's button has asked macOS for the permission. The key is this field's name,
    /// permanently.
    public var hasAskedForScreenRecording = false
    /// Whether an action that brings an app or window to the front also hides every other app. The key is this field's
    /// name, permanently.
    public var isHideBackgroundAppsOn = false

    /// The apps some gesture holds alone, missing ones included: one tap away, so the switcher leaves them out.
    /// Derived, never stored.
    public var oneAppBundleIDs: Set<BundleID> {
        Set(assignments.values.filter { $0.second == nil }.map(\.first.bundleID))
    }

    /// The slide kinds whose setting is on. Derived, never stored.
    public var slides: Set<SlideKind> {
        var slides: Set<SlideKind> = []
        if isSwipeOn { slides.insert(.swipe) }
        if isWindowSwipeOn { slides.insert(.windowSwipe) }
        return slides
    }

    public init() {}

    public init(from decoder: any Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        handMode = try container.decodeIfPresent(HandMode.self, forKey: .handMode) ?? handMode
        isThumbAtBottom = try container.decodeIfPresent(Bool.self, forKey: .isThumbAtBottom) ?? isThumbAtBottom
        assignments = try container.decodeIfPresent([Gesture: Assignment].self, forKey: .assignments) ?? assignments
        isLaunchAnimationOn =
            try container.decodeIfPresent(Bool.self, forKey: .isLaunchAnimationOn) ?? isLaunchAnimationOn
        isSwipeOn = try container.decodeIfPresent(Bool.self, forKey: .isSwipeOn) ?? isSwipeOn
        isSwapOn = try container.decodeIfPresent(Bool.self, forKey: .isSwapOn) ?? isSwapOn
        isWindowSwipeOn = try container.decodeIfPresent(Bool.self, forKey: .isWindowSwipeOn) ?? isWindowSwipeOn
        hasAskedForScreenRecording =
            try container.decodeIfPresent(Bool.self, forKey: .hasAskedForScreenRecording) ?? hasAskedForScreenRecording
        isHideBackgroundAppsOn =
            try container.decodeIfPresent(Bool.self, forKey: .isHideBackgroundAppsOn) ?? isHideBackgroundAppsOn
    }
}

/// The wire form of the thumb corner: `right` is the thumb on the left side, `left` the thumb on the right side.
private enum HandMode: String, Codable {
    case right
    case left
}

/// The settings record under `settings`, plus, beside it, the one key the previous version must never drop.
/// Local-substitutable: tests use a throwaway `UserDefaults` suite.
@MainActor public struct SettingsStore {
    private let defaults: UserDefaults
    private let key = "settings"
    private let externalCornerKey = "externalThumbCorner"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// nil means nothing was ever saved, which is a first launch. Undecodable data loads as `Settings()`,
    /// not as a first launch, so a user who turned the login item off is never re-enrolled.
    public func load() -> Settings? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return (try? PropertyListDecoder().decode(Settings.self, from: data)) ?? Settings()
    }

    public func save(_ settings: Settings) {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    /// The External trackpad corner; nil until the Mac has mixed trackpads. The key's presence is that record, so a
    /// value this build cannot read loads as `ThumbCorners.defaultExternal`, never as nil.
    func loadExternalCorner() -> ThumbCorner? {
        guard let saved = defaults.object(forKey: externalCornerKey) else { return nil }
        return (saved as? String).flatMap(SavedCorner.init(rawValue:))?.corner ?? ThumbCorners.defaultExternal
    }

    /// One synchronous `set` of one key beside the record. It survives a force-quit, a version that does not
    /// know the key never rewrites it, and it neither ends nor fakes a first run. Takes no nil: nothing
    /// clears the record.
    func saveExternalCorner(_ corner: ThumbCorner) {
        defaults.set(SavedCorner(corner).rawValue, forKey: externalCornerKey)
    }
}

/// The key's permanent values. Exhaustive switches map them to and from `ThumbCorner`, so renaming a case there
/// cannot change what is saved, and `ThumbCorner` stays non-`Codable`.
private enum SavedCorner: String {
    case topLeft, topRight, bottomLeft, bottomRight

    init(_ corner: ThumbCorner) {
        switch corner {
        case .topLeft: self = .topLeft
        case .topRight: self = .topRight
        case .bottomLeft: self = .bottomLeft
        case .bottomRight: self = .bottomRight
        }
    }

    var corner: ThumbCorner {
        switch self {
        case .topLeft: .topLeft
        case .topRight: .topRight
        case .bottomLeft: .bottomLeft
        case .bottomRight: .bottomRight
        }
    }
}
