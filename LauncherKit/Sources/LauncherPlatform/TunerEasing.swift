#if DEBUG
import LauncherCore
import SwiftUI

/// The tuner's named timing curves: what a designer picks from instead of typing control points.
enum NamedCurve: String, CaseIterable, Identifiable {
    case linear, smooth, smoothStrong, fallAndLand, easeIn, easeOut, easeOutLong, slowSettle, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .linear: "Linear"
        case .smooth: "Smooth"
        case .smoothStrong: "Smooth, stronger"
        case .fallAndLand: "Fall & land"
        case .easeIn: "Ease in"
        case .easeOut: "Ease out"
        case .easeOutLong: "Ease out, long tail"
        case .slowSettle: "Slow settle"
        case .custom: "Custom"
        }
    }

    /// The curve's control points; nil for Custom, which keeps whatever the knobs hold.
    var curve: CubicCurve? {
        switch self {
        case .linear: CubicCurve(0, 0, 1, 1)
        case .smooth: CubicCurve(0.37, 0, 0.63, 1)
        case .smoothStrong: CubicCurve(0.65, 0, 0.35, 1)
        case .fallAndLand: CubicCurve(0.55, 0, 0.3, 1)
        case .easeIn: CubicCurve(0.32, 0, 0.67, 0)
        case .easeOut: CubicCurve(0.33, 1, 0.68, 1)
        case .easeOutLong: CubicCurve(0.22, 1, 0.36, 1)
        case .slowSettle: CubicCurve(0.3, 0, 0.1, 1)
        case .custom: nil
        }
    }

    /// The named curve `curve` is, to the knobs' 0.01 step; Custom when it is none of them.
    static func matching(_ curve: CubicCurve) -> NamedCurve {
        allCases.first { named in
            guard let points = named.curve else { return false }
            return [
                (points.x1, curve.x1), (points.y1, curve.y1), (points.x2, curve.x2), (points.y2, curve.y2),
            ].allSatisfy { abs($0 - $1) < 0.005 }
        } ?? .custom
    }
}

/// A small drawing of a timing curve: time left to right, progress bottom to top.
struct CurvePicture: View {
    let curve: CubicCurve

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 4
            let width = size.width - 2 * inset, height = size.height - 2 * inset
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: inset + x * width, y: inset + (1 - y) * height)
            }
            var frame = Path()
            frame.addRect(CGRect(x: inset, y: inset, width: width, height: height))
            context.stroke(frame, with: .color(.secondary.opacity(0.3)), lineWidth: 0.5)
            var path = Path()
            path.move(to: point(0, 0))
            for step in 1...60 {
                let x = Double(step) / 60
                path.addLine(to: point(x, curve.value(at: x)))
            }
            context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)
        }
        .frame(width: 64, height: 44)
    }
}

#endif
