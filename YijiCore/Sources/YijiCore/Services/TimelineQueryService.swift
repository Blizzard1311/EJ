import Foundation

public struct TimelineQuery: Equatable, Sendable {
    public var rawText: String
    public var range: EventTimeRange
    public var sliceCategories: [RecordSliceCategory]

    public init(rawText: String, range: EventTimeRange, sliceCategories: [RecordSliceCategory] = []) {
        self.rawText = rawText
        self.range = range
        self.sliceCategories = sliceCategories
    }
}

public struct TimelineQuerySection: Equatable, Sendable {
    public var title: String
    public var records: [Record]

    public init(title: String, records: [Record]) {
        self.title = title
        self.records = records
    }
}

public enum TimelineQueryService {
    public static func parseQuery(
        _ text: String,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> TimelineQuery? {
        guard SearchIntentClassifier.isSearchQuery(text) else {
            return nil
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        guard timelineQueryMarkers.contains(where: trimmed.contains) ||
                timelinePlanningKeywords.contains(where: trimmed.contains) else {
            return nil
        }

        guard let range = TimeExpressionParser.parseQueryRange(in: trimmed, now: now, calendar: calendar) else {
            return nil
        }

        return TimelineQuery(
            rawText: trimmed,
            range: range,
            sliceCategories: RecordSliceClassifier.queryCategories(in: trimmed)
        )
    }

    public static func matchingRecords(for query: TimelineQuery, in records: [Record]) -> [Record] {
        records
            .filter { record in
                guard let timeRange = eventTimeRange(for: record) else {
                    return false
                }
                return timeRange.overlaps(query.range) && matchesSliceCategories(record, query: query)
            }
            .sorted { lhs, rhs in
                let lhsRange = eventTimeRange(for: lhs)
                let rhsRange = eventTimeRange(for: rhs)
                let lhsDate = lhsRange?.start ?? lhs.recordDate
                let rhsDate = rhsRange?.start ?? rhs.recordDate
                if lhsDate == rhsDate {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhsDate < rhsDate
            }
    }

    public static func groupedSections(
        for query: TimelineQuery,
        in records: [Record],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [TimelineQuerySection] {
        var orderedSections: [TimelineQuerySection] = []

        for record in matchingRecords(for: query, in: records) {
            let title = sectionTitle(for: record, calendar: calendar)
            if let index = orderedSections.firstIndex(where: { $0.title == title }) {
                orderedSections[index].records.append(record)
            } else {
                orderedSections.append(TimelineQuerySection(title: title, records: [record]))
            }
        }

        return orderedSections
    }

    public static func summary(
        for query: TimelineQuery,
        in records: [Record],
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> String {
        let matches = matchingRecords(for: query, in: records)
        let rangeText = query.range.displayText(calendar: calendar)
        let categoryText = categorySummaryText(for: query)

        guard !matches.isEmpty else {
            return YijiLocalization.format("timeline.none", rangeText, categoryText)
        }

        if matches.count == 1, let first = matches.first {
            return YijiLocalization.format("timeline.one", rangeText, categoryText, first.content)
        }

        return YijiLocalization.format("timeline.many", rangeText, categoryText, matches.count)
    }

    private static func sectionTitle(for record: Record, calendar: Calendar) -> String {
        guard let range = eventTimeRange(for: record) else {
            return YijiDateFormatter.dayFormatter.string(from: record.recordDate)
        }

        switch range.granularity {
        case .exactTime, .day:
            return YijiDateFormatter.dayFormatter.string(from: range.start)
        case .week, .month, .halfYear, .quarter, .year:
            return range.displayText(calendar: calendar)
        }
    }

    private static func eventTimeRange(for record: Record) -> EventTimeRange? {
        if let eventTime = record.eventTime {
            return eventTime
        }
        if record.category == .reminder {
            return EventTimeRange(start: record.recordDate, end: record.recordDate, granularity: .exactTime)
        }
        return nil
    }

    private static func matchesSliceCategories(_ record: Record, query: TimelineQuery) -> Bool {
        guard !query.sliceCategories.isEmpty else {
            return true
        }

        let recordCategories = Set(record.sliceCategories)
        return query.sliceCategories.contains(where: recordCategories.contains)
    }

    private static func categorySummaryText(for query: TimelineQuery) -> String {
        guard !query.sliceCategories.isEmpty else {
            return " "
        }

        let separator = YijiLocalization.isEnglish ? ", " : "、"
        let names = query.sliceCategories.map(\.displayName).joined(separator: separator)
        return YijiLocalization.format("timeline.category", names)
    }
}

private let timelineQueryMarkers = [
    "有哪些",
    "有什么",
    "帮我看",
    "帮我查",
    "列出",
    "看看"
]

private let timelinePlanningKeywords = [
    "计划",
    "安排",
    "日程",
    "事项",
    "提醒",
    "待办"
]
