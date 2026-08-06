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
        let category = normalize(record.displayCategoryName)
        let storageContainer = normalize(record.resolvedStorageContainer?.displayName ?? "")
        let sliceCategories = normalize(record.sliceCategoryNames.joined(separator: " "))
        let tags = normalize(record.tags.joined(separator: " "))
        let searchable = [content, objectName, location, category, storageContainer, sliceCategories, tags].joined(separator: " ")

        var score = 0

        if searchable.localizedCaseInsensitiveContains(normalizedQuery) {
            score += 2
        }

        for token in tokens {
            score += weightedMatchScore(token: token, target: objectName, directScore: 5, inverseScore: 4)
            score += weightedMatchScore(token: token, target: location, directScore: 4, inverseScore: 3)
            score += weightedMatchScore(token: token, target: storageContainer, directScore: 4, inverseScore: 3)
            score += weightedMatchScore(token: token, target: sliceCategories, directScore: 4, inverseScore: 3)
            score += weightedMatchScore(token: token, target: tags, directScore: 3, inverseScore: 2)
            score += weightedMatchScore(token: token, target: content, directScore: 2, inverseScore: 1)
            score += weightedMatchScore(token: token, target: category, directScore: 1, inverseScore: 1)
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

    private static func weightedMatchScore(
        token: String,
        target: String,
        directScore: Int,
        inverseScore: Int
    ) -> Int {
        guard !token.isEmpty, !target.isEmpty else {
            return 0
        }

        if target.localizedCaseInsensitiveContains(token) {
            return directScore
        }

        guard token.count >= 2, token.localizedCaseInsensitiveContains(target) else {
            return 0
        }

        return inverseScore
    }
}

private let commonQueryPhrases = [
    "请帮我找一下",
    "帮我找一下",
    "帮我查一下",
    "在什么地方",
    "在哪个位置",
    "在哪个地方",
    "在哪里",
    "在哪儿",
    "在哪呢",
    "帮我找",
    "我想找",
    "查一下",
    "查找",
    "搜索",
    "告诉我",
    "看看",
    "一下",
    "我的",
    "哪里",
    "在哪",
    "放哪了",
    "放哪",
    "放在",
    "有没有",
    "记录过",
    "记得",
    "请问"
    ,"dónde está"
    ,"donde está"
    ,"donde esta"
    ,"dónde guardé"
    ,"donde guardé"
    ,"donde guarde"
    ,"búscame"
    ,"buscame"
    ,"encuéntrame"
    ,"encuentrame"
    ,"どこにある"
    ,"どこに置いた"
    ,"どこ"
    ,"探して"
    ,"検索して"
]

private extension Array {
    func `let`<Result>(_ transform: ([Element]) -> Result) -> Result {
        transform(self)
    }
}
