import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

struct TunerCodingTests {
    /// The presets the tuner saved on this Mac before the launch bounce existed, verbatim from its defaults.
    private static let presetsBeforeBounce = """
        [{"name":"Preset 1","tuning":{"duration":0.34,"rise":70,"shrinkCurve":1.4000000000000001,"fadeCurve":4,\
        "minimumSway":0.1,"tiltCurve":1,"forceReduceMotion":false,"maximumSway":0.4,"swayCurve":1.8,"shrink":0.55,\
        "maximumTilt":4,"popSize":0,"iconSide":60,"riseCurve":1.8,"popTime":0.04}},{"name":"Preset 2","tuning":\
        {"duration":0.34,"rise":70,"shrinkCurve":1.4000000000000001,"fadeCurve":4,"minimumSway":0.1,"tiltCurve":1,\
        "forceReduceMotion":false,"maximumSway":0.26,"swayCurve":1.8,"shrink":0.55,"maximumTilt":4,"popSize":0.2,\
        "iconSide":60,"riseCurve":1.8,"popTime":0.075}}]
        """

    /// The fixture's values, written out: 14 numbers and the reduce-motion flag make the 15 flight keys.
    private static let flights: [(name: String, numbers: [String: Double])] = [
        ("Preset 1", [
            "duration": 0.34, "rise": 70, "shrinkCurve": 1.4000000000000001, "fadeCurve": 4, "minimumSway": 0.1,
            "tiltCurve": 1, "maximumSway": 0.4, "swayCurve": 1.8, "shrink": 0.55, "maximumTilt": 4, "popSize": 0,
            "iconSide": 60, "riseCurve": 1.8, "popTime": 0.04,
        ]),
        ("Preset 2", [
            "duration": 0.34, "rise": 70, "shrinkCurve": 1.4000000000000001, "fadeCurve": 4, "minimumSway": 0.1,
            "tiltCurve": 1, "maximumSway": 0.26, "swayCurve": 1.8, "shrink": 0.55, "maximumTilt": 4, "popSize": 0.2,
            "iconSide": 60, "riseCurve": 1.8, "popTime": 0.075,
        ]),
    ]

    @Test func `a preset saved before the bounce keeps its flight and gets the shipped bounce`() throws {
        let presets = try JSONDecoder().decode([TuningPreset].self, from: Data(Self.presetsBeforeBounce.utf8))

        #expect(presets.map(\.name) == ["Preset 1", "Preset 2"])
        for (index, expected) in Self.flights.enumerated() {
            let tuning = presets[index].tuning
            let actual: [String: Double] = [
                "duration": tuning.duration, "rise": tuning.rise, "shrinkCurve": tuning.shrinkCurve,
                "fadeCurve": tuning.fadeCurve, "minimumSway": tuning.minimumSway, "tiltCurve": tuning.tiltCurve,
                "maximumSway": tuning.maximumSway, "swayCurve": tuning.swayCurve, "shrink": tuning.shrink,
                "maximumTilt": tuning.maximumTilt, "popSize": tuning.popSize, "iconSide": tuning.iconSide,
                "riseCurve": tuning.riseCurve, "popTime": tuning.popTime,
            ]
            #expect(actual == expected.numbers, "\(expected.name)")
            #expect(tuning.forceReduceMotion == false, "\(expected.name)")
        }
        #expect(presets.allSatisfy { $0.tuning.bounce == LaunchTuning.Bounce() })
        #expect(presets.allSatisfy { $0.tuning.pick == .shipped })
    }

    @Test func `every bounce knob survives a save and load`() throws {
        var tuning = LaunchTuning()
        tuning.bounce = LaunchTuning.Bounce(
            height: 41, timeUp: 0.21, timeDown: 0.22, rest: 0.13, squash: 0.17, gap: 9, offset: 5, trailing: 0.31,
            spacing: 14, fadeOut: 0.27, slide: 0.23, pulseLow: 0.37, pulsePeriod: 1.9)
        let presets = [TuningPreset(name: "Bouncy", tuning: tuning)]

        let loaded = try JSONDecoder().decode([TuningPreset].self, from: JSONEncoder().encode(presets))

        #expect(loaded == presets)
    }

    @Test func `a saved bounce with only some knobs keeps the shipped rest`() throws {
        let json = #"{"bounce":{"height":55,"gap":3}}"#

        let tuning = try JSONDecoder().decode(LaunchTuning.self, from: Data(json.utf8))

        var expected = LaunchTuning.Bounce()
        expected.height = 55
        expected.gap = 3
        #expect(tuning.bounce == expected)
    }

