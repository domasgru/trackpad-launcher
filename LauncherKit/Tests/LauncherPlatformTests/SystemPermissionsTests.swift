import Foundation
import LauncherCore
import Synchronization
import Testing
import notify

@testable import LauncherPlatform

@MainActor @Suite struct SystemPermissionsTests {
    /// True when `onChange` ran within `seconds` of `action`; the push is awaited, never polled.
    private func changeArrives(
        on adapter: SystemPermissions, within seconds: Int, after action: () -> Void
    ) async -> Bool {
        let outcome = AsyncStream<Bool>.makeStream()
        adapter.onChange = { outcome.continuation.yield(true) }
        let bound = Task {
            try await Task.sleep(for: .seconds(seconds))
            outcome.continuation.yield(false)
        }
        action()
        var iterator = outcome.stream.makeAsyncIterator()
        let arrived = await iterator.next() ?? false
        bound.cancel()
        adapter.onChange = nil
        return arrived
    }

    @Test func broadcastReachesOnChangeOnlyWhenTrustOrScreenCaptureChanged() async {
        let trusted = Mutex(false)
        let capturing = Mutex(false)
        let adapter = SystemPermissions(
            trusted: { trusted.withLock { $0 } }, capturing: { capturing.withLock { $0 } })
        #expect(!adapter.isGranted(.accessibility))
        #expect(!adapter.isGranted(.screenRecording))

        let noise = await changeArrives(on: adapter, within: 1) {
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(!noise, "a broadcast without a change stays silent")

        let captureGranted = await changeArrives(on: adapter, within: 5) {
            capturing.withLock { $0 = true }
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(captureGranted, "onChange arrives within 5 s of a Screen Recording grant")
        #expect(adapter.isGranted(.screenRecording))
        #expect(!adapter.isGranted(.accessibility))

        let trustGranted = await changeArrives(on: adapter, within: 5) {
            trusted.withLock { $0 = true }
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(trustGranted, "onChange arrives within 5 s of an Accessibility grant")
        #expect(adapter.isGranted(.accessibility))
        #expect(adapter.isGranted(.screenRecording))

        let revoked = await changeArrives(on: adapter, within: 5) {
            trusted.withLock { $0 = false }
            notify_post(SystemPermissions.changeNotification)
        }
        #expect(revoked, "onChange arrives within 5 s of a revoke")
        #expect(!adapter.isGranted(.accessibility))
    }
}
