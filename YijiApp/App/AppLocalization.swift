import Foundation

enum AppReleaseConfiguration {
    private static let cloudSyncInfoKey = "YijiCloudSyncEnabled"

    static var cloudSyncEnabled: Bool {
        if let configuredValue = Bundle.main.object(forInfoDictionaryKey: cloudSyncInfoKey) as? Bool {
            return configuredValue
        }
        if let configuredValue = Bundle.main.object(forInfoDictionaryKey: cloudSyncInfoKey) as? String {
            return NSString(string: configuredValue).boolValue
        }

#if DEBUG
        return true
#else
        return false
#endif
    }
}

enum AppSupport {
    static let email = "zl.kenneth@gmail.com"
    static let emailURL = URL(string: "mailto:\(email)")!
    static let privacyURL = URL(string: "https://blizzard1311.github.io/EJ/privacy.html")!
    static let supportURL = URL(string: "https://blizzard1311.github.io/EJ/support.html")!
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case english = "en"
    case spanish = "es"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            AppLocalization.text("跟随系统")
        case .simplifiedChinese:
            AppLocalization.text("简体中文")
        case .traditionalChinese:
            AppLocalization.text("繁体中文")
        case .english:
            "English"
        case .spanish:
            "Español"
        case .japanese:
            "日本語"
        }
    }

    var locale: Locale {
        Locale(identifier: AppLocalization.languageCode(for: self))
    }
}

enum SpeechLanguage: String, CaseIterable, Identifiable {
    case automatic
    case mandarinChina = "zh-CN"
    case mandarinTaiwan = "zh-TW"
    case englishUnitedStates = "en-US"
    case spanishUnitedStates = "es-US"
    case spanishMexico = "es-MX"
    case spanishSpain = "es-ES"
    case japaneseJapan = "ja-JP"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic:
            AppLocalization.text("跟随 App 语言")
        case .mandarinChina:
            AppLocalization.text("普通话（中国大陆）")
        case .mandarinTaiwan:
            AppLocalization.text("中文（台湾）")
        case .englishUnitedStates:
            "English (U.S.)"
        case .spanishUnitedStates:
            "Español (EE. UU.)"
        case .spanishMexico:
            "Español (México)"
        case .spanishSpain:
            "Español (España)"
        case .japaneseJapan:
            "日本語（日本）"
        }
    }
}

enum AppLocalization {
    static let languagePreferenceKey = "yiji.appLanguage"
    static let speechLanguagePreferenceKey = "yiji.speechLanguage"

    static var selectedLanguage: AppLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: languagePreferenceKey),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .system
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languagePreferenceKey)
        }
    }

    static var selectedSpeechLanguage: SpeechLanguage {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: speechLanguagePreferenceKey),
                  let language = SpeechLanguage(rawValue: rawValue) else {
                return .automatic
            }
            return language
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: speechLanguagePreferenceKey)
        }
    }

    static var languageCode: String {
        languageCode(for: selectedLanguage)
    }

    static func languageCode(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        case .english:
            return "en"
        case .spanish:
            return "es"
        case .japanese:
            return "ja"
        case .system:
            return Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "zh-Hans"
        }
    }

    static var speechLocale: Locale {
        switch selectedSpeechLanguage {
        case .mandarinChina:
            return Locale(identifier: "zh-CN")
        case .mandarinTaiwan:
            return Locale(identifier: "zh-TW")
        case .englishUnitedStates:
            return Locale(identifier: "en-US")
        case .spanishUnitedStates:
            return Locale(identifier: "es-US")
        case .spanishMexico:
            return Locale(identifier: "es-MX")
        case .spanishSpain:
            return Locale(identifier: "es-ES")
        case .japaneseJapan:
            return Locale(identifier: "ja-JP")
        case .automatic:
            let code = languageCode.lowercased()
            if code.hasPrefix("zh-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") || code.hasPrefix("zh-mo") {
                return Locale(identifier: "zh-TW")
            }
            if code.hasPrefix("en") {
                return Locale(identifier: "en-US")
            }
            if code.hasPrefix("es") {
                return Locale(identifier: "es-US")
            }
            if code.hasPrefix("ja") {
                return Locale(identifier: "ja-JP")
            }
            return Locale(identifier: "zh-CN")
        }
    }

    static func text(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, arguments: arguments)
    }

    private static var localizedBundle: Bundle {
        let rawCode = languageCode.lowercased()
        let code: String
        if rawCode.hasPrefix("zh-hant") || rawCode.hasPrefix("zh-tw") || rawCode.hasPrefix("zh-hk") || rawCode.hasPrefix("zh-mo") {
            code = "zh-Hant"
        } else if rawCode.hasPrefix("en") {
            code = "en"
        } else if rawCode.hasPrefix("es") {
            code = "es"
        } else if rawCode.hasPrefix("ja") {
            code = "ja"
        } else {
            code = "zh-Hans"
        }
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
}
