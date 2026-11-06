import AppKit
import LauncherCore
import Testing

@testable import LauncherPlatform

@Suite struct ThisCopyTests {
    private static func event(_ id: AEEventID, loginMarker: Bool) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass), eventID: id, targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        if loginMarker {
            event.setParam(
                NSAppleEventDescriptor(enumCode: OSType(keyAELaunchedAsLogInItem)), forKeyword: AEKeyword(keyAEPropData))
        }
        return event
    }

    @Test func aStartCarryingTheLoginMarkerIsAtLogin() {
        let launch = ThisCopy.launch(event: Self.event(AEEventID(kAEOpenApplication), loginMarker: true), arguments: [])
        #expect(launch == Launch(opening: .atLogin))
    }

    @Test func aStartWithoutTheMarkerIsByHand() {
        let launch = ThisCopy.launch(event: Self.event(AEEventID(kAEOpenApplication), loginMarker: false), arguments: [])
        #expect(launch == Launch(opening: .byHand))
    }

    @Test func aStartWithNoEventIsByHand() {
        #expect(ThisCopy.launch(event: nil, arguments: []) == Launch(opening: .byHand))
    }

    @Test func aReopenIsByHandUnlessItCarriesTheMarker() {
        #expect(ThisCopy.opening(of: Self.event(AEEventID(kAEReopenApplication), loginMarker: false)) == .byHand)
        #expect(ThisCopy.opening(of: Self.event(AEEventID(kAEReopenApplication), loginMarker: true)) == .atLogin)
        #expect(ThisCopy.opening(of: nil) == .byHand)
    }

    @Test func theEjectFlagWithAVolumeNamesTheDiskImageToEject() {
        let launch = ThisCopy.launch(event: nil, arguments: ["TrackpadLauncher", "--eject-disk-image", "/Volumes/Trackpad Launcher"])
        #expect(launch == Launch(opening: .byHand, diskImageToEject: DiskImage(volume: URL(filePath: "/Volumes/Trackpad Launcher"))))
    }

    @Test func theEjectFlagWithNoVolumeIsIgnored() {
        #expect(ThisCopy.launch(event: nil, arguments: ["TrackpadLauncher", "--eject-disk-image"]).diskImageToEject == nil)
    }

    @Test func unrelatedArgumentsAreIgnored() {
        let launch = ThisCopy.launch(event: nil, arguments: ["TrackpadLauncher", "-NSDocumentRevisionsDebugMode", "YES"])
        #expect(launch == Launch(opening: .byHand))
    }
}
