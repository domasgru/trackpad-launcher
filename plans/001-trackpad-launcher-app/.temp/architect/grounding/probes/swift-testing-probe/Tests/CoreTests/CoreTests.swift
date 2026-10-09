import Testing
@testable import Core
@Test func adds() { #expect(Core.add(1, 2) == 3) }
@Test(arguments: [1, 2]) func parameterised(n: Int) { #expect(n > 0) }
