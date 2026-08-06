import Foundation

struct MultilingualReminderIntent {
    let title: String
    let remindAt: Date?
    let repeatRule: ReminderRepeatRule
    let warning: String?
}

struct MultilingualStorageIntent {
    let objectName: String
    let location: String
}

enum MultilingualInputParser {
    private static let spanishNumberPattern = #"(?:\d{1,4}|un|una|uno|dos|tres|cuatro|cinco|seis|siete|ocho|nueve|diez|once|doce|trece|catorce|quince|diecis[eé]is|diecisiete|dieciocho|diecinueve|veinte|veintiuno|veintid[oó]s|veintitr[eé]s|veinticuatro|veinticinco|veintis[eé]is|veintisiete|veintiocho|veintinueve|treinta|treinta\s+y\s+uno)"#
    private static let japaneseNumberPattern = #"[\d一二三四五六七八九十]{1,4}"#

    static func parseReminder(
        content: String,
        now: Date,
        calendar: Calendar
    ) -> MultilingualReminderIntent? {
        if isSpanishReminder(content) {
            let title = spanishReminderTitle(content)
            let remindAt = parseSpanishDate(content, now: now, calendar: calendar)
            return MultilingualReminderIntent(
                title: title.isEmpty ? content : title,
                remindAt: remindAt,
                repeatRule: spanishRepeatRule(content),
                warning: remindAt == nil
                    ? "Se detectó un recordatorio, pero falta una fecha u hora válida."
                    : nil
            )
        }

        if isJapaneseReminder(content) {
            let title = japaneseReminderTitle(content)
            let remindAt = parseJapaneseDate(content, now: now, calendar: calendar)
            return MultilingualReminderIntent(
                title: title.isEmpty ? content : title,
                remindAt: remindAt,
                repeatRule: japaneseRepeatRule(content),
                warning: remindAt == nil
                    ? "リマインダーを認識しましたが、有効な日時が見つかりません。"
                    : nil
            )
        }

        return nil
    }

    static func parseStorage(content: String) -> MultilingualStorageIntent? {
        let spanishPatterns = [
            #"^(?:yo\s+)?(?:puse|coloqu[eé]|guard[eé]|dej[eé]|met[ií])\s+(?:(?:el|la|los|las|mi|mis)\s+)?(.+?)\s+(?:en|dentro\s+de)\s+(?:(?:el|la|los|las)\s+)?(.+)$"#,
            #"^(?:(?:el|la|los|las|mi|mis)\s+)?(.+?)\s+(?:est[aá]|se\s+encuentra)\s+(?:en|dentro\s+de)\s+(?:(?:el|la|los|las)\s+)?(.+)$"#
        ]
        for pattern in spanishPatterns {
            if let result = firstMatch(pattern, in: content, options: [.caseInsensitive]), result.count >= 3 {
                let objectName = clean(result[1])
                let location = clean(result[2])
                if !objectName.isEmpty, !location.isEmpty {
                    return MultilingualStorageIntent(objectName: objectName, location: location)
                }
            }
        }

        let japanesePatterns = [
            #"^(.+?)(?:を|は)(.+?)(?:に|へ)(?:入れた|しまった|置いた|保管した|収納した|入れてある|置いてある|入っている|保管している)$"#,
            #"^(.+?)は(.+?)(?:にある|に置いてある|に入っている|で保管している)$"#
        ]
        for pattern in japanesePatterns {
            if let result = firstMatch(pattern, in: content), result.count >= 3 {
                let objectName = clean(result[1])
                let location = clean(result[2])
                if !objectName.isEmpty, !location.isEmpty {
                    return MultilingualStorageIntent(objectName: objectName, location: location)
                }
            }
        }

        return nil
    }

