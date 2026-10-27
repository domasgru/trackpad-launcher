import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct QuitSignalsTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let hasQuitReason: Bool
        let afterPowerOff: Bool
        let sender: String
        let expected: QuitRequest
        var testDescription: String { "reason \(hasQuitReason), power-off \(afterPowerOff), sender \(sender)" }
    }

    nonisolated static let cases: [Case] = [
        Case(hasQuitReason: false, afterPowerOff: false, sender: "com.apple.dock", expected: .other),
        Case(hasQuitReason: false, afterPowerOff: false, sender: "com.apple.loginwindow", expected: .system),
        Case(hasQuitReason: false, afterPowerOff: true, sender: "com.apple.dock", expected: .system),
        Case(hasQuitReason: false, afterPowerOff: true, sender: "com.apple.loginwindow", expected: .system),
        Case(hasQuitReason: true, afterPowerOff: false, sender: "com.apple.dock", expected: .system),
        Case(hasQuitReason: true, afterPowerOff: false, sender: "com.apple.loginwindow", expected: .system),
        Case(hasQuitReason: true, afterPowerOff: true, sender: "com.apple.dock", expected: .system),
        Case(hasQuitReason: true, afterPowerOff: true, sender: "com.apple.loginwindow", expected: .system),
    ]

    @Test(arguments: cases)
    func aQuitIsTheSystemsExactlyWhenOneOfTheThreeSignalsHolds(_ input: Case) {
        #expect(
            QuitSignals.request(
                hasQuitReason: input.hasQuitReason, senderBundleID: input.sender, afterPowerOff: input.afterPowerOff)
                == input.expected)
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
