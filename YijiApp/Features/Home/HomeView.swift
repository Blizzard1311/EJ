import SwiftUI
import Foundation
import YijiCore

struct HomeView: View {
    private enum BrowseScene: Hashable {
        case storage
        case calendar

        var title: String {
            switch self {
            case .storage:
                "收纳场景"
            case .calendar:
                "日历"
            }
        }

        var systemImage: String {
            switch self {
            case .storage:
                "folder"
            case .calendar:
                "calendar"
            }
        }
    }

    private struct StorageContainerPickerView: View {
        @EnvironmentObject private var appModel: AppModel
        @Environment(\.dismiss) private var dismiss

        var body: some View {
            NavigationStack {
                List {
                    Section("固定显示") {
                        ForEach(StorageContainer.allCases, id: \.rawValue) { container in
                            Button {
                                appModel.toggleVisibleStorageContainer(container)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: storageContainerIcon(container))
                                        .foregroundStyle(storageContainerTint(container))
                                        .frame(width: 24, height: 24)

                                    Text(container.displayName)
                                        .foregroundStyle(.primary)

                                    Spacer(minLength: 8)

                                    Image(systemName: appModel.isStorageContainerVisible(container) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(
                                            appModel.isStorageContainerVisible(container)
                                                ? storageContainerTint(container)
                                                : Color.secondary.opacity(0.4)
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Section {
                        Text("已选容器会固定在收纳场景中。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("显示容器")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("恢复默认") {
                            appModel.resetVisibleStorageContainers()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
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

        private func storageContainerTint(_ container: StorageContainer) -> Color {
            switch container {
            case .medicineKit:
                Color(red: 0.86, green: 0.44, blue: 0.40)
            case .documentPouch:
                Color(red: 0.28, green: 0.55, blue: 0.92)
            case .jewelryBox:
                Color(red: 0.70, green: 0.48, blue: 0.80)
            case .digitalBox:
                Color(red: 0.25, green: 0.65, blue: 0.72)
            case .wardrobe:
                Color(red: 0.47, green: 0.59, blue: 0.40)
            case .storageBox:
                Color(red: 0.71, green: 0.53, blue: 0.36)
            case .drawer:
                Color(red: 0.58, green: 0.50, blue: 0.42)
            case .bag:
                Color(red: 0.54, green: 0.45, blue: 0.62)
            }
        }
    }

    private struct StorageContainerGroup: Identifiable {
        let container: StorageContainer?
        let records: [Record]

        var id: String {
            container?.rawValue ?? "other-location"
        }

        var displayName: String {
            container?.displayName ?? "其他位置"
        }
    }

    private struct FolderTabShape: Shape {
        func path(in rect: CGRect) -> Path {
            let radius = min(18, rect.height * 0.34)
            let notchDepth = min(11, rect.height * 0.24)
            let notchWidth = min(116, rect.width * 0.52)
            let notchCorner = min(12, notchDepth * 0.95)
            let notchEnd = min(rect.width - radius - 24, notchWidth)

            var path = Path()
            path.move(to: CGPoint(x: radius, y: notchDepth))
            path.addLine(to: CGPoint(x: notchEnd - notchCorner, y: notchDepth))
            path.addCurve(
                to: CGPoint(x: notchEnd, y: 0),
                control1: CGPoint(x: notchEnd - notchCorner * 0.2, y: notchDepth),
                control2: CGPoint(x: notchEnd - notchCorner * 0.2, y: 0)
            )
            path.addLine(to: CGPoint(x: rect.width - radius, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: rect.width, y: radius),
                control: CGPoint(x: rect.width, y: 0)
            )
            path.addLine(to: CGPoint(x: rect.width, y: rect.height - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.width - radius, y: rect.height),
                control: CGPoint(x: rect.width, y: rect.height)
            )
            path.addLine(to: CGPoint(x: radius, y: rect.height))
            path.addQuadCurve(
                to: CGPoint(x: 0, y: rect.height - radius),
                control: CGPoint(x: 0, y: rect.height)
            )
            path.addLine(to: CGPoint(x: 0, y: notchDepth + radius))
            path.addQuadCurve(
                to: CGPoint(x: radius, y: notchDepth),
                control: CGPoint(x: 0, y: notchDepth)
            )
            path.closeSubpath()

            return path
        }
    }

    private let monthCalendarHeight: CGFloat = 500
    @EnvironmentObject private var appModel: AppModel
    @State private var deletingRecord: Record?
    @State private var selectedDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var visibleMonth = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var activeScene: BrowseScene = .storage
    @State private var showingStorageContainerPicker = false
    @State private var selectedStorageGroupID: String?

    var body: some View {
        List {
            if isSearchingRecords {
                activeSearchSection
                queryResultsSection
            } else {
                sceneTabsSection

                if let statusMessage = appModel.statusMessage {
                    statusSection(statusMessage)
                }

                switch activeScene {
                case .storage:
                    storageContainersSection
                case .calendar:
                    monthCalendarSection
                    calendarContentSection
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(screenBackground)
        .navigationDestination(
            isPresented: Binding(
                get: { selectedStorageGroup != nil },
                set: { isPresented in
                    if !isPresented {
                        selectedStorageGroupID = nil
                    }
                }
            )
        ) {
            if let selectedStorageGroup {
                storageContainerDetailView(for: selectedStorageGroup)
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
        .onAppear {
            syncSelectedDateIfNeeded()
        }
        .onChange(of: appModel.focusedRecordID) { _ in
            syncSelectedDateIfNeeded()
        }
        .sheet(isPresented: $showingStorageContainerPicker) {
            StorageContainerPickerView()
                .environmentObject(appModel)
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

    private var sceneTabsSection: some View {
        Section {
            HStack(spacing: 0) {
                sceneTabButton(for: .storage)
                sceneTabButton(for: .calendar)
            }
            .padding(5)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.88, green: 0.91, blue: 0.96).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
        }
        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listSectionSeparator(.hidden, edges: .all)
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
                    }
                )
                .frame(height: monthCalendarHeight)

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

    @ViewBuilder
    private var calendarContentSection: some View {
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

            if !selectedDateStreamRecords.isEmpty {
                recordsSection
            }
        }
    }

    private var storageContainersSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                storageContainersHeader

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10, alignment: .top),
                        GridItem(.flexible(), spacing: 10, alignment: .top)
                    ],
                    spacing: 10
                ) {
                    ForEach(displayedStorageGroups) { group in
                        Button {
                            selectedStorageGroupID = group.id
                        } label: {
                            storageContainerCard(for: group)
                        }
                        .buttonStyle(.plain)
                    }
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

    private var storageContainersHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("收纳场景")
                    .font(.headline.weight(.semibold))

                Text(storageContainersSectionSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 8) {
                countBadge("\(displayedStorageGroups.count) 个容器")

                Button {
                    showingStorageContainerPicker = true
                } label: {
                    Label("管理", systemImage: "slider.horizontal.3")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.10))
                        )
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
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
                    countText: "\(selectedDateStreamRecords.count) 条"
                )

                ForEach(Array(selectedDateStreamRecords.enumerated()), id: \.element.id) { index, record in
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

    private func storageContainerCard(for group: StorageContainerGroup) -> some View {
        let tint = storageContainerTint(group.container)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: storageContainerIcon(group.container))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.13))
                    )

                Spacer(minLength: 8)

                countBadge("\(group.records.count) 件")
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(group.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(storageContainerCaption(for: group))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            VStack(alignment: .leading, spacing: 6) {
                if group.records.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.dashed")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(tint)

                            Text("暂无物品")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        Text("新增后会显示在这里。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                } else {
                    ForEach(Array(group.records.prefix(3).enumerated()), id: \.element.id) { _, record in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(tint.opacity(0.9))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.objectName ?? record.content)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if let location = record.location {
                                    Text(location)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if group.records.count > 3 {
                        Text("还有 \(group.records.count - 3) 件")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(tint)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func storageContainerDetailView(for group: StorageContainerGroup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                storageContainerDetailHeader(for: group)

                if group.records.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("暂无物品", systemImage: "square.dashed")
                            .font(.headline)
                        Text("之后记录到这个场景的物品会显示在这里。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            title: "记录详情",
                            subtitle: "只显示“\(group.displayName)”里的记录",
                            countText: "\(group.records.count) 件"
                        )

                        ForEach(Array(group.records.enumerated()), id: \.element.id) { index, record in
                            if index > 0 {
                                Divider()
                            }

                            storageContainerRecordRow(for: record)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white.opacity(0.92))
                    )
                }
            }
            .padding(16)
        }
        .background(screenBackground)
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func storageContainerDetailHeader(for group: StorageContainerGroup) -> some View {
        let tint = storageContainerTint(group.container)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: storageContainerIcon(group.container))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(tint.opacity(0.13))
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(group.displayName)
                        .font(.title2.weight(.semibold))
                    Text("\(group.records.count) 件物品")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let latestRecordDate = group.records.map(\.createdAt).max() {
                infoChip("最近记录 \(YijiDateFormatter.dayFormatter.string(from: latestRecordDate))", icon: "calendar")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private func storageContainerRecordRow(for record: Record) -> some View {
        let reminder = appModel.reminder(for: record)
        let tint = storageContainerTint(record.resolvedStorageContainer)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: storageContainerIcon(record.resolvedStorageContainer))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(tint.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(record.objectName ?? record.content)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    if let location = record.location {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                infoChip(YijiDateFormatter.dayFormatter.string(from: record.createdAt), icon: "calendar")
                infoChip(quantityText(for: record) ?? "数量未填写", icon: "number")
            }

            if let reminder {
                infoChip(reminderStatusText(for: reminder), icon: "bell")
            } else if needsExpiryReminder(record) {
                infoChip("可添加到期提醒", icon: "bell.badge")
            } else {
                infoChip("未设置到期提醒", icon: "bell.slash")
            }
        }
        .padding(.vertical, 8)
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

    private func needsExpiryReminder(_ record: Record) -> Bool {
        let keywords = ["到期", "过期", "有效期", "保质期", "失效", "截止"]
        return keywords.contains { record.content.localizedCaseInsensitiveContains($0) }
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

    private func sceneTabButton(for scene: BrowseScene) -> some View {
        let isActive = activeScene == scene

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                activeScene = scene
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: scene.systemImage)
                    .font(.subheadline.weight(.semibold))

                Text(scene.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                Group {
                    if isActive {
                        FolderTabShape()
                            .fill(Color.white.opacity(0.98))
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.clear)
                    }
                }
            )
            .overlay(
                Group {
                    if isActive {
                        FolderTabShape()
                            .stroke(Color.white.opacity(0.95), lineWidth: 1)
                    }
                }
            )
            .shadow(color: isActive ? Color.black.opacity(0.06) : .clear, radius: 10, y: 4)
            .foregroundStyle(isActive ? Color(red: 0.20, green: 0.30, blue: 0.46) : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func storageContainerIcon(_ container: StorageContainer?) -> String {
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
        case nil:
            "tray.full"
        }
    }

    private func storageContainerTint(_ container: StorageContainer?) -> Color {
        switch container {
        case .medicineKit:
            Color(red: 0.86, green: 0.44, blue: 0.40)
        case .documentPouch:
            Color(red: 0.28, green: 0.55, blue: 0.92)
        case .jewelryBox:
            Color(red: 0.70, green: 0.48, blue: 0.80)
        case .digitalBox:
            Color(red: 0.25, green: 0.65, blue: 0.72)
        case .wardrobe:
            Color(red: 0.47, green: 0.59, blue: 0.40)
        case .storageBox:
            Color(red: 0.71, green: 0.53, blue: 0.36)
        case .drawer:
            Color(red: 0.58, green: 0.50, blue: 0.42)
        case .bag:
            Color(red: 0.54, green: 0.45, blue: 0.62)
        case nil:
            Color(red: 0.55, green: 0.58, blue: 0.64)
        }
    }

    private func storageContainerCaption(for group: StorageContainerGroup) -> String {
        let locations = group.records
            .compactMap(\.location)
            .prefix(2)
            .joined(separator: " · ")

        if !locations.isEmpty {
            return locations
        }

        return "按场景回看"
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
            return "输入后显示结果。"
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

    private var allStorageRecords: [Record] {
        appModel.records
            .filter { $0.category == .storage }
            .sorted { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.updatedAt > rhs.updatedAt
            }
    }

    private var selectedDateStreamRecords: [Record] {
        selectedDateRecords.filter { $0.category != .storage }
    }

    private var allStorageGroups: [StorageContainerGroup] {
        let grouped = Dictionary(grouping: allStorageRecords) { $0.resolvedStorageContainer }

        let orderedContainers = StorageContainer.allCases.compactMap { container -> StorageContainerGroup? in
            guard let records = grouped[container], !records.isEmpty else {
                return nil
            }
            return StorageContainerGroup(container: container, records: records)
        }

        let uncategorized = grouped[nil]
            .map { StorageContainerGroup(container: nil, records: $0) }

        return orderedContainers + (uncategorized.map { [$0] } ?? [])
    }

    private var displayedStorageGroups: [StorageContainerGroup] {
        let grouped = Dictionary(uniqueKeysWithValues: allStorageGroups.map { ($0.id, $0) })

        let persistentGroups = appModel.visibleStorageContainers.map { container in
            grouped[container.rawValue] ?? StorageContainerGroup(container: container, records: [])
        }

        let transientGroups = allStorageGroups.filter { group in
            guard let container = group.container else {
                return true
            }

            return !appModel.visibleStorageContainers.contains(container)
        }

        return persistentGroups + transientGroups
    }

    private var selectedStorageGroup: StorageContainerGroup? {
        guard let selectedStorageGroupID else {
            return nil
        }

        return displayedStorageGroups.first { $0.id == selectedStorageGroupID }
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

    private var reminderSectionSubtitle: String {
        if !selectedDatePendingReminders.isEmpty && !selectedDateNotifiedReminders.isEmpty {
            return "待提醒和已提醒都会按时间显示"
        }

        if !selectedDatePendingReminders.isEmpty {
            return "当天待提醒"
        }

        if !selectedDateNotifiedReminders.isEmpty {
            return "当天已提醒"
        }

        return "当天提醒会按时间顺序排列"
    }

    private var recordsSectionSubtitle: String {
        if selectedDateStreamRecords.count <= 1 {
            if selectedDateReminders.isEmpty {
                return "这一天的记录会显示在这里"
            }
            return "按时间倒序回看这一天留下的内容"
        }

        return "想法、事项和其他记录会按时间倒序显示"
    }

    private var storageContainersSectionSubtitle: String {
        if allStorageRecords.isEmpty {
            return "先固定你常用的容器，后面录入的物品会自动归到这里"
        }

        if allStorageGroups.count == 1,
           let first = allStorageGroups.first {
            return "你目前主要在“\(first.displayName)”里找东西"
        }

        return "按收纳场景回看物品"
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
