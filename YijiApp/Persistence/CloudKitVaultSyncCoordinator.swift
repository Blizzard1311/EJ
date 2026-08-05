import Foundation
import OSLog

#if DEBUG
import CloudKit
#endif

struct CloudSyncStatusSnapshot: Sendable {
    enum Availability: Sendable {
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unknown
        case disabled
    }

    var availability: Availability
    var lastSuccessfulSyncDate: Date?
    var lastErrorDescription: String?
}

#if DEBUG
actor CloudKitVaultSyncCoordinator {
    private enum Constants {
        static let containerIdentifier = "iCloud.com.blizzard1311.yiji"
        static let recordType = "VaultState"
        static let recordName = "primary"
        static let payloadField = "payload"
        static let modifiedAtField = "modifiedAt"
        static let lastWriterDeviceIDField = "lastWriterDeviceID"
        static let lastSuccessfulSyncDateKey = "yiji.cloudSyncLastSuccessfulSyncDate"
    }

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.blizzard1311.yiji",
        category: "CloudKitVaultSync"
    )
    private let container: CKContainer
    private let database: CKDatabase
    private let recordID = CKRecord.ID(recordName: Constants.recordName)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let userDefaults: UserDefaults

    private var lastKnownAvailability: CloudSyncStatusSnapshot.Availability = .unknown
    private var lastSuccessfulSyncDate: Date?
    private var lastErrorDescription: String?

    init(
        containerIdentifier: String = Constants.containerIdentifier,
        userDefaults: UserDefaults = .standard
    ) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = self.container.privateCloudDatabase
        self.userDefaults = userDefaults
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        lastSuccessfulSyncDate = userDefaults.object(forKey: Constants.lastSuccessfulSyncDateKey) as? Date
    }

    func synchronize(localVault: PersistedVault) async -> PersistedVault {
        let normalizedLocalVault = normalized(localVault)

        do {
            let availability = try await refreshAvailability()
            guard availability == .available else {
                logger.info("[CloudSync] skipped-cloud-sync availability=\(String(describing: availability), privacy: .public) local=[\(normalizedLocalVault.syncDebugSummary, privacy: .public)]")
                return normalizedLocalVault
            }

            let remoteRecord = try await fetchRemoteRecord()
            switch remoteRecord {
            case .none:
                guard normalizedLocalVault.hasUserContent else {
                    logger.info("[CloudSync] cloud-empty-and-local-empty local=[\(normalizedLocalVault.syncDebugSummary, privacy: .public)]")
                    markSuccess()
                    return normalizedLocalVault
                }

                logger.info("[CloudSync] cloud-empty-uploading-local local=[\(normalizedLocalVault.syncDebugSummary, privacy: .public)]")
                let savedVault = try await saveVault(normalizedLocalVault, using: nil)
                logger.info("[CloudSync] upload-finished saved=[\(savedVault.syncDebugSummary, privacy: .public)]")
                markSuccess()
                return savedVault

            case .some(let record):
                let remoteVault = try decodeVault(from: record)
                if remoteVault.resolvedModifiedAt > normalizedLocalVault.resolvedModifiedAt {
                    logger.info("[CloudRestore] remote-newer-restoring local=[\(normalizedLocalVault.syncDebugSummary, privacy: .public)] remote=[\(remoteVault.syncDebugSummary, privacy: .public)]")
                    markSuccess()
                    return remoteVault
                }

                logger.info("[CloudSync] local-newer-saving-to-cloud local=[\(normalizedLocalVault.syncDebugSummary, privacy: .public)] remote=[\(remoteVault.syncDebugSummary, privacy: .public)]")
                let savedVault = try await saveVault(normalizedLocalVault, using: record)
                logger.info("[CloudSync] cloud-save-finished saved=[\(savedVault.syncDebugSummary, privacy: .public)]")
                markSuccess()
                return savedVault
            }
        } catch {
            let summary = describe(error: error)
            logger.error("Cloud sync failed: \(summary, privacy: .public)")
            lastErrorDescription = userFacingDescription(for: error)
            return normalizedLocalVault
        }
    }

    func refreshStatus() async -> CloudSyncStatusSnapshot {
        do {
            _ = try await refreshAvailability()
        } catch {
            lastErrorDescription = userFacingDescription(for: error)
        }

        return CloudSyncStatusSnapshot(
            availability: lastKnownAvailability,
            lastSuccessfulSyncDate: lastSuccessfulSyncDate,
            lastErrorDescription: lastErrorDescription
        )
    }

    private func normalized(_ vault: PersistedVault) -> PersistedVault {
        var normalizedVault = vault
        if normalizedVault.modifiedAt == nil {
            normalizedVault.modifiedAt = .distantPast
        }
        return normalizedVault
    }

    private func refreshAvailability() async throws -> CloudSyncStatusSnapshot.Availability {
        let status = try await accountStatus()
        let availability: CloudSyncStatusSnapshot.Availability

        switch status {
        case .available:
            availability = .available
        case .noAccount:
            availability = .noAccount
        case .restricted:
            availability = .restricted
        case .temporarilyUnavailable, .couldNotDetermine:
            availability = .temporarilyUnavailable
        @unknown default:
            availability = .unknown
        }

        lastKnownAvailability = availability
        if availability != .available {
            lastErrorDescription = nil
        }
        return availability
    }

    private func markSuccess() {
        let now = Date()
        lastSuccessfulSyncDate = now
        lastErrorDescription = nil
        userDefaults.set(now, forKey: Constants.lastSuccessfulSyncDateKey)
    }

    private func fetchRemoteRecord() async throws -> CKRecord? {
        try await withCheckedThrowingContinuation { continuation in
            database.fetch(withRecordID: recordID) { record, error in
                if let ckError = error as? CKError, ckError.code == .unknownItem {
                    continuation.resume(returning: nil)
                    return
                }

                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: record)
            }
        }
    }

    private func saveVault(_ vault: PersistedVault, using existingRecord: CKRecord?) async throws -> PersistedVault {
        let preferredVault = normalized(vault)
        let record = existingRecord ?? CKRecord(recordType: Constants.recordType, recordID: recordID)
        try apply(preferredVault, to: record)

        do {
            _ = try await saveRecord(record)
            return preferredVault
        } catch let ckError as CKError where ckError.code == .serverRecordChanged {
            guard let serverRecord = ckError.serverRecord else {
                throw ckError
            }

            let remoteVault = try decodeVault(from: serverRecord)
            if remoteVault.resolvedModifiedAt > preferredVault.resolvedModifiedAt {
                logger.info("[CloudRestore] server-record-changed-using-remote local=[\(preferredVault.syncDebugSummary, privacy: .public)] remote=[\(remoteVault.syncDebugSummary, privacy: .public)]")
                return remoteVault
            }

            logger.info("[CloudSync] server-record-changed-overwriting-remote local=[\(preferredVault.syncDebugSummary, privacy: .public)] remote=[\(remoteVault.syncDebugSummary, privacy: .public)]")
            try apply(preferredVault, to: serverRecord)
            _ = try await saveRecord(serverRecord)
            return preferredVault
        }
    }

    private func decodeVault(from record: CKRecord) throws -> PersistedVault {
        guard let payload = record[Constants.payloadField] as? NSData else {
            throw CKError(.partialFailure)
        }

        var vault = try decoder.decode(PersistedVault.self, from: payload as Data)
        if let modifiedAt = record[Constants.modifiedAtField] as? Date {
            vault.modifiedAt = modifiedAt
        }
        if let lastWriterDeviceID = record[Constants.lastWriterDeviceIDField] as? String {
            vault.lastWriterDeviceID = lastWriterDeviceID
        }
        return normalized(vault)
    }

    private func apply(_ vault: PersistedVault, to record: CKRecord) throws {
        let payload = try encoder.encode(vault)
        record[Constants.payloadField] = payload as NSData
        record[Constants.modifiedAtField] = vault.resolvedModifiedAt as NSDate
        if let lastWriterDeviceID = vault.lastWriterDeviceID {
            record[Constants.lastWriterDeviceIDField] = lastWriterDeviceID as NSString
        } else {
            record[Constants.lastWriterDeviceIDField] = nil
        }
    }

    private func saveRecord(_ record: CKRecord) async throws -> CKRecord {
        try await withCheckedThrowingContinuation { continuation in
            database.save(record) { savedRecord, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                continuation.resume(returning: savedRecord ?? record)
            }
        }
    }

    private func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: status)
            }
        }
    }

    private func describe(error: Error) -> String {
        if let ckError = error as? CKError {
            var details: [String] = []
            let nsError = ckError as NSError
            details.append("code=\(ckError.code.rawValue)")
            details.append("symbol=\(String(describing: ckError.code))")

            if let containerID = ckError.userInfo["CKContainerID"] as? String {
                details.append("container=\(containerID)")
            } else {
                details.append("container=\(Constants.containerIdentifier)")
            }

            if let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
                details.append("retryAfter=\(retryAfter)")
            }

            if let serverDescription = ckError.userInfo[NSDebugDescriptionErrorKey] as? String,
               !serverDescription.isEmpty {
                details.append("debug=\(serverDescription)")
            }

            if let localizedFailureReason = nsError.localizedFailureReason,
               !localizedFailureReason.isEmpty {
                details.append("reason=\(localizedFailureReason)")
            }

            if let localizedRecoverySuggestion = nsError.localizedRecoverySuggestion,
               !localizedRecoverySuggestion.isEmpty {
                details.append("suggestion=\(localizedRecoverySuggestion)")
            }

            if let underlyingError = ckError.userInfo[NSUnderlyingErrorKey] {
                details.append("underlying=\(String(describing: underlyingError))")
            }

            if let serverRecord = ckError.serverRecord {
                details.append("serverRecordType=\(serverRecord.recordType)")
                details.append("serverRecordName=\(serverRecord.recordID.recordName)")
            }

            return "The operation couldn’t be completed. (CKErrorDomain error \(ckError.code.rawValue).) [\(details.joined(separator: " | "))]"
        }

        return error.localizedDescription
    }

    private func userFacingDescription(for error: Error) -> String {
        guard let ckError = error as? CKError else {
            return error.localizedDescription
        }

        switch ckError.code {
        case .quotaExceeded:
            if let retryAfter = ckError.userInfo[CKErrorRetryAfterKey] as? TimeInterval {
                let retryMinutes = Int(retryAfter.rounded(.up) / 60.0)
                return AppLocalization.format("cloud.retry_minutes", max(retryMinutes, 1))
            }
            return AppLocalization.text("iCloud 存储空间不足，云端备份暂时失败。请清理 iCloud 空间后再试。")
        case .networkUnavailable, .networkFailure:
            return AppLocalization.text("网络连接不稳定，暂时无法完成 iCloud 备份。请检查网络后再试。")
        case .notAuthenticated:
            return AppLocalization.text("当前未登录 iCloud，无法进行云端备份。请先登录 iCloud。")
        case .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return AppLocalization.text("iCloud 服务暂时繁忙，稍后会自动重试。")
        default:
            if !error.localizedDescription.isEmpty,
               error.localizedDescription != "The operation couldn’t be completed." {
                return AppLocalization.format("cloud.backup_error", error.localizedDescription)
            }
            return AppLocalization.text("云端备份暂时失败，请稍后重试。")
        }
    }
}
#else
actor CloudKitVaultSyncCoordinator {
    init(
        containerIdentifier: String = "iCloud.com.blizzard1311.yiji",
        userDefaults: UserDefaults = .standard
    ) {}

    func synchronize(localVault: PersistedVault) -> PersistedVault {
        localVault
    }

    func refreshStatus() -> CloudSyncStatusSnapshot {
        CloudSyncStatusSnapshot(
            availability: .disabled,
            lastSuccessfulSyncDate: nil,
            lastErrorDescription: nil
        )
    }
}
#endif
