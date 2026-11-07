import CardContract
import Testing

@Suite struct VersionTests {
    @Test(arguments: ["1.10.0", "1.1", "26", "0.0.1", "123456789.1"])
    func dottedWholeNumbersParseAndKeepTheirText(text: String) throws {
        let version = try #require(Version(text))
        #expect(version.description == text)
    }

    @Test(arguments: ["1.1.0-beta", "v1.1", "", "1..1", ".1", "1.", "1234567890.1", "1.2.3a", "1 .2", "١.٢", "-1.0"])
    func anythingElseIsNotAVersion(text: String) {
        #expect(Version(text) == nil)
    }

    @Test func partsCompareAsNumbersNotText() throws {
        #expect(try #require(Version("1.9.0")) < Version(1, 10, 0))
        #expect(Version(1, 0, 5) < Version(1, 1))
        #expect(!(Version(2, 0) < Version(1, 99, 99)))
    }

    @Test func aMissingPartCountsAsZeroForEqualityHashingAndOrder() throws {
        let short = try #require(Version("1.1"))
        let long = try #require(Version("1.1.0"))
        #expect(short == long)
        #expect(short.hashValue == long.hashValue)
        #expect(Set([short, long]).count == 1)
        #expect(!(short < long) && !(long < short))
        #expect(short.description == "1.1")
        #expect(long.description == "1.1.0")
        #expect(Version(26, 0) == Version(26))
    }

    @Test func thisMacsVersionBuildsFromParts() {
        #expect(Version(26, 6, 2).description == "26.6.2")
        #expect(Version(26, 6, 2) > Version(26, 6))
    }
}
