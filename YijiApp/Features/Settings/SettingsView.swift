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

    var body: some View {
        List {
            profileSection
            managementSection
            backupSection
            notificationSection
            statusSection
            aboutSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle("我的")
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

    private var profileSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.14))
                            .frame(width: 58, height: 58)
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("本地用户")
                            .font(.headline)
                        Text("当前版本先聚焦个人生活记录和本地找回。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    profileMetric(title: "记录", value: "\(appModel.records.count)")
                    profileMetric(title: "提醒", value: "\(appModel.reminders.count)")
                    profileMetric(title: "搜索历史", value: "\(appModel.searchHistory.count)")
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var managementSection: some View {
        Section {
            settingsCardSection(title: "常用功能", subtitle: "把最常打开的入口放在前面") {
                NavigationLink {
                    profilePlaceholder("个人信息", systemImage: "person.crop.circle")
                } label: {
                    settingsRow(
                        "个人信息",
                        detail: "昵称、头像和后续登录入口",
                        systemImage: "person.crop.circle"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RemindersView()
                } label: {
                    settingsRow(
                        "提醒管理",
                        detail: "查看待提醒、已完成和失败提醒",
                        systemImage: "bell"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    syncPlaceholder
                } label: {
                    settingsRow(
                        "备份与同步",
                        detail: "先本地保存，后续接 iCloud 或腾讯云",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var backupSection: some View {
        Section {
            settingsCardSection(title: "本地数据", subtitle: "支持导出和恢复 JSON 备份") {
                Button("生成备份文件") {
                    Task {
                        await appModel.prepareExportFile()
                    }
                }
                .buttonStyle(.borderless)

                Button("导入备份文件") {
                    showingImportPicker = true
                }
                .buttonStyle(.borderless)

                if let exportURL = appModel.exportURL {
                    ShareLink(item: exportURL) {
                        Label("分享备份文件", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.blue)
                    }
                }

                Text("导入前会二次确认。恢复后会覆盖当前记录、提醒，并重新同步本地通知。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text("会导出当前所有记录、提醒和最近搜索历史为 JSON 文件，适合手动备份、迁移设备或恢复数据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var notificationSection: some View {
        Section {
            settingsCardSection(title: "通知设置", subtitle: "确认提醒是否能进入系统通知") {
                switch appModel.notifications.authorizationStatus {
                case .unknown:
                    Button("开启通知权限") {
                        Task {
                            await appModel.requestNotificationAccess()
                        }
                    }
                    Text("开启后可以直接发送一条 10 秒后的测试通知，验证真机是否正常接收。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .denied:
                    Button("前往系统设置开启通知") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    Text("当前提醒仍会保存到本地，但不会出现在系统通知中心。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                case .granted:
                    Button("发送 10 秒后测试通知") {
                        Task {
                            await appModel.sendTestNotification()
                        }
                    }
                    Button("刷新通知状态") {
                        Task {
                            await appModel.notifications.refreshAuthorizationStatus()
                            await appModel.notifications.refreshScheduledIdentifiers()
                        }
                    }
                    Text("如果测试通知能收到，后续待提醒事项也会按相同机制推送。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var statusSection: some View {
        Section {
            settingsCardSection(title: "当前状态", subtitle: "便于快速判断本地功能是否就绪") {
                LabeledContent("语音权限", value: appModel.speech.authorizationStatus.displayName)
                LabeledContent("通知权限", value: appModel.notifications.authorizationStatus.displayName)
                LabeledContent("待提醒", value: "\(appModel.pendingReminders.count)")
                LabeledContent("最近搜索", value: appModel.searchHistory.first ?? "暂无")

                if let statusMessage = appModel.statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var aboutSection: some View {
        Section {
            settingsCardSection(title: "关于易记", subtitle: "先把 MVP 做稳定，再继续补同步与账号") {
                Text("一句话记录生活细节，未来帮你找回。")
                Text("当前版本聚焦语音记录、本地搜索、提醒建模和手动备份。")
                    .foregroundStyle(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 18, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func profileMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingsRow(_ title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
                .foregroundStyle(.blue)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func settingsCardSection<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func profilePlaceholder(_ title: String, systemImage: String) -> some View {
        List {
            Section {
                Label(title, systemImage: systemImage)
                Text("MVP 阶段先保留页面入口，后续再补登录、昵称和头像。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(title)
    }

    private var syncPlaceholder: some View {
        List {
            Section("规划中") {
                Text("当前版本先本地保存，后续再接 iCloud 或腾讯云同步。")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("备份与同步")
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
