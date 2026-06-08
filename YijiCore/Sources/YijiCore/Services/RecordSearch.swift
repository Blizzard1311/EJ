import Foundation

public enum RecordSearch {
    public static func query(_ keyword: String, in records: [Record]) -> [Record] {
        let term = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else {
            return sort(records.map { ($0, 0) }).map(\.0)
        }

        return records
            .compactMap { record in
                let score = score(record: record, query: term)
                guard score > 0 else { return nil }
                return (record, score)
            }
            .let(sort)
            .map(\.0)
    }

    private static func score(record: Record, query: String) -> Int {
        let normalizedQuery = normalize(query)
        let tokens = queryTokens(from: normalizedQuery)

        let content = normalize(record.content)
        let objectName = normalize(record.objectName ?? "")
        let location = normalize(record.location ?? "")
        let category = normalize(record.category.displayName)
        let tags = normalize(record.tags.joined(separator: " "))
        let searchable = [content, objectName, location, category, tags].joined(separator: " ")

        var score = 0

        if searchable.localizedCaseInsensitiveContains(normalizedQuery) {
            score += 2
        }

        for token in tokens {
            if objectName.localizedCaseInsensitiveContains(token) {
                score += 5
            }
            if location.localizedCaseInsensitiveContains(token) {
                score += 4
            }
            if tags.localizedCaseInsensitiveContains(token) {
                score += 3
            }
            if content.localizedCaseInsensitiveContains(token) {
                score += 2
            }
            if category.localizedCaseInsensitiveContains(token) {
                score += 1
            }
        }

        return score
    }

    private static func queryTokens(from normalizedQuery: String) -> [String] {
        let stripped = commonQueryPhrases.reduce(normalizedQuery) { partial, phrase in
            partial.replacingOccurrences(of: phrase, with: " ")
        }

        let tokens = stripped
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        if tokens.isEmpty {
            return normalizedQuery.isEmpty ? [] : [normalizedQuery]
        }

        return tokens
    }

    private static func normalize(_ text: String) -> String {
        let punctuation = CharacterSet(charactersIn: "，。！？；：、,.!?;:")
        return text
            .lowercased()
            .components(separatedBy: punctuation)
            .joined(separator: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sort(_ scored: [(Record, Int)]) -> [(Record, Int)] {
        scored.sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                if lhs.0.recordDate == rhs.0.recordDate {
                    return lhs.0.createdAt > rhs.0.createdAt
                }
                return lhs.0.recordDate > rhs.0.recordDate
            }
            return lhs.1 > rhs.1
        }
    }
}

private let commonQueryPhrases = [
    "帮我找",
    "我想找",
    "查一下",
    "查找",
    "搜索",
    "看看",
    "哪里",
    "在哪儿",
    "在哪",
    "放哪了",
    "放哪",
    "放在",
    "有没有",
    "记录过",
    "记得",
    "请问"
]

private extension Array {
    func `let`<Result>(_ transform: ([Element]) -> Result) -> Result {
        transform(self)
    }
}
