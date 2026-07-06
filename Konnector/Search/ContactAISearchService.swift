import Foundation
import NaturalLanguage

enum ContactAISearchService {
    struct Match: Identifiable, Equatable {
        let contact: ContactSnapshot
        let score: Double
        let matchedTerms: [String]

        var id: String { contact.sourceIdentifier }
    }

    private static let stopWords: Set<String> = [
        "a", "an", "the", "who", "someone", "somebody", "person", "people", "with", "in", "at", "from",
        "works", "work", "worked", "working", "is", "are", "was", "were", "has", "have", "had", "that", "this",
        "looking", "for", "find", "me", "my", "i", "want", "need", "and", "or", "of", "to", "on", "about",
        "company", "companies"
    ]

    private static let aliasGroups: [[String]] = [
        ["uk", "united", "kingdom", "britain", "british", "england"],
        ["usa", "us", "united", "states", "america", "american"],
        ["ceo", "chief", "executive", "officer"],
        ["dev", "developer", "engineer", "engineering", "software"],
        ["math", "mathematician", "mathematics"],
        ["science", "scientist", "scientific"],
        ["author", "writer", "writing"],
        ["physicist", "physics", "radium"],
        ["cryptography", "cryptographer", "bletchley", "codebreaking"]
    ]

    private static let minimumScore = 1.5

    static func search(
        contacts: [ContactSnapshot],
        badgeCatalog: [BadgeDefinition],
        query: String
    ) -> [Match] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }

        let normalizedQuery = normalize(trimmedQuery)
        let queryTokens = tokens(in: normalizedQuery)
        guard !queryTokens.isEmpty else { return [] }

        let embedding = NLEmbedding.wordEmbedding(for: .english)

        return contacts
            .map { contact in
                score(
                    contact: contact,
                    badgeCatalog: badgeCatalog,
                    normalizedQuery: normalizedQuery,
                    queryTokens: queryTokens,
                    embedding: embedding
                )
            }
            .filter { $0.score >= minimumScore }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.contact.sortName.localizedCaseInsensitiveCompare(rhs.contact.sortName) == .orderedAscending
                }
                return lhs.score > rhs.score
            }
    }

    private static func score(
        contact: ContactSnapshot,
        badgeCatalog: [BadgeDefinition],
        normalizedQuery: String,
        queryTokens: [String],
        embedding: NLEmbedding?
    ) -> Match {
        let corpus = normalize(contact.aiSearchableText(badgeCatalog: badgeCatalog))
        let corpusTokens = tokens(in: corpus)
        var score = 0.0
        var matchedTerms: [String] = []

        if corpus.contains(normalizedQuery) {
            score += 15
            matchedTerms.append(trimmedDisplayTerm(from: normalizedQuery))
        }

        for token in queryTokens {
            if corpusTokens.contains(token) {
                score += 3
                appendMatch(token, to: &matchedTerms)
                continue
            }

            if corpus.contains(token) {
                score += 2
                appendMatch(token, to: &matchedTerms)
                continue
            }

            if let aliasScore = aliasMatchScore(for: token, in: corpusTokens) {
                score += aliasScore.score
                appendMatch(aliasScore.term, to: &matchedTerms)
                continue
            }

            if let semanticMatch = bestSemanticMatch(for: token, in: corpusTokens, embedding: embedding) {
                score += semanticMatch.score
                appendMatch(semanticMatch.term, to: &matchedTerms)
            }
        }

        return Match(contact: contact, score: score, matchedTerms: matchedTerms)
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func tokens(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var results: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range])
            guard token.count >= 2, !stopWords.contains(token) else { return true }
            results.append(token)
            return true
        }
        return results
    }

    private static func bestSemanticMatch(
        for queryToken: String,
        in corpusTokens: [String],
        embedding: NLEmbedding?
    ) -> (term: String, score: Double)? {
        guard let embedding else { return nil }

        var best: (term: String, score: Double)?

        for corpusToken in corpusTokens {
            let distance = embedding.distance(between: queryToken, and: corpusToken)
            guard distance.isFinite, distance < 0.95 else { continue }

            let semanticScore = (0.95 - distance) * 4
            guard semanticScore >= 1.0 else { continue }
            if best == nil || semanticScore > best!.score {
                best = (corpusToken, semanticScore)
            }
        }

        return best
    }

    private static func aliasMatchScore(for queryToken: String, in corpusTokens: [String]) -> (term: String, score: Double)? {
        guard let aliases = aliasGroups.first(where: { $0.contains(queryToken) }) else { return nil }

        for corpusToken in corpusTokens where aliases.contains(corpusToken) {
            return (corpusToken, 2.5)
        }

        return nil
    }

    private static func appendMatch(_ term: String, to matchedTerms: inout [String]) {
        let display = trimmedDisplayTerm(from: term)
        guard !matchedTerms.contains(where: { $0.caseInsensitiveCompare(display) == .orderedSame }) else { return }
        matchedTerms.append(display)
    }

    private static func trimmedDisplayTerm(from term: String) -> String {
        term.prefix(1).uppercased() + term.dropFirst()
    }
}
