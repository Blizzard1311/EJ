import Foundation

public enum TimeExpressionParser {
    public static func parseEventTime(in text: String, now: Date = Date(), calendar: Calendar = .current) -> EventTimeRange? {
        parseRange(in: text, now: now, calendar: calendar)
    }

    public static func parseQueryRange(in text: String, now: Date = Date(), calendar: Calendar = .current) -> EventTimeRange? {
        parseRange(in: text, now: now, calendar: calendar)
    }

    private static func parseRange(in text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        if let explicit = parseExplicitMonthDayRange(text, now: now, calendar: calendar) {
            return explicit
        }
        if let weekday = parseReferencedWeekdayRange(text, now: now, calendar: calendar) {
            return weekday
        }
        if let relativeDay = parseRelativeDayRange(text, now: now, calendar: calendar) {
            return relativeDay
        }
        if let week = parseRelativeWeekRange(text, now: now, calendar: calendar) {
            return week
        }
        if let monthOrdinalWeek = parseMonthOrdinalWeekRange(text, now: now, calendar: calendar) {
            return monthOrdinalWeek
        }
        if let month = parseRelativeMonthRange(text, now: now, calendar: calendar) {
            return month
        }
        if let halfYear = parseHalfYearRange(text, now: now, calendar: calendar) {
            return halfYear
        }
        if let namedQuarter = parseNamedQuarterRange(text, now: now, calendar: calendar) {
            return namedQuarter
        }
        if let quarter = parseRelativeQuarterRange(text, now: now, calendar: calendar) {
            return quarter
        }
        if let year = parseRelativeYearRange(text, now: now, calendar: calendar) {
            return year
        }
        return nil
    }

    private static func parseExplicitMonthDayRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        guard let result = firstMatch(pattern: #"(?:(\d{4})年)?\s*(\d{1,2})月(\d{1,2})[日号]?"#, in: text),
              result.count >= 4 else {
            return nil
        }

        let currentYear = calendar.component(.year, from: now)
        let year = Int(result[1]) ?? currentYear
        guard let month = Int(result[2]), let day = Int(result[3]) else {
            return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        guard let dayDate = calendar.date(from: components) else {
            return nil
        }

        let resolvedDay = if result[1].isEmpty && dayDate < calendar.startOfDay(for: now) {
            calendar.date(byAdding: .year, value: 1, to: dayDate) ?? dayDate
        } else {
            dayDate
        }

        if let time = parseTime(text) {
            var timeComponents = calendar.dateComponents([.year, .month, .day], from: resolvedDay)
            timeComponents.hour = time.hour
            timeComponents.minute = time.minute
            let exact = calendar.date(from: timeComponents) ?? resolvedDay
            return EventTimeRange(start: exact, end: exact, granularity: .exactTime)
        }

        return makeDayRange(for: resolvedDay, calendar: calendar)
    }

    private static func parseReferencedWeekdayRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        guard let result = firstMatch(
            pattern: #"((?:(?:上上|下下|上|下|本|这)?(?:周|星期|礼拜)))([一二三四五六日天])"#,
            in: text
        ), result.count >= 3 else {
            return nil
        }

        let prefix = result[1]
        let weekdayText = result[2]
        let mondayOffsetMap: [String: Int] = [
            "一": 0,
            "二": 1,
            "三": 2,
            "四": 3,
            "五": 4,
            "六": 5,
            "日": 6,
            "天": 6
        ]
        guard let weekdayOffset = mondayOffsetMap[weekdayText] else {
            return nil
        }

        let targetDate: Date
        if let weekOffset = weekOffset(for: prefix) {
            let weekStart = startOfWeek(containing: now, offset: weekOffset, calendar: calendar)
            targetDate = calendar.date(byAdding: .day, value: weekdayOffset, to: weekStart) ?? weekStart
        } else {
            let currentWeekday = calendar.component(.weekday, from: now)
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
            let dayOffset = (targetWeekday - currentWeekday + 7) % 7
            let startOfToday = calendar.startOfDay(for: now)
            targetDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) ?? startOfToday
        }

        if let time = parseTime(text) {
            var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = time.hour
            components.minute = time.minute
            let exact = calendar.date(from: components) ?? targetDate
            return EventTimeRange(start: exact, end: exact, granularity: .exactTime)
        }

