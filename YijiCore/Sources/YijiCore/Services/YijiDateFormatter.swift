import Foundation

public enum YijiDateFormatter {
    private static var usesEnglish: Bool {
        YijiLocalization.isEnglish
    }

    public static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: usesEnglish ? "en_US" : "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = usesEnglish ? "MMM d, yyyy" : "yyyy 年 M 月 d 日"
        return formatter
    }

    public static var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: usesEnglish ? "en_US" : "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = usesEnglish ? "MMM d, h:mm a" : "M 月 d 日 HH:mm"
        return formatter
    }

    public static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: usesEnglish ? "en_US" : "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = usesEnglish ? "h:mm a" : "HH:mm"
        return formatter
    }
}
