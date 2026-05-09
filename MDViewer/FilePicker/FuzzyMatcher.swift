import Foundation

struct FuzzyScore {
    let score: Int
    let matchedIndices: [Int]
}

enum FuzzyMatcher {
    /// Returns a relevance score and matched character indices if every character
    /// in `query` can be matched in order within `text`. Returns `nil` if the query
    /// cannot be matched.
    static func score(_ query: String, against text: String) -> FuzzyScore? {
        let queryChars = Array(query)
        let textChars = Array(text)

        guard !queryChars.isEmpty else {
            return FuzzyScore(score: 0, matchedIndices: [])
        }

        var queryIndex = 0
        var matchedIndices: [Int] = []
        var score = 0
        var lastMatchedIndex: Int? = nil
        var currentRunLength = 0

        let wordBoundaryChars: Set<Character> = ["/", "-", "_", ".", " "]

        for (textIndex, textChar) in textChars.enumerated() {
            guard queryIndex < queryChars.count else { break }
            let queryChar = queryChars[queryIndex]

            if textChar.lowercased() == queryChar.lowercased() {
                matchedIndices.append(textIndex)

                // Base match
                score += 10

                // Consecutive bonus
                if let last = lastMatchedIndex, textIndex == last + 1 {
                    currentRunLength += 1
                    score += 15 + (5 * max(0, currentRunLength - 2))
                } else {
                    currentRunLength = 1
                }

                // Start-of-word bonus
                if textIndex == 0 || wordBoundaryChars.contains(textChars[textIndex - 1]) {
                    score += 10
                }

                lastMatchedIndex = textIndex
                queryIndex += 1
            }
        }

        guard queryIndex == queryChars.count else { return nil }

        // Exact substring bonus (case-insensitive)
        let textLower = text.lowercased()
        let queryLower = query.lowercased()
        if textLower.range(of: queryLower) != nil {
            score += 50
        }

        // Case-sensitive exact match bonus
        if text.contains(query) {
            score += 20
        }

        // Length penalty
        score -= textChars.count

        score = max(0, score)

        return FuzzyScore(score: score, matchedIndices: matchedIndices)
    }
}
