/// What the launcher window's screen recording hint button does.
public enum ScreenRecordingHint: Equatable, Sendable {
    /// Never asked: the button asks macOS.
    case ask
    /// Asked before and still missing: the button opens System Settings on the Screen Recording page.
    case openSettings
}
