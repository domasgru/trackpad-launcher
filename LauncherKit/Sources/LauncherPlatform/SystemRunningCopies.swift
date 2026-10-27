import AppKit
import LauncherCore

@MainActor public final class SystemRunningCopies: RunningCopies {
    public init() {}

    public func endThisCopy() { NSApp.terminate(nil) }
}
