import Foundation

public enum SearchIntentClassifier {
    public static func isSearchQuery(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        if trimmed.contains("?") || trimmed.contains("？") {
            return true
        }

        let normalized = normalize(trimmed)
        return queryPhrases.contains { normalized.contains($0) }
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
}

private let queryPhrases = [
    "帮我找一下",
    "帮我找",
    "帮我查一下",
    "帮我查",
    "我想找",
    "查一下",
    "查找",
    "搜索",
    "看看",
    "告诉我",
    "在哪里",
    "在哪儿",
    "在哪呢",
    "在哪个位置",
    "在哪个地方",
    "在哪",
    "哪里",
    "放哪了",
    "放哪",
    "有没有",
    "有哪些",
    "有什么",
    "列出",
    "帮我看",
    "帮我列"
]
