import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct QuitSignalsTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let hasQuitReason: Bool
        let senderBundleID: String?
        let afterPowerOff: Bool
        var testDescription: String {
            "reason \(hasQuitReason), sender \(senderBundleID ?? "none"), after power-off \(afterPowerOff)"
        }
    }

    nonisolated static let cases: [Case] = [true, false].flatMap { reason in
        ["com.apple.loginwindow", "com.apple.dock"].flatMap { sender in
            [true, false].map { Case(hasQuitReason: reason, senderBundleID: sender, afterPowerOff: $0) }
        }
    }

    @Test(arguments: cases)
    func aQuitIsTheSystemsExactlyWhenOneOfTheThreeSignalsHolds(_ input: Case) {
        let expected: QuitRequest =
            input.hasQuitReason || input.senderBundleID == "com.apple.loginwindow" || input.afterPowerOff
            ? .system : .other

        #expect(
            QuitSignals.request(
                hasQuitReason: input.hasQuitReason, senderBundleID: input.senderBundleID,
                afterPowerOff: input.afterPowerOff) == expected)
    }

    private static func quit(reason: OSType?) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEQuitApplication), targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        if let reason {
            event.setParam(NSAppleEventDescriptor(enumCode: reason), forKeyword: AEKeyword(kAEQuitReason))
        }
        return event
    }

    @Test(arguments: [kAEQuitAll, kAEShutDown, kAERestart, kAEReallyLogOut])
    func aQuitCarryingAReasonIsTheSystems(_ reason: OSType) {
        let signals = QuitSignals(workspace: NotificationCenter())

        #expect(signals.request(for: Self.quit(reason: reason)) == .system)
    }

    @Test func aQuitWithoutAReasonOrWithoutAnEventIsAnotherQuit() {
        let signals = QuitSignals(workspace: NotificationCenter())

        #expect(signals.request(for: Self.quit(reason: nil)) == .other)
        #expect(signals.request(for: nil) == .other)
    }

    @Test func aQuitAfterPowerOffWasAnnouncedIsTheSystems() {
        let workspace = NotificationCenter()
        let signals = QuitSignals(workspace: workspace)
        #expect(signals.request(for: Self.quit(reason: nil)) == .other)

        workspace.post(name: NSWorkspace.willPowerOffNotification, object: nil)

        #expect(signals.request(for: Self.quit(reason: nil)) == .system)
    }
}
