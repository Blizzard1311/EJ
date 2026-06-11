import SwiftUI
import YijiCore

struct RecordRowView: View {
    enum Style {
        case detailed
        case stream
    }

    let record: Record
    var style: Style = .detailed

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recordTitle)
                        .font(titleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(style == .stream ? 2 : 1)

                    if let primaryDescription {
                        Text(primaryDescription)
                            .font(descriptionFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(style == .stream ? 2 : 2)
                    }
                }
                Spacer(minLength: 10)
                VStack(alignment: .trailing, spacing: style == .stream ? 4 : 6) {
                    categoryChip

                    if style == .detailed {
                        Text(YijiDateFormatter.dayFormatter.string(from: record.recordDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if style == .detailed, let originalContentLine {
                Text(originalContentLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 6) {
                if style == .detailed {
                    sourceChip
                }

                if let secondaryMeta {
                    infoChip(secondaryMeta.text, icon: secondaryMeta.icon)
                }

                if !record.sliceCategoryNames.isEmpty {
                    infoChip(record.sliceCategoryNames.joined(separator: " / "), icon: "line.3.horizontal.decrease.circle")
                }
            }
            .font(.caption2)
        }
        .padding(.vertical, 1)
    }

    private var recordTitle: String {
        if let objectName = record.objectName {
            return objectName
        }
        return record.content
    }

    private var titleFont: Font {
        switch style {
        case .detailed:
            .caption.weight(.semibold)
        case .stream:
            .footnote.weight(.semibold)
        }
    }

    private var descriptionFont: Font {
        switch style {
        case .detailed:
            .caption2
        case .stream:
            .caption
        }
    }

    private var primaryDescription: String? {
        switch style {
        case .detailed:
            return detailedPrimaryDescription
        case .stream:
            return streamPrimaryDescription
        }
    }

    private var detailedPrimaryDescription: String? {
        if let location = record.location, record.category == .storage {
            return "位置：\(location)"
        }

        if let eventTimeSummary = record.eventTimeSummary {
            return "时间：\(eventTimeSummary)"
        }

        return record.answerSummary
    }

    private var streamPrimaryDescription: String? {
        if let location = record.location, record.category == .storage {
            return "放在 \(location)"
        }

        if let objectName = record.objectName,
           let trimmedContent,
           trimmedContent != objectName {
            return trimmedContent
        }

        return nil
    }

    private var trimmedContent: String? {
        let trimmed = record.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var originalContentLine: String? {
        guard let trimmed = trimmedContent,
              trimmed != recordTitle,
              trimmed != detailedPrimaryDescription else {
            return nil
        }

        return trimmed
    }

    private var secondaryMeta: (text: String, icon: String)? {
        if let eventTimeSummary = record.eventTimeSummary {
            return (eventTimeSummary, "calendar")
        }

        if style == .detailed, let location = record.location {
            return (location, "mappin.and.ellipse")
        }

        return nil
    }

    private var categoryChip: some View {
        Text(record.displayCategoryName)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
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
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
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
