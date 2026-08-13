import Foundation

public enum RecordCategory: String, Codable, CaseIterable, Sendable {
    case storage
    case reminder
    case note
    case other

    public var displayName: String {
        switch self {
        case .storage:
            YijiLocalization.text("物品位置")
        case .reminder:
            YijiLocalization.text("提醒事项")
        case .note:
            YijiLocalization.text("想法笔记")
        case .other:
            YijiLocalization.text("其他")
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
    public var storageContainer: StorageContainer?
    public var customStorageContainerName: String?
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
        storageContainer: StorageContainer? = nil,
        customStorageContainerName: String? = nil,
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
        self.storageContainer = storageContainer
        self.customStorageContainerName = customStorageContainerName
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
            return YijiLocalization.text("时间安排")
        }
        return category.displayName
    }

    var resolvedStorageContainer: StorageContainer? {
        resolvedStorageContainers.first
    }

    var resolvedStorageContainers: [StorageContainer] {
        guard category == .storage else {
            return []
        }

        var containers: [StorageContainer] = []

        if let storageContainer {
            containers.append(storageContainer)
        }

        for container in StorageContainerClassifier.classifyAll(for: self)
        where !containers.contains(container) {
            containers.append(container)
        }

        return containers
    }

    var explicitCustomStorageContainerName: String? {
        guard category == .storage else {
            return nil
        }

        let trimmed = customStorageContainerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    var normalizedStorageObjectName: String? {
        guard category == .storage else {
            return nil
        }

        let trimmed = objectName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return nil
        }

        return trimmed.lowercased()
    }

    var displayStorageLocation: String? {
        let trimmedLocation = location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedLocation = trimmedLocation.isEmpty ? nil : trimmedLocation

        guard category == .storage else {
            return normalizedLocation
        }

        if let storageContainer {
            guard let normalizedLocation else {
                return storageContainer.displayName
            }

            let locationContainers = StorageContainerClassifier.classifyAll(
                content: "",
                objectName: nil,
                location: normalizedLocation,
                tags: []
            )

            if !locationContainers.isEmpty, !locationContainers.contains(storageContainer) {
                return storageContainer.displayName
            }

            return normalizedLocation
        }

        if let explicitCustomStorageContainerName {
            return normalizedLocation ?? explicitCustomStorageContainerName
        }

        return normalizedLocation
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
            return YijiLocalization.format("record.answer.storage", dateText, objectName, location)
        }
        if let eventTime {
            return YijiLocalization.format("record.answer.event", eventTime.displayText(), content)
        }
        return YijiLocalization.format("record.answer.note", dateText, content)
    }

    var eventTimeSummary: String? {
        eventTime?.displayText()
    }
}
