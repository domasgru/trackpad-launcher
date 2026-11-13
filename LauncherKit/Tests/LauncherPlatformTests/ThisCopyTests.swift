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
        let launch = ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--eject-disk-image", "/Volumes/Trackpad App"])
        #expect(launch == Launch(opening: .byHand, diskImageToEject: DiskImage(volume: URL(filePath: "/Volumes/Trackpad App"))))
    }

    @Test func theEjectFlagWithNoVolumeIsIgnored() {
        #expect(ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--eject-disk-image"]).diskImageToEject == nil)
    }

    @Test func theAfterUpdateFlagIsTheHandOversStartWhateverTheEventSays() {
        let atLogin = Self.event(AEEventID(kAEOpenApplication), loginMarker: true)
        #expect(ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--after-update"]) == Launch(opening: .afterUpdate(withWindow: false)))
        #expect(ThisCopy.launch(event: atLogin, arguments: ["TrackpadApp", "--after-update"]).opening == .afterUpdate(withWindow: false))
    }

    @Test func theAfterUpdateFlagSitsBesideTheEjectFlag() {
        let launch = ThisCopy.launch(
            event: nil, arguments: ["TrackpadApp", "--after-update", "--eject-disk-image", "/Volumes/Trackpad App"])
        #expect(launch == Launch(opening: .afterUpdate(withWindow: false), diskImageToEject: DiskImage(volume: URL(filePath: "/Volumes/Trackpad App"))))
    }

    @Test func theWithWindowFlagBesideAfterUpdateBringsTheWindowInEitherOrderAndBesideTheEjectFlag() {
        let volume = DiskImage(volume: URL(filePath: "/Volumes/Trackpad App"))
        #expect(
            ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--after-update", "--with-window"])
                == Launch(opening: .afterUpdate(withWindow: true)))
        #expect(
            ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--with-window", "--after-update"])
                == Launch(opening: .afterUpdate(withWindow: true)))
        #expect(
            ThisCopy.launch(
                event: nil,
                arguments: ["TrackpadApp", "--after-update", "--with-window", "--eject-disk-image", "/Volumes/Trackpad App"])
                == Launch(opening: .afterUpdate(withWindow: true), diskImageToEject: volume))
    }

    @Test func theWithWindowFlagAloneIsIgnored() {
        #expect(ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--with-window"]) == Launch(opening: .byHand))
    }

    @Test func theAtLoginFlagReadsAsALoginStartWithNoEvent() {
        #expect(ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "--at-login"]) == Launch(opening: .atLogin))
    }

    @Test func aReopenIgnoresArguments() {
        #expect(ThisCopy.opening(of: Self.event(AEEventID(kAEReopenApplication), loginMarker: false)) == .byHand)
    }

    @Test func unrelatedArgumentsAreIgnored() {
        let launch = ThisCopy.launch(event: nil, arguments: ["TrackpadApp", "-NSDocumentRevisionsDebugMode", "YES"])
        #expect(launch == Launch(opening: .byHand))
    }
}
