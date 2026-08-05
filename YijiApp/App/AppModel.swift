import Foundation
import Combine
import OSLog
import YijiCore

struct StorageContainerDefinition: Identifiable, Codable, Hashable, Sendable {
    var id: String
    var name: String
    var builtInRawValue: String?

    init(id: String, name: String, builtInRawValue: String? = nil) {
        self.id = id
        self.name = name
        self.builtInRawValue = builtInRawValue
    }

    init(builtIn container: StorageContainer, name: String? = nil) {
        self.id = container.rawValue
        self.name = name ?? container.displayName
        self.builtInRawValue = container.rawValue
    }

    init(customName: String) {
        self.id = "custom-\(UUID().uuidString.lowercased())"
        self.name = customName
        self.builtInRawValue = nil
    }

    var builtInContainer: StorageContainer? {
        builtInRawValue.flatMap(StorageContainer.init(rawValue:))
    }

    var displayName: String {
        if let builtInContainer {
            return builtInContainer.displayName
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return builtInContainer?.displayName ?? AppLocalization.text("未命名容器")
    }

    var isCustom: Bool {
        builtInContainer == nil
    }
}

@MainActor
final class AppModel: ObservableObject {
    private static let lastBackupDateKey = "yiji.lastBackupDate"
    private static let visibleStorageContainersKey = "yiji.visibleStorageContainers"
    private static let storageContainerDefinitionsKey = "yiji.storageContainerDefinitions"
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.blizzard1311.yiji",
        category: "AppModel"
    )
    private let repository: FileBackedVaultStore
    private let parser = RecordParser()
    private let calendar = Calendar(identifier: .gregorian)
    private var cloudSyncDateFormatter: DateFormatter {
        YijiDateFormatter.dateTimeFormatter
    }
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
    @Published var selectedTab: AppTab = {
        switch ProcessInfo.processInfo.environment["YIJI_START_TAB"] {
        case "homeView":
            return .capture
        case "calendar":
            return .calendar
        default:
            return .home
        }
    }()
    @Published var searchText = ""
    @Published var searchHistory: [String] = []
    @Published private(set) var appLanguage = AppLocalization.selectedLanguage
    @Published var exportURL: URL?
    @Published var statusMessage: String?
    @Published var focusedRecordID: UUID?
    @Published var focusedRecordBadgeText: String?
    @Published private(set) var storageContainerDefinitions: [StorageContainerDefinition]
    @Published private(set) var lastBackupDate: Date?
    @Published private(set) var lastRecognizedVoiceText: String?
    @Published private(set) var cloudSyncStatusDetail = AppLocalization.text(
        AppReleaseConfiguration.cloudSyncEnabled
            ? "正在检查 iCloud 同步状态"
            : "当前版本使用本机存储与手动备份"
    )

