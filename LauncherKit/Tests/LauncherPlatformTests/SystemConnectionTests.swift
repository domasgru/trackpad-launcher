import Foundation
import Testing

@testable import LauncherPlatform

@MainActor @Suite(.serialized) struct SystemConnectionTests {
    private final class Readings {
        var values: [Bool] = []
    }

    @Test func watchPushesOneReadingWithNoChangeOnThePath() async {
        let connection = SystemConnection()
        let readings = Readings()

        let first: Bool? = await awaiting("the present reading") { done in
            connection.onChange = { value in
                readings.values.append(value)
                done(value)
            }
            connection.watch()
        }
        try? await Task.sleep(for: .milliseconds(1000))
        connection.stop()

        #expect(first != nil)
        #expect(readings.values.count == 1)
    }

    @Test func nothingArrivesAfterStopAndASecondWatchPushesAgain() async {
        let connection = SystemConnection()
        let readings = Readings()
        let _: Bool? = await awaiting("the first reading") { done in
            connection.onChange = { value in
                readings.values.append(value)
                done(value)
            }
            connection.watch()
        }
        connection.stop()
        let before = readings.values.count
        try? await Task.sleep(for: .milliseconds(500))

        #expect(readings.values.count == before)

        let _: Bool? = await awaiting("the second reading") { done in
            connection.onChange = { value in
                readings.values.append(value)
                done(value)
            }
            connection.watch()
        }
        connection.stop()

        #expect(readings.values.count == before + 1)
    }
}
