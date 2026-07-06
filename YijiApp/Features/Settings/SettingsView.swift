import SwiftUI
import UIKit
import UniformTypeIdentifiers
import YijiCore

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var showingImportPicker = false
    @State private var pendingImportURL: URL?
    @State private var showingImportConfirmation = false
    private let backupDateFormatter = YijiDateFormatter.dateTimeFormatter

    var body: some View {
        List {
            localModeSection
            remindersSection
            localDataSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .task {
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
            settingsCardSection(title: "本机数据", subtitle: "记录、提醒和权限") {
                HStack(spacing: 10) {
                    metricCard(title: "记录", value: "\(appModel.records.count)")
                    metricCard(title: "提醒", value: "\(appModel.reminders.count)")
                }

                HStack(spacing: 10) {
                    metricCard(title: "剩余可记录", value: "\(appModel.remainingRecordSlots)")
                    metricCard(title: "待提醒", value: "\(appModel.pendingReminders.count)")
                }

                infoStrip(
                    title: "记录",
                    detail: appModel.recordCapacityText,
                    systemImage: "internaldrive"
                )

                HStack(spacing: 8) {
                    statusPill("语音 · \(appModel.speech.authorizationStatus.displayName)")
                    statusPill("通知 · \(appModel.notifications.authorizationStatus.displayName)")
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var remindersSection: some View {
        Section {
            settingsCardSection(title: "提醒", subtitle: "待办和通知") {
                NavigationLink {
                    RemindersView()
                } label: {
                    actionRow(
                        "提醒管理",
                        detail: appModel.pendingReminders.isEmpty
                            ? "暂无待提醒"
                            : "还有 \(appModel.pendingReminders.count) 条待提醒",
                        systemImage: "bell"
                    )
                }
                .buttonStyle(.plain)

                switch appModel.notifications.authorizationStatus {
                case .unknown:
                    actionButton("开启通知权限", systemImage: "bell.badge") {
                        Task {
                            await appModel.requestNotificationAccess()
                        }
                    }
                case .denied:
                    actionButton("前往系统设置开启通知", systemImage: "gearshape") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                case .granted:
                    infoStrip(
                        title: "通知",
                        detail: "已开启",
                        systemImage: "bell.badge.fill"
                    )
                }

                if let nextReminder = appModel.nextPendingReminder {
                    infoStrip(
                        title: "下一条待提醒",
                        detail: "\(backupDateFormatter.string(from: nextReminder.remindAt)) · \(nextReminder.title)",
                        systemImage: "clock.badge"
                    )
                } else {
                    infoStrip(
                        title: "下一条待提醒",
                        detail: "暂无待提醒",
                        systemImage: "clock.badge.checkmark"
                    )
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
            settingsCardSection(title: "备份", subtitle: "导出或恢复本地数据") {
                infoStrip(
                    title: "上次备份",
                    detail: appModel.lastBackupDate.map { backupDateFormatter.string(from: $0) } ?? "还没有导出过备份",
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

    private func statusPill(_ title: String) -> some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.78))
            )
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
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
