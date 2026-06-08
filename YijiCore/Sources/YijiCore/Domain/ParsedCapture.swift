import Foundation

public struct ParsedCapture: Sendable {
    public var record: Record
    public var reminder: Reminder?
    public var warnings: [String]

    public init(record: Record, reminder: Reminder?, warnings: [String] = []) {
        self.record = record
        self.reminder = reminder
        self.warnings = warnings
    }
}
