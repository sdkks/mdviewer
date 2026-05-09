import XCTest
@testable import MDViewer

final class FuzzyMatcherTests: XCTestCase {
    func testExactSubstringMatch() {
        let result = FuzzyMatcher.score("readme", against: "README.md")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchedIndices, [0, 1, 2, 3, 4, 5])
        XCTAssertGreaterThan(result!.score, 0)
    }

    func testDiscontiguousMatch() {
        // "README.md" → R(0) E(1) A(2) D(3) M(4) E(5) .(6) m(7) d(8)
        // Query "rdm" matches R(0), D(3), M(4)
        let result = FuzzyMatcher.score("rdm", against: "README.md")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.matchedIndices, [0, 3, 4])
        XCTAssertGreaterThan(result!.score, 0)
    }

    func testPathFuzzyMatch() {
        // "examples/readme.md" → e(0) x(1) a(2) m(3) p(4) l(5) e(6) s(7) /(8) r(9) e(10) a(11) d(12) m(13) e(14)
        // Query "exrs" → e(0), x(1), r(9), but no s after index 9, so nil
        let result = FuzzyMatcher.score("exrs", against: "examples/readme.md")
        XCTAssertNil(result)
    }

    func testCaseSensitivityBonus() {
        let lower = FuzzyMatcher.score("readme", against: "readme.md")!
        let mixed = FuzzyMatcher.score("readme", against: "README.md")!
        // Both match, case-sensitive exact gives +20 bonus to the lower-cased text
        XCTAssertEqual(lower.score - mixed.score, 20)
    }

    func testWordBoundaryBonus() {
        let result = FuzzyMatcher.score("r", against: "/readme.md")!
        // 'r' at index 1 follows '/' (word boundary) → +10 bonus
        XCTAssertEqual(result.matchedIndices, [1])
        XCTAssertGreaterThan(result.score, 10)
    }

    func testConsecutiveBonus() {
        let single = FuzzyMatcher.score("a", against: "abc")!
        let double = FuzzyMatcher.score("ab", against: "abc")!
        let triple = FuzzyMatcher.score("abc", against: "abc")!
        // Consecutive matches should yield progressively higher scores
        XCTAssertGreaterThan(double.score, single.score)
        XCTAssertGreaterThan(triple.score, double.score)
    }

    func testLengthPenalty() {
        let short = FuzzyMatcher.score("ab", against: "ab.md")!
        let long = FuzzyMatcher.score("ab", against: "abcdefgh.md")!
        // Same query, shorter text should score higher
        XCTAssertGreaterThan(short.score, long.score)
    }

    func testNoMatchReturnsNil() {
        let result = FuzzyMatcher.score("xyz", against: "abc.md")
        XCTAssertNil(result)
    }

    func testEmptyQuery() {
        let result = FuzzyMatcher.score("", against: "README.md")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.score, 0)
        XCTAssertTrue(result?.matchedIndices.isEmpty ?? false)
    }

    func testSortingOrder() {
        let candidates = [
            ("readme.md", 0),
            ("src/readme.md", 0),
            ("changelog.md", 0)
        ]
        var scored: [(String, Int)] = []
        for (name, _) in candidates {
            if let r = FuzzyMatcher.score("readme", against: name) {
                scored.append((name, r.score))
            }
        }
        scored.sort { $0.1 > $1.1 }
        // Exact case-sensitive match should rank highest
        XCTAssertEqual(scored[0].0, "readme.md")
    }
}
