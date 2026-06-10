import Foundation
import YijiCore

actor FileBackedVaultStore {
    enum StoreError: LocalizedError {
        case emptyBackupFile
        case invalidBackupFormat
        case unreadableBackupFile

        var errorDescription: String? {
            switch self {
            case .emptyBackupFile:
                "备份文件是空的，请选择易记导出的 JSON 备份文件。"
            case .invalidBackupFormat:
                "备份文件格式不正确，请确认选择的是易记导出的 JSON 备份文件。"
            case .unreadableBackupFile:
                "备份文件无法读取，请重新选择文件或检查文件权限。"
            }
        }
    }

    private struct PersistedVault: Codable {
        var records: [Record] = []
        var reminders: [Reminder] = []
        var searchHistory: [String] = []

        private enum CodingKeys: String, CodingKey {
            case records
            case reminders
            case searchHistory
        }

        init(records: [Record] = [], reminders: [Reminder] = [], searchHistory: [String] = []) {
            self.records = records
            self.reminders = reminders
            self.searchHistory = searchHistory
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            records = try container.decodeIfPresent([Record].self, forKey: .records) ?? []
            reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
            searchHistory = try container.decodeIfPresent([String].self, forKey: .searchHistory) ?? []
        }
    }

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() throws -> VaultSnapshot {
        snapshot(from: try readVault())
    }

    func save(_ parsedCapture: ParsedCapture) throws -> VaultSnapshot {
        var vault = try readVault()
        vault.records.insert(parsedCapture.record, at: 0)
        vault.records.sort { lhs, rhs in
            if lhs.recordDate == rhs.recordDate {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.recordDate > rhs.recordDate
        }

        if let reminder = parsedCapture.reminder {
            vault.reminders.removeAll { $0.id == reminder.id }
            vault.reminders.append(reminder)
            vault.reminders.sort { $0.remindAt < $1.remindAt }
        }

        try writeVault(vault)
        return snapshot(from: vault)
    }

    func replace(records: [Record], reminders: [Reminder], searchHistory: [String] = []) throws -> VaultSnapshot {
        let vault = PersistedVault(records: records, reminders: reminders, searchHistory: searchHistory)
        try writeVault(vault)
        return snapshot(from: vault)
    }

    func updateSearchHistory(_ searchHistory: [String]) throws -> VaultSnapshot {
        var vault = try readVault()
        vault.searchHistory = searchHistory
        try writeVault(vault)
        return snapshot(from: vault)
    }

    func updateReminder(_ reminder: Reminder) throws -> VaultSnapshot {
        var vault = try readVault()
        guard let index = vault.reminders.firstIndex(where: { $0.id == reminder.id }) else {
            return snapshot(from: vault)
        }

        vault.reminders[index] = reminder
        try writeVault(vault)
        return snapshot(from: vault)
    }

    func deleteReminder(id: UUID) throws -> VaultSnapshot {
        var vault = try readVault()
        vault.reminders.removeAll { $0.id == id }
        try writeVault(vault)
        return snapshot(from: vault)
    }

    func deleteRecord(id: UUID) throws -> VaultSnapshot {
        var vault = try readVault()
        vault.records.removeAll { $0.id == id }
        vault.reminders.removeAll { $0.recordID == id }
        try writeVault(vault)
        return snapshot(from: vault)
    }

    func exportBackupFile() throws -> URL {
        let vault = try readVault()
        let exportURL = fileManager.temporaryDirectory
            .appendingPathComponent(exportFilename, isDirectory: false)
        let data = try encoder.encode(vault)
        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }

    func importBackupFile(from sourceURL: URL) throws -> VaultSnapshot {
        let data: Data
        do {
            data = try Data(contentsOf: sourceURL)
        } catch {
            throw StoreError.unreadableBackupFile
        }

        switch BackupPayloadInspector.validate(data) {
        case .valid:
            break
        case .empty:
            throw StoreError.emptyBackupFile
        case .invalidJSON, .unrecognizedShape:
            throw StoreError.invalidBackupFormat
        }

        let vault: PersistedVault
        do {
            vault = try decoder.decode(PersistedVault.self, from: data)
        } catch {
            throw StoreError.invalidBackupFormat
        }
        try writeVault(vault)
        return snapshot(from: vault)
    }

    private func readVault() throws -> PersistedVault {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PersistedVault()
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(PersistedVault.self, from: data)
    }

    private func writeVault(_ vault: PersistedVault) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        let data = try encoder.encode(vault)
        try data.write(to: fileURL, options: .atomic)
    }

    private func snapshot(from vault: PersistedVault) -> VaultSnapshot {
        VaultSnapshot(
            records: vault.records.sorted { lhs, rhs in
                if lhs.recordDate == rhs.recordDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.recordDate > rhs.recordDate
            },
            reminders: vault.reminders.sorted { $0.remindAt < $1.remindAt },
            searchHistory: vault.searchHistory
        )
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL
            .appendingPathComponent("Yiji", isDirectory: true)
            .appendingPathComponent("vault.json", isDirectory: false)
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "yiji-backup-\(formatter.string(from: Date())).json"
    }
}
