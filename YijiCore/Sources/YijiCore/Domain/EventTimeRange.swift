import Foundation

public enum EventTimeGranularity: String, Codable, CaseIterable, Sendable {
    case exactTime
    case day
    case week
    case month
    case halfYear
    case quarter
    case year
}

public struct EventTimeRange: Hashable, Codable, Sendable {
    public var start: Date
    public var end: Date
    public var granularity: EventTimeGranularity

    public init(start: Date, end: Date, granularity: EventTimeGranularity) {
        self.start = start
        self.end = end
        self.granularity = granularity
    }
}

public extension EventTimeRange {
    func overlaps(_ other: EventTimeRange) -> Bool {
        start <= other.end && end >= other.start
    }

    func displayText(calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        switch granularity {
        case .exactTime:
            return YijiDateFormatter.dateTimeFormatter.string(from: start)
        case .day:
            return YijiDateFormatter.dayFormatter.string(from: start)
        case .week:
            return YijiLocalization.format(
                "date.range",
                YijiDateFormatter.dayFormatter.string(from: start),
                YijiDateFormatter.dayFormatter.string(from: end)
            )
        case .month:
            let components = calendar.dateComponents([.year, .month], from: start)
            return YijiLocalization.format("date.month", components.year ?? 0, components.month ?? 0)
        case .halfYear:
            let year = calendar.component(.year, from: start)
            let halfYearText = calendar.component(.month, from: start) <= 6
                ? YijiLocalization.text("上半年")
                : YijiLocalization.text("下半年")
            return YijiLocalization.format("date.year_period", year, halfYearText)
        case .quarter:
            let components = calendar.dateComponents([.year, .month], from: start)
            let quarter = ((components.month ?? 1) - 1) / 3 + 1
            let quarterText: String
            switch quarter {
            case 1:
                quarterText = YijiLocalization.text("一季度")
            case 2:
                quarterText = YijiLocalization.text("二季度")
            case 3:
                quarterText = YijiLocalization.text("三季度")
            default:
                quarterText = YijiLocalization.text("四季度")
            }
            return YijiLocalization.format("date.year_period", components.year ?? 0, quarterText)
        case .year:
            let year = calendar.component(.year, from: start)
            return YijiLocalization.format("date.year", year)
        }
    }
}