    private static func isSpanishReminder(_ content: String) -> Bool {
        firstMatch(#"\b(?:recu[eé]rdame|recordarme|av[ií]same|avisarme)\b"#, in: content, options: [.caseInsensitive]) != nil
    }

    private static func isJapaneseReminder(_ content: String) -> Bool {
        ["リマインドして", "リマインダーを設定", "思い出させて", "通知して", "知らせて"].contains(where: content.contains)
    }

    private static func spanishRepeatRule(_ content: String) -> ReminderRepeatRule {
        let normalized = content.lowercased()
        if matches(#"\b(?:todos\s+los\s+d[ií]as|cada\s+d[ií]a|diariamente)\b"#, normalized) { return .daily }
        if matches(#"\b(?:cada\s+semana|semanalmente)\b"#, normalized) { return .weekly }
        if matches(#"\b(?:cada\s+mes|mensualmente)\b"#, normalized) { return .monthly }
        if matches(#"\b(?:cada\s+a[nñ]o|anualmente)\b"#, normalized) { return .yearly }
        return .none
    }

    private static func japaneseRepeatRule(_ content: String) -> ReminderRepeatRule {
        if content.contains("毎日") { return .daily }
        if content.contains("毎週") { return .weekly }
        if content.contains("毎月") { return .monthly }
        if content.contains("毎年") { return .yearly }
        return .none
    }

    private static func parseSpanishDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        if let duration = spanishRelativeDuration(content, now: now, calendar: calendar) { return duration }
        if let explicit = spanishExplicitDate(content, now: now, calendar: calendar) { return explicit }
        if let monthly = spanishMonthlyDate(content, now: now, calendar: calendar) { return monthly }
        if let weekday = spanishWeekdayDate(content, now: now, calendar: calendar) { return weekday }

        let normalized = content.lowercased()
        if spanishRepeatRule(content) == .daily {
            return nextOccurrence(of: spanishTime(content) ?? (9, 0), now: now, calendar: calendar)
        }

        let withoutMorningPhrase = replacing(
            #"\b(?:por|de)\s+la\s+ma[nñ]ana\b"#,
            in: normalized,
            with: ""
        )
        let dayOffset: Int?
        if matches(#"\bpasado\s+ma[nñ]ana\b"#, normalized) {
            dayOffset = 2
        } else if matches(#"\bma[nñ]ana\b"#, withoutMorningPhrase) {
            dayOffset = 1
        } else if matches(#"\bhoy\b|\besta\s+noche\b"#, normalized) {
            dayOffset = 0
        } else {
            dayOffset = nil
        }

        if let dayOffset {
            return date(
                dayOffset: dayOffset,
                time: spanishTime(content) ?? spanishDefaultTime(content),
                now: now,
                calendar: calendar
            )
        }

        guard let time = spanishTime(content) else { return nil }
        return nextOccurrence(of: time, now: now, calendar: calendar)
    }

    private static func spanishRelativeDuration(_ content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(
            #"\b(?:en|dentro\s+de)\s+("# + spanishNumberPattern + #")\s*(minutos?|horas?|d[ií]as?|semanas?)\b"#,
            in: content,
            options: [.caseInsensitive]
        ), result.count >= 3, let amount = spanishNumber(result[1]), amount > 0 else {
            return nil
        }

        let unit = result[2].lowercased()
        let component: Calendar.Component
        if unit.hasPrefix("minuto") { component = .minute }
        else if unit.hasPrefix("hora") { component = .hour }
        else if unit.hasPrefix("d") { component = .day }
        else { component = .weekOfYear }
        return calendar.date(byAdding: component, value: amount, to: now)
    }

    private static func spanishExplicitDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        let monthPattern = "enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre"
        guard let result = firstMatch(
            #"\b(?:el\s+)?("# + spanishNumberPattern + #")\s+de\s+("# + monthPattern + #")(?:\s+de\s+(\d{4}))?\b"#,
            in: content,
            options: [.caseInsensitive]
        ), result.count >= 4, let day = spanishNumber(result[1]), let month = spanishMonth(result[2]) else {
            return nil
        }

        let explicitYear = Int(result[3])
        let year = explicitYear ?? calendar.component(.year, from: now)
        guard var candidate = makeDate(
            year: year,
            month: month,
            day: day,
            time: spanishTime(content) ?? spanishDefaultTime(content),
            calendar: calendar
        ) else { return nil }
        if explicitYear == nil, candidate < now {
            candidate = calendar.date(byAdding: .year, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func spanishMonthlyDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(
            #"\b(?:cada\s+mes|mensualmente)(?:\s+el)?\s+("# + spanishNumberPattern + #")(?:\s+de\s+cada\s+mes)?\b"#,
            in: content,
            options: [.caseInsensitive]
        ), result.count >= 2, let day = spanishNumber(result[1]) else { return nil }

        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        let time = spanishTime(content) ?? spanishDefaultTime(content)
        components.hour = time.0
        components.minute = time.1
        guard let candidate = calendar.date(from: components) else { return nil }
        return candidate >= now ? candidate : calendar.date(byAdding: .month, value: 1, to: candidate)
    }

    private static func spanishWeekdayDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        let weekdays = "lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo"
        guard let result = firstMatch(
            #"\b(?:(pr[oó]ximo|este)\s+)?("# + weekdays + #")\b"#,
            in: content,
            options: [.caseInsensitive]
        ), result.count >= 3 else { return nil }

        let weekdayText = result[2].lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
        let offsets = ["lunes": 0, "martes": 1, "miercoles": 2, "jueves": 3, "viernes": 4, "sabado": 5, "domingo": 6]
        guard let weekdayOffset = offsets[weekdayText] else { return nil }
        let weekStart = startOfWeek(now, calendar: calendar)
        var target = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart) ?? weekStart
        let time = spanishTime(content) ?? spanishDefaultTime(content)
        target = applying(time: time, to: target, calendar: calendar) ?? target
        if !result[1].isEmpty || target <= now {
            target = calendar.date(byAdding: .day, value: 7, to: target) ?? target
        }
        return target
    }

    private static func spanishTime(_ content: String) -> (Int, Int)? {
        let patterns = [
            #"\ba\s+la(?:s)?\s+("# + spanishNumberPattern + #")(?::(\d{2}))?\s*(de\s+la\s+ma[nñ]ana|de\s+la\s+tarde|de\s+la\s+noche|a\.?\s*m\.?|p\.?\s*m\.?)?"#,
            #"\b(\d{1,2}):(\d{2})\s*(a\.?\s*m\.?|p\.?\s*m\.?)?"#,
            #"\b("# + spanishNumberPattern + #")\s*()\s*(a\.?\s*m\.?|p\.?\s*m\.?)\b"#
        ]
        for pattern in patterns {
            guard let result = firstMatch(pattern, in: content, options: [.caseInsensitive]), result.count >= 4,
                  var hour = spanishNumber(result[1]) else { continue }
            let minute = Int(result[2]) ?? 0
            let meridiem = result[3].lowercased()
            if meridiem.contains("tarde") || meridiem.contains("noche") || meridiem.contains("p") {
                if hour < 12 { hour += 12 }
            } else if meridiem.contains("mañana") || meridiem.contains("manana") || meridiem.contains("a") {
                if hour == 12 { hour = 0 }
            }
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return (hour, minute)
        }
        return nil
    }

    private static func spanishDefaultTime(_ content: String) -> (Int, Int) {
        let normalized = content.lowercased()
        if normalized.contains("noche") { return (20, 0) }
        if normalized.contains("tarde") { return (15, 0) }
        if normalized.contains("mediodía") || normalized.contains("mediodia") { return (12, 0) }
        return (9, 0)
    }

    private static func parseJapaneseDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        if let duration = japaneseRelativeDuration(content, now: now, calendar: calendar) { return duration }
        if let explicit = japaneseExplicitDate(content, now: now, calendar: calendar) { return explicit }
        if let monthly = japaneseMonthlyDate(content, now: now, calendar: calendar) { return monthly }
        if let weekday = japaneseWeekdayDate(content, now: now, calendar: calendar) { return weekday }
        if japaneseRepeatRule(content) == .daily {
            return nextOccurrence(of: japaneseTime(content) ?? (9, 0), now: now, calendar: calendar)
        }

        let dayOffset: Int?
        if content.contains("明後日") { dayOffset = 2 }
        else if content.contains("明日") || content.contains("明朝") { dayOffset = 1 }
        else if content.contains("今日") || content.contains("今夜") || content.contains("今朝") { dayOffset = 0 }
        else { dayOffset = nil }

        if let dayOffset {
            return date(
                dayOffset: dayOffset,
                time: japaneseTime(content) ?? japaneseDefaultTime(content),
                now: now,
                calendar: calendar
            )
        }
        guard let time = japaneseTime(content) else { return nil }
        return nextOccurrence(of: time, now: now, calendar: calendar)
    }

    private static func japaneseRelativeDuration(_ content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch("(" + japaneseNumberPattern + #")\s*(分|時間|日|週間)後"#, in: content),
              result.count >= 3, let amount = japaneseNumber(result[1]), amount > 0 else { return nil }
        let component: Calendar.Component
        switch result[2] {
        case "分": component = .minute
        case "時間": component = .hour
        case "日": component = .day
        default: component = .weekOfYear
        }
        return calendar.date(byAdding: component, value: amount, to: now)
    }

    private static func japaneseExplicitDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(#"(?:(\d{4})年)?\s*("# + japaneseNumberPattern + #")月\s*("# + japaneseNumberPattern + #")日"#, in: content),
              result.count >= 4, let month = japaneseNumber(result[2]), let day = japaneseNumber(result[3]) else { return nil }
        let explicitYear = Int(result[1])
        let year = explicitYear ?? calendar.component(.year, from: now)
        guard var candidate = makeDate(
            year: year,
            month: month,
            day: day,
            time: japaneseTime(content) ?? japaneseDefaultTime(content),
            calendar: calendar
        ) else { return nil }
        if explicitYear == nil, candidate < now {
            candidate = calendar.date(byAdding: .year, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static func japaneseMonthlyDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch("毎月\\s*(" + japaneseNumberPattern + ")日", in: content), result.count >= 2,
              let day = japaneseNumber(result[1]) else { return nil }
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        let time = japaneseTime(content) ?? japaneseDefaultTime(content)
        components.hour = time.0
        components.minute = time.1
        guard let candidate = calendar.date(from: components) else { return nil }
        return candidate >= now ? candidate : calendar.date(byAdding: .month, value: 1, to: candidate)
    }

    private static func japaneseWeekdayDate(_ content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(#"(?:(再来週|来週|今週)の?)?([月火水木金土日])曜日"#, in: content),
              result.count >= 3 else { return nil }
        let offsets = ["月": 0, "火": 1, "水": 2, "木": 3, "金": 4, "土": 5, "日": 6]
        guard let weekdayOffset = offsets[result[2]] else { return nil }
        let explicitWeekOffset: Int? = switch result[1] {
        case "今週": 0
        case "来週": 1
        case "再来週": 2
        default: nil
        }
        let weekStart = startOfWeek(now, calendar: calendar)
        var target = calendar.date(byAdding: .day, value: weekdayOffset + (explicitWeekOffset ?? 0) * 7, to: weekStart) ?? weekStart
        target = applying(time: japaneseTime(content) ?? japaneseDefaultTime(content), to: target, calendar: calendar) ?? target
        if explicitWeekOffset == nil, target <= now {
            target = calendar.date(byAdding: .day, value: 7, to: target) ?? target
        }
        return target
    }

    private static func japaneseTime(_ content: String) -> (Int, Int)? {
        if content.contains("正午") { return (12, 0) }
        if content.contains("午前0時") || content.contains("深夜0時") { return (0, 0) }

        if let result = firstMatch(#"(?:(午前|午後|夜|朝)\s*)?("# + japaneseNumberPattern + #")時(?:("# + japaneseNumberPattern + #")分|(半))?"#, in: content),
           result.count >= 5, var hour = japaneseNumber(result[2]) {
            let minute = result[4] == "半" ? 30 : (japaneseNumber(result[3]) ?? 0)
            if (result[1] == "午後" || result[1] == "夜") && hour < 12 { hour += 12 }
            if result[1] == "午前", hour == 12 { hour = 0 }
            guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
            return (hour, minute)
        }
        if let result = firstMatch(#"(\d{1,2}):(\d{2})"#, in: content), result.count >= 3,
           let hour = Int(result[1]), let minute = Int(result[2]),
           (0...23).contains(hour), (0...59).contains(minute) {
            return (hour, minute)
        }
        return nil
    }

    private static func japaneseDefaultTime(_ content: String) -> (Int, Int) {
        if content.contains("今夜") || content.contains("夜") { return (20, 0) }
        if content.contains("午後") { return (15, 0) }
        if content.contains("正午") { return (12, 0) }
        return (9, 0)
    }

    private static func spanishReminderTitle(_ content: String) -> String {
        guard let marker = firstMatchWithRange(
            #"\b(?:recu[eé]rdame|recordarme|av[ií]same|avisarme)\b"#,
            in: content,
            options: [.caseInsensitive]
        ) else { return content }
        var title = String(content[marker.range.upperBound...])
        title = replacing(#"\b(?:hoy|ma[nñ]ana|pasado\s+ma[nñ]ana|esta\s+noche)\b"#, in: title, with: " ")
        title = replacing(#"\b(?:en|dentro\s+de)\s+"# + spanishNumberPattern + #"\s*(?:minutos?|horas?|d[ií]as?|semanas?)\b"#, in: title, with: " ")
        title = replacing(#"\b(?:todos\s+los\s+d[ií]as|cada\s+d[ií]a|cada\s+semana|cada\s+mes|cada\s+a[nñ]o)\b"#, in: title, with: " ")
        title = replacing(
            #"\b(?:el\s+)?"# + spanishNumberPattern + #"\s+de\s+(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|setiembre|octubre|noviembre|diciembre)(?:\s+de\s+\d{4})?\b"#,
            in: title,
            with: " "
        )
        title = replacing(#"\b(?:(?:pr[oó]ximo|este)\s+)?(?:lunes|martes|mi[eé]rcoles|jueves|viernes|s[aá]bado|domingo)\b"#, in: title, with: " ")
        title = replacing(#"\ba\s+la(?:s)?\s+"# + spanishNumberPattern + #"(?::\d{2})?\s*(?:de\s+la\s+(?:ma[nñ]ana|tarde|noche)|[ap]\.?\s*m\.?)?"#, in: title, with: " ")
        title = replacing(#"^\s*(?:que|de)\s+"#, in: title, with: "")
        return clean(title)
    }

    private static func japaneseReminderTitle(_ content: String) -> String {
        let markers = ["リマインドして", "リマインダーを設定", "思い出させて", "通知して", "知らせて"]
        guard let marker = markers.compactMap({ value -> (String, Range<String.Index>)? in
            content.range(of: value).map { (value, $0) }
        }).min(by: { $0.1.lowerBound < $1.1.lowerBound }) else { return content }

        var title = String(content[..<marker.1.lowerBound])
        if title.isEmpty {
            title = String(content[marker.1.upperBound...])
        }
        title = replacing(#"(?:今日|明日|明後日|今夜|今朝|明朝)(?:の)?"#, in: title, with: "")
        title = replacing(#"(?:\d{4}年)?\s*"# + japaneseNumberPattern + "月\\s*" + japaneseNumberPattern + #"日(?:の)?"#, in: title, with: "")
        title = replacing("毎月\\s*" + japaneseNumberPattern + #"日(?:の)?"#, in: title, with: "")
        title = replacing(#"(?:再来週|来週|今週)?(?:の)?[月火水木金土日]曜日(?:の)?"#, in: title, with: "")
        title = replacing(japaneseNumberPattern + #"\s*(?:分|時間|日|週間)後(?:に)?"#, in: title, with: "")
        title = replacing(#"(?:毎日|毎週|毎月|毎年)(?:の)?"#, in: title, with: "")
        title = replacing(#"(?:(?:午前|午後|夜|朝)\s*)?"# + japaneseNumberPattern + "時(?:" + japaneseNumberPattern + #"分|半)?(?:に)?"#, in: title, with: "")
        title = replacing(#"(?:こと|よう)(?:を|に)?$"#, in: title, with: "")
        return clean(title.trimmingCharacters(in: CharacterSet(charactersIn: "、， ")))
    }

    private static func spanishMonth(_ value: String) -> Int? {
        let normalized = value.lowercased().folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
        return [
            "enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6,
            "julio": 7, "agosto": 8, "septiembre": 9, "setiembre": 9, "octubre": 10,
            "noviembre": 11, "diciembre": 12
        ][normalized]
    }

    private static func spanishNumber(_ value: String) -> Int? {
        if let number = Int(value) { return number }
        let normalized = value
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es"))
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "un": 1, "una": 1, "uno": 1, "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5,
            "seis": 6, "siete": 7, "ocho": 8, "nueve": 9, "diez": 10, "once": 11,
            "doce": 12, "trece": 13, "catorce": 14, "quince": 15, "dieciseis": 16,
            "diecisiete": 17, "dieciocho": 18, "diecinueve": 19, "veinte": 20,
            "veintiuno": 21, "veintidos": 22, "veintitres": 23, "veinticuatro": 24,
            "veinticinco": 25, "veintiseis": 26, "veintisiete": 27, "veintiocho": 28,
            "veintinueve": 29, "treinta": 30, "treinta y uno": 31
        ][normalized]
    }

    private static func japaneseNumber(_ value: String) -> Int? {
        if value.isEmpty { return nil }
        if let number = Int(value) { return number }
        let digits: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9
        ]
        if value == "十" { return 10 }
        if let tenIndex = value.firstIndex(of: "十") {
            let prefix = value[..<tenIndex]
            let suffix = value[value.index(after: tenIndex)...]
            let tens = prefix.isEmpty ? 1 : (prefix.first.flatMap { digits[$0] } ?? 0)
            let ones = suffix.isEmpty ? 0 : (suffix.first.flatMap { digits[$0] } ?? 0)
            return tens * 10 + ones
        }
        if value.count == 1, let value = value.first.flatMap({ digits[$0] }) { return value }
        return nil
    }

    private static func date(
        dayOffset: Int,
        time: (Int, Int),
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let target = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { return nil }
        return applying(time: time, to: target, calendar: calendar)
    }

    private static func nextOccurrence(of time: (Int, Int), now: Date, calendar: Calendar) -> Date? {
        guard let today = applying(time: time, to: now, calendar: calendar) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }

    private static func applying(time: (Int, Int), to date: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.0
        components.minute = time.1
        return calendar.date(from: components)
    }

    private static func makeDate(
        year: Int,
        month: Int,
        day: Int,
        time: (Int, Int),
        calendar: Calendar
    ) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = time.0
        components.minute = time.1
        return calendar.date(from: components)
    }

    private static func startOfWeek(_ date: Date, calendar: Calendar) -> Date {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        weekCalendar.minimumDaysInFirstWeek = 4
        let weekday = weekCalendar.component(.weekday, from: date)
        let distance = (weekday - weekCalendar.firstWeekday + 7) % 7
        let target = weekCalendar.date(byAdding: .day, value: -distance, to: date) ?? date
        return weekCalendar.startOfDay(for: target)
    }

    private static func matches(_ pattern: String, _ content: String) -> Bool {
        firstMatch(pattern, in: content, options: [.caseInsensitive]) != nil
    }

    private static func clean(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "。！？!?,，、")))
    }

    private static func replacing(_ pattern: String, in content: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return content }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        return regex.stringByReplacingMatches(in: content, range: range, withTemplate: replacement)
    }

    private static func firstMatch(
        _ pattern: String,
        in content: String,
        options: NSRegularExpression.Options = []
    ) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            let matchRange = match.range(at: index)
            guard matchRange.location != NSNotFound, let range = Range(matchRange, in: content) else { return "" }
            return String(content[range])
        }
    }

    private static func firstMatchWithRange(
        _ pattern: String,
        in content: String,
        options: NSRegularExpression.Options = []
    ) -> (value: String, range: Range<String.Index>)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let fullRange = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: fullRange),
              let range = Range(match.range, in: content) else { return nil }
        return (String(content[range]), range)
    }
}
