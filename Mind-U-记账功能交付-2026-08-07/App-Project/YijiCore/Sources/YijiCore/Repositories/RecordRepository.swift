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
    public var expenses: [Expense]
    public var expenseCategories: [ExpenseCategoryDefinition]

    public init(
        records: [Record],
        reminders: [Reminder],
        searchHistory: [String] = [],
        expenses: [Expense] = [],
        expenseCategories: [ExpenseCategoryDefinition] = ExpenseCategoryDefinition.defaults
    ) {
        self.records = records
        self.reminders = reminders
        self.searchHistory = searchHistory
        self.expenses = expenses
        self.expenseCategories = expenseCategories
    }
}
