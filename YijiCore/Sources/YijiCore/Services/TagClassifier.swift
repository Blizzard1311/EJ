import Foundation

public enum TagClassifier {
    public static func tags(for content: String, objectName: String?) -> [String] {
        let text = [content, objectName].compactMap { $0 }.joined(separator: " ")
        var tags: [String] = []

        let rules: [(String, String)] = [
            ("证件", "证件"),
            ("身份证", "证件"),
            ("户口本", "证件"),
            ("护照", "证件"),
            ("银行卡", "财务"),
            ("发票", "财务"),
            ("药", "健康"),
            ("医院", "健康"),
            ("快递", "购物"),
            ("材料", "家庭事务")
        ]

        for (keyword, tag) in rules where text.contains(keyword) && !tags.contains(tag) {
            tags.append(tag)
        }

        return tags
    }
}
