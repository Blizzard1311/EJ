import SwiftUI
import YijiCore

struct HomeView: View {
    @Environment(AppModel.self) private var appModel
    @State private var deletingRecord: Record?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                heroSection
                if let statusMessage = appModel.statusMessage {
                    statusSection(statusMessage)
                }
                reminderSection
                recordsSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(screenBackground)
            .navigationTitle("记录列表")
            .onAppear {
                scrollToFocusedRecord(with: proxy)
            }
            .onChange(of: appModel.focusedRecordID) { _, _ in
                scrollToFocusedRecord(with: proxy)
            }
        }
        .confirmationDialog(
            "删除后将同时移除关联提醒。",
            isPresented: Binding(
                get: { deletingRecord != nil },
                set: { isPresented in
                    if !isPresented {
                        deletingRecord = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) {
                guard let record = deletingRecord else { return }
                Task {
                    await appModel.deleteRecord(id: record.id)
                    deletingRecord = nil
                }
            }
            Button("取消", role: .cancel) {
                deletingRecord = nil
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

    private var heroSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("把生活里的小事记下来，之后再找回来。")
                    .font(.headline.weight(.semibold))
                Text("物品、提醒和临时想法，都可以先用一句自然语言留下来。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    NavigationLink {
                        SearchView()
                    } label: {
                        quickAction(
                            title: "搜索记录",
                            subtitle: "快速找回物品和提醒",
                            systemImage: "magnifyingglass"
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        CaptureView()
                    } label: {
                        quickAction(
                            title: "立即录入",
                            subtitle: "语音或文字都可以",
                            systemImage: "waveform.badge.mic"
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    summaryCard(title: "总记录", value: "\(appModel.records.count)")
                    summaryCard(title: "待提醒", value: "\(appModel.reminders.filter { $0.status == .pending }.count)")
                    summaryCard(title: "物品定位", value: "\(appModel.records.filter { $0.category == .storage }.count)")
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
    private var reminderSection: some View {
        if !appModel.reminderHighlights.isEmpty {
            Section {
                sectionTitle("近期提醒", subtitle: "最近即将发生的事项")

                ForEach(appModel.reminderHighlights) { reminder in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                                .frame(width: 34, height: 34)
                                .background(
                                    Circle()
                                        .fill(Color.orange.opacity(0.14))
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(reminder.title)
                                    .font(.headline)
                                Text(reminder.body.isEmpty ? "到时间后会同步到系统通知。" : reminder.body)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)
                        }

                        HStack {
                            Label(YijiDateFormatter.dateTimeFormatter.string(from: reminder.remindAt), systemImage: "calendar")
                            Spacer()
                            Text(reminder.repeatRule.displayName)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
                }
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var recordsSection: some View {
        if appModel.records.isEmpty {
            Section {
                sectionTitle("最近记录", subtitle: "你的本地记录会按时间排列在这里")

                Text("还没有记录，先去录入一句话。")
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 18, trailing: 16))
            .listRowBackground(Color.clear)
        } else {
            ForEach(recordSections) { section in
                Section {
                    sectionTitle(section.title, subtitle: "按天归档，方便回看")

                    ForEach(section.records) { record in
                        NavigationLink {
                            RecordDetailView(recordID: record.id)
                        } label: {
                            recordCard(for: record)
                        }
                        .id(record.id)
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("删除", role: .destructive) {
                                deletingRecord = record
                            }
                        }
                    }
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
    }

    private func scrollToFocusedRecord(with proxy: ScrollViewProxy) {
        guard let focusedRecordID = appModel.focusedRecordID else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(focusedRecordID, anchor: .top)
        }
    }

    private func recordCard(for record: Record) -> some View {
        let isFocused = appModel.focusedRecordID == record.id

        return VStack(alignment: .leading, spacing: 12) {
            if isFocused {
                Label(appModel.focusedRecordBadgeText ?? "刚更新", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            RecordRowView(record: record)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isFocused ? Color.blue.opacity(0.45) : .clear, lineWidth: 1.5)
        )
        .shadow(color: isFocused ? Color.blue.opacity(0.12) : .clear, radius: 10, y: 4)
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.95, green: 0.96, blue: 0.99))
        )
    }

    private func quickAction(title: String, subtitle: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    private var recordSections: [RecordSection] {
        let calendar = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: appModel.records) {
            calendar.startOfDay(for: $0.recordDate)
        }

        return grouped
            .map { date, records in
                RecordSection(
                    title: sectionTitle(for: date, calendar: calendar),
                    date: date,
                    records: records.sorted { lhs, rhs in
                        if lhs.recordDate == rhs.recordDate {
                            return lhs.createdAt > rhs.createdAt
                        }
                        return lhs.recordDate > rhs.recordDate
                    }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private func sectionTitle(for date: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(date) {
            return "今天"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return YijiDateFormatter.dayFormatter.string(from: date)
    }
}

private struct RecordSection: Identifiable {
    let title: String
    let date: Date
    let records: [Record]

    var id: Date { date }
}

#Preview("记录列表 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("记录列表 - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        NavigationStack {
            HomeView()
        }
    }
}

#Preview("记录列表 - 空状态") {
    PreviewSupport.canvas(model: PreviewSupport.emptyAppModel(), device: "iPhone SE (3rd generation)") {
        NavigationStack {
            HomeView()
        }
    }
}
