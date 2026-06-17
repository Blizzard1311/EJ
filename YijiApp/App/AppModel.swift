import Foundation
import Combine
import OSLog
import YijiCore

@MainActor
final class AppModel: ObservableObject {
    private let freeRecordLimit = 30
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.blizzard1311.yiji",
        category: "AppModel"
    )
    private let repository: FileBackedVaultStore
    private let parser = RecordParser()
    private let calendar = Calendar(identifier: .gregorian)
    private var statusRevision = 0
    private var statusClearTask: Task<Void, Never>?
    private var focusRevision = 0
    private var focusClearTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []
    private var hasUserEditedVoiceDraft = false

    let speech = SpeechTranscriber()
    let notifications = LocalNotificationScheduler()

    @Published var records: [YijiCore.Record] = []
    @Published var reminders: [Reminder] = []
    @Published var captureText = ""
    @Published var draftSource: CaptureSource = .text
    @Published var selectedTab: AppTab = .home
    @Published var searchText = ""
    @Published var searchHistory: [String] = []
    @Published var exportURL: URL?
    @Published var statusMessage: String?
    @Published var focusedRecordID: UUID?
    @Published var focusedRecordBadgeText: String?
    @Published private(set) var lastRecognizedVoiceText: String?

    init(repository: FileBackedVaultStore = FileBackedVaultStore()) {
        self.repository = repository
        bindChildObjects()

        speech.onTranscript = { [weak self] transcript in
            guard let self else { return }
            self.applyVoiceTranscript(transcript)
        }

        speech.onFinalTranscript = { [weak self] transcript in
            guard let self else { return }
            self.handleFinalVoiceTranscript(transcript)
        }
    }

    func load() async {
        do {
            let snapshot = try await repository.load()
            records = snapshot.records
            reminders = snapshot.reminders
            searchHistory = snapshot.searchHistory
            let cleanedLegacyReminderCount = await cleanupLegacyFailedReminderArtifacts()
            if cleanedLegacyReminderCount > 0 {
                showTransientStatus("已清理 \(cleanedLegacyReminderCount) 条旧错误提醒和关联记录。", seconds: 4.5)
            } else if statusMessage == nil {
                clearStatusMessage()
            }
        } catch {
            showPersistentStatus("读取本地数据失败：\(error.localizedDescription)")
        }

        speech.refreshAuthorizationStatus()
        await refreshReminderStates()
    }

    func preview(for text: String) -> ParsedCapture? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return parser.parse(content: trimmed, source: draftSource, now: Date(), calendar: calendar)
    }

    func saveCapture() async {
        guard let parsed = preview(for: captureText) else { return }
        if let warning = parsed.warnings.first {
            showPersistentStatus(warning)
            return
        }
        guard canSaveAdditionalRecord else {
            showPersistentStatus("当前版本最多可记录 30 条。")
            return
        }
        do {
            let snapshot = try await repository.save(parsed)
            records = snapshot.records
            reminders = snapshot.reminders
            captureText = ""
            focusRecord(parsed.record.id, badgeText: "刚保存")
            if draftSource == .voice {
                speech.resetTranscript()
            }
            if parsed.reminder != nil {
                if let reminder = parsed.reminder {
                    await scheduleNotification(for: reminder, successMessage: "提醒内容已保存，并已同步到本地通知。")
                }
            } else {
                showTransientStatus("记录已保存到本地。")
            }
        } catch {
            showPersistentStatus("保存失败：\(error.localizedDescription)")
        }
    }

    func startVoiceCapture() {
        draftSource = .voice
        hasUserEditedVoiceDraft = false
        lastRecognizedVoiceText = nil
        clearStatusMessage()
        speech.startRecording()
    }

    func stopVoiceCapture() {
        speech.stopRecording()
    }

    func submitCaptureDraft() async {
        let trimmed = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        draftSource = .voice

        if SearchIntentClassifier.isSearchQuery(trimmed) {
            activateSearch(trimmed, navigateToRecords: true)
            captureText = ""
            speech.resetTranscript()
            return
        }

        await saveCapture()
    }

    func clearCaptureDraft() {
        captureText = ""
        draftSource = .text
        hasUserEditedVoiceDraft = false
        lastRecognizedVoiceText = nil
        speech.resetTranscript()
        clearStatusMessage()
    }

    func updateCaptureDraftText(_ text: String) {
        captureText = text

        guard draftSource == .voice, !speech.isRecording else { return }

        let normalizedDraft = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRecognized = lastRecognizedVoiceText?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        hasUserEditedVoiceDraft = normalizedDraft != normalizedRecognized
    }

    func refreshReminderStates() async {
        await notifications.refreshAuthorizationStatus()
        await reconcileReminderStatuses()
        await notifications.sync(reminders: reminders)
    }

    private func handleFinalVoiceTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        applyVoiceTranscript(trimmed)
    }

    private func applyVoiceTranscript(_ transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        draftSource = .voice
        lastRecognizedVoiceText = trimmed.isEmpty ? nil : trimmed

        guard !hasUserEditedVoiceDraft || speech.isRecording else { return }
        captureText = trimmed
    }

    func requestNotificationAccess() async {
        do {
            try await notifications.ensureAuthorization()
            await notifications.sync(reminders: reminders)
            showTransientStatus("通知权限已开启。后续提醒会同步到系统通知。")
        } catch {
            showPersistentStatus("通知权限未开启：\(error.localizedDescription)")
        }
    }

    func sendTestNotification() async {
        do {
            try await notifications.scheduleTestNotification()
            await notifications.refreshScheduledIdentifiers()
            showTransientStatus("测试通知已创建，预计 10 秒后送达。")
        } catch {
            showPersistentStatus("测试通知发送失败：\(error.localizedDescription)")
        }
    }

    func prepareExportFile() async {
        do {
            exportURL = try await repository.exportBackupFile()
            showTransientStatus("本地备份文件已生成，可以直接分享或保存。")
        } catch {
            exportURL = nil
            showPersistentStatus("导出备份失败：\(error.localizedDescription)")
        }
    }

    func importBackupFile(from url: URL) async {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let snapshot = try await repository.importBackupFile(from: url)
            records = snapshot.records
            reminders = snapshot.reminders
            searchHistory = snapshot.searchHistory
            let cleanedLegacyReminderCount = await cleanupLegacyFailedReminderArtifacts()
            captureText = ""
            searchText = ""
            exportURL = nil
            await notifications.sync(reminders: reminders)
            if let latestRecordID = records.first?.id {
                focusRecord(latestRecordID, badgeText: "已导入")
            } else {
                selectedTab = .home
                clearFocusedRecord()
            }
            let message = cleanedLegacyReminderCount > 0
                ? "备份已导入，并清理了 \(cleanedLegacyReminderCount) 条旧错误提醒。"
                : "备份已导入，当前记录、提醒和本地通知已同步更新。"
            if statusMessage == nil {
                showTransientStatus(message)
            }
        } catch {
            showPersistentStatus("导入备份失败：\(error.localizedDescription)")
        }
    }

    func updateReminder(_ reminder: Reminder) async -> Bool {
        do {
            let snapshot = try await repository.updateReminder(reminder)
            reminders = snapshot.reminders
            records = snapshot.records
            await syncNotification(for: reminder, successMessage: "提醒已更新。")
            return true
        } catch {
            showPersistentStatus("更新提醒失败：\(error.localizedDescription)")
            return false
        }
    }

    func setReminderStatus(_ reminder: Reminder, status: ReminderStatus) async {
        var updated = reminder
        updated.status = status
        _ = await updateReminder(updated)
    }

    func deleteReminder(id: UUID) async {
        do {
            let snapshot = try await repository.deleteReminder(id: id)
            reminders = snapshot.reminders
            records = snapshot.records
            notifications.cancel(reminderID: id)
            showTransientStatus("提醒已删除。")
        } catch {
            showPersistentStatus("删除提醒失败：\(error.localizedDescription)")
        }
    }

    func deleteRecord(id: UUID) async {
        let linkedReminderIDs = reminders
            .filter { $0.recordID == id }
            .map(\.id)

        do {
            let snapshot = try await repository.deleteRecord(id: id)
            records = snapshot.records
            reminders = snapshot.reminders
            if focusedRecordID == id {
                clearFocusedRecord()
            }

            for reminderID in linkedReminderIDs {
                notifications.cancel(reminderID: reminderID)
            }

            showTransientStatus(
                linkedReminderIDs.isEmpty
                    ? "记录已删除。"
                    : "记录和关联提醒已删除。"
            )
        } catch {
            showPersistentStatus("删除记录失败：\(error.localizedDescription)")
        }
    }

    func record(for reminder: Reminder) -> YijiCore.Record? {
        guard let recordID = reminder.recordID else { return nil }
        return records.first(where: { $0.id == recordID })
    }

    func reminder(for record: YijiCore.Record) -> Reminder? {
        reminders.first(where: { $0.recordID == record.id })
    }

    var recentRecords: [YijiCore.Record] {
        Array(records.prefix(5))
    }

    var reminderHighlights: [Reminder] {
        reminders.filter { $0.status == .pending }.prefix(5).map { $0 }
    }

    var searchResults: [YijiCore.Record] {
        RecordSearch.query(searchText, in: records)
    }

    func activateSearch(_ term: String, navigateToRecords: Bool = false) {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        searchText = normalized
        registerSearchTerm(normalized)
        clearStatusMessage()

        if navigateToRecords {
            selectedTab = .capture
        }
    }

    func clearActiveSearch() {
        searchText = ""
    }

    func registerSearchTerm(_ term: String) {
        let normalized = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }

        searchHistory.removeAll { $0.caseInsensitiveCompare(normalized) == .orderedSame }
        searchHistory.insert(normalized, at: 0)
        if searchHistory.count > 8 {
            searchHistory = Array(searchHistory.prefix(8))
        }
        persistSearchHistory()
    }

    func removeSearchTerm(_ term: String) {
        searchHistory.removeAll { $0.caseInsensitiveCompare(term) == .orderedSame }
        persistSearchHistory()
    }

    func clearSearchHistory() {
        searchHistory.removeAll()
        persistSearchHistory()
    }

    var pendingReminders: [Reminder] {
        reminders.filter { $0.status == .pending }
    }

    var archivedReminders: [Reminder] {
        reminders.filter { $0.status != .pending }
    }

    func showPersistentStatus(_ message: String) {
        presentStatus(message, autoClearAfterNanoseconds: nil)
    }

    func showTransientStatus(_ message: String, seconds: Double = 3.0) {
        let nanoseconds = UInt64(max(1, seconds) * 1_000_000_000)
        presentStatus(message, autoClearAfterNanoseconds: nanoseconds)
    }

    func clearStatusMessage() {
        presentStatus(nil, autoClearAfterNanoseconds: nil)
    }

    private var canSaveAdditionalRecord: Bool {
        records.count < freeRecordLimit
    }

    private func scheduleNotification(for reminder: Reminder, successMessage: String) async {
        do {
            try await notifications.schedule(reminder: reminder)
            showTransientStatus(successMessage)
        } catch {
            if let schedulerError = error as? LocalNotificationScheduler.SchedulerError,
               schedulerError == .pastDue {
                logger.error(
                    "scheduleNotification failed with pastDue reminderID=\(reminder.id.uuidString, privacy: .public) remindAt=\(reminder.remindAt.formatted(date: .numeric, time: .shortened), privacy: .public)"
                )
                await markReminderFailed(reminder, message: "提醒时间已过，已标记为失败。")
            } else {
                logger.error(
                    "scheduleNotification failed reminderID=\(reminder.id.uuidString, privacy: .public) description=\(error.localizedDescription, privacy: .public)"
                )
                showPersistentStatus("提醒已保存，但本地通知创建失败：\(error.localizedDescription)")
            }
        }
    }

    private func syncNotification(for reminder: Reminder, successMessage: String) async {
        if reminder.status == .pending {
            await scheduleNotification(for: reminder, successMessage: successMessage)
        } else {
            notifications.cancel(reminderID: reminder.id)
            showTransientStatus(successMessage)
        }
    }

    private func reconcileReminderStatuses() async {
        let expired = reminders.filter {
            $0.status == .pending && $0.repeatRule == .none && $0.remindAt <= Date()
        }

        guard !expired.isEmpty else { return }

        for reminder in expired {
            var updatedReminder = reminder
            updatedReminder.status = notifications.authorizationStatus == .granted ? .notified : .failed

            if let snapshot = try? await repository.updateReminder(updatedReminder) {
                reminders = snapshot.reminders
                records = snapshot.records
            }
        }
    }

    private func cleanupLegacyFailedReminderArtifacts() async -> Int {
        let legacyReminders = reminders.filter(isLegacyFailedReminderArtifact)
        guard !legacyReminders.isEmpty else { return 0 }

        let legacyReminderIDs = Set(legacyReminders.map(\.id))
        let linkedRecordIDs = Set(legacyReminders.compactMap(\.recordID))

        do {
            let snapshot = try await repository.replace(
                records: records.filter { !linkedRecordIDs.contains($0.id) },
                reminders: reminders.filter { !legacyReminderIDs.contains($0.id) },
                searchHistory: searchHistory
            )
            reminders = snapshot.reminders
            records = snapshot.records
            return legacyReminders.count
        } catch {
            showPersistentStatus("清理旧错误提醒失败：\(error.localizedDescription)")
            return 0
        }
    }

    // Early voice reminder builds could save "now" as remindAt when time parsing failed.
    private func isLegacyFailedReminderArtifact(_ reminder: Reminder) -> Bool {
        guard reminder.status == .failed, !reminder.body.isEmpty else {
            return false
        }

        let reparsed = parser.parse(
            content: reminder.body,
            source: .voice,
            now: reminder.createdAt,
            calendar: calendar
        )
        guard let reparsedReminder = reparsed.reminder else {
            return false
        }

        let drift = abs(reparsedReminder.remindAt.timeIntervalSince(reminder.remindAt))
        return drift >= 60
    }

    private func markReminderFailed(_ reminder: Reminder, message: String) async {
        var failedReminder = reminder
        failedReminder.status = .failed

        do {
            let snapshot = try await repository.updateReminder(failedReminder)
            reminders = snapshot.reminders
            records = snapshot.records
            notifications.cancel(reminderID: reminder.id)
            showPersistentStatus(message)
        } catch {
            showPersistentStatus("提醒状态更新失败：\(error.localizedDescription)")
        }
    }

    private func persistSearchHistory() {
        let currentHistory = searchHistory

        Task {
            _ = try? await repository.updateSearchHistory(currentHistory)
        }
    }

    private func focusRecord(_ recordID: UUID, badgeText: String) {
        focusRevision += 1
        let revision = focusRevision

        focusClearTask?.cancel()
        focusClearTask = nil
        focusedRecordID = recordID
        focusedRecordBadgeText = badgeText

        focusClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 4_000_000_000)
            } catch {
                return
            }

            await MainActor.run {
                self?.clearFocusedRecordIfCurrent(recordID, revision: revision)
            }
        }
    }

    private func presentStatus(_ message: String?, autoClearAfterNanoseconds: UInt64?) {
        statusRevision += 1
        let revision = statusRevision

        statusClearTask?.cancel()
        statusClearTask = nil
        statusMessage = message

        guard message != nil, let autoClearAfterNanoseconds else { return }

        statusClearTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: autoClearAfterNanoseconds)
            } catch {
                return
            }

            await MainActor.run {
                self?.clearStatusMessageIfCurrent(revision)
            }
        }
    }

    private func clearStatusMessageIfCurrent(_ revision: Int) {
        guard statusRevision == revision else { return }
        statusMessage = nil
        statusClearTask = nil
    }

    private func clearFocusedRecord() {
        focusedRecordID = nil
        focusedRecordBadgeText = nil
        focusClearTask?.cancel()
        focusClearTask = nil
    }

    private func clearFocusedRecordIfCurrent(_ recordID: UUID, revision: Int) {
        guard focusedRecordID == recordID, focusRevision == revision else { return }
        clearFocusedRecord()
    }

    private func bindChildObjects() {
        speech.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        notifications.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
