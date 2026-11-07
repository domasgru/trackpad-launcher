import Foundation

/// A version as releases and Info.plists write it: dotted whole numbers ("1.10.0"). Compared part by part, a missing
/// part counting as zero: 1.9.0 < 1.10.0, 1.1 == 1.1.0. "1.1.0-beta", "v1.1" and "" are not versions, so a release named
/// with one never counts.
public struct Version: Comparable, Hashable, Sendable, CustomStringConvertible {
    /// As written, for the card: "App version 1.10.0 is available".
    public let description: String
    /// Trailing zeros dropped, so ==, hash and < agree.
    private let parts: [Int]

    /// Non-empty by construction: this Mac's macOS, fixtures.
    public init(_ first: Int, _ rest: Int...) {
        let all = [first] + rest
        description = all.map(String.init).joined(separator: ".")
        parts = Self.trimmed(all)
    }

    /// Digits and single dots only; each part at most 9 digits.
    public init?(_ text: String) {
        let pieces = text.split(separator: ".", omittingEmptySubsequences: false)
        var numbers: [Int] = []
        for piece in pieces {
            guard (1...9).contains(piece.utf8.count), piece.utf8.allSatisfy({ (48...57).contains($0) }),
                let number = Int(piece)
            else { return nil }
            numbers.append(number)
        }
        description = text
        parts = Self.trimmed(numbers)
    }

    private static func trimmed(_ numbers: [Int]) -> [Int] {
        var kept = numbers
        while kept.last == 0 { kept.removeLast() }
        return kept
    }

    public static func < (a: Version, b: Version) -> Bool { a.parts.lexicographicallyPrecedes(b.parts) }
    public static func == (a: Version, b: Version) -> Bool { a.parts == b.parts }
    public func hash(into hasher: inout Hasher) { hasher.combine(parts) }
}
