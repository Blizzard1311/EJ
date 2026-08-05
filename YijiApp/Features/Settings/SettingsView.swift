import SwiftUI
import UIKit
import CoreLocation
import UniformTypeIdentifiers
import YijiCore

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var showingImportPicker = false
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    private let locationManager = CLLocationManager()
    private var backupDateFormatter: DateFormatter {
        YijiDateFormatter.dateTimeFormatter
    }

    var body: some View {
        List {
            pageTitleSection
            localModeSection
            languageSection
            privacySection
            localDataSection
            supportSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
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
            "导入会覆盖当前本地记录、提醒和通知安排。",
            isPresented: $showingImportConfirmation,
            titleVisibility: .visible
        ) {
            Button("覆盖导入", role: .destructive) {
                guard let pendingImportURL else { return }
                Task {
                    await appModel.importBackupFile(from: pendingImportURL)
                    self.pendingImportURL = nil
                }
            }
            Button("取消", role: .cancel) {
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
            Text("设置")
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
                    metricCard(title: "记录", value: "\(appModel.records.count)")
                    Divider()
                    metricCard(title: "提醒", value: "\(appModel.reminders.count)")
                }

                Divider()

                infoStrip(
                    title: "数据存储",
                    detail: AppReleaseConfiguration.cloudSyncEnabled
                        ? "记录和提醒会先保存在本机，并在可用时同步到 iCloud"
                        : "记录和提醒保存在本机，可随时导出备份",
                    systemImage: "internaldrive"
                )
            }
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var privacySection: some View {
        Section {
            settingsCardSection(title: "权限与隐私") {
                infoStrip(
                    title: "语音与麦克风",
                    detail: "用于语音录入",
                    systemImage: "mic",
                    status: appModel.speech.authorizationStatus.displayName
                )

                Divider()

                infoStrip(
                    title: "通知",
                    detail: "用于到期提醒",
                    systemImage: "bell.badge",
                    status: appModel.notifications.authorizationStatus.displayName
                )

                Divider()

                infoStrip(
                    title: "定位",
                    detail: "用于月历天气",
                    systemImage: "location",
                    status: locationAuthorizationDisplayName
                )

                if appModel.notifications.authorizationStatus == .unknown {
                    Divider()
                    actionButton("开启通知权限", systemImage: "bell.badge") {
                        Task {
                            await appModel.requestNotificationAccess()
                        }
                    }
                }

                if shouldShowOpenSettingsAction {
                    Divider()
                    actionButton("前往系统设置", systemImage: "gearshape") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }

                if let statusMessage = appModel.statusMessage {
                    Divider()
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var languageSection: some View {
        Section {
            settingsCardSection(title: "语言") {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(AppTheme.surfaceMuted)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("App 语言")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("更改后立即应用，并同步调整语音识别语言")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }

                    Spacer(minLength: 8)

                    Picker(
                        "App 语言",
                        selection: Binding(
                            get: { appModel.appLanguage },
                            set: { appModel.selectAppLanguage($0) }
                        )
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(AppTheme.accent)
                }
                .padding(14)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var localDataSection: some View {
        Section {
            settingsCardSection(title: "备份与恢复") {
                if AppReleaseConfiguration.cloudSyncEnabled {
                    infoStrip(
                        title: "iCloud 同步",
                        detail: appModel.cloudSyncStatusDetail,
                        systemImage: "icloud"
                    )

                    Divider()
                }

                infoStrip(
                    title: "上次备份",
                    detail: appModel.lastBackupDate.map { backupDateFormatter.string(from: $0) } ?? "暂无备份",
                    systemImage: "externaldrive.badge.timemachine"
                )

                Divider()

                actionButton("生成备份文件", systemImage: "arrow.down.doc") {
                    Task {
                        await appModel.prepareExportFile()
                    }
                }

                Divider()

                actionButton("导入备份文件", systemImage: "square.and.arrow.down") {
                    showingImportPicker = true
                }

                Divider()

                infoStrip(
                    title: "卸载前保护",
                    detail: "如果准备删除 App，仍建议先导出备份文件到“文件”或 iCloud Drive",
                    systemImage: "externaldrive.badge.icloud"
                )

                if let exportURL = appModel.exportURL {
                    Divider()
                    ShareLink(item: exportURL) {
                        actionRow(
                            "分享备份文件",
                            detail: exportURL.lastPathComponent,
                            systemImage: "square.and.arrow.up",
                            showsChevron: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 18, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var supportSection: some View {
        Section {
            settingsCardSection(title: "支持") {
                Button {
                    openURL(AppSupport.privacyURL)
                } label: {
                    actionRow(
                        "隐私政策",
                        detail: "blizzard1311.github.io",
                        systemImage: "hand.raised",
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    openURL(AppSupport.supportURL)
                } label: {
                    actionRow(
                        "在线支持",
                        detail: "blizzard1311.github.io",
                        systemImage: "questionmark.circle",
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)

                Divider()

                Button {
                    openURL(AppSupport.emailURL)
                } label: {
                    actionRow(
                        "联系支持",
                        detail: AppSupport.email,
                        systemImage: "envelope",
                        showsChevron: false
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
            Text(value)
                .font(.title3.weight(.semibold))
            Text(AppLocalization.text(title))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func actionRow(_ title: String, detail: String, systemImage: String, showsChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .foregroundStyle(AppTheme.accent)
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surfaceMuted)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.text(title))
                    .font(.subheadline)
                if !detail.isEmpty {
                    Text(AppLocalization.text(detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }

    private func actionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            actionRow(title, detail: "", systemImage: systemImage, showsChevron: false)
        }
        .buttonStyle(.plain)
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

    private var shouldShowOpenSettingsAction: Bool {
        appModel.speech.authorizationStatus == .denied ||
        appModel.notifications.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private func infoStrip(
        title: String,
        detail: String,
        systemImage: String,
        status: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(AppTheme.surfaceMuted)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(AppLocalization.text(title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AppLocalization.text(detail))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)

            if let status {
                Text(status)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(permissionStatusColor(status))
                    .lineLimit(1)
            }
        }
        .padding(14)
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
