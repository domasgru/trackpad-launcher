import Foundation
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
}