    /// The presets the tuner saved on this Mac with the bounce and the swipe settings but before the pick animation,
    /// verbatim from its defaults.
    private static let presetsBeforePick = #"""
        [{"name":"Preset 1","tuning":{"swipeFollowsCursor":true,"forceReduceMotion":false,"popTime":0.04,"fadeCurve":4,"minimumSway":0.1,"swayCurve":1.8,"shrinkCurve":1.4000000000000001,"tiltCurve":1,"duration":0.34,"maximumSway":0.4,"maximumTilt":4,"bounce":{"pulsePeriod":1.4,"trailing":0,"inflateCurve":3,"slide":0.2,"squash":0,"height":30,"offset":0,"pulseLow":0.5,"inflateFrom":20,"timeDown":0.3,"style":"jump","timeUp":0.3,"creep":0.15,"fadeOut":0.2,"rest":0.1,"gap":8,"spacing":12,"inflateTime":0.5,"creepTime":8},"popSize":0,"shrink":0.55,"rise":70,"swipePointsPerStep":100,"riseCurve":1.8,"iconSide":60,"swipeTrackingSpeed":-1}},{"name":"Preset 2","tuning":{"swipeFollowsCursor":true,"forceReduceMotion":false,"popTime":0.075,"fadeCurve":4,"minimumSway":0.1,"swayCurve":1.8,"shrinkCurve":1.4000000000000001,"tiltCurve":1,"duration":0.34,"maximumSway":0.26,"maximumTilt":4,"bounce":{"pulsePeriod":1.4,"trailing":0,"inflateCurve":2,"slide":0.2,"squash":0.05,"height":15,"offset":0,"pulseLow":0.5,"inflateFrom":24,"timeDown":0.15,"style":"inflate","timeUp":0.2,"creep":0.4,"fadeOut":0.2,"rest":0.5,"gap":8,"spacing":12,"inflateTime":0.4,"creepTime":5},"popSize":0.2,"shrink":0.55,"rise":70,"swipePointsPerStep":100,"riseCurve":1.8,"iconSide":60,"swipeTrackingSpeed":-1}}]
        """#

    private static let savedFlights: [(name: String, numbers: [String: Double])] = [
        ("Preset 1", [
            "duration": 0.34, "rise": 70, "shrinkCurve": 1.4000000000000001, "fadeCurve": 4, "minimumSway": 0.1,
            "tiltCurve": 1, "maximumSway": 0.4, "swayCurve": 1.8, "shrink": 0.55, "maximumTilt": 4, "popSize": 0,
            "iconSide": 60, "riseCurve": 1.8, "popTime": 0.04,
            "swipePointsPerStep": 100, "swipeTrackingSpeed": -1,
        ]),
        ("Preset 2", [
            "duration": 0.34, "rise": 70, "shrinkCurve": 1.4000000000000001, "fadeCurve": 4, "minimumSway": 0.1,
            "tiltCurve": 1, "maximumSway": 0.26, "swayCurve": 1.8, "shrink": 0.55, "maximumTilt": 4, "popSize": 0.2,
            "iconSide": 60, "riseCurve": 1.8, "popTime": 0.075,
            "swipePointsPerStep": 100, "swipeTrackingSpeed": -1,
        ]),
    ]

    private static let savedBounces: [LaunchTuning.Bounce] = [
        LaunchTuning.Bounce(
            style: .jump, height: 30, timeUp: 0.3, timeDown: 0.3, rest: 0.1, squash: 0, gap: 8, offset: 0,
            trailing: 0, spacing: 12, fadeOut: 0.2, slide: 0.2, pulseLow: 0.5, pulsePeriod: 1.4, inflateFrom: 20,
            inflateTime: 0.5, inflateCurve: 3, creep: 0.15, creepTime: 8),
        LaunchTuning.Bounce(
            style: .inflate, height: 15, timeUp: 0.2, timeDown: 0.15, rest: 0.5, squash: 0.05, gap: 8, offset: 0,
            trailing: 0, spacing: 12, fadeOut: 0.2, slide: 0.2, pulseLow: 0.5, pulsePeriod: 1.4, inflateFrom: 24,
            inflateTime: 0.4, inflateCurve: 2, creep: 0.4, creepTime: 5),
    ]

    @Test func `a preset saved before the pick animation keeps every saved knob and gets the shipped pick`() throws {
        let presets = try JSONDecoder().decode([TuningPreset].self, from: Data(Self.presetsBeforePick.utf8))

        #expect(presets.map(\.name) == ["Preset 1", "Preset 2"])
        for (index, expected) in Self.savedFlights.enumerated() {
            let tuning = presets[index].tuning
            let actual: [String: Double] = [
                "duration": tuning.duration, "rise": tuning.rise, "shrinkCurve": tuning.shrinkCurve,
                "fadeCurve": tuning.fadeCurve, "minimumSway": tuning.minimumSway, "tiltCurve": tuning.tiltCurve,
                "maximumSway": tuning.maximumSway, "swayCurve": tuning.swayCurve, "shrink": tuning.shrink,
                "maximumTilt": tuning.maximumTilt, "popSize": tuning.popSize, "iconSide": tuning.iconSide,
                "riseCurve": tuning.riseCurve, "popTime": tuning.popTime,
                "swipePointsPerStep": tuning.swipePointsPerStep, "swipeTrackingSpeed": tuning.swipeTrackingSpeed,
            ]
            #expect(actual == expected.numbers, "\(expected.name)")
            #expect(tuning.swipeFollowsCursor == true, "\(expected.name)")
            #expect(tuning.forceReduceMotion == false, "\(expected.name)")
            #expect(tuning.bounce == Self.savedBounces[index], "\(expected.name)")
            #expect(tuning.pick == .shipped, "\(expected.name)")
        }
    }

    @Test func `every pick knob survives a save and load`() throws {
        var tuning = LaunchTuning()
        tuning.pick = PickAnimation(startScale: 0.25, peakScale: 1.35, growTime: 0.45, settleTime: 0.35, rise: 11)
        let presets = [TuningPreset(name: "Grower", tuning: tuning)]

        let loaded = try JSONDecoder().decode([TuningPreset].self, from: JSONEncoder().encode(presets))

        #expect(loaded == presets)
    }

    @Test func `a saved pick with only some knobs keeps the shipped rest`() throws {
        let json = #"{"pick":{"growTime":0.5}}"#

        let tuning = try JSONDecoder().decode(LaunchTuning.self, from: Data(json.utf8))

        #expect(tuning.pick == PickAnimation(startScale: 0.5, peakScale: 1.08, growTime: 0.5, settleTime: 0.2, rise: 6))
    }

    private static var everythingAwayFromShipped: LaunchTuning {
        var t = LaunchTuning()
        t.iconSide = 80
        t.duration = 0.5
        t.popSize = 0.3
        t.popTime = 0.1
        t.rise = 90
        t.riseCurve = 2.5
        t.shrink = 0.4
        t.shrinkCurve = 2
        t.fadeCurve = 5
        t.maximumSway = 0.5
        t.minimumSway = 0.2
        t.swayCurve = 2.5
        t.maximumTilt = 8
        t.tiltCurve = 2
        t.forceReduceMotion = true
        t.swipeFollowsCursor = false
        t.swipePointsPerStep = 150
        t.swipeTrackingSpeed = 1.5
        t.bounce = LaunchTuning.Bounce(
            style: .jump, height: 41, timeUp: 0.21, timeDown: 0.22, rest: 0.13, squash: 0.17, gap: 9, offset: 5,
            trailing: 0.31, spacing: 14, fadeOut: 0.27, slide: 0.23, pulseLow: 0.37, pulsePeriod: 1.9,
            inflateFrom: 30, inflateTime: 0.6, inflateCurve: 3, creep: 0.2, creepTime: 7)
        t.pick = PickAnimation(startScale: 0.25, peakScale: 1.35, growTime: 0.45, settleTime: 0.35, rise: 11)
        return t
    }

    @Test func `resetting Pick ships the pick and keeps everything else`() {
        let away = Self.everythingAwayFromShipped
        var expected = away
        expected.pick = .shipped

        #expect(away.resettingToShipped(.pick) == expected)
    }

    @Test func `resetting Launch ships the fourteen flight knobs and keeps everything else`() {
        let away = Self.everythingAwayFromShipped
        let shipped = LaunchTuning.shipped
        var expected = away
        expected.iconSide = shipped.iconSide
        expected.duration = shipped.duration
        expected.popSize = shipped.popSize
        expected.popTime = shipped.popTime
        expected.rise = shipped.rise
        expected.riseCurve = shipped.riseCurve
        expected.shrink = shipped.shrink
        expected.shrinkCurve = shipped.shrinkCurve
        expected.fadeCurve = shipped.fadeCurve
        expected.maximumSway = shipped.maximumSway
        expected.minimumSway = shipped.minimumSway
        expected.swayCurve = shipped.swayCurve
        expected.maximumTilt = shipped.maximumTilt
        expected.tiltCurve = shipped.tiltCurve

        #expect(away.resettingToShipped(.launch) == expected)
    }

    @Test func `resetting Bounce ships only the bounce`() {
        let away = Self.everythingAwayFromShipped
        var expected = away
        expected.bounce = LaunchTuning.shipped.bounce

        #expect(away.resettingToShipped(.bounce) == expected)
    }

    @Test func `resetting Swipe ships only the three swipe settings`() {
        let away = Self.everythingAwayFromShipped
        var expected = away
        expected.swipeFollowsCursor = LaunchTuning.shipped.swipeFollowsCursor
        expected.swipePointsPerStep = LaunchTuning.shipped.swipePointsPerStep
        expected.swipeTrackingSpeed = LaunchTuning.shipped.swipeTrackingSpeed

        #expect(away.resettingToShipped(.swipe) == expected)
    }
}
