import SwiftUI
import YijiCore

struct RecordRowView: View {
    let record: Record

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(recordTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(record.answerSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 8) {
                    categoryChip

                    Text(YijiDateFormatter.dayFormatter.string(from: record.recordDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(record.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                sourceChip
                if let location = record.location {
                    infoChip(location, icon: "mappin.and.ellipse")
                }
                if !record.tags.isEmpty {
                    infoChip(record.tags.joined(separator: " / "), icon: "tag")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 2)
    }

    private var recordTitle: String {
        if let objectName = record.objectName {
            return objectName
        }
        return record.content
    }

    private var categoryChip: some View {
        Text(record.category.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color(for: record.category).opacity(0.14))
            )
            .foregroundStyle(color(for: record.category))
    }

    private var sourceChip: some View {
        infoChip(sourceName(record.source), icon: sourceIcon(record.source))
    }

    private func infoChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
            )
            .foregroundStyle(.secondary)
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

    private func sourceIcon(_ source: CaptureSource) -> String {
        switch source {
        case .voice:
            "waveform"
        case .text:
            "text.cursor"
        case .imported:
            "square.and.arrow.down"
        }
    }

    private func color(for category: RecordCategory) -> Color {
        switch category {
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
}

#Preview("记录行") {
    List {
        RecordRowView(record: PreviewSupport.record())
    }
}
