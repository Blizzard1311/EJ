import SwiftUI
import YijiCore

struct ReminderEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Reminder
    @State private var isSaving = false
    @State private var saveErrorMessage: String?
    let onSave: (Reminder) async -> Bool

    init(reminder: Reminder, onSave: @escaping (Reminder) async -> Bool) {
        _draft = State(initialValue: reminder)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard

                    editorCard(title: "提醒内容") {
                        VStack(spacing: 12) {
                            fieldGroup(title: "标题") {
                                TextField("输入标题", text: $draft.title)
                            }

                            fieldGroup(title: "备注") {
                                TextField("输入备注", text: $draft.body, axis: .vertical)
                                    .lineLimit(3...5)
                            }
                        }
                    }

                    editorCard(title: "提醒时间") {
                        VStack(alignment: .leading, spacing: 14) {
                            fieldGroup(title: "时间") {
                                DatePicker(
                                    "提醒时间",
                                    selection: $draft.remindAt,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .labelsHidden()
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            pickerGroup(title: "重复规则", selectionText: draft.repeatRule.displayName) {
                                Picker("重复规则", selection: $draft.repeatRule) {
                                    ForEach(ReminderRepeatRule.allCases, id: \.self) { rule in
                                        Text(rule.displayName).tag(rule)
                                    }
                                }
                            }

                            pickerGroup(title: "状态", selectionText: draft.status.displayName) {
                                Picker("状态", selection: $draft.status) {
                                    ForEach(ReminderStatus.allCases, id: \.self) { status in
                                        Text(status.displayName).tag(status)
                                    }
                                }
                            }
                        }
                    }

                    editorCard(title: "状态") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                Image(systemName: editorHint.icon)
                                    .foregroundStyle(editorHint.color)
                                    .frame(width: 24)
                                Text(editorHint.text)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(editorHint.color)
                            }

                            if let detail = editorHint.detail {
                                Text(detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            if let saveErrorMessage {
                                Text(saveErrorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                        )
                    }
                }
            }
            .padding(16)
            .background(screenBackground)
            .navigationTitle("编辑提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                saveBar
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.title.isEmpty ? "编辑提醒" : draft.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                statusBadge(title: draft.status.displayName, color: statusColor(draft.status))
                statusBadge(title: draft.repeatRule.displayName, color: .blue)
            }

            Text(YijiDateFormatter.dateTimeFormatter.string(from: draft.remindAt))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.23, green: 0.54, blue: 1.0),
                            Color(red: 0.39, green: 0.69, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .foregroundStyle(.white)
    }

    private func editorCard<Content: View>(
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private func fieldGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                )
        }
    }

    private func pickerGroup<SelectionContent: View>(
        title: String,
        selectionText: String,
        @ViewBuilder content: () -> SelectionContent
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectionText)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
            )
        }
        .buttonStyle(.plain)
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.1)

            Button {
                Task {
                    let normalizedDraft = normalizedReminder
                    if let validationMessage = validationMessage(for: normalizedDraft) {
                        saveErrorMessage = validationMessage
                        return
                    }

                    saveErrorMessage = nil
                    isSaving = true
                    let didSave = await onSave(normalizedDraft)
                    isSaving = false

                    if didSave {
                        dismiss()
                    } else {
                        saveErrorMessage = "保存失败，请稍后再试。"
                    }
                }
            } label: {
                Text(isSaving ? "保存中..." : "保存提醒")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, Color(red: 0.2, green: 0.55, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isSaveDisabled)
            .opacity(isSaveDisabled ? 0.5 : 1)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
    }

    private func statusBadge(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(0.18))
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
            .foregroundStyle(.white)
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

    private var editorHint: (text: String, icon: String, color: Color, detail: String?) {
        if draft.status != .pending {
            if draft.status == .notified {
                return ("已送达", "checkmark.bell.fill", .blue, nil)
            }
            return ("未安排通知", "bell.slash", .gray, nil)
        }

        if draft.repeatRule == .none && draft.remindAt <= Date() {
            return ("时间已过", "exclamationmark.triangle.fill", .red, nil)
        }

        switch appModel.notifications.authorizationStatus {
        case .granted:
            return ("通知已开启", "bell.badge.fill", .green, nil)
        case .denied:
            return ("通知未开启", "bell.slash.fill", .red, nil)
        case .unknown:
            return ("待开启通知", "bell.badge", .orange, nil)
        }
    }

    private var normalizedReminder: Reminder {
        var reminder = draft
        reminder.title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.body = reminder.body.trimmingCharacters(in: .whitespacesAndNewlines)
        return reminder
    }

    private var isSaveDisabled: Bool {
        isSaving || normalizedReminder.title.isEmpty
    }

    private func validationMessage(for reminder: Reminder) -> String? {
        guard reminder.status == .pending else { return nil }
        guard reminder.repeatRule == .none else { return nil }
        guard reminder.remindAt <= Date() else { return nil }
        return "提醒时间已过，请调整后再保存。"
    }
}

#Preview("编辑提醒") {
    ReminderEditorView(reminder: PreviewSupport.reminder()) { _ in true }
        .environmentObject(PreviewSupport.appModel())
}

#Preview("编辑提醒 - 通知未开启") {
    ReminderEditorView(reminder: PreviewSupport.overdueReminder()) { _ in true }
        .environmentObject(PreviewSupport.notificationDeniedAppModel())
}
