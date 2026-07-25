import Foundation
import YijiCore

struct PersistedVault: Codable, Equatable, Sendable {
    var records: [Record] = []
    var reminders: [Reminder] = []
    var searchHistory: [String] = []
    var modifiedAt: Date?
    var lastWriterDeviceID: String?

    private enum CodingKeys: String, CodingKey {
        case records
        case reminders
        case searchHistory
        case modifiedAt
        case lastWriterDeviceID
    }

    init(
        records: [Record] = [],
        reminders: [Reminder] = [],
        searchHistory: [String] = [],
        modifiedAt: Date? = nil,
        lastWriterDeviceID: String? = nil
    ) {
        self.records = records
        self.reminders = reminders
        self.searchHistory = searchHistory
        self.modifiedAt = modifiedAt
        self.lastWriterDeviceID = lastWriterDeviceID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        records = try container.decodeIfPresent([Record].self, forKey: .records) ?? []
        reminders = try container.decodeIfPresent([Reminder].self, forKey: .reminders) ?? []
        searchHistory = try container.decodeIfPresent([String].self, forKey: .searchHistory) ?? []
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt)
        lastWriterDeviceID = try container.decodeIfPresent(String.self, forKey: .lastWriterDeviceID)
    }

    var hasUserContent: Bool {
        !records.isEmpty || !reminders.isEmpty || !searchHistory.isEmpty
    }

    var resolvedModifiedAt: Date {
        modifiedAt ?? .distantPast
    }

    mutating func touch(now: Date = Date(), deviceID: String = SyncDeviceIdentity.current) {
        modifiedAt = now
        lastWriterDeviceID = deviceID
    }
}

enum SyncDeviceIdentity {
    private static let key = "yiji.cloudSyncDeviceID"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}

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

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cloudSync: CloudKitVaultSyncCoordinator

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        cloudSync: CloudKitVaultSyncCoordinator = CloudKitVaultSyncCoordinator()
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.cloudSync = cloudSync
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() async throws -> VaultSnapshot {
        let resolvedVault = try await synchronizeCurrentVault()
        return snapshot(from: resolvedVault)
    }

    func refreshFromCloud() async throws -> VaultSnapshot {
        let resolvedVault = try await synchronizeCurrentVault()
        return snapshot(from: resolvedVault)
    }

    func cloudSyncStatus() async -> CloudSyncStatusSnapshot {
        await cloudSync.refreshStatus()
    }

    func save(_ parsedCapture: ParsedCapture) async throws -> VaultSnapshot {
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

        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    func replace(records: [Record], reminders: [Reminder], searchHistory: [String] = []) async throws -> VaultSnapshot {
        let vault = PersistedVault(records: records, reminders: reminders, searchHistory: searchHistory)
        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    func updateSearchHistory(_ searchHistory: [String]) async throws -> VaultSnapshot {
        var vault = try readVault()
        vault.searchHistory = searchHistory
        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    func updateReminder(_ reminder: Reminder) async throws -> VaultSnapshot {
        var vault = try readVault()
        guard let index = vault.reminders.firstIndex(where: { $0.id == reminder.id }) else {
            return snapshot(from: vault)
        }

        vault.reminders[index] = reminder
        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    func deleteReminder(id: UUID) async throws -> VaultSnapshot {
        var vault = try readVault()
        vault.reminders.removeAll { $0.id == id }
        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    func deleteRecord(id: UUID) async throws -> VaultSnapshot {
        var vault = try readVault()
        vault.records.removeAll { $0.id == id }
        vault.reminders.removeAll { $0.recordID == id }
        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    func exportBackupFile() throws -> URL {
        let vault = try readVault()
        let exportURL = fileManager.temporaryDirectory
            .appendingPathComponent(exportFilename, isDirectory: false)
        let data = try encoder.encode(vault)
        try data.write(to: exportURL, options: .atomic)
        return exportURL
    }

    func importBackupFile(from sourceURL: URL) async throws -> VaultSnapshot {
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

        let syncedVault = try await persistAndSynchronize(vault)
        return snapshot(from: syncedVault)
    }

    private func synchronizeCurrentVault() async throws -> PersistedVault {
        let localVault = try readVault()
        let syncedVault = await cloudSync.synchronize(localVault: localVault)
        if syncedVault != localVault {
            try writeVault(syncedVault)
        }
        return syncedVault
    }

    private func persistAndSynchronize(_ vault: PersistedVault) async throws -> PersistedVault {
        var localVault = vault
        localVault.touch()
        try writeVault(localVault)

        let syncedVault = await cloudSync.synchronize(localVault: localVault)
        if syncedVault != localVault {
            try writeVault(syncedVault)
        }
        return syncedVault
    }

    private func readVault() throws -> PersistedVault {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PersistedVault()
        }

        let data = try Data(contentsOf: fileURL)
        var vault = try decoder.decode(PersistedVault.self, from: data)

        if vault.modifiedAt == nil {
            vault.modifiedAt = fallbackModifiedDate(for: vault)
            if vault.lastWriterDeviceID == nil, vault.modifiedAt != nil {
                vault.lastWriterDeviceID = SyncDeviceIdentity.current
            }
        }

        return vault
    }

    private func writeVault(_ vault: PersistedVault) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }

        let data = try encoder.encode(vault)
        try data.write(to: fileURL, options: .atomic)
    }

    private func fallbackModifiedDate(for vault: PersistedVault) -> Date? {
        if let fileAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let fileModifiedDate = fileAttributes[.modificationDate] as? Date {
            return fileModifiedDate
        }

        let recordDates = vault.records.flatMap { [$0.updatedAt, $0.createdAt, $0.recordDate] }
        let reminderDates = vault.reminders.flatMap { [$0.createdAt, $0.remindAt] }
        return (recordDates + reminderDates).max()
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
