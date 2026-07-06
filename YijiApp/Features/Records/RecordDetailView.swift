import SwiftUI
import Foundation
import YijiCore

struct RecordDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let recordID: UUID
    private let previewRecord: Record?
    @State private var showingDeleteConfirmation = false
    @State private var showingOriginalContent = false

    init(recordID: UUID, previewRecord: Record? = nil) {
        self.recordID = recordID
        self.previewRecord = previewRecord
    }

    var body: some View {
        ScrollView {
            if let record = currentRecord {
                let reminder = appModel.reminder(for: record)
                VStack(alignment: .leading, spacing: 16) {
                    heroCard(for: record, reminder: reminder)
                    summaryGrid(for: record)
                    reminderCard(for: record, reminder: reminder)
                    detailCard(for: record)
                    originalContentCard(for: record)
                }
                .padding(16)
            } else {
                unavailableState
            }
        }
        .background(screenBackground)
        .navigationTitle(currentRecord == nil ? "记录已移除" : "记录详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if currentRecord != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("删除", role: .destructive) {
                        showingDeleteConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("删除后将同时移除关联提醒。", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("删除记录", role: .destructive) {
                Task {
                    await appModel.deleteRecord(id: recordID)
                    dismiss()
                }
            }
            Button("取消", role: .cancel) {}
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

    @ViewBuilder
    private var unavailableState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label("这条记录已不存在。", systemImage: "tray.full")
                    .font(.headline)
                Text("它可能已经被删除，或者在导入备份时被新的本地数据覆盖。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.92))
            )

            Button("返回上一页") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private func heroCard(for record: Record, reminder: Reminder?) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: heroIcon(for: record))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(categoryColor(for: record))
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(categoryColor(for: record).opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 7) {
                    Text(primaryTitle(for: record))
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        chip(record.displayCategoryName, color: categoryColor(for: record))
                        if let storageContainer = record.resolvedStorageContainer {
                            chip(storageContainer.displayName, color: storageContainerColor(storageContainer))
                        }
                    }
                }
            }

            if let location = record.location {
                infoLine("位置", value: location, systemImage: "mappin.and.ellipse")
            }

            infoLine(
                "记录于",
                value: YijiDateFormatter.dayFormatter.string(from: record.createdAt),
                systemImage: "calendar"
            )

            if let reminder {
                infoLine(
                    "提醒",
                    value: reminderStatusText(for: reminder),
                    systemImage: reminder.status == .pending ? "bell.badge" : "bell"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private func summaryGrid(for record: Record) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            summaryTile(
                title: "数量",
                value: quantityText(for: record) ?? "未填写",
                systemImage: "number",
                color: quantityText(for: record) == nil ? .gray : .blue
            )
            summaryTile(
                title: "场景",
                value: record.resolvedStorageContainer?.displayName ?? record.displayCategoryName,
                systemImage: "folder",
                color: record.resolvedStorageContainer.map(storageContainerColor) ?? categoryColor(for: record)
            )
            summaryTile(
                title: "记录日期",
                value: YijiDateFormatter.dayFormatter.string(from: record.createdAt),
                systemImage: "calendar",
                color: .green
            )
            summaryTile(
                title: "提醒",
                value: reminderShortText(for: record),
                systemImage: "bell",
                color: reminderShortColor(for: record)
            )
        }
    }

    private func summaryTile(title: String, value: String, systemImage: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(color.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private func reminderCard(for record: Record, reminder: Reminder?) -> some View {
        groupedCard(title: "到期与提醒") {
            if let reminder {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: reminderIcon(for: reminder))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(reminderColor(for: reminder))
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(reminderColor(for: reminder).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(reminder.title)
                            .font(.subheadline.weight(.semibold))
                        Text(YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(reminderStatusText(for: reminder))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(reminderColor(for: reminder))
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: needsExpiryReminder(record) ? "bell.badge" : "bell.slash")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(needsExpiryReminder(record) ? .orange : .gray)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill((needsExpiryReminder(record) ? Color.orange : Color.gray).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(needsExpiryReminder(record) ? "可添加到期提醒" : "未设置到期提醒")
                            .font(.subheadline.weight(.semibold))
                        Text(needsExpiryReminder(record) ? "原文包含到期相关信息。" : "这条记录当前没有关联提醒。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func detailCard(for record: Record) -> some View {
        groupedCard(title: "详情") {
            if let objectName = record.objectName {
                detailRow(title: "名称", value: objectName)
            }
            if let quantity = quantityText(for: record) {
                detailRow(title: "数量", value: quantity)
            }
            if let location = record.location {
                detailRow(title: "位置", value: location)
            }
            if let storageContainer = record.resolvedStorageContainer {
                detailRow(title: "收纳场景", value: storageContainer.displayName)
            }
            detailRow(title: "分类", value: record.displayCategoryName)
            detailRow(title: "记录日期", value: YijiDateFormatter.dayFormatter.string(from: record.createdAt))
            if let eventTimeSummary = record.eventTimeSummary {
                detailRow(title: "相关时间", value: eventTimeSummary)
            }
        }
    }

    private func originalContentCard(for record: Record) -> some View {
        groupedCard(title: "原始记录") {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showingOriginalContent.toggle()
                }
            } label: {
                HStack {
                    Label(showingOriginalContent ? "收起原文" : "查看原文", systemImage: "doc.text")
                    Spacer()
                    Image(systemName: showingOriginalContent ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showingOriginalContent {
                Text(record.content)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .padding(.top, 6)
            }
        }
    }

    private func groupedCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    private func infoLine(_ title: String, value: String, systemImage: String) -> some View {
        Label {
            HStack(spacing: 4) {
                Text(title)
                    .foregroundStyle(.secondary)
                Text(value)
                    .foregroundStyle(.primary)
            }
            .font(.footnote)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
            .foregroundStyle(color)
    }

    private func categoryColor(for record: Record) -> Color {
        switch record.category {
        case .storage:
            .blue
        case .reminder:
            .orange
        case .note:
            .green
        case .other:
            .gray
        }
    }

    private func heroIcon(for record: Record) -> String {
        switch record.category {
        case .storage:
            record.resolvedStorageContainer.map(storageContainerIcon) ?? "cube.box"
        case .reminder:
            "bell.badge"
        case .note:
            "note.text"
        case .other:
            "square.grid.2x2"
        }
    }

    private func storageContainerIcon(_ container: StorageContainer) -> String {
        switch container {
        case .medicineKit:
            "cross.case"
        case .documentPouch:
            "doc.text"
        case .jewelryBox:
            "sparkles"
        case .digitalBox:
            "cable.connector"
        case .wardrobe:
            "hanger"
        case .storageBox:
            "archivebox"
        case .drawer:
            "tray.2"
        case .bag:
            "bag"
        }
    }

    private func storageContainerColor(_ container: StorageContainer) -> Color {
        switch container {
        case .medicineKit:
            Color(red: 0.88, green: 0.45, blue: 0.40)
        case .documentPouch:
            Color(red: 0.31, green: 0.55, blue: 0.92)
        case .jewelryBox:
            Color(red: 0.70, green: 0.47, blue: 0.78)
        case .digitalBox:
            Color(red: 0.31, green: 0.66, blue: 0.70)
        case .wardrobe:
            Color(red: 0.48, green: 0.58, blue: 0.41)
        case .storageBox:
            Color(red: 0.69, green: 0.53, blue: 0.37)
        case .drawer:
            Color(red: 0.57, green: 0.50, blue: 0.42)
        case .bag:
            Color(red: 0.52, green: 0.45, blue: 0.60)
        }
    }

    private func sourceName(_ source: CaptureSource) -> String {
        switch source {
        case .voice:
            "语音"
        case .text:
            "文字"
        case .imported:
            "导入"
        }
    }

    private func primaryTitle(for record: Record) -> String {
        if let objectName = record.objectName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !objectName.isEmpty {
            return objectName
        }

        let trimmed = record.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 22 else {
            return trimmed
        }

        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: 22)
        return "\(trimmed[..<endIndex])..."
    }

    private func quantityText(for record: Record) -> String? {
        let content = record.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let patterns = [
            #"(\d+(?:\.\d+)?)\s*(盒|瓶|张|个|件|包|袋|本|支|片|粒|套|份|条|双|罐|桶|卷)"#,
            #"([一二两三四五六七八九十百]+)\s*(盒|瓶|张|个|件|包|袋|本|支|片|粒|套|份|条|双|罐|桶|卷)"#
        ]

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let range = NSRange(content.startIndex..<content.endIndex, in: content)
            guard let match = expression.firstMatch(in: content, range: range),
                  match.numberOfRanges >= 3,
                  let numberRange = Range(match.range(at: 1), in: content),
                  let unitRange = Range(match.range(at: 2), in: content) else {
                continue
            }

            return "\(content[numberRange]) \(content[unitRange])"
        }

        return nil
    }

    private func reminderShortText(for record: Record) -> String {
        guard let reminder = appModel.reminder(for: record) else {
            return needsExpiryReminder(record) ? "可添加" : "未设置"
        }

        return reminder.status == .pending ? timeDistanceText(to: reminder.remindAt) : reminder.status.displayName
    }

    private func reminderShortColor(for record: Record) -> Color {
        guard let reminder = appModel.reminder(for: record) else {
            return needsExpiryReminder(record) ? .orange : .gray
        }

        return reminderColor(for: reminder)
    }

    private func reminderStatusText(for reminder: Reminder) -> String {
        if reminder.status == .pending {
            return timeDistanceText(to: reminder.remindAt)
        }
        return reminder.status.displayName
    }

    private func timeDistanceText(to date: Date) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let targetDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0

        if days > 0 {
            return "还有 \(days) 天"
        }
        if days == 0 {
            return "今天"
        }
        return "已过期 \(abs(days)) 天"
    }

    private func reminderColor(for reminder: Reminder) -> Color {
        switch reminder.status {
        case .pending:
            reminder.remindAt < Date() ? .red : .orange
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

    private func reminderIcon(for reminder: Reminder) -> String {
        switch reminder.status {
        case .pending:
            "bell.badge"
        case .notified:
            "checkmark.bell"
        case .done:
            "checkmark.circle"
        case .cancelled:
            "bell.slash"
        case .failed:
            "exclamationmark.triangle"
        }
    }

    private func needsExpiryReminder(_ record: Record) -> Bool {
        let keywords = ["到期", "过期", "有效期", "保质期", "失效", "截止"]
        return keywords.contains { record.content.localizedCaseInsensitiveContains($0) }
    }

    private var currentRecord: Record? {
        appModel.records.first(where: { $0.id == recordID }) ?? previewRecord
    }
}

#Preview("记录详情") {
    PreviewSupport.canvas {
        NavigationStack {
            RecordDetailView(recordID: PreviewSupport.record().id, previewRecord: PreviewSupport.record())
        }
    }
}
