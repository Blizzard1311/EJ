import SwiftUI
import YijiCore

struct HomeView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var deletingRecord: Record?
    @State private var selectedTimeSlice: RecordTimeSlice = .all
    @State private var selectedCategorySlice: RecordSliceCategory?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                filtersSection

                if isSearchingRecords {
                    activeSearchSection
                    queryResultsSection
                } else {
                    if let statusMessage = appModel.statusMessage {
                        statusSection(statusMessage)
                    }

                    recordsSection
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(screenBackground)
            .navigationTitle("录")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                scrollToFocusedRecord(with: proxy)
            }
            .onChange(of: appModel.focusedRecordID) { _ in
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
                Color(red: 0.94, green: 0.95, blue: 0.98),
                Color(red: 0.97, green: 0.98, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 10))
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

                    Button("清除") {
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
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.86))
            )
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 2, trailing: 10))
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
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.86))
                    )
                }
            } else {
                ForEach(queryResults) { record in
                    NavigationLink {
                        RecordDetailView(recordID: record.id)
                    } label: {
                        queryResultCard(for: record)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 8, trailing: 10))
        .listRowBackground(Color.clear)
    }

    private var filtersSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                filterGroup(title: "时间", showsReset: hasActiveFilters) {
                    ForEach(RecordTimeSlice.allCases) { slice in
                        filterChip(
                            title: slice.title,
                            isSelected: selectedTimeSlice == slice
                        ) {
                            selectedTimeSlice = slice
                        }
                    }
                }

                filterGroup(title: "分类") {
                    filterChip(
                        title: "全部",
                        isSelected: selectedCategorySlice == nil
                    ) {
                        selectedCategorySlice = nil
                    }

                    ForEach(RecordSliceCategory.allCases, id: \.self) { category in
                        filterChip(
                            title: category.displayName,
                            isSelected: selectedCategorySlice == category
                        ) {
                            selectedCategorySlice = category
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.84))
            )
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 2, trailing: 10))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var recordsSection: some View {
        if appModel.records.isEmpty {
            Section {
                Text("还没有记录，先回首页说一句话。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.86))
                    )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 8, trailing: 10))
            .listRowBackground(Color.clear)
        } else if filteredRecords.isEmpty {
            Section {
                Text("换一个时间或分类试试。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.86))
                    )
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 8, trailing: 10))
            .listRowBackground(Color.clear)
        } else {
            ForEach(recordSections) { section in
                Section {
                    daySectionHeader(section.title)

                    ForEach(Array(section.records.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            RecordDetailView(recordID: record.id)
                        } label: {
                            recordCard(for: record, showsDivider: index < section.records.count - 1)
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
                .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 4, trailing: 10))
                .listRowBackground(Color.clear)
            }
        }
    }

    private var emptyQueryState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("没有找到匹配内容")
                .font(.footnote.weight(.semibold))
            Text("你可以换一种问法，或者先回首页把它记下来。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
    }

    private func scrollToFocusedRecord(with proxy: ScrollViewProxy) {
        guard let focusedRecordID = appModel.focusedRecordID else { return }

        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(focusedRecordID, anchor: .top)
        }
    }

    private func recordCard(for record: Record, showsDivider: Bool) -> some View {
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
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isFocused ? Color(red: 0.93, green: 0.96, blue: 1.0).opacity(0.96) : Color.white.opacity(0.54))
        )
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .padding(.leading, 12)
            }
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

    private func daySectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.top, 1)
        .padding(.bottom, 1)
    }

    private func filterGroup<Content: View>(
        title: String,
        showsReset: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if showsReset {
                    Button("清除") {
                        resetFilters()
                    }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    content()
                }
                .padding(.vertical, 1)
            }
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue.opacity(0.12) : Color.white.opacity(0.68))
                )
                .foregroundStyle(isSelected ? Color.blue : Color.primary)
        }
        .buttonStyle(.plain)
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

    private var timeFilteredRecords: [Record] {
        appModel.records.filter { selectedTimeSlice.matches(record: $0, calendar: filterCalendar) }
    }

    private var filteredRecords: [Record] {
        timeFilteredRecords.filter(matchesCategory)
    }

    private var hasActiveFilters: Bool {
        selectedTimeSlice != .all || selectedCategorySlice != nil
    }

    private func matchesCategory(_ record: Record) -> Bool {
        guard let selectedCategorySlice else {
            return true
        }
        return record.sliceCategories.contains(selectedCategorySlice)
    }

    private var filterCalendar: Calendar {
        Calendar(identifier: .gregorian)
    }

    private var recordSections: [RecordSection] {
        let calendar = filterCalendar
        let grouped = Dictionary(grouping: filteredRecords) {
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

    private func clearSearch() {
        appModel.clearActiveSearch()
    }

    private func resetFilters() {
        selectedTimeSlice = .all
        selectedCategorySlice = nil
    }
}

private struct RecordSection: Identifiable {
    let title: String
    let date: Date
    let records: [Record]

    var id: Date { date }
}

private enum RecordTimeSlice: String, CaseIterable, Identifiable {
    case all
    case today
    case thisWeek
    case thisMonth
    case scheduled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            "全部"
        case .today:
            "今天"
        case .thisWeek:
            "本周"
        case .thisMonth:
            "本月"
        case .scheduled:
            "有安排"
        }
    }

    func matches(record: Record, calendar: Calendar) -> Bool {
        switch self {
        case .all:
            return true
        case .scheduled:
            return record.primaryTimeRange != nil
        case .today, .thisWeek, .thisMonth:
            return record.browseTimeRange.overlaps(referenceRange(calendar: calendar))
        }
    }

    func matches(date: Date, calendar: Calendar) -> Bool {
        switch self {
        case .all:
            return true
        case .scheduled:
            return true
        case .today, .thisWeek, .thisMonth:
            let pointRange = EventTimeRange(start: date, end: date, granularity: .exactTime)
            return pointRange.overlaps(referenceRange(calendar: calendar))
        }
    }

    private func referenceRange(calendar: Calendar) -> EventTimeRange {
        let now = Date()

        switch self {
        case .all, .scheduled:
            return EventTimeRange(start: .distantPast, end: .distantFuture, granularity: .year)
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)?.addingTimeInterval(-1) ?? start
            return EventTimeRange(start: start, end: end, granularity: .day)
        case .thisWeek:
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .day, value: 7, to: start)?.addingTimeInterval(-1) ?? start
            return EventTimeRange(start: start, end: end, granularity: .week)
        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: components) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start)?.addingTimeInterval(-1) ?? start
            return EventTimeRange(start: start, end: end, granularity: .month)
        }
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
