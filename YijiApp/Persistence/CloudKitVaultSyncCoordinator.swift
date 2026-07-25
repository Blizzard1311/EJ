import CloudKit
import Foundation
import OSLog

struct CloudSyncStatusSnapshot: Sendable {
    enum Availability: Sendable {
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case unknown
    }

    var availability: Availability
    var lastSuccessfulSyncDate: Date?
    var lastErrorDescription: String?
}

actor CloudKitVaultSyncCoordinator {
    private enum Constants {
        static let containerIdentifier = "iCloud.com.blizzard1311.yiji"
        static let recordType = "VaultState"
        static let recordName = "primary"
        static let payloadField = "payload"
        static let modifiedAtField = "modifiedAt"
        static let lastWriterDeviceIDField = "lastWriterDeviceID"
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

    private var lastKnownAvailability: CloudSyncStatusSnapshot.Availability = .unknown
    private var lastSuccessfulSyncDate: Date?
    private var lastErrorDescription: String?

    init(containerIdentifier: String = Constants.containerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.database = self.container.privateCloudDatabase
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func synchronize(localVault: PersistedVault) async -> PersistedVault {
        let normalizedLocalVault = normalized(localVault)

        do {
            let availability = try await refreshAvailability()
            guard availability == .available else {
                return normalizedLocalVault
            }

            let remoteRecord = try await fetchRemoteRecord()
            switch remoteRecord {
            case .none:
                guard normalizedLocalVault.hasUserContent else {
                    markSuccess()
                    return normalizedLocalVault
                }

                let savedVault = try await saveVault(normalizedLocalVault, using: nil)
                markSuccess()
                return savedVault

            case .some(let record):
                let remoteVault = try decodeVault(from: record)
                if remoteVault.resolvedModifiedAt > normalizedLocalVault.resolvedModifiedAt {
                    markSuccess()
                    return remoteVault
                }

                let savedVault = try await saveVault(normalizedLocalVault, using: record)
                markSuccess()
                return savedVault
            }
        } catch {
            logger.error("Cloud sync failed: \(error.localizedDescription, privacy: .public)")
            lastErrorDescription = error.localizedDescription
            return normalizedLocalVault
        }
    }

    func refreshStatus() async -> CloudSyncStatusSnapshot {
        do {
            _ = try await refreshAvailability()
        } catch {
            lastErrorDescription = error.localizedDescription
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
        lastSuccessfulSyncDate = Date()
        lastErrorDescription = nil
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
                return remoteVault
            }

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
}
