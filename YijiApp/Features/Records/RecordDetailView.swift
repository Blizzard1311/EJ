import SwiftUI
import YijiCore

struct RecordDetailView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    let recordID: UUID
    private let previewRecord: Record?
    @State private var showingDeleteConfirmation = false

    init(recordID: UUID, previewRecord: Record? = nil) {
        self.recordID = recordID
        self.previewRecord = previewRecord
    }

    var body: some View {
        ScrollView {
            if let record = currentRecord {
                VStack(alignment: .leading, spacing: 16) {
                    heroCard(for: record)
                    groupedCard(title: "内容信息") {
                        detailRow(title: "原文", value: record.content)
                        if let objectName = record.objectName {
                            detailRow(title: "对象", value: objectName)
                        }
                        if let location = record.location {
                            detailRow(title: "位置", value: location)
                        }
                        detailRow(title: "分类", value: record.displayCategoryName)
                    }

                    groupedCard(title: "时间信息") {
                        detailRow(title: "记录时间", value: YijiDateFormatter.dateTimeFormatter.string(from: record.createdAt))
                        detailRow(title: "业务时间", value: YijiDateFormatter.dateTimeFormatter.string(from: record.recordDate))
                        if let eventTimeSummary = record.eventTimeSummary {
                            detailRow(title: "计划时间", value: eventTimeSummary)
                        }
                    }

                    groupedCard(title: "补充信息") {
                        detailRow(title: "来源", value: sourceName(record.source))
                        detailRow(title: "切片分类", value: record.sliceCategoryNames.joined(separator: " / "))
                        detailRow(title: "标签", value: record.tags.isEmpty ? "无" : record.tags.joined(separator: " / "))
                        Text(record.answerSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }

                    if let reminder = appModel.reminder(for: record) {
                        groupedCard(title: "关联提醒") {
                            detailRow(title: "标题", value: reminder.title)
                            detailRow(title: "时间", value: YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt))
                            detailRow(title: "状态", value: reminder.status.displayName)
                            detailRow(title: "重复", value: reminder.repeatRule.displayName)
                        }
                    }
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

    private func heroCard(for record: Record) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(record.objectName ?? record.content)
                .font(.title2.weight(.semibold))

            if let location = record.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                chip(record.displayCategoryName, color: categoryColor(for: record))
                chip(sourceName(record.source), color: .blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.92))
        )
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
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
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
