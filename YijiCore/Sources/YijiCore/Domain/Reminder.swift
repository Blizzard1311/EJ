import Foundation

public enum ReminderRepeatRule: String, Codable, CaseIterable, Sendable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    public var displayName: String {
        switch self {
        case .none:
            YijiLocalization.text("一次性")
        case .daily:
            YijiLocalization.text("每天")
        case .weekly:
            YijiLocalization.text("每周")
        case .monthly:
            YijiLocalization.text("每月")
        case .yearly:
            YijiLocalization.text("每年")
        }
    }
}

public enum ReminderStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case notified
    case done
    case cancelled
    case failed

    public var displayName: String {
        switch self {
        case .pending:
            YijiLocalization.text("待提醒")
        case .notified:
            YijiLocalization.text("已提醒")
        case .done:
            YijiLocalization.text("已完成")
        case .cancelled:
            YijiLocalization.text("已取消")
        case .failed:
            YijiLocalization.text("失败")
        }
    }
}

public struct Reminder: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var recordID: UUID?
    public var title: String
    public var body: String
    public var remindAt: Date
    public var repeatRule: ReminderRepeatRule
    public var status: ReminderStatus
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        recordID: UUID? = nil,
        title: String,
        body: String,
        remindAt: Date,
        repeatRule: ReminderRepeatRule = .none,
        status: ReminderStatus = .pending,
        createdAt: Date
    ) {
        self.id = id
        self.recordID = recordID
        self.title = title
        self.body = body
        self.remindAt = remindAt
        self.repeatRule = repeatRule
        self.status = status
        self.createdAt = createdAt
    }
}
