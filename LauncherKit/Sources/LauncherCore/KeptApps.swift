import Foundation

/// The apps a hide keeps. `front` must be active and shown before anything hides; `beside`, a split gesture's other
/// app, is kept but never waited for. Never the same app twice.
public struct KeptApps: Hashable, Sendable {
    public let front: BundleID
    public let beside: BundleID?

    public init(front: BundleID, beside: BundleID? = nil) {
        self.front = front
        self.beside = beside == front ? nil : beside
    }

    public func keeps(_ app: BundleID) -> Bool { app == front || app == beside }

    /// Whether `app`'s first window showing hides the others now: `front` must be frontmost, and when `app` is `beside`,
    /// `front`'s own launch must not still be waiting for its window (that window hides instead).
    func hides(onWindowOf app: BundleID, frontmost: BundleID?, frontStillWaits: Bool) -> Bool {
        guard frontmost == front else { return false }
        return !(app == beside && frontStillWaits)
    }
}
