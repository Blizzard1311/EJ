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
            return "\(YijiDateFormatter.dayFormatter.string(from: start)) 至 \(YijiDateFormatter.dayFormatter.string(from: end))"
        case .month:
            let components = calendar.dateComponents([.year, .month], from: start)
            return "\(components.year ?? 0) 年 \(components.month ?? 0) 月"
        case .halfYear:
            let year = calendar.component(.year, from: start)
            let halfYearText = calendar.component(.month, from: start) <= 6 ? "上半年" : "下半年"
            return "\(year) 年\(halfYearText)"
        case .quarter:
            let components = calendar.dateComponents([.year, .month], from: start)
            let quarter = ((components.month ?? 1) - 1) / 3 + 1
            let quarterText: String
            switch quarter {
            case 1:
                quarterText = "一季度"
            case 2:
                quarterText = "二季度"
            case 3:
                quarterText = "三季度"
            default:
                quarterText = "四季度"
            }
            return "\(components.year ?? 0) 年\(quarterText)"
        case .year:
            let year = calendar.component(.year, from: start)
            return "\(year) 年"
        }
    }
}
