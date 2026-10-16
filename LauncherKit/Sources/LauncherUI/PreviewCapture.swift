import CoreGraphics
import LauncherCore
// ScreenCaptureKit's filter and configuration are not marked Sendable; each is built once here and only read by its
// one capture.
@preconcurrency import ScreenCaptureKit

/// Pictures of windows, taken off the main actor. The one file that captures the screen, for previews only.
enum PreviewCapture {
    /// Yields each window's picture as it is taken: the on-screen windows are listed once (about 14 ms), then each
    /// listed window is captured once, concurrently, alone and sized to its proportions within `fitting` pixels, with
    /// no cursor and no shadow. A window that cannot be captured yields nothing. Cancelling the consuming task stops
    /// the captures. Called only for a window switcher whose `showsPreviews` is true, so it never prompts.
    nonisolated static func pictures(
        of windows: [WindowID], fitting: (width: Int, height: Int)
    ) -> AsyncStream<(WindowID, CGImage)> {
        let wanted = Set(windows.map(\.rawValue))
        let (width, height) = fitting
        return AsyncStream { continuation in
            let work = Task {
                defer { continuation.finish() }
                guard
                    let content = try? await SCShareableContent.excludingDesktopWindows(
                        true, onScreenWindowsOnly: true)
                else { return }
                await withTaskGroup { group in
                    for window in content.windows where wanted.contains(window.windowID) {
                        let id = WindowID(rawValue: window.windowID)
                        let filter = SCContentFilter(desktopIndependentWindow: window)
                        let still = configuration(for: window.frame.size, width: width, height: height)
                        group.addTask {
                            guard !Task.isCancelled,
                                let picture = try? await SCScreenshotManager.captureImage(
                                    contentFilter: filter, configuration: still)
                            else { return }
                            continuation.yield((id, picture))
                        }
                    }
                }
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    /// One still of one window: `size`'s proportions within `width` × `height` pixels.
    private nonisolated static func configuration(for size: CGSize, width: Int, height: Int) -> SCStreamConfiguration {
        let fit = size.width > 0 && size.height > 0
            ? min(Double(width) / size.width, Double(height) / size.height) : 1
        let configuration = SCStreamConfiguration()
        configuration.width = max(Int((size.width * fit).rounded()), 1)
        configuration.height = max(Int((size.height * fit).rounded()), 1)
        configuration.scalesToFit = true
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.captureResolution = .best
        return configuration
    }
}
