import CoreGraphics
import Testing

@testable import LauncherUI

@Suite struct GlassMirrorMatchTests {
    private let views = (0..<12).map { CGRect(x: 100.0 * Double($0), y: 10 + Double($0), width: 80, height: 80 + Double($0)) }
    private let permutation = [3, 7, 0, 11, 5, 1, 9, 2, 10, 4, 8, 6]

    private let all = Set(0..<12)

    private func shuffled(_ rects: [CGRect]) -> [CGRect] { permutation.map { rects[$0] } }

    @Test func eachViewTakesTheElementAtItsFrame() {
        #expect(GlassMirror.match(elements: views, views: views, animating: all) == Array(0..<12))
        let elements = shuffled(views)
        let matched = GlassMirror.match(elements: elements, views: views, animating: all)
        #expect(matched == (0..<12).map { view in permutation.firstIndex(of: view)! })
    }

    @Test func anElementHalfAPointOffStillMatchesAndOneSixTenthsOffDoesNot() {
        var near = views
        near[4].origin.x += 0.4
        #expect(GlassMirror.match(elements: near, views: views, animating: all) == Array(0..<12))
        var far = views
        far[4].origin.x += 0.6
        #expect(GlassMirror.match(elements: far, views: views, animating: all) == nil)
    }

    @Test func anAmbiguousOrPartialMirrorMatchesNothing() {
        var twice = views
        twice[11] = views[0].offsetBy(dx: 0.3, dy: 0)
        #expect(GlassMirror.match(elements: twice, views: views, animating: all) == nil)
        #expect(GlassMirror.match(elements: Array(views.dropLast()), views: views, animating: all) == nil)
        var stray = views
        stray[5] = CGRect(x: 5000, y: 5000, width: 10, height: 10)
        #expect(GlassMirror.match(elements: stray, views: views, animating: all) == nil)
    }

    @Test func viewsThatNeverAnimateMayCoincideWithEachOther() {
        var coincident = views
        for spare in 5..<11 { coincident[spare] = views[11] }
        let animating: Set<Int> = [0, 1, 2, 3, 4, 11]
        #expect(GlassMirror.match(elements: coincident, views: coincident, animating: [0, 1, 2, 3, 4])
            == [0, 1, 2, 3, 4, nil, nil, nil, nil, nil, nil, nil])
        #expect(GlassMirror.match(elements: coincident, views: coincident, animating: animating) == nil)
    }

    @Test func anAnimatingViewStillNeedsItsOwnElementAmongCoincidentOnes() {
        var coincident = views
        for index in 1..<12 { coincident[index] = views[0] }
        #expect(GlassMirror.match(elements: coincident, views: coincident, animating: [0]) == nil)
        #expect(GlassMirror.match(elements: coincident, views: coincident, animating: []) == Array(repeating: nil, count: 12))
    }

    @Test func aBeadLeftUnmappedNeedsNoElementOfItsOwn() {
        var coincident = views
        for index in 0..<11 { coincident[index] = views[0] }
        let matched = GlassMirror.match(elements: coincident, views: coincident, animating: [11])
        #expect(matched == Array(repeating: nil, count: 11) + [11])
    }
}
