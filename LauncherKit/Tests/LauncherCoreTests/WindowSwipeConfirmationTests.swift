import Testing
import LauncherCore

@MainActor @Suite struct WindowSwipeConfirmationTests {
    private let macBook = Trackpad.macBook14.id
    private let magic = Trackpad.magicTrackpad.id

    private func start(on trackpad: TrackpadID) -> TrackpadEvent {
        .windowSwipe(SwipeEvent(phase: .began, trackpad: trackpad))
    }

    /// Delivers `event` to a handler that records it and confirms `confirming`, if any.
    private func deliver(
        _ event: TrackpadEvent, confirming: TrackpadID?, through confirmation: WindowSwipeConfirmation
    ) -> (answer: Bool?, handled: Int) {
        var handled = 0
        let answer = confirmation.deliver(event) { _ in
            handled += 1
            if let confirming { confirmation.confirm(on: confirming) }
        }
        return (answer, handled)
    }

    @Test func aStartIsAWindowSwipeOnlyWhenItsHandlerConfirmsItsOwnTrackpad() {
        let confirmation = WindowSwipeConfirmation()
        let own = deliver(start(on: macBook), confirming: macBook, through: confirmation)
        let other = deliver(start(on: macBook), confirming: magic, through: confirmation)
        let none = deliver(start(on: macBook), confirming: nil, through: confirmation)
        #expect(own.answer == true && own.handled == 1)
        #expect(other.answer == false && other.handled == 1)
        #expect(none.answer == false && none.handled == 1)
    }

    @Test func aStartWithNoHandlerIsNoWindowSwipe() {
        #expect(WindowSwipeConfirmation().deliver(start(on: macBook), to: nil) == false)
    }

    @Test(arguments: [
        TrackpadEvent.swipe(SwipeEvent(phase: .began, trackpad: Trackpad.macBook14.id)),
        .windowSwipe(SwipeEvent(phase: .moved(travelMM: 12), trackpad: Trackpad.macBook14.id)),
        .gesture(GestureEvent(gesture: .two, trackpad: Trackpad.macBook14.id)),
    ])
    func everyOtherEventIsHandedOverAndGetsNoAnswer(event: TrackpadEvent) {
        let delivered = deliver(event, confirming: macBook, through: WindowSwipeConfirmation())
        #expect(delivered.answer == nil)
        #expect(delivered.handled == 1)
    }

    @Test func aConfirmationBetweenDeliveriesDoesNotCarryOverToTheNextStart() {
        let confirmation = WindowSwipeConfirmation()
        _ = deliver(.gesture(GestureEvent(gesture: .one, trackpad: macBook)), confirming: nil, through: confirmation)
        confirmation.confirm(on: macBook)
        #expect(deliver(start(on: macBook), confirming: nil, through: confirmation).answer == false)
    }
}