        return makeDayRange(for: targetDate, calendar: calendar)
    }

    private static func parseRelativeDayRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        let dayOffset: Int?
        if text.contains("大后天") {
            dayOffset = 3
        } else if text.contains("后天") {
            dayOffset = 2
        } else if text.contains("明天") || text.contains("明早") || text.contains("明晚") {
            dayOffset = 1
        } else if text.contains("前天") {
            dayOffset = -2
        } else if text.contains("今天") || text.contains("今晚") || text.contains("今早") {
            dayOffset = 0
        } else {
            dayOffset = nil
        }

        guard let dayOffset else {
            return nil
        }

        let startOfToday = calendar.startOfDay(for: now)
        guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
            return nil
        }

        if let time = parseTime(text) {
            var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = time.hour
            components.minute = time.minute
            let exact = calendar.date(from: components) ?? targetDate
            return EventTimeRange(start: exact, end: exact, granularity: .exactTime)
        }

        return makeDayRange(for: targetDate, calendar: calendar)
    }

    private static func parseRelativeWeekRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        if text.contains("下下周") {
            return makeWeekRange(containing: now, offset: 2, calendar: calendar)
        }
        if text.contains("上上周") {
            return makeWeekRange(containing: now, offset: -2, calendar: calendar)
        }
        if text.contains("下周") {
            return makeWeekRange(containing: now, offset: 1, calendar: calendar)
        }
        if text.contains("上周") {
            return makeWeekRange(containing: now, offset: -1, calendar: calendar)
        }
        if text.contains("本周") || text.contains("这周") {
            return makeWeekRange(containing: now, offset: 0, calendar: calendar)
        }
        return nil
    }

    private static func parseMonthOrdinalWeekRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        guard let result = firstMatch(
            pattern: #"(?:(上个月|下个月|本月|这个月)|(?:(\d{4})年)?(\d{1,2})月)?\s*(第)?\s*([一二三四五六123456])\s*周(?!后)(?!内)"#,
            in: text
        ), result.count >= 6 else {
            return nil
        }

        let relativeMonthText = result[1]
        let explicitYearText = result[2]
        let explicitMonthText = result[3]
        let ordinalMarker = result[4]
        let ordinalText = result[5]

        let hasMonthContext = !relativeMonthText.isEmpty || !explicitMonthText.isEmpty
        guard hasMonthContext || !ordinalMarker.isEmpty else {
            return nil
        }

        guard let ordinal = ordinalNumber(from: ordinalText),
              let monthStart = resolvedMonthStart(
                relativeMonthText: relativeMonthText,
                explicitYearText: explicitYearText,
                explicitMonthText: explicitMonthText,
                now: now,
                calendar: calendar
              ) else {
            return nil
        }

        return makeOrdinalWeekRange(containingMonthStart: monthStart, ordinal: ordinal, calendar: calendar)
    }

    private static func parseRelativeMonthRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        if text.contains("下个月") {
            return makeMonthRange(containing: now, offset: 1, calendar: calendar)
        }
        if text.contains("上个月") {
            return makeMonthRange(containing: now, offset: -1, calendar: calendar)
        }
        if text.contains("本月") || text.contains("这个月") {
            return makeMonthRange(containing: now, offset: 0, calendar: calendar)
        }
        return nil
    }

    private static func parseHalfYearRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        guard let result = firstMatch(
            pattern: #"(?:(\d{4})年|(后年|明年|今年|去年))?\s*(上半年|下半年)"#,
            in: text
        ), result.count >= 4 else {
            return nil
        }

        let year = resolvedYear(explicitYearText: result[1], relativeYearText: result[2], now: now, calendar: calendar)
        let startMonth = result[3] == "上半年" ? 1 : 7
        return makeHalfYearRange(year: year, startMonth: startMonth, calendar: calendar)
    }

    private static func parseNamedQuarterRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        guard let result = firstMatch(
            pattern: #"(?:(\d{4})年|(后年|明年|今年|去年))?\s*第?\s*([一二三四1234])\s*季度"#,
            in: text
        ), result.count >= 4 else {
            return nil
        }

        let year = resolvedYear(explicitYearText: result[1], relativeYearText: result[2], now: now, calendar: calendar)
        guard let quarter = quarterNumber(from: result[3]) else {
            return nil
        }
        return makeQuarterRange(year: year, quarter: quarter, calendar: calendar)
    }

    private static func parseRelativeQuarterRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        if text.contains("下季度") {
            return makeQuarterRange(containing: now, offset: 1, calendar: calendar)
        }
        if text.contains("本季度") || text.contains("这季度") {
            return makeQuarterRange(containing: now, offset: 0, calendar: calendar)
        }
        return nil
    }

    private static func parseRelativeYearRange(_ text: String, now: Date, calendar: Calendar) -> EventTimeRange? {
        if text.contains("后年") {
            return makeYearRange(containing: now, offset: 2, calendar: calendar)
        }
        if text.contains("前年") {
            return makeYearRange(containing: now, offset: -2, calendar: calendar)
        }
        if text.contains("明年") {
            return makeYearRange(containing: now, offset: 1, calendar: calendar)
        }
        if text.contains("去年") {
            return makeYearRange(containing: now, offset: -1, calendar: calendar)
        }
        if text.contains("今年") {
            return makeYearRange(containing: now, offset: 0, calendar: calendar)
        }
        return nil
    }

    private static func makeDayRange(for date: Date, calendar: Calendar) -> EventTimeRange {
        let start = calendar.startOfDay(for: date)
        return EventTimeRange(
            start: start,
            end: endOfDay(for: start, calendar: calendar),
            granularity: .day
        )
    }

    private static func makeWeekRange(containing date: Date, offset: Int, calendar: Calendar) -> EventTimeRange {
        let start = startOfWeek(containing: date, offset: offset, calendar: calendar)
        let end = endOfDay(for: calendar.date(byAdding: .day, value: 6, to: start) ?? start, calendar: calendar)
        return EventTimeRange(start: start, end: end, granularity: .week)
    }

    private static func makeMonthRange(containing date: Date, offset: Int, calendar: Calendar) -> EventTimeRange {
        var components = calendar.dateComponents([.year, .month], from: date)
        components.day = 1
        let monthStart = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .month, value: offset, to: monthStart) ?? monthStart
        let nextStart = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return EventTimeRange(start: start, end: nextStart.addingTimeInterval(-1), granularity: .month)
    }

    private static func makeHalfYearRange(year: Int, startMonth: Int, calendar: Calendar) -> EventTimeRange {
        makeMonthSpanRange(
            year: year,
            startMonth: startMonth,
            monthSpan: 6,
            granularity: .halfYear,
            calendar: calendar
        )
    }

    private static func makeQuarterRange(containing date: Date, offset: Int, calendar: Calendar) -> EventTimeRange {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let quarterStartMonth = ((month - 1) / 3) * 3 + 1

        var components = DateComponents()
        components.year = year
        components.month = quarterStartMonth
        components.day = 1
        let currentQuarterStart = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let start = calendar.date(byAdding: .month, value: offset * 3, to: currentQuarterStart) ?? currentQuarterStart
        let nextStart = calendar.date(byAdding: .month, value: 3, to: start) ?? start
        return EventTimeRange(start: start, end: nextStart.addingTimeInterval(-1), granularity: .quarter)
    }

    private static func makeQuarterRange(year: Int, quarter: Int, calendar: Calendar) -> EventTimeRange {
        let startMonth = ((quarter - 1) * 3) + 1
        return makeMonthSpanRange(
            year: year,
            startMonth: startMonth,
            monthSpan: 3,
            granularity: .quarter,
            calendar: calendar
        )
    }

    private static func makeYearRange(containing date: Date, offset: Int, calendar: Calendar) -> EventTimeRange {
        let year = calendar.component(.year, from: date) + offset
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        let start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        let nextStart = calendar.date(byAdding: .year, value: 1, to: start) ?? start
        return EventTimeRange(start: start, end: nextStart.addingTimeInterval(-1), granularity: .year)
    }

    private static func makeOrdinalWeekRange(containingMonthStart monthStart: Date, ordinal: Int, calendar: Calendar) -> EventTimeRange? {
        guard ordinal > 0 else {
            return nil
        }

        let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        let monthEnd = nextMonthStart.addingTimeInterval(-1)
        let monthWeekStart = startOfWeek(containing: monthStart, offset: ordinal - 1, calendar: calendar)
        let monthWeekEnd = endOfDay(
            for: calendar.date(byAdding: .day, value: 6, to: monthWeekStart) ?? monthWeekStart,
            calendar: calendar
        )

        let start = max(monthWeekStart, monthStart)
        let end = min(monthWeekEnd, monthEnd)
        guard start <= end else {
            return nil
        }

        return EventTimeRange(start: start, end: end, granularity: .week)
    }

    private static func makeMonthSpanRange(
        year: Int,
        startMonth: Int,
        monthSpan: Int,
        granularity: EventTimeGranularity,
        calendar: Calendar
    ) -> EventTimeRange {
        var components = DateComponents()
        components.year = year
        components.month = startMonth
        components.day = 1

        let start = calendar.date(from: components) ?? calendar.startOfDay(for: Date())
        let nextStart = calendar.date(byAdding: .month, value: monthSpan, to: start) ?? start
        return EventTimeRange(start: start, end: nextStart.addingTimeInterval(-1), granularity: granularity)
    }

    private static func resolvedMonthStart(
        relativeMonthText: String,
        explicitYearText: String,
        explicitMonthText: String,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        if let month = Int(explicitMonthText) {
            let year = Int(explicitYearText) ?? calendar.component(.year, from: now)
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            return calendar.date(from: components)
        }

        let monthOffset: Int
        switch relativeMonthText {
        case "上个月":
            monthOffset = -1
        case "下个月":
            monthOffset = 1
        default:
            monthOffset = 0
        }

        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = 1
        let currentMonthStart = calendar.date(from: components) ?? calendar.startOfDay(for: now)
        return calendar.date(byAdding: .month, value: monthOffset, to: currentMonthStart) ?? currentMonthStart
    }

    private static func resolvedYear(
        explicitYearText: String,
        relativeYearText: String,
        now: Date,
        calendar: Calendar
    ) -> Int {
        if let explicitYear = Int(explicitYearText) {
            return explicitYear
        }

        let currentYear = calendar.component(.year, from: now)
        if relativeYearText == "后年" {
            return currentYear + 2
        }
        if relativeYearText == "前年" {
            return currentYear - 2
        }
        if relativeYearText == "明年" {
            return currentYear + 1
        }
        if relativeYearText == "去年" {
            return currentYear - 1
        }
        return currentYear
    }

    private static func quarterNumber(from text: String) -> Int? {
        switch text {
        case "1", "一":
            return 1
        case "2", "二":
            return 2
        case "3", "三":
            return 3
        case "4", "四":
            return 4
        default:
            return nil
        }
    }

    private static func ordinalNumber(from text: String) -> Int? {
        switch text {
        case "1", "一":
            return 1
        case "2", "二":
            return 2
        case "3", "三":
            return 3
        case "4", "四":
            return 4
        case "5", "五":
            return 5
        case "6", "六":
            return 6
        default:
            return nil
        }
    }

    private static func weekOffset(for prefix: String) -> Int? {
        switch prefix {
        case "上上周", "上上星期", "上上礼拜":
            return -2
        case "上周", "上星期", "上礼拜":
            return -1
        case "本周", "本星期", "本礼拜", "这周", "这星期", "这礼拜":
            return 0
        case "下周", "下星期", "下礼拜":
            return 1
        case "下下周", "下下星期", "下下礼拜":
            return 2
        default:
            return nil
        }
    }

    private static func startOfWeek(containing date: Date, offset: Int, calendar: Calendar) -> Date {
        var weekCalendar = calendar
        weekCalendar.firstWeekday = 2
        weekCalendar.minimumDaysInFirstWeek = 4
        let weekday = weekCalendar.component(.weekday, from: date)
        let distance = (weekday - weekCalendar.firstWeekday + 7) % 7
        let thisWeekStart = weekCalendar.startOfDay(
            for: weekCalendar.date(byAdding: .day, value: -distance, to: date) ?? date
        )
        return weekCalendar.date(byAdding: .day, value: offset * 7, to: thisWeekStart) ?? thisWeekStart
    }

    private static func endOfDay(for date: Date, calendar: Calendar) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) ?? date
        return nextDay.addingTimeInterval(-1)
    }

    private static func parseTime(_ text: String) -> (hour: Int, minute: Int)? {
        if let result = firstMatch(
            pattern: #"(?:(凌晨|早上|上午|中午|下午|晚上))?\s*([零〇一二三四五六七八九十两\d]{1,3})\s*[:：]\s*([零〇一二三四五六七八九十两\d]{1,3})"#,
            in: text
        ), result.count >= 4 {
            let meridiem = result[1]
            guard var hour = parseChineseOrArabicNumber(result[2]),
                  let minute = parseChineseOrArabicNumber(result[3]) else {
                return nil
            }

            if ["下午", "晚上"].contains(meridiem), hour < 12 {
                hour += 12
            } else if meridiem == "中午", hour < 11 {
                hour += 12
            }

            return (hour, minute)
        }

        guard let result = firstMatch(
            pattern: #"(?:(凌晨|早上|上午|中午|下午|晚上))?\s*([零〇一二三四五六七八九十两\d]{1,3})(?:点钟|点|时)(?:(半|整)|([零〇一二三四五六七八九十两\d]{1,3})分?)?"#,
            in: text
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
        } else if result[3] == "整" {
            minute = 0
        } else if let value = parseChineseOrArabicNumber(result[4]) {
            minute = value
        } else {
            minute = 0
        }

        if ["下午", "晚上"].contains(meridiem), hour < 12 {
            hour += 12
        } else if meridiem == "中午", hour < 11 {
            hour += 12
        } else if meridiem.isEmpty, hour < 12, text.contains("今晚") || text.contains("明晚") {
            hour += 12
        }

        return (hour, minute)
    }

    private static func firstMatch(pattern: String, in content: String) -> [String]? {
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

    private static func parseChineseOrArabicNumber(_ text: String) -> Int? {
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

        if text.allSatisfy({ digits[$0] != nil }) {
            return text.reduce(into: 0) { partialResult, character in
                partialResult = partialResult * 10 + (digits[character] ?? 0)
            }
        }

        return nil
    }
}
