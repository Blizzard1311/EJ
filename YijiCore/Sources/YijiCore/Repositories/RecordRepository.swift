import Foundation

public protocol RecordRepository: Sendable {
    func snapshot() async -> VaultSnapshot
    func save(_ parsedCapture: ParsedCapture) async
    func search(keyword: String) async -> [Record]
}

public struct VaultSnapshot: Sendable {
    public var records: [Record]
    public var reminders: [Reminder]
    public var searchHistory: [String]

    public init(records: [Record], reminders: [Reminder], searchHistory: [String] = []) {
        self.records = records
        self.reminders = reminders
        self.searchHistory = searchHistory
    }
}
