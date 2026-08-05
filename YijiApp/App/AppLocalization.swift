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
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            AppLocalization.text("跟随系统")
        case .simplifiedChinese:
            AppLocalization.text("简体中文")
        case .english:
            "English"
        }
    }

    var locale: Locale {
        Locale(identifier: AppLocalization.languageCode(for: self))
    }
}

enum AppLocalization {
    static let languagePreferenceKey = "yiji.appLanguage"

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

    static var languageCode: String {
        languageCode(for: selectedLanguage)
    }

    static func languageCode(for language: AppLanguage) -> String {
        switch language {
        case .simplifiedChinese:
            return "zh-Hans"
        case .english:
            return "en"
        case .system:
            return Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? "zh-Hans"
        }
    }

    static var speechLocale: Locale {
        if languageCode.lowercased().hasPrefix("en") {
            return Locale(identifier: "en-US")
        }
        return Locale(identifier: "zh-CN")
    }

    static func text(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = text(key)
        return String(format: format, arguments: arguments)
    }

    private static var localizedBundle: Bundle {
        let code = languageCode
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main
        }
        return bundle
    }
}