    init(repository: FileBackedVaultStore = FileBackedVaultStore()) {
        self.repository = repository
        self.storageContainerDefinitions = Self.loadStorageContainerDefinitions()
        self.lastBackupDate = UserDefaults.standard.object(forKey: Self.lastBackupDateKey) as? Date
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

    func selectAppLanguage(_ language: AppLanguage) {
        guard appLanguage != language else { return }
        AppLocalization.selectedLanguage = language
        appLanguage = language
        statusMessage = nil
        focusedRecordBadgeText = nil
        speech.refreshRecognitionLanguage()
        cloudSyncStatusDetail = AppLocalization.text(
            AppReleaseConfiguration.cloudSyncEnabled
                ? "正在检查 iCloud 同步状态"
                : "当前版本使用本机存储与手动备份"
        )

        Task { [weak self] in
            await self?.refreshCloudSyncStatus()
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
                showTransientStatus("已整理历史提醒。", seconds: 4.5)
            } else if statusMessage == nil {
                clearStatusMessage()
            }
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("读取本地数据失败"), error.localizedDescription))
        }

        speech.refreshAuthorizationStatus()
        await refreshReminderStates()
        await refreshCloudSyncStatus()
    }

    func refreshCloudSnapshot() async {
        do {
            let snapshot = try await repository.refreshFromCloud()
            records = snapshot.records
            reminders = snapshot.reminders
            searchHistory = snapshot.searchHistory
            await notifications.sync(reminders: reminders)
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("刷新 iCloud 数据失败"), error.localizedDescription))
        }

        await refreshCloudSyncStatus()
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
        do {
            let snapshot = try await repository.save(parsed)
            records = snapshot.records
            reminders = snapshot.reminders
            captureText = ""
            lastRecognizedVoiceText = nil
            focusRecord(parsed.record.id, badgeText: "刚保存")
            if draftSource == .voice {
                speech.resetTranscript()
            }
            if parsed.reminder != nil {
                if let reminder = parsed.reminder {
                    await scheduleNotification(for: reminder, successMessage: "已记录")
                }
            } else {
                showTransientStatus("已记录")
            }
            await refreshCloudSyncStatus()
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("保存失败"), error.localizedDescription))
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
            lastRecognizedVoiceText = nil
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
            showTransientStatus("通知权限已开启。")
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("通知权限未开启"), error.localizedDescription))
        }
    }

    func prepareExportFile() async {
        do {
            exportURL = try await repository.exportBackupFile()
            persistLastBackupDate(Date())
            showTransientStatus("本地备份文件已生成，可以直接分享或保存。")
        } catch {
            exportURL = nil
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("导出备份失败"), error.localizedDescription))
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
                ? "备份已导入，历史提醒已整理。"
                : "备份已导入，当前记录、提醒和本地通知已同步更新。"
            if statusMessage == nil {
                showTransientStatus(message)
            }
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("导入备份失败"), error.localizedDescription))
        }

        await refreshCloudSyncStatus()
    }

    func updateReminder(_ reminder: Reminder) async -> Bool {
        do {
            let snapshot = try await repository.updateReminder(reminder)
            reminders = snapshot.reminders
            records = snapshot.records
            await syncNotification(for: reminder, successMessage: "提醒已更新。")
            await refreshCloudSyncStatus()
            return true
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("更新提醒失败"), error.localizedDescription))
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
            await refreshCloudSyncStatus()
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("删除提醒失败"), error.localizedDescription))
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
            await refreshCloudSyncStatus()
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("删除记录失败"), error.localizedDescription))
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

    var nextPendingReminder: Reminder? {
        pendingReminders.min { lhs, rhs in
            if lhs.remindAt == rhs.remindAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.remindAt < rhs.remindAt
        }
    }

    func refreshNotificationStatus() async {
        await notifications.refreshAuthorizationStatus()
        await notifications.refreshScheduledIdentifiers()
    }

    var availableBuiltInStorageContainers: [StorageContainer] {
        let configuredBuiltIns = Set(storageContainerDefinitions.compactMap(\.builtInContainer))
        return StorageContainer.allCases.filter { !configuredBuiltIns.contains($0) }
    }

    func addBuiltInStorageContainer(_ container: StorageContainer) {
        guard !storageContainerDefinitions.contains(where: { $0.builtInContainer == container }) else {
            return
        }

        var updated = storageContainerDefinitions
        updated.append(StorageContainerDefinition(builtIn: container))
        applyStorageContainerDefinitions(updated)
    }

    func addCustomStorageContainer(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showTransientStatus("请输入容器名称。")
            return
        }

        guard !storageContainerDefinitions.contains(where: { $0.displayName == trimmed }) else {
            showTransientStatus("容器名称已存在。")
            return
        }

        var updated = storageContainerDefinitions
        updated.append(StorageContainerDefinition(customName: trimmed))
        applyStorageContainerDefinitions(updated)
    }

    func updateStorageContainerName(_ name: String, for definitionID: String) {
        guard let index = storageContainerDefinitions.firstIndex(where: { $0.id == definitionID }) else {
            return
        }

        storageContainerDefinitions[index].name = name
        persistStorageContainerDefinitions(storageContainerDefinitions)
        objectWillChange.send()
    }

    func removeStorageContainerDefinition(_ definitionID: String) {
        storageContainerDefinitions.removeAll { $0.id == definitionID }
        persistStorageContainerDefinitions(storageContainerDefinitions)
    }

    func resetStorageContainerDefinitions() {
        applyStorageContainerDefinitions(Self.defaultStorageContainerDefinitions)
    }

    func storageContainerDefinition(for container: StorageContainer) -> StorageContainerDefinition? {
        storageContainerDefinitions.first { $0.builtInContainer == container }
    }

    func matchingCustomStorageContainerDefinition(for record: YijiCore.Record) -> StorageContainerDefinition? {
        let customDefinitions = storageContainerDefinitions
            .filter(\.isCustom)
            .sorted { $0.displayName.count > $1.displayName.count }

        guard !customDefinitions.isEmpty else {
            return nil
        }

        let haystack = [
            record.objectName,
            record.location,
            Optional(record.content)
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        .joined(separator: " ")

        guard !haystack.isEmpty else {
            return nil
        }

        return customDefinitions.first { definition in
            let keyword = definition.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !keyword.isEmpty else {
                return false
            }
            return haystack.contains(keyword)
        }
    }

    func showPersistentStatus(_ message: String) {
        presentStatus(AppLocalization.text(message), autoClearAfterNanoseconds: nil)
    }

    func showTransientStatus(_ message: String, seconds: Double = 3.0) {
        let nanoseconds = UInt64(max(1, seconds) * 1_000_000_000)
        presentStatus(AppLocalization.text(message), autoClearAfterNanoseconds: nanoseconds)
    }

    func clearStatusMessage() {
        presentStatus(nil, autoClearAfterNanoseconds: nil)
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
                showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("提醒已保存，但本地通知创建失败"), error.localizedDescription))
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
                await refreshCloudSyncStatus()
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
            await refreshCloudSyncStatus()
            return legacyReminders.count
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("清理旧错误提醒失败"), error.localizedDescription))
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
            await refreshCloudSyncStatus()
        } catch {
            showPersistentStatus(AppLocalization.format("error.with_detail", AppLocalization.text("提醒状态更新失败"), error.localizedDescription))
        }
    }

    private func persistSearchHistory() {
        let currentHistory = searchHistory

        Task {
            _ = try? await repository.updateSearchHistory(currentHistory)
            await self.refreshCloudSyncStatus()
        }
    }

    private func refreshCloudSyncStatus() async {
        let status = await repository.cloudSyncStatus()
        switch status.availability {
        case .available:
            if let lastSuccessfulSyncDate = status.lastSuccessfulSyncDate {
                cloudSyncStatusDetail = AppLocalization.format(
                    "cloud.last_sync",
                    cloudSyncDateFormatter.string(from: lastSuccessfulSyncDate)
                )
            } else if let lastErrorDescription = status.lastErrorDescription, !lastErrorDescription.isEmpty {
                cloudSyncStatusDetail = AppLocalization.format("cloud.backup_failed", lastErrorDescription)
            } else {
                cloudSyncStatusDetail = AppLocalization.text("已连接 iCloud · 等待首次同步")
            }
        case .noAccount:
            cloudSyncStatusDetail = AppLocalization.text("未登录 iCloud，当前仅保留本机数据")
        case .restricted:
            cloudSyncStatusDetail = AppLocalization.text("当前设备无法使用 iCloud，当前仅保留本机数据")
        case .temporarilyUnavailable:
            cloudSyncStatusDetail = AppLocalization.text("iCloud 暂时不可用，稍后会自动重试")
        case .unknown:
            if let lastErrorDescription = status.lastErrorDescription, !lastErrorDescription.isEmpty {
                cloudSyncStatusDetail = AppLocalization.format("cloud.status_failed", lastErrorDescription)
            } else {
                cloudSyncStatusDetail = AppLocalization.text("iCloud 同步状态暂时不可用")
            }
        case .disabled:
            cloudSyncStatusDetail = AppLocalization.text("当前版本使用本机存储与手动备份")
        }
    }

    private func applyStorageContainerDefinitions(_ definitions: [StorageContainerDefinition]) {
        let normalized = Self.normalizeStorageContainerDefinitions(definitions)
        storageContainerDefinitions = normalized
        persistStorageContainerDefinitions(normalized)
    }

    private func persistStorageContainerDefinitions(_ definitions: [StorageContainerDefinition]) {
        guard let data = try? JSONEncoder().encode(definitions) else {
            return
        }
        UserDefaults.standard.set(data, forKey: Self.storageContainerDefinitionsKey)
    }

    private func persistLastBackupDate(_ date: Date) {
        lastBackupDate = date
        UserDefaults.standard.set(date, forKey: Self.lastBackupDateKey)
    }

    private func focusRecord(_ recordID: UUID, badgeText: String) {
        focusRevision += 1
        let revision = focusRevision

        focusClearTask?.cancel()
        focusClearTask = nil
        focusedRecordID = recordID
        focusedRecordBadgeText = AppLocalization.text(badgeText)

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

    private static var defaultStorageContainerDefinitions: [StorageContainerDefinition] {
        [
            StorageContainerDefinition(builtIn: .documentPouch),
            StorageContainerDefinition(builtIn: .medicineKit),
            StorageContainerDefinition(builtIn: .digitalBox),
            StorageContainerDefinition(builtIn: .wardrobe),
            StorageContainerDefinition(builtIn: .bag)
        ]
    }

    private static func loadStorageContainerDefinitions() -> [StorageContainerDefinition] {
        if let data = UserDefaults.standard.data(forKey: storageContainerDefinitionsKey),
           let definitions = try? JSONDecoder().decode([StorageContainerDefinition].self, from: data) {
            return normalizeStorageContainerDefinitions(definitions)
        }

        if let rawValues = UserDefaults.standard.array(forKey: visibleStorageContainersKey) as? [String] {
            let migrated = rawValues
                .compactMap(StorageContainer.init(rawValue:))
                .map { StorageContainerDefinition(builtIn: $0) }
            return normalizeStorageContainerDefinitions(migrated)
        }

        return defaultStorageContainerDefinitions
    }

    private static func normalizeStorageContainerDefinitions(_ definitions: [StorageContainerDefinition]) -> [StorageContainerDefinition] {
        var seen = Set<String>()
        var normalized: [StorageContainerDefinition] = []

        for definition in definitions {
            guard !seen.contains(definition.id) else {
                continue
            }

            if let rawValue = definition.builtInRawValue,
               StorageContainer(rawValue: rawValue) == nil {
                continue
            }

            normalized.append(definition)
            seen.insert(definition.id)
        }

        return normalized
    }
}
