import Foundation

public enum YijiDateFormatter {
    private static var usesEnglish: Bool {
        YijiLocalization.isEnglish
    }

    private static var locale: Locale {
        if usesEnglish {
            return Locale(identifier: "en_US")
        }
        if YijiLocalization.isSpanish {
            return Locale(identifier: "es_US")
        }
        if YijiLocalization.isJapanese {
            return Locale(identifier: "ja_JP")
        }
        return Locale(identifier: YijiLocalization.isTraditionalChinese ? "zh_TW" : "zh_CN")
    }

    public static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        if usesEnglish {
            formatter.dateFormat = "MMM d, yyyy"
        } else if YijiLocalization.isSpanish {
            formatter.dateFormat = "d MMM yyyy"
        } else if YijiLocalization.isJapanese {
            formatter.dateFormat = "yyyy年M月d日"
        } else {
            formatter.dateFormat = "yyyy 年 M 月 d 日"
        }
        return formatter
    }

    public static var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        if usesEnglish {
            formatter.dateFormat = "MMM d, h:mm a"
        } else if YijiLocalization.isSpanish {
            formatter.dateFormat = "d MMM, HH:mm"
        } else if YijiLocalization.isJapanese {
            formatter.dateFormat = "M月d日 HH:mm"
        } else {
            formatter.dateFormat = "M 月 d 日 HH:mm"
        }
        return formatter
    }

    public static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = usesEnglish ? "h:mm a" : "HH:mm"
        return formatter
    }
}
