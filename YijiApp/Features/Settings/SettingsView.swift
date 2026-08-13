import SwiftUI
import UIKit
import CoreLocation
import UniformTypeIdentifiers
import YijiCore

struct SettingsView: View {
    private enum LocalDataCategory {
        case records
        case reminders
        case expenses
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var showingImportPicker = false
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    @State private var showingLanguageSettings = false
    @State private var showingPrivacySettings = false
    @State private var showingBackupSettings = false
    @State private var selectedLocalDataCategory: LocalDataCategory?
    private let locationManager = CLLocationManager()
    private var backupDateFormatter: DateFormatter {
        YijiDateFormatter.dateTimeFormatter
    }

    var body: some View {
        List {
            pageTitleSection
            localModeSection
            preferencesSection
            dataSection
            supportSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 16)
        }
        .navigationDestination(isPresented: $showingLanguageSettings) {
            languageSettingsView
        }
        .navigationDestination(isPresented: $showingPrivacySettings) {
            privacySettingsView
        }
        .navigationDestination(isPresented: $showingBackupSettings) {
            backupSettingsView
        }
        .navigationDestination(
            isPresented: Binding(
                get: { selectedLocalDataCategory != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedLocalDataCategory = nil
                    }
                }
            )
        ) {
            switch selectedLocalDataCategory {
            case .records:
                LocalRecordsDataView()
            case .reminders:
                LocalRemindersDataView()
            case .expenses:
                LocalExpensesDataView()
            case .none:
                EmptyView()
            }
        }
        .task {
            appModel.speech.refreshAuthorizationStatus()
            await appModel.refreshNotificationStatus()
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pendingImportURL = url
                showingImportConfirmation = true
            case .failure(let error):
                appModel.showPersistentStatus(
                    AppLocalization.format("error.with_detail", AppLocalization.text("选择备份文件失败"), error.localizedDescription)
                )
            }
        }
        .confirmationDialog(
            AppLocalization.text("导入会覆盖当前本地记录、提醒、账目和通知安排。"),
            isPresented: $showingImportConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("覆盖导入"), role: .destructive) {
                guard let pendingImportURL else { return }
                Task {
                    await appModel.importBackupFile(from: pendingImportURL)
                    self.pendingImportURL = nil
                }
            }
            Button(AppLocalization.text("取消"), role: .cancel) {
                pendingImportURL = nil
            }
        } message: {
            Text(pendingImportURL?.lastPathComponent ?? AppLocalization.text("请选择一个 JSON 备份文件。"))
        }
    }

    private var screenBackground: some View {
        AppTheme.canvas.ignoresSafeArea()
    }

    private var pageTitleSection: some View {
        Section {
            Text(AppLocalization.text("设置"))
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var localModeSection: some View {
        Section {
            settingsCardSection(title: "本机数据") {
                HStack(spacing: 0) {
                    Button {
                        selectedLocalDataCategory = .records
                    } label: {
                        metricCard(title: "记录数量", value: "\(appModel.records.count)")
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button {
                        selectedLocalDataCategory = .reminders
                    } label: {
                        metricCard(title: "提醒", value: "\(appModel.reminders.count)")
                    }
                    .buttonStyle(.plain)

                    Divider()

                    Button {
                        selectedLocalDataCategory = .expenses
                    } label: {
                        metricCard(title: "帐目数量", value: "\(appModel.expenses.count)")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var preferencesSection: some View {
        Section {
            settingsCardSection(title: "偏好设置") {
                Button {
                    showingLanguageSettings = true
                } label: {
                    settingsSummaryRow(
                        title: "语言",
                        value: appModel.appLanguage.displayName,
                        systemImage: "globe"
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    showingPrivacySettings = true
                } label: {
                    settingsSummaryRow(
                        title: "权限与隐私",
                        value: permissionSummary,
                        systemImage: "lock.shield",
                        valueColor: permissionStatusColor(permissionSummary)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var dataSection: some View {
        Section {
            settingsCardSection(title: "备份与恢复") {
                Button {
                    showingBackupSettings = true
                } label: {
                    settingsSummaryRow(
                        title: "上次备份",
                        value: backupSummary,
                        systemImage: "externaldrive"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var languageSettingsView: some View {
        List {
            Section {
                NavigationLink {
                    appLanguageSelectionView
                } label: {
                    detailNavigationRow(
                        title: "App 语言",
                        value: appModel.appLanguage.displayName,
                        systemImage: "globe"
                    )
                }

                NavigationLink {
                    speechLanguageSelectionView
                } label: {
                    detailNavigationRow(
                        title: "语音识别语言",
                        value: appModel.speechLanguage.displayName,
                        systemImage: "waveform"
                    )
                }
            } footer: {
                Text(AppLocalization.text("界面语言更改后立即生效。语音识别语言可以跟随 App，也可以单独选择。"))
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle(Text(AppLocalization.text("语言")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appLanguageSelectionView: some View {
        List {
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        appModel.selectAppLanguage(language)
                    } label: {
                        selectionRow(
                            title: language.displayName,
                            isSelected: appModel.appLanguage == language
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle(Text(AppLocalization.text("App 语言")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var speechLanguageSelectionView: some View {
        List {
            Section {
                ForEach(SpeechLanguage.allCases) { language in
                    Button {
                        appModel.selectSpeechLanguage(language)
                    } label: {
                        selectionRow(
                            title: language.displayName,
                            isSelected: appModel.speechLanguage == language
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle(Text(AppLocalization.text("语音识别语言")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var privacySettingsView: some View {
        List {
            Section {
                permissionDetailRow(
                    title: "语音与麦克风",
                    detail: "用于语音录入",
                    systemImage: "mic",
                    status: appModel.speech.authorizationStatus.displayName
                )

                permissionDetailRow(
                    title: "通知",
                    detail: "用于到期提醒",
                    systemImage: "bell.badge",
                    status: appModel.notifications.authorizationStatus.displayName
                )

                permissionDetailRow(
                    title: "定位",
                    detail: "用于月历天气",
                    systemImage: "location",
                    status: locationAuthorizationDisplayName
                )
            }

            if appModel.notifications.authorizationStatus == .unknown {
                Section {
                    Button {
                        Task {
                            await appModel.requestNotificationAccess()
                        }
                    } label: {
                        settingsActionLabel("开启通知权限", systemImage: "bell.badge")
                    }
                }
            }

            if shouldShowOpenSettingsAction {
                Section {
                    Button {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    } label: {
                        settingsActionLabel("前往系统设置", systemImage: "gearshape")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle(Text(AppLocalization.text("权限与隐私")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var backupSettingsView: some View {
        List {
            if AppReleaseConfiguration.cloudSyncEnabled {
                Section {
                    detailInformationRow(
                        title: "iCloud 同步",
                        detail: appModel.cloudSyncStatusDetail,
                        systemImage: "icloud"
                    )
                }
            }

            Section {
                detailInformationRow(
                    title: "上次备份",
                    detail: backupSummary,
                    systemImage: "externaldrive"
                )
            }

            Section {
                Button {
                    Task {
                        await appModel.prepareExportFile()
                    }
                } label: {
                    settingsActionLabel("生成备份文件", systemImage: "arrow.down.doc")
                }

                Button {
                    showingImportPicker = true
                } label: {
                    settingsActionLabel("导入备份文件", systemImage: "square.and.arrow.down")
                }

                if let exportURL = appModel.exportURL {
                    ShareLink(item: exportURL) {
                        settingsActionLabel("分享备份文件", systemImage: "square.and.arrow.up")
                    }
                }
            }

            Section {
                detailInformationRow(
                    title: "卸载前保护",
                    detail: "如果准备删除 App，仍建议先导出备份文件到“文件”或 iCloud Drive",
                    systemImage: "externaldrive.badge.icloud"
                )
            }

            if let statusMessage = appModel.statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle(Text(AppLocalization.text("备份与恢复")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var supportSection: some View {
        Section {
            settingsCardSection(title: "支持") {
                Button {
                    openURL(AppSupport.privacyURL)
                } label: {
                    actionRow(
                        "隐私政策",
                        detail: "",
                        systemImage: "hand.raised",
                        trailingSystemImage: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    openURL(AppSupport.supportURL)
                } label: {
                    actionRow(
                        "在线支持",
                        detail: "",
                        systemImage: "questionmark.circle",
                        trailingSystemImage: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    openURL(AppSupport.emailURL)
                } label: {
                    actionRow(
                        "联系支持",
                        detail: "",
                        systemImage: "envelope",
                        trailingSystemImage: "arrow.up.right"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 18, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.title3.weight(.semibold))

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            Text(AppLocalization.text(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text(title))
        .accessibilityValue(value)
        .accessibilityAddTraits(.isButton)
    }

    private func settingsSummaryRow(
        title: String,
        value: String,
        systemImage: String,
        valueColor: Color = .secondary
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(systemImage)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.text(title))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(valueColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 18)
                .accessibilityHidden(true)
        }
        .padding(.leading, 14)
        .padding(.trailing, 22)
        .padding(.vertical, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text(title))
        .accessibilityValue(value)
    }

    private func detailNavigationRow(
        title: String,
        value: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(systemImage)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.text(title))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.text(title))
        .accessibilityValue(value)
    }

    private func selectionRow(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityValue(isSelected ? AppLocalization.text("已选择") : "")
    }

    private func permissionDetailRow(
        title: String,
        detail: String,
        systemImage: String,
        status: String
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(systemImage)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.text(title))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(AppLocalization.text(detail))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text(status)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(permissionStatusColor(status))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(permissionStatusColor(status).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func detailInformationRow(
        title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            settingsIcon(systemImage)

            VStack(alignment: .leading, spacing: 5) {
                Text(AppLocalization.text(title))
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(AppLocalization.text(detail))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func settingsActionLabel(_ title: String, systemImage: String) -> some View {
        Label {
            Text(AppLocalization.text(title))
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(AppTheme.accent)
        }
    }

    private func settingsIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(AppTheme.surfaceMuted)
            )
    }

    private func actionRow(
        _ title: String,
        detail: String,
        systemImage: String,
        trailingSystemImage: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            settingsIcon(systemImage)

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.text(title))
                    .font(.subheadline)
                if !detail.isEmpty {
                    Text(AppLocalization.text(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 10)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 58)
        .contentShape(Rectangle())
    }

    private var locationAuthorizationDisplayName: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return AppLocalization.text("已授权")
        case .denied, .restricted:
            return AppLocalization.text("未授权")
        case .notDetermined:
            return AppLocalization.text("未请求")
        @unknown default:
            return AppLocalization.text("未请求")
        }
    }

    private var permissionSummary: String {
        let speechGranted = appModel.speech.authorizationStatus == .granted
        let notificationGranted = appModel.notifications.authorizationStatus == .granted
        let locationGranted = locationManager.authorizationStatus == .authorizedAlways ||
            locationManager.authorizationStatus == .authorizedWhenInUse

        if speechGranted && notificationGranted && locationGranted {
            return AppLocalization.text("已授权")
        }

        let hasDeniedPermission = appModel.speech.authorizationStatus == .denied ||
            appModel.notifications.authorizationStatus == .denied ||
            locationManager.authorizationStatus == .denied ||
            locationManager.authorizationStatus == .restricted

        return AppLocalization.text(hasDeniedPermission ? "未授权" : "未请求")
    }

    private var backupSummary: String {
        appModel.lastBackupDate.map { backupDateFormatter.string(from: $0) }
            ?? AppLocalization.text("暂无备份")
    }

    private var shouldShowOpenSettingsAction: Bool {
        appModel.speech.authorizationStatus == .denied ||
        appModel.notifications.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private func settingsCardSection<Content: View>(
        title: String,
        subtitle: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppLocalization.text(title))
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .padding(.leading, 3)

            if !subtitle.isEmpty {
                Text(AppLocalization.text(subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 3)
            }

            VStack(spacing: 0) {
                content()
            }
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
        }
    }

    private func permissionStatusColor(_ status: String) -> Color {
        switch status {
        case AppLocalization.text("已授权"):
            AppTheme.completed
        case AppLocalization.text("未授权"):
            .red
        default:
            AppTheme.reminder
        }
    }
}

private struct LocalRecordsDataView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var deletingRecord: Record?

    var body: some View {
        List {
            if appModel.records.isEmpty {
                localDataEmptyRow(title: "暂无记录", systemImage: "doc.text")
            } else {
                Section {
                    ForEach(appModel.records) { record in
                        NavigationLink {
                            RecordDetailView(recordID: record.id)
                        } label: {
                            RecordRowView(
                                record: record,
                                reminder: appModel.reminder(for: record)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(AppLocalization.text("删除"), role: .destructive) {
                                deletingRecord = record
                            }
                        }
                    }
                } header: {
                    Text(AppLocalization.format("record_count", appModel.records.count))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(Text(AppLocalization.text("记录数量")))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            AppLocalization.text("删除后将同时移除关联提醒。"),
            isPresented: Binding(
                get: { deletingRecord != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingRecord = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("删除记录"), role: .destructive) {
                guard let record = deletingRecord else { return }
                Task {
                    await appModel.deleteRecord(id: record.id)
                    deletingRecord = nil
                }
            }
            Button(AppLocalization.text("取消"), role: .cancel) {
                deletingRecord = nil
            }
        }
    }
}

private struct LocalRemindersDataView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var deletingReminder: Reminder?

    var body: some View {
        List {
            if appModel.reminders.isEmpty {
                localDataEmptyRow(title: "暂无提醒", systemImage: "bell")
            } else {
                Section {
                    ForEach(appModel.reminders) { reminder in
                        NavigationLink {
                            LocalReminderDataDetailView(reminderID: reminder.id)
                        } label: {
                            LocalReminderDataRow(reminder: reminder)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(AppLocalization.text("删除"), role: .destructive) {
                                deletingReminder = reminder
                            }
                        }
                    }
                } header: {
                    Text(AppLocalization.format("reminder_count", appModel.reminders.count))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(Text(AppLocalization.text("提醒")))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            AppLocalization.text("删除"),
            isPresented: Binding(
                get: { deletingReminder != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingReminder = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("删除"), role: .destructive) {
                guard let reminder = deletingReminder else { return }
                Task {
                    await appModel.deleteReminder(id: reminder.id)
                    deletingReminder = nil
                }
            }
            Button(AppLocalization.text("取消"), role: .cancel) {
                deletingReminder = nil
            }
        }
    }
}

private struct LocalReminderDataRow: View {
    let reminder: Reminder

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: reminder.status == .pending ? "bell.fill" : "bell")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(statusColor)
                .frame(width: 36, height: 36)
                .background(statusColor.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                if !reminder.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(reminder.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(reminder.status.displayName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.12), in: Capsule())
        }
        .padding(.vertical, 3)
    }

    private var statusColor: Color {
        switch reminder.status {
        case .pending:
            AppTheme.reminder
        case .notified:
            AppTheme.accent
        case .done:
            AppTheme.completed
        case .cancelled:
            .gray
        case .failed:
            .red
        }
    }
}

private struct LocalReminderDataDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingReminder: Reminder?
    @State private var showingDeleteConfirmation = false

    let reminderID: UUID

    var body: some View {
        List {
            if let reminder {
                Section(AppLocalization.text("提醒内容")) {
                    localDataValueRow(title: "标题", value: reminder.title)

                    if !reminder.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        localDataValueRow(title: "备注", value: reminder.body)
                    }
                }

                Section(AppLocalization.text("提醒时间")) {
                    localDataValueRow(
                        title: "提醒时间",
                        value: YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt)
                    )
                    localDataValueRow(title: "重复规则", value: reminder.repeatRule.displayName)
                    localDataValueRow(title: "状态", value: reminder.status.displayName)
                }

                if let record = appModel.record(for: reminder) {
                    Section {
                        NavigationLink {
                            RecordDetailView(recordID: record.id)
                        } label: {
                            Label(AppLocalization.text("查看关联记录"), systemImage: "doc.text")
                        }
                    }
                }
            } else {
                localDataEmptyRow(title: "暂无提醒", systemImage: "bell.slash")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(Text(AppLocalization.text("提醒")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let reminder {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(AppLocalization.text("编辑")) {
                        editingReminder = reminder
                    }

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(AppLocalization.text("删除"))
                }
            }
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderEditorView(reminder: reminder) { updated in
                await appModel.updateReminder(updated)
            }
            .environmentObject(appModel)
        }
        .confirmationDialog(
            AppLocalization.text("删除"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("删除"), role: .destructive) {
                Task {
                    await appModel.deleteReminder(id: reminderID)
                    dismiss()
                }
            }
            Button(AppLocalization.text("取消"), role: .cancel) {}
        }
    }

    private var reminder: Reminder? {
        appModel.reminders.first(where: { $0.id == reminderID })
    }
}

private struct LocalExpensesDataView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var deletingExpense: Expense?

    var body: some View {
        List {
            if appModel.expenses.isEmpty {
                localDataEmptyRow(title: "暂无帐目", systemImage: "receipt")
            } else {
                Section {
                    ForEach(appModel.expenses) { expense in
                        NavigationLink {
                            LocalExpenseDataDetailView(expenseID: expense.id)
                        } label: {
                            LocalExpenseDataRow(expense: expense)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(AppLocalization.text("删除"), role: .destructive) {
                                deletingExpense = expense
                            }
                        }
                    }
                } header: {
                    Text(AppLocalization.format("共 %d 笔", appModel.expenses.count))
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(Text(AppLocalization.text("全部帐目")))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            AppLocalization.text("删除"),
            isPresented: Binding(
                get: { deletingExpense != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingExpense = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("删除"), role: .destructive) {
                guard let expense = deletingExpense else { return }
                Task {
                    await appModel.deleteExpense(id: expense.id)
                    deletingExpense = nil
                }
            }
            Button(AppLocalization.text("取消"), role: .cancel) {
                deletingExpense = nil
            }
        }
    }
}

private struct LocalExpenseDataRow: View {
    @EnvironmentObject private var appModel: AppModel
    let expense: Expense

    var body: some View {
        let category = appModel.expenseCategory(for: expense.categoryID)

        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text("\(category.displayName) · \(YijiDateFormatter.dayFormatter.string(from: expense.spentAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(localExpenseCurrencyText(expense))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

private struct LocalExpenseDataDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    let expenseID: UUID

    var body: some View {
        List {
            if let expense {
                let category = appModel.expenseCategory(for: expense.categoryID)

                Section(AppLocalization.text("消费内容")) {
                    localDataValueRow(title: "消费内容", value: expense.title)
                    localDataValueRow(title: "金额", value: localExpenseCurrencyText(expense))
                    localDataValueRow(title: "类别", value: category.displayName)
                    localDataValueRow(
                        title: "日期",
                        value: YijiDateFormatter.dateTimeFormatter.string(from: expense.spentAt)
                    )
                }

                if let originalTranscript = expense.originalTranscript?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !originalTranscript.isEmpty,
                   originalTranscript != expense.title {
                    Section(AppLocalization.text("消费描述")) {
                        Text(originalTranscript)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                }
            } else {
                localDataEmptyRow(title: "暂无帐目", systemImage: "receipt")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(Text(AppLocalization.text("全部帐目")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if expense != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel(AppLocalization.text("删除"))
                }
            }
        }
        .confirmationDialog(
            AppLocalization.text("删除"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(AppLocalization.text("删除"), role: .destructive) {
                Task {
                    await appModel.deleteExpense(id: expenseID)
                    dismiss()
                }
            }
            Button(AppLocalization.text("取消"), role: .cancel) {}
        }
    }

    private var expense: Expense? {
        appModel.expenses.first(where: { $0.id == expenseID })
    }
}

private func localDataValueRow(title: String, value: String) -> some View {
    LabeledContent {
        Text(value)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.trailing)
            .textSelection(.enabled)
    } label: {
        Text(AppLocalization.text(title))
            .foregroundStyle(.secondary)
    }
}

private func localDataEmptyRow(title: String, systemImage: String) -> some View {
    VStack(spacing: 10) {
        Image(systemName: systemImage)
            .font(.system(size: 30, weight: .light))
            .foregroundStyle(.tertiary)
        Text(AppLocalization.text(title))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 36)
    .listRowBackground(Color.clear)
}

private func localExpenseCurrencyText(_ expense: Expense) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = expense.currency.rawValue
    formatter.locale = Locale(identifier: AppLocalization.languageCode)
    formatter.minimumFractionDigits = expense.currency.minorUnitDigits
    formatter.maximumFractionDigits = expense.currency.minorUnitDigits
    let amount = expense.currency.decimalAmount(from: expense.amountMinorUnits)
    return formatter.string(from: NSDecimalNumber(decimal: amount))
        ?? "\(expense.currency.rawValue) \(amount)"
}

#Preview("我的页 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            SettingsView()
        }
    }
}

#Preview("我的页 - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        NavigationStack {
            SettingsView()
        }
    }
}

#Preview("我的页 - 通知未开启") {
    PreviewSupport.canvas(model: PreviewSupport.notificationDeniedAppModel(), device: "iPhone SE (3rd generation)") {
        NavigationStack {
            SettingsView()
        }
    }
}
