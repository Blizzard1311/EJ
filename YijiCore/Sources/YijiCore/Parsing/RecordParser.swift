import Foundation

public struct RecordParser: Sendable {
    public init() {}

    public func parse(
        content rawContent: String,
        source: CaptureSource = .text,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ParsedCapture {
        let content = sanitize(rawContent)
        let timestamp = now

        if let reminder = parseReminder(content: content, now: now, calendar: calendar) {
            let tags = TagClassifier.tags(for: content, objectName: reminder.title)
            let record = Record(
                content: content,
                objectName: reminder.title,
                location: nil,
                recordDate: reminder.remindAt,
                category: .reminder,
                tags: tags,
                source: source,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            var linkedReminder = reminder
            linkedReminder.recordID = record.id
            return ParsedCapture(record: record, reminder: linkedReminder)
        }

        if let storage = parseStorage(content: content) {
            let tags = TagClassifier.tags(for: content, objectName: storage.objectName)
            let record = Record(
                content: content,
                objectName: storage.objectName,
                location: storage.location,
                recordDate: timestamp,
                category: .storage,
                tags: tags,
                source: source,
                createdAt: timestamp,
                updatedAt: timestamp
            )
            return ParsedCapture(record: record, reminder: nil)
        }

        let category: RecordCategory = content.contains("想法") || content.contains("记一下") ? .note : .other
        let record = Record(
            content: content,
            objectName: nil,
            location: nil,
            recordDate: timestamp,
            category: category,
            tags: TagClassifier.tags(for: content, objectName: nil),
            source: source,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return ParsedCapture(record: record, reminder: nil)
    }

    private func sanitize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。！？!?,，"))
    }

    private func parseStorage(content: String) -> (objectName: String, location: String)? {
        let patterns = [
            #"^我把(.+?)放在(.+)$"#,
            #"^我把(.+?)放进(.+)$"#,
            #"^我把(.+?)塞进(.+)$"#,
            #"^我把(.+?)装进(.+)$"#,
            #"^我把(.+?)搁在(.+)$"#,
            #"^我把(.+?)留在(.+)$"#,
            #"^(.+?)放在(.+)$"#,
            #"^(.+?)放进(.+)$"#,
            #"^(.+?)塞进(.+)$"#,
            #"^(.+?)装进(.+)$"#,
            #"^(.+?)在(.+)$"#,
            #"^(.+?)收在(.+)$"#,
            #"^(.+?)放到(.+)$"#,
            #"^(.+?)藏在(.+)$"#
        ]

        for pattern in patterns {
            if let result = firstMatch(pattern: pattern, in: content), result.count >= 3 {
                let objectName = sanitize(result[1])
                let location = sanitize(result[2])
                guard !objectName.isEmpty, !location.isEmpty else { continue }
                return (objectName, location)
            }
        }

        return nil
    }

    private func parseReminder(content: String, now: Date, calendar: Calendar) -> Reminder? {
        let reminderKeywords = ["提醒我", "记得提醒我", "到时候提醒我", "别忘了"]
        guard reminderKeywords.contains(where: content.contains) else {
            return nil
        }

        let repeatRule = parseRepeatRule(content: content)
        guard let remindAt = parseDate(content: content, now: now, calendar: calendar) else {
            return Reminder(
                title: reminderTitle(from: content, fallback: content),
                body: content,
                remindAt: now,
                repeatRule: repeatRule,
                status: .failed,
                createdAt: now
            )
        }

        let title = reminderTitle(from: content, fallback: content)
        return Reminder(
            title: title,
            body: content,
            remindAt: remindAt,
            repeatRule: repeatRule,
            status: .pending,
            createdAt: now
        )
    }

    private func reminderTitle(from content: String, fallback: String) -> String {
        let markers = ["提醒我", "记得提醒我", "到时候提醒我", "别忘了"]
        for marker in markers {
            if let range = content.range(of: marker) {
                let title = sanitizeReminderTitle(String(content[range.upperBound...]))
                if !title.isEmpty {
                    return title
                }
            }
        }
        return fallback
    }

    private func parseRepeatRule(content: String) -> ReminderRepeatRule {
        if content.contains("每天") {
            return .daily
        }
        if content.contains("每周") {
            return .weekly
        }
        if content.contains("每月") {
            return .monthly
        }
        if content.contains("每年") {
            return .yearly
        }
        return .none
    }

    private func parseDate(content: String, now: Date, calendar: Calendar) -> Date? {
        if let explicit = parseExplicitMonthDay(content: content, now: now, calendar: calendar) {
            return explicit
        }
        if let monthly = parseMonthlyDay(content: content, now: now, calendar: calendar) {
            return monthly
        }
        if let weekly = parseReferencedWeekday(content: content, now: now, calendar: calendar) {
            return weekly
        }
        if content.contains("每天"), let daily = parseDailyTime(content: content, now: now, calendar: calendar) {
            return daily
        }

        var dayOffset = 0
        let hasRelativeDay = content.contains("今天")
            || content.contains("今晚")
            || content.contains("今早")
            || content.contains("明早")
            || content.contains("明晚")
            || content.contains("明天")
            || content.contains("后天")
        if content.contains("明天") || content.contains("明早") || content.contains("明晚") {
            dayOffset = 1
        } else if content.contains("后天") {
            dayOffset = 2
        } else if !hasRelativeDay {
            return nil
        }

        let time = parseTime(content: content) ?? defaultTime(for: content)
        let baseDate = calendar.startOfDay(for: now)
        guard let date = calendar.date(byAdding: .day, value: dayOffset, to: baseDate) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = time.hour
        components.minute = time.minute
        return calendar.date(from: components)
    }

    private func parseExplicitMonthDay(content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(pattern: #"(?:(\d{4})年)?\s*(\d{1,2})月(\d{1,2})[日号]?"#, in: content), result.count >= 4 else {
            return nil
        }

        let currentYear = calendar.component(.year, from: now)
        let year = Int(result[1]) ?? currentYear
        guard let month = Int(result[2]), let day = Int(result[3]) else {
            return nil
        }
        let time = parseTime(content: content) ?? defaultTime(for: content)

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = time.hour
        components.minute = time.minute

        guard let date = calendar.date(from: components) else {
            return nil
        }

        if result[1].isEmpty && date < now {
            return calendar.date(byAdding: .year, value: 1, to: date)
        }
        return date
    }

    private func parseMonthlyDay(content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(pattern: #"每月\s*(\d{1,2})[日号]"#, in: content), result.count >= 2,
              let day = Int(result[1]) else {
            return nil
        }

        let time = parseTime(content: content) ?? defaultTime(for: content)
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = day
        components.hour = time.hour
        components.minute = time.minute

        guard let date = calendar.date(from: components) else {
            return nil
        }

        if date >= now {
            return date
        }
        return calendar.date(byAdding: .month, value: 1, to: date)
    }

    private func parseReferencedWeekday(content: String, now: Date, calendar: Calendar) -> Date? {
        guard let result = firstMatch(
            pattern: #"((?:下|本|这)?(?:周|星期|礼拜))([一二三四五六日天])"#,
            in: content
        ), result.count >= 3 else {
            return nil
        }

        let prefix = result[1]
        let weekdayText = result[2]
        let weekdayMap: [String: Int] = [
            "日": 1,
            "天": 1,
            "一": 2,
            "二": 3,
            "三": 4,
            "四": 5,
            "五": 6,
            "六": 7
        ]
        guard let targetWeekday = weekdayMap[weekdayText] else {
            return nil
        }

        let time = parseTime(content: content) ?? defaultTime(for: content)
        let currentWeekday = calendar.component(.weekday, from: now)
        var dayOffset = (targetWeekday - currentWeekday + 7) % 7

        if prefix.contains("下") {
            dayOffset += 7
        }

        let startOfToday = calendar.startOfDay(for: now)
        guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
            return nil
        }

        var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = time.hour
        components.minute = time.minute
        guard var candidate = calendar.date(from: components) else {
            return nil
        }

        if !prefix.contains("下"), candidate < now {
            candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
        }

        return candidate
    }

    private func parseDailyTime(content: String, now: Date, calendar: Calendar) -> Date? {
        let time = parseTime(content: content) ?? defaultTime(for: content)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = time.hour
        components.minute = time.minute
        guard let candidate = calendar.date(from: components) else {
            return nil
        }
        if candidate > now {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: candidate)
    }

    private func parseTime(content: String) -> (hour: Int, minute: Int)? {
        guard let result = firstMatch(
            pattern: #"(?:(凌晨|早上|上午|中午|下午|晚上))?\s*([零〇一二三四五六七八九十两\d]{1,3})点(?:(半)|([零〇一二三四五六七八九十两\d]{1,3})分?)?"#,
            in: content
        ), result.count >= 5 else {
            return nil
        }

        let meridiem = result[1]
        guard var hour = parseChineseOrArabicNumber(result[2]) else {
            return nil
        }
        let minute: Int
        if result[3] == "半" {
            minute = 30
        } else if let value = parseChineseOrArabicNumber(result[4]) {
            minute = value
        } else {
            minute = 0
        }

        if ["下午", "晚上"].contains(meridiem), hour < 12 {
            hour += 12
        } else if meridiem == "中午", hour < 11 {
            hour += 12
        } else if meridiem.isEmpty, hour < 12, content.contains("今晚") || content.contains("明晚") {
            hour += 12
        }

        return (hour, minute)
    }

    private func defaultTime(for content: String) -> (hour: Int, minute: Int) {
        if content.contains("今晚") || content.contains("晚上") {
            return (20, 0)
        }
        if content.contains("下午") {
            return (15, 0)
        }
        if content.contains("中午") {
            return (12, 0)
        }
        if content.contains("明早") || content.contains("早上") || content.contains("上午") {
            return (9, 0)
        }
        return (9, 0)
    }

    private func firstMatch(pattern: String, in content: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: range) else {
            return nil
        }

        return (0..<match.numberOfRanges).compactMap { index in
            let matchRange = match.range(at: index)
            guard let range = Range(matchRange, in: content) else {
                return ""
            }
            return String(content[range])
        }
    }

    private func parseChineseOrArabicNumber(_ text: String) -> Int? {
        if text.isEmpty {
            return nil
        }
        if let number = Int(text) {
            return number
        }

        let digits: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "三": 3, "四": 4,
            "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]

        if text == "十" {
            return 10
        }

        if let tenIndex = text.firstIndex(of: "十") {
            let prefix = text[..<tenIndex]
            let suffix = text[text.index(after: tenIndex)...]
            let tens = prefix.isEmpty ? 1 : (digits[prefix.first ?? "零"] ?? 0)
            let ones = suffix.isEmpty ? 0 : (digits[suffix.first ?? "零"] ?? 0)
            return tens * 10 + ones
        }

        if text.count == 1, let value = digits[text.first ?? "零"] {
            return value
        }

        return nil
    }

    private func sanitizeReminderTitle(_ rawTitle: String) -> String {
        var title = sanitize(rawTitle)
        let leadingPatterns = [
            #"^(今天|今晚|今早|明天|明晚|明早|后天)"#,
            #"^((?:下|本|这)?(?:周|星期|礼拜)[一二三四五六日天])"#,
            #"^(每(?:天|周|月|年)\S*)"#,
            #"^(?:(?:\d{4})年)?\d{1,2}月\d{1,2}[日号]?"#,
            #"^(凌晨|早上|上午|中午|下午|晚上)?\s*[零〇一二三四五六七八九十两\d]{1,3}点(?:(?:半)|(?:[零〇一二三四五六七八九十两\d]{1,3})分?)?"#
        ]

        for pattern in leadingPatterns {
            if let result = firstMatch(pattern: pattern, in: title), let matched = result.first, !matched.isEmpty {
                title = sanitize(String(title.dropFirst(matched.count)))
            }
        }

        return title
    }
}
