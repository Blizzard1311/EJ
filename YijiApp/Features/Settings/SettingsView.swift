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
    private let backupDateFormatter = YijiDateFormatter.dateTimeFormatter

    var body: some View {
        List {
            localModeSection
            privacySection
            localDataSection
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
                appModel.showPersistentStatus("选择备份文件失败：\(error.localizedDescription)")
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
            Text(pendingImportURL?.lastPathComponent ?? "请选择一个 JSON 备份文件。")
        }
    }

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.95, green: 0.96, blue: 0.99),
                Color(red: 0.98, green: 0.98, blue: 0.99)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var localModeSection: some View {
        Section {
            settingsCardSection(title: "本机数据") {
                HStack(spacing: 10) {
                    metricCard(title: "记录", value: "\(appModel.records.count)")
                    metricCard(title: "提醒", value: "\(appModel.reminders.count)")
                }

                infoStrip(
                    title: "数据存储",
                    detail: "记录和提醒会先保存在本机，并在可用时同步到 iCloud",
                    systemImage: "internaldrive"
                )
            }
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var privacySection: some View {
        Section {
            settingsCardSection(title: "权限与隐私") {
                infoStrip(
                    title: "语音与麦克风",
                    detail: "用于语音录入 · \(appModel.speech.authorizationStatus.displayName)",
                    systemImage: "mic"
                )

                infoStrip(
                    title: "通知",
                    detail: "用于到期提醒 · \(appModel.notifications.authorizationStatus.displayName)",
                    systemImage: "bell.badge"
                )

                infoStrip(
                    title: "定位",
                    detail: "用于月历天气 · \(locationAuthorizationDisplayName)",
                    systemImage: "location"
                )

                if appModel.notifications.authorizationStatus == .unknown {
                    actionButton("开启通知权限", systemImage: "bell.badge") {
                        Task {
                            await appModel.requestNotificationAccess()
                        }
                    }
                }

                if shouldShowOpenSettingsAction {
                    actionButton("前往系统设置", systemImage: "gearshape") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                }

                if let statusMessage = appModel.statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var localDataSection: some View {
        Section {
            settingsCardSection(title: "备份与恢复") {
                infoStrip(
                    title: "iCloud 同步",
                    detail: appModel.cloudSyncStatusDetail,
                    systemImage: "icloud"
                )

                infoStrip(
                    title: "上次备份",
                    detail: appModel.lastBackupDate.map { backupDateFormatter.string(from: $0) } ?? "暂无备份",
                    systemImage: "externaldrive.badge.timemachine"
                )

                actionButton("生成备份文件", systemImage: "arrow.down.doc") {
                    Task {
                        await appModel.prepareExportFile()
                    }
                }

                actionButton("导入备份文件", systemImage: "square.and.arrow.down") {
                    showingImportPicker = true
                }

                infoStrip(
                    title: "卸载前保护",
                    detail: "如果准备删除 App，仍建议先导出备份文件到“文件”或 iCloud Drive",
                    systemImage: "externaldrive.badge.icloud"
                )

                if let exportURL = appModel.exportURL {
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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 18, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func actionRow(_ title: String, detail: String, systemImage: String, showsChevron: Bool = true) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .foregroundStyle(.blue)
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                if !detail.isEmpty {
                    Text(detail)
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
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
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
            return "已授权"
        case .denied, .restricted:
            return "未授权"
        case .notDetermined:
            return "未请求"
        @unknown default:
            return "未请求"
        }
    }

    private var shouldShowOpenSettingsAction: Bool {
        appModel.speech.authorizationStatus == .denied ||
        appModel.notifications.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private func infoStrip(title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func settingsCardSection<Content: View>(
        title: String,
        subtitle: String = "",
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
        )
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
