import SwiftUI
import YijiCore

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var deletingRecord: Record?
    @State private var selectedDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var visibleMonth = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var calendarHeight: CGFloat = 432

    var body: some View {
        List {
            if isSearchingRecords {
                activeSearchSection
                queryResultsSection
            } else {
                monthCalendarSection

                if let statusMessage = appModel.statusMessage {
                    statusSection(statusMessage)
                }

                daySummarySection
                dayContentSection
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(screenBackground)
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
        .onAppear {
            syncSelectedDateIfNeeded()
        }
        .onChange(of: appModel.focusedRecordID) { _ in
            syncSelectedDateIfNeeded()
        }
    }

    private var screenBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.94, green: 0.95, blue: 0.98),
                Color(red: 0.97, green: 0.98, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var monthCalendarSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 9) {
                CalendarMonthView(
                    selectedDate: selectedDate,
                    visibleMonth: visibleMonth,
                    eventDates: recordDateSet,
                    reminderDates: pendingReminderDateSet,
                    notifiedDates: notifiedReminderDateSet,
                    calendar: filterCalendar,
                    onDateSelected: { date in
                        selectedDate = filterCalendar.startOfDay(for: date)
                    },
                    onVisibleMonthChanged: { date in
                        visibleMonth = filterCalendar.startOfDay(for: date)
                    },
                    onHeightChanged: { height in
                        calendarHeight = height
                    }
                )
                .frame(height: calendarHeight)

                calendarLegend
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            )
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
    }

    private func statusSection(_ statusMessage: String) -> some View {
        Section {
            Label(statusMessage, systemImage: "info.circle")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.74))
                )
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var daySummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayHeaderTitle)
                            .font(.headline.weight(.semibold))
                        Text(dayHeaderSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 10)

                    countBadge(daySummaryCountText)
                }

                HStack(spacing: 10) {
                    summaryPill(
                        title: "记录",
                        value: "\(selectedDateRecords.count)",
                        tint: .blue,
                        systemImage: "circle.fill"
                    )
                    summaryPill(
                        title: "待提醒",
                        value: "\(selectedDatePendingReminders.count)",
                        tint: .orange,
                        systemImage: "bell.fill"
                    )
                    summaryPill(
                        title: "已提醒",
                        value: "\(selectedDateNotifiedReminders.count)",
                        tint: .green,
                        systemImage: "checkmark.circle.fill"
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var dayContentSection: some View {
        if selectedDateRecords.isEmpty && selectedDateReminders.isEmpty {
            Section {
                Text("这一天还没有内容。你可以回“记”里新增，或换一个日期看看。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.86))
                    )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
        } else {
            if !selectedDatePendingReminders.isEmpty || !selectedDateNotifiedReminders.isEmpty || !selectedDateArchivedReminders.isEmpty {
                reminderSection(title: "提醒", reminders: selectedDateReminders)
            }

            if !selectedDateRecords.isEmpty {
                recordsSection
            }
        }
    }

    private func reminderSection(title: String, reminders: [Reminder]) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    title: title,
                    subtitle: reminderSectionSubtitle,
                    countText: "\(reminders.count) 条"
                )

                ForEach(Array(reminders.enumerated()), id: \.element.id) { index, reminder in
                    if index > 0 {
                        Divider()
                    }

                    reminderCard(for: reminder)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var recordsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    title: "记录",
                    subtitle: recordsSectionSubtitle,
                    countText: "\(selectedDateRecords.count) 条"
                )

                ForEach(Array(selectedDateRecords.enumerated()), id: \.element.id) { index, record in
                    if index > 0 {
                        Divider()
                    }

                    NavigationLink {
                        RecordDetailView(recordID: record.id)
                    } label: {
                        recordCard(for: record)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除", role: .destructive) {
                            deletingRecord = record
                        }
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var activeSearchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("“\(trimmedSearchText)”")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button("返回月历") {
                        clearSearch()
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Text(querySummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var queryResultsSection: some View {
        Section {
            if queryResults.isEmpty {
                emptyQueryState
            } else if activeTimelineQuery != nil {
                ForEach(Array(queryTimelineSections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        ForEach(Array(section.records.enumerated()), id: \.element.id) { index, record in
                            if index > 0 {
                                Divider()
                            }

                            NavigationLink {
                                RecordDetailView(recordID: record.id)
                            } label: {
                                queryResultCard(for: record)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.86))
                    )
                }
            } else {
                ForEach(queryResults) { record in
                    NavigationLink {
                        RecordDetailView(recordID: record.id)
                    } label: {
                        queryResultCard(for: record)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.86))
                            )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除", role: .destructive) {
                            deletingRecord = record
                        }
                    }
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 10, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var emptyQueryState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("没有找到匹配内容")
                .font(.footnote.weight(.semibold))
            Text("你可以换一种问法，或者先回首页把它记下来。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
    }

    private func summaryPill(title: String, value: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.12))
                    )

                Spacer(minLength: 0)
            }

            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private var calendarLegend: some View {
        HStack(spacing: 18) {
            calendarLegendItem(title: "记录", color: .blue)
            calendarLegendItem(title: "待提醒", color: .orange)
            calendarLegendItem(title: "已提醒", color: .green)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 0)
        .padding(.bottom, 0)
    }

    private func calendarLegendItem(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func reminderCard(for reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.footnote.weight(.semibold))

                    if !reminder.body.isEmpty {
                        Text(reminder.body)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }

                Spacer(minLength: 10)

                Text(reminder.status.displayName)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(reminderStatusColor(reminder.status).opacity(0.14))
                    )
                    .foregroundStyle(reminderStatusColor(reminder.status))
            }

            HStack(spacing: 8) {
                infoChip(YijiDateFormatter.timeFormatter.string(from: reminder.remindAt), icon: "clock")
                infoChip(reminder.repeatRule.displayName, icon: "repeat")
            }

            if let record = appModel.record(for: reminder) {
                NavigationLink {
                    RecordDetailView(recordID: record.id)
                } label: {
                    Label("查看关联记录", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func recordCard(for record: Record) -> some View {
        let isFocused = appModel.focusedRecordID == record.id

        return VStack(alignment: .leading, spacing: 8) {
            if isFocused {
                Label(appModel.focusedRecordBadgeText ?? "刚更新", systemImage: "checkmark.circle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            RecordRowView(record: record, style: .stream)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isFocused ? Color(red: 0.93, green: 0.96, blue: 1.0).opacity(0.96) : Color.white.opacity(0.48))
        )
    }

    private func sectionHeader(title: String, subtitle: String, countText: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            countBadge(countText)
        }
    }

    private func queryResultCard(for record: Record) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RecordRowView(record: record, style: .stream)

            if activeTimelineQuery == nil {
                Text(record.answerSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private func infoChip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
            )
            .foregroundStyle(.secondary)
    }

    private func countBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.05))
            )
    }

    private func reminderStatusColor(_ status: ReminderStatus) -> Color {
        switch status {
        case .pending:
            .orange
        case .notified:
            .green
        case .done:
            .blue
        case .cancelled:
            .gray
        case .failed:
            .red
        }
    }

    private func syncSelectedDateIfNeeded() {
        if let focusedRecordID = appModel.focusedRecordID,
           let record = appModel.records.first(where: { $0.id == focusedRecordID }) {
            let recordDay = filterCalendar.startOfDay(for: record.recordDate)
            selectedDate = recordDay
            visibleMonth = recordDay
            return
        }

        guard selectedDateRecords.isEmpty,
              selectedDateReminders.isEmpty,
              let firstDate = allTimelineDates.sorted(by: >).first else {
            return
        }

        selectedDate = firstDate
        visibleMonth = firstDate
    }

    private var filterCalendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    private var trimmedSearchText: String {
        appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearchingRecords: Bool {
        !trimmedSearchText.isEmpty
    }

    private var activeTimelineQuery: TimelineQuery? {
        TimelineQueryService.parseQuery(trimmedSearchText, now: Date(), calendar: filterCalendar)
    }

    private var queryTimelineSections: [TimelineQuerySection] {
        guard let activeTimelineQuery else { return [] }
        return TimelineQueryService.groupedSections(for: activeTimelineQuery, in: appModel.records, calendar: filterCalendar)
    }

    private var queryResults: [Record] {
        if let activeTimelineQuery {
            return TimelineQueryService.matchingRecords(for: activeTimelineQuery, in: appModel.records)
        }
        return appModel.searchResults
    }

    private var querySummaryText: String {
        if let activeTimelineQuery {
            return TimelineQueryService.summary(for: activeTimelineQuery, in: appModel.records, calendar: filterCalendar)
        }

        guard !trimmedSearchText.isEmpty else {
            return "输入后，这里会直接回答。"
        }

        guard let first = queryResults.first else {
            return "没有找到与“\(trimmedSearchText)”相关的历史记录。"
        }

        if queryResults.count == 1 {
            return first.answerSummary
        }

        return "我找到了 \(queryResults.count) 条与“\(trimmedSearchText)”相关的记录，最近一条是: \(first.answerSummary)"
    }

    private var selectedDateRecords: [Record] {
        appModel.records
            .filter { filterCalendar.isDate($0.recordDate, inSameDayAs: selectedDate) }
            .sorted { lhs, rhs in
                if lhs.recordDate == rhs.recordDate {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.recordDate > rhs.recordDate
            }
    }

    private var selectedDateReminders: [Reminder] {
        appModel.reminders
            .filter { filterCalendar.isDate($0.remindAt, inSameDayAs: selectedDate) }
            .sorted { $0.remindAt < $1.remindAt }
    }

    private var selectedDatePendingReminders: [Reminder] {
        selectedDateReminders.filter { $0.status == .pending }
    }

    private var selectedDateNotifiedReminders: [Reminder] {
        selectedDateReminders.filter { $0.status == .notified }
    }

    private var selectedDateArchivedReminders: [Reminder] {
        selectedDateReminders.filter { $0.status != .pending && $0.status != .notified }
    }

    private var recordDateSet: Set<Date> {
        Set(appModel.records.map { filterCalendar.startOfDay(for: $0.recordDate) })
    }

    private var pendingReminderDateSet: Set<Date> {
        Set(
            appModel.reminders
                .filter { $0.status == .pending }
                .map { filterCalendar.startOfDay(for: $0.remindAt) }
        )
    }

    private var notifiedReminderDateSet: Set<Date> {
        Set(
            appModel.reminders
                .filter { $0.status == .notified }
                .map { filterCalendar.startOfDay(for: $0.remindAt) }
        )
    }

    private var allTimelineDates: Set<Date> {
        recordDateSet.union(pendingReminderDateSet).union(notifiedReminderDateSet)
    }

    private var dayHeaderTitle: String {
        if filterCalendar.isDateInToday(selectedDate) {
            return "今天"
        }

        if filterCalendar.isDateInYesterday(selectedDate) {
            return "昨天"
        }

        return YijiDateFormatter.dayFormatter.string(from: selectedDate)
    }

    private var dayHeaderSubtitle: String {
        if selectedDateRecords.isEmpty && selectedDateReminders.isEmpty {
            return "当前没有记录或提醒"
        }

        if !selectedDatePendingReminders.isEmpty {
            return "先看当天待提醒，再回看记录"
        }

        if !selectedDateNotifiedReminders.isEmpty {
            return "这一天有已提醒内容，可继续补充处理结果"
        }

        return "按日期回看这一天留下的内容"
    }

    private var daySummaryCountText: String {
        "\(selectedDateRecords.count + selectedDateReminders.count) 条内容"
    }

    private var reminderSectionSubtitle: String {
        if !selectedDatePendingReminders.isEmpty && !selectedDateNotifiedReminders.isEmpty {
            return "待提醒和已提醒都会按时间显示"
        }

        if !selectedDatePendingReminders.isEmpty {
            return "优先处理当天还未提醒的事项"
        }

        if !selectedDateNotifiedReminders.isEmpty {
            return "已提醒事项可继续补充处理结果"
        }

        return "当天提醒会按时间顺序排列"
    }

    private var recordsSectionSubtitle: String {
        if selectedDateRecords.count <= 1 {
            return "这一天的记录会显示在这里"
        }

        return "按时间倒序回看这一天留下的内容"
    }

    private func clearSearch() {
        appModel.clearActiveSearch()
    }
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
