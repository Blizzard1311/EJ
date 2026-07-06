import SwiftUI
import YijiCore

struct RemindersView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var editingReminder: Reminder?

    var body: some View {
        List {
            summarySection
            if let statusMessage = appModel.statusMessage {
                statusSection(statusMessage)
            }

            if appModel.reminders.isEmpty {
                Section {
                    Text("还没有提醒事项。")
                        .foregroundStyle(.secondary)
                }
            } else {
                remindersSection(title: "待提醒", reminders: appModel.pendingReminders)
                remindersSection(title: "已处理", reminders: appModel.archivedReminders)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle("提醒管理")
        .task {
            await appModel.refreshReminderStates()
        }
        .sheet(item: $editingReminder) { reminder in
            ReminderEditorView(reminder: reminder) { updated in
                await appModel.updateReminder(updated)
            }
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

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("提醒", subtitle: "待办、已提醒、已完成")

                HStack(spacing: 10) {
                    summaryCard(title: "待提醒", value: "\(appModel.pendingReminders.count)", color: .orange)
                    summaryCard(title: "已提醒", value: "\(appModel.reminders.filter { $0.status == .notified }.count)", color: .blue)
                    summaryCard(title: "已完成", value: "\(appModel.reminders.filter { $0.status == .done }.count)", color: .green)
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

    private func statusSection(_ statusMessage: String) -> some View {
        Section {
            Label(statusMessage, systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.82))
                )
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func remindersSection(title: String, reminders: [Reminder]) -> some View {
        if !reminders.isEmpty {
            Section {
                sectionTitle(title, subtitle: title == "待提醒" ? "按时间排列" : "完成、取消和失败")

                ForEach(reminders) { reminder in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title)
                                    .font(.headline)
                                if !reminder.body.isEmpty {
                                    Text(reminder.body)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 12)
                            statusBadge(reminder.status)
                        }

                        HStack {
                            Label(YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt), systemImage: "calendar")
                            Spacer()
                            Text(reminder.repeatRule.displayName)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        notificationStateView(for: reminder)

                        if let record = appModel.record(for: reminder) {
                            NavigationLink {
                                RecordDetailView(recordID: record.id)
                            } label: {
                                Label("查看关联记录", systemImage: "doc.text")
                                    .font(.footnote)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除", role: .destructive) {
                            Task {
                                await appModel.deleteReminder(id: reminder.id)
                            }
                        }
                        Button("编辑") {
                            editingReminder = reminder
                        }
                        .tint(.blue)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        switch reminder.status {
                        case .pending:
                            Button("标完成") {
                                Task {
                                    await appModel.setReminderStatus(reminder, status: .done)
                                }
                            }
                            .tint(.green)

                            Button("取消") {
                                Task {
                                    await appModel.setReminderStatus(reminder, status: .cancelled)
                                }
                            }
                            .tint(.gray)
                        case .notified:
                            Button("标完成") {
                                Task {
                                    await appModel.setReminderStatus(reminder, status: .done)
                                }
                            }
                            .tint(.green)

                            Button("重启") {
                                Task {
                                    await appModel.setReminderStatus(reminder, status: .pending)
                                }
                            }
                            .tint(.orange)
                        case .done, .cancelled, .failed:
                            Button("重启") {
                                Task {
                                    await appModel.setReminderStatus(reminder, status: .pending)
                                }
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func summaryCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func statusBadge(_ status: ReminderStatus) -> some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(statusColor(status).opacity(0.14))
            )
            .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: ReminderStatus) -> Color {
        switch status {
        case .pending:
            .orange
        case .notified:
            .blue
        case .done:
            .green
        case .cancelled:
            .gray
        case .failed:
            .red
        }
    }

    @ViewBuilder
    private func notificationStateView(for reminder: Reminder) -> some View {
        let descriptor = notificationDescriptor(for: reminder)
        Label(descriptor.text, systemImage: descriptor.icon)
            .font(.caption)
            .foregroundStyle(descriptor.color)
    }

    private func notificationDescriptor(for reminder: Reminder) -> (text: String, icon: String, color: Color) {
        if reminder.status == .failed {
            return ("提醒失败", "exclamationmark.triangle.fill", .red)
        }

        if reminder.status == .notified {
            return ("已送达", "checkmark.bell.fill", .blue)
        }

        if reminder.status != .pending {
            return ("未启用通知", "bell.slash", .gray)
        }

        switch appModel.notifications.authorizationStatus {
        case .granted:
            if appModel.notifications.isScheduled(reminderID: reminder.id) {
                return ("通知已开启", "bell.badge.fill", .green)
            }
            return ("等待同步", "clock.badge", .orange)
        case .denied:
            return ("通知未开启", "bell.slash.fill", .red)
        case .unknown:
            return ("待开启通知", "bell.badge", .orange)
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("提醒管理 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            RemindersView()
        }
    }
}

#Preview("提醒管理 - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        NavigationStack {
            RemindersView()
        }
    }
}

#Preview("提醒管理 - 空状态") {
    PreviewSupport.canvas(model: PreviewSupport.reminderEmptyAppModel(), device: "iPhone SE (3rd generation)") {
        NavigationStack {
            RemindersView()
        }
    }
}
