import Foundation

enum YijiLocalization {
    private static let languagePreferenceKey = "yiji.appLanguage"

    static var isEnglish: Bool {
        guard Bundle.main.bundleIdentifier == "com.blizzard1311.yiji" else {
            return false
        }
        return languageCode.lowercased().hasPrefix("en")
    }

    static var isTraditionalChinese: Bool {
        guard Bundle.main.bundleIdentifier == "com.blizzard1311.yiji" else {
            return false
        }
        let code = languageCode.lowercased()
        return code.hasPrefix("zh-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") || code.hasPrefix("zh-mo")
    }

    static var isSpanish: Bool {
        guard Bundle.main.bundleIdentifier == "com.blizzard1311.yiji" else {
            return false
        }
        return languageCode.lowercased().hasPrefix("es")
    }

    static var isJapanese: Bool {
        guard Bundle.main.bundleIdentifier == "com.blizzard1311.yiji" else {
            return false
        }
        return languageCode.lowercased().hasPrefix("ja")
    }

    static func text(_ key: String) -> String {
        let localized = localizedBundle.localizedString(forKey: key, value: key, table: nil)
        if localized != key {
            return localized
        }
        return simplifiedChineseFallbacks[key] ?? key
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, arguments: arguments)
    }

    private static let simplifiedChineseFallbacks: [String: String] = [
        "record.answer.storage": "你在 %@ 记录过：%@ 放在 %@。",
        "record.answer.event": "你记录过一项时间相关内容：%@，%@。",
        "record.answer.note": "你在 %@ 记录过：%@。",
        "date.range": "%@ 至 %@",
        "date.month": "%1$ld 年 %2$ld 月",
        "date.year_period": "%1$ld 年%2$@",
        "date.year": "%ld 年",
        "timeline.none": "%@%@暂时没有找到已记录的计划或安排。",
        "timeline.one": "%@%@你有 1 项安排：%@。",
        "timeline.many": "%@%@你有 %ld 项安排，已按时间排好。",
        "timeline.category": " 的%@事项里，"
    ]

    private static var languageCode: String {
        if let storedLanguage = UserDefaults.standard.string(forKey: languagePreferenceKey) {
            if storedLanguage == "en" {
                return "en"
            }
            if storedLanguage == "zh-Hant" {
                return "zh-Hant"
            }
            if storedLanguage == "zh-Hans" {
                return "zh-Hans"
            }
            if storedLanguage == "es" {
                return "es"
            }
            if storedLanguage == "ja" {
                return "ja"
            }
        }
        return Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "zh-Hans"
    }

    private static var localizedBundle: Bundle {
        let rawCode = languageCode.lowercased()
        let resourceCode: String
        if rawCode.hasPrefix("zh-hant") || rawCode.hasPrefix("zh-tw") || rawCode.hasPrefix("zh-hk") || rawCode.hasPrefix("zh-mo") {
            resourceCode = "zh-Hant"
        } else if rawCode.hasPrefix("en") {
            resourceCode = "en"
        } else if rawCode.hasPrefix("es") {
            resourceCode = "es"
        } else if rawCode.hasPrefix("ja") {
            resourceCode = "ja"
        } else {
            resourceCode = "zh-Hans"
        }
        guard Bundle.main.bundleIdentifier == "com.blizzard1311.yiji",
              let path = Bundle.main.path(forResource: resourceCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
}
