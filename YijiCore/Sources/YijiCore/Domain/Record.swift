import Foundation

public enum RecordCategory: String, Codable, CaseIterable, Sendable {
    case storage
    case reminder
    case note
    case other

    public var displayName: String {
        switch self {
        case .storage:
            "物品位置"
        case .reminder:
            "提醒事项"
        case .note:
            "想法笔记"
        case .other:
            "其他"
        }
    }
}

public enum CaptureSource: String, Codable, CaseIterable, Sendable {
    case voice
    case text
    case imported
}

public struct Record: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var content: String
    public var objectName: String?
    public var location: String?
    public var recordDate: Date
    public var eventTime: EventTimeRange?
    public var category: RecordCategory
    public var tags: [String]
    public var source: CaptureSource
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        content: String,
        objectName: String? = nil,
        location: String? = nil,
        recordDate: Date,
        eventTime: EventTimeRange? = nil,
        category: RecordCategory,
        tags: [String] = [],
        source: CaptureSource,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.content = content
        self.objectName = objectName
        self.location = location
        self.recordDate = recordDate
        self.eventTime = eventTime
        self.category = category
        self.tags = tags
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension Record {
    var displayCategoryName: String {
        if category == .note, eventTime != nil {
            return "时间安排"
        }
        return category.displayName
    }

    var sliceCategories: [RecordSliceCategory] {
        RecordSliceClassifier.categories(for: self)
    }

    var sliceCategoryNames: [String] {
        sliceCategories.map(\.displayName)
    }

    var primaryTimeRange: EventTimeRange? {
        if let eventTime {
            return eventTime
        }
        if category == .reminder {
            return EventTimeRange(start: recordDate, end: recordDate, granularity: .exactTime)
        }
        return nil
    }

    var browseTimeRange: EventTimeRange {
        primaryTimeRange ?? EventTimeRange(start: recordDate, end: recordDate, granularity: .exactTime)
    }

    var answerSummary: String {
        let dateText = YijiDateFormatter.dayFormatter.string(from: recordDate)
        if let objectName, let location {
            return "你在 \(dateText) 记录过：\(objectName) 放在 \(location)。"
        }
        if let eventTime {
            return "你记录过一项时间相关内容：\(eventTime.displayText())，\(content)。"
        }
        return "你在 \(dateText) 记录过：\(content)。"
    }

    var eventTimeSummary: String? {
        eventTime?.displayText()
    }
}
