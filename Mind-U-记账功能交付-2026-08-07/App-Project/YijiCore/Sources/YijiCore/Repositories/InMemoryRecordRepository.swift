import Foundation

public actor InMemoryRecordRepository: RecordRepository {
    private var records: [Record]
    private var reminders: [Reminder]
    private var searchHistory: [String]

    public init(records: [Record] = [], reminders: [Reminder] = [], searchHistory: [String] = []) {
        self.records = records.sorted { $0.recordDate > $1.recordDate }
        self.reminders = reminders.sorted { $0.remindAt < $1.remindAt }
        self.searchHistory = searchHistory
    }

    public func snapshot() async -> VaultSnapshot {
        VaultSnapshot(records: records, reminders: reminders, searchHistory: searchHistory)
    }

    public func save(_ parsedCapture: ParsedCapture) async {
        records.insert(parsedCapture.record, at: 0)
        records.sort { $0.recordDate > $1.recordDate }

        if let reminder = parsedCapture.reminder {
            reminders.append(reminder)
            reminders.sort { $0.remindAt < $1.remindAt }
        }
    }

    public func search(keyword: String) async -> [Record] {
        RecordSearch.query(keyword, in: records)
    }
}
