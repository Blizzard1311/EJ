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
                "收纳"
            case .calendar:
                "计划"
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
        @State private var showingAddCustomContainer = false
        @State private var newCustomContainerName = ""

        var body: some View {
            NavigationStack {
                List {
                    Section("容器") {
                        ForEach(appModel.storageContainerDefinitions) { definition in
                            HStack(spacing: 12) {
                                Image(systemName: storageContainerIcon(definition))
                                    .foregroundStyle(storageContainerTint(definition))
                                    .frame(width: 24, height: 24)

                                TextField(
                                    "容器名称",
                                    text: Binding(
                                        get: { definition.name },
                                        set: { appModel.updateStorageContainerName($0, for: definition.id) }
                                    )
                                )
                                .textInputAutocapitalization(.never)

                                Spacer(minLength: 8)

                                Button(role: .destructive) {
                                    appModel.removeStorageContainerDefinition(definition.id)
                                } label: {
                                    Image(systemName: definition.isCustom ? "trash" : "minus.circle")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !appModel.availableBuiltInStorageContainers.isEmpty {
                        Section("添加内置容器") {
                            ForEach(appModel.availableBuiltInStorageContainers, id: \.rawValue) { container in
                                Button {
                                    appModel.addBuiltInStorageContainer(container)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: storageContainerIcon(container))
                                            .foregroundStyle(storageContainerTint(container))
                                            .frame(width: 24, height: 24)

                                        Text(container.displayName)
                                            .foregroundStyle(.primary)

                                        Spacer(minLength: 8)

                                        Image(systemName: "plus.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .navigationTitle("管理容器")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("恢复默认") {
                            appModel.resetStorageContainerDefinitions()
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button("新增") {
                            newCustomContainerName = ""
                            showingAddCustomContainer = true
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
                .alert("新增容器", isPresented: $showingAddCustomContainer) {
                    TextField("容器名称", text: $newCustomContainerName)
                    Button("取消", role: .cancel) {
                        newCustomContainerName = ""
                    }
                    Button("新增") {
                        appModel.addCustomStorageContainer(named: newCustomContainerName)
                        newCustomContainerName = ""
                    }
                } message: {
                    Text("输入新的容器名称")
                }
            }
        }

        private func storageContainerIcon(_ definition: StorageContainerDefinition) -> String {
            if let container = definition.builtInContainer {
                return storageContainerIcon(container)
            }
            return "shippingbox"
        }

        private func storageContainerTint(_ definition: StorageContainerDefinition) -> Color {
            if let container = definition.builtInContainer {
                return storageContainerTint(container)
            }
            return Color(red: 0.42, green: 0.49, blue: 0.78)
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
        enum Kind {
            case builtIn(StorageContainer)
            case custom
            case uncategorized
        }

        let id: String
        let displayName: String
        let kind: Kind
        let records: [Record]
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
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var deletingRecord: Record?
    @State private var selectedDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var visibleMonth = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var activeScene: BrowseScene = {
        if ProcessInfo.processInfo.environment["YIJI_START_SCENE"] == "calendar" {
            return .calendar
        }
        return .storage
    }()
    @State private var showingStorageContainerPicker = false
    @State private var selectedStorageGroupID: String?
    @StateObject private var calendarWeatherModel = CalendarWeatherModel()

    var body: some View {
        List {
            if isSearchingRecords {
                activeSearchSection
                queryResultsSection
            } else {
                if let statusMessage = appModel.statusMessage {
                    statusSection(statusMessage)
                }

                storageContainersSection
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
                    eventDates: [],
                    reminderDates: pendingReminderDateSet,
                    notifiedDates: notifiedReminderDateSet,
                    weatherByDate: calendarWeatherModel.weatherByDate,
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

                if let selectedDateWeather {
                    selectedDateWeatherCard(selectedDateWeather)
                }

                calendarWeatherStatusRow
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
        if selectedDateReminders.isEmpty {
            Section {
                Text("暂无提醒")
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
                    ForEach(allStorageGroups) { group in
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
        HStack(spacing: 10) {
            Text("收纳")
                .font(.headline.weight(.semibold))
            Spacer(minLength: 10)

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

    private var activeSearchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("“\(trimmedSearchText)”")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Button("返回计划") {
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
            Text("换个关键词试试")
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 18) {
                calendarLegendItem(title: "待提醒", color: .orange)
                calendarLegendItem(title: "已提醒", color: .green)
            }

            HStack(spacing: 6) {
                Image(systemName: "cloud.sun.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)

                Text("天气")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private func selectedDateWeatherCard(_ weather: CalendarDayWeather) -> some View {
        let accentColor = Color(uiColor: weather.accentColor)

        return HStack(spacing: 10) {
            Image(systemName: weather.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.summaryLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(weather.temperatureLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.14), lineWidth: 1)
        )
    }

    private var calendarWeatherStatusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: calendarWeatherModel.statusIconName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(calendarWeatherModel.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if calendarWeatherModel.shouldOfferSettings {
                Button("去设置") {
                    openLocationSettings()
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            } else if let actionTitle = calendarWeatherModel.actionTitle {
                Button(actionTitle) {
                    calendarWeatherModel.refresh()
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 4)
    }

    private func storageContainerCard(for group: StorageContainerGroup) -> some View {
        let tint = storageContainerTint(for: group)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: storageContainerIcon(for: group))
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
        let tint = storageContainerTint(for: group)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: storageContainerIcon(for: group))
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
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(record.objectName ?? record.content)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        if let reminder {
                            Image(systemName: reminder.status == .pending ? "bell.fill" : "bell")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(reminderStatusColor(reminder.status))
                                .accessibilityLabel("有关联提醒：\(reminder.status.displayName)")
                        }
                    }

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

    private func sectionHeader(title: String, subtitle: String = "", countText: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.semibold))
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    private func storageContainerIcon(for group: StorageContainerGroup) -> String {
        switch group.kind {
        case .builtIn(let container):
            return storageContainerIcon(container)
        case .custom:
            return "shippingbox"
        case .uncategorized:
            return "tray.full"
        }
    }

    private func storageContainerTint(for group: StorageContainerGroup) -> Color {
        switch group.kind {
        case .builtIn(let container):
            return storageContainerTint(container)
        case .custom:
            return Color(red: 0.42, green: 0.49, blue: 0.78)
        case .uncategorized:
            return Color(red: 0.55, green: 0.58, blue: 0.64)
        }
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
            return ""
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

    private var allStorageGroups: [StorageContainerGroup] {
        var groupedRecords: [String: [Record]] = [:]
        for record in allStorageRecords {
            for groupID in storageGroupIDs(for: record) {
                groupedRecords[groupID, default: []].append(record)
            }
        }
        let configuredIDs = Set(appModel.storageContainerDefinitions.map(\.id))

        let configuredGroups = appModel.storageContainerDefinitions.map { definition in
            makeStorageContainerGroup(
                id: definition.id,
                displayName: definition.displayName,
                kind: definition.builtInContainer.map(StorageContainerGroup.Kind.builtIn) ?? .custom,
                records: groupedRecords[definition.id] ?? []
            )
        }

        let transientBuiltInGroups = StorageContainer.allCases.compactMap { container -> StorageContainerGroup? in
            guard !configuredIDs.contains(container.rawValue),
                  let records = groupedRecords[container.rawValue],
                  !records.isEmpty else {
                return nil
            }

            return makeStorageContainerGroup(
                id: container.rawValue,
                displayName: container.displayName,
                kind: .builtIn(container),
                records: records
            )
        }

        let uncategorizedGroup: StorageContainerGroup? = {
            guard let records = groupedRecords["other-location"], !records.isEmpty else {
                return nil
            }

            return makeStorageContainerGroup(
                id: "other-location",
                displayName: "其他位置",
                kind: .uncategorized,
                records: records
            )
        }()

        return configuredGroups + transientBuiltInGroups + (uncategorizedGroup.map { [$0] } ?? [])
    }

    private var selectedStorageGroup: StorageContainerGroup? {
        guard let selectedStorageGroupID else {
            return nil
        }

        return allStorageGroups.first { $0.id == selectedStorageGroupID }
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
        Set(appModel.records.map { filterCalendar.startOfDay(for: $0.recordDate) })
            .union(pendingReminderDateSet)
            .union(notifiedReminderDateSet)
    }

    private var reminderSectionSubtitle: String {
        ""
    }

    private func storageGroupIDs(for record: Record) -> [String] {
        var groupIDs = record.resolvedStorageContainers.map(\.rawValue)

        if let customDefinition = appModel.matchingCustomStorageContainerDefinition(for: record),
           !groupIDs.contains(customDefinition.id) {
            groupIDs.append(customDefinition.id)
        }

        if groupIDs.isEmpty {
            groupIDs.append("other-location")
        }

        return groupIDs
    }

    private func makeStorageContainerGroup(
        id: String,
        displayName: String,
        kind: StorageContainerGroup.Kind,
        records: [Record]
    ) -> StorageContainerGroup {
        StorageContainerGroup(
            id: id,
            displayName: displayName,
            kind: kind,
            records: records
        )
    }

    private func clearSearch() {
        appModel.clearActiveSearch()
    }

    private func openLocationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(settingsURL)
    }

    private var selectedDateWeather: CalendarDayWeather? {
        calendarWeatherModel.dayWeather(for: selectedDate)
    }
}

struct CalendarView: View {
    private let monthCalendarHeight: CGFloat = 500

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @State private var visibleMonth = Calendar(identifier: .gregorian).startOfDay(for: Date())
    @StateObject private var weatherModel = CalendarWeatherModel()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if let statusMessage = appModel.statusMessage {
                    statusCard(statusMessage)
                }

                calendarCard

                if selectedDateRecords.isEmpty && selectedDateReminders.isEmpty {
                    emptyDayCard
                } else {
                    if !selectedDateRecords.isEmpty {
                        recordsCard
                    }

                    if !selectedDateReminders.isEmpty {
                        remindersCard
                    }
                }
            }
            .padding(16)
        }
        .background(screenBackground)
        .onAppear {
            syncSelectedDateIfNeeded()
            weatherModel.activate()
        }
        .onChange(of: appModel.focusedRecordID) { _ in
            syncSelectedDateIfNeeded()
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                weatherModel.activate()
            }
        }
    }

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("日历")
                .font(.headline.weight(.semibold))

            CalendarMonthView(
                selectedDate: selectedDate,
                visibleMonth: visibleMonth,
                eventDates: recordDateSet,
                reminderDates: pendingReminderDateSet,
                notifiedDates: notifiedReminderDateSet,
                weatherByDate: weatherModel.weatherByDate,
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

            if let selectedDateWeather {
                selectedDateWeatherCard(selectedDateWeather)
            }

            weatherStatusRow
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.white.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.62), lineWidth: 1)
        )
    }

    private var recordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "记录", countText: "\(selectedDateRecords.count) 条")

            ForEach(Array(selectedDateRecords.enumerated()), id: \.element.id) { index, record in
                if index > 0 {
                    Divider()
                }

                NavigationLink {
                    RecordDetailView(recordID: record.id)
                } label: {
                    RecordRowView(record: record, style: .stream)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "提醒", countText: "\(selectedDateReminders.count) 条")

            ForEach(Array(selectedDateReminders.enumerated()), id: \.element.id) { index, reminder in
                if index > 0 {
                    Divider()
                }

                reminderRow(reminder)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    @ViewBuilder
    private func reminderRow(_ reminder: Reminder) -> some View {
        if let record = appModel.record(for: reminder) {
            NavigationLink {
                RecordDetailView(recordID: record.id)
            } label: {
                reminderContent(reminder)
            }
            .buttonStyle(.plain)
        } else {
            reminderContent(reminder)
        }
    }

    private func reminderContent(_ reminder: Reminder) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)

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
        }
        .padding(.vertical, 6)
    }

    private var emptyDayCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("这一天还没有内容", systemImage: "calendar.badge.plus")
                .font(.headline)

            Text("在“记录”页记录事项或设置提醒后，会自动显示在对应日期。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackground)
    }

    private func statusCard(_ statusMessage: String) -> some View {
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

    private var calendarLegend: some View {
        HStack(spacing: 16) {
            legendItem(title: "记录", color: .blue)
            legendItem(title: "待提醒", color: .orange)
            legendItem(title: "已提醒", color: .green)

            HStack(spacing: 6) {
                Image(systemName: "cloud.sun.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text("天气")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func legendItem(title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func selectedDateWeatherCard(_ weather: CalendarDayWeather) -> some View {
        let accentColor = Color(uiColor: weather.accentColor)

        return HStack(spacing: 10) {
            Image(systemName: weather.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.10))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(weather.summaryLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(weather.temperatureLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accentColor.opacity(0.14), lineWidth: 1)
        )
    }

    private var weatherStatusRow: some View {
        HStack(spacing: 8) {
            Image(systemName: weatherModel.statusIconName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(weatherModel.statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if weatherModel.shouldOfferSettings {
                Button("去设置") {
                    openLocationSettings()
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            } else if let actionTitle = weatherModel.actionTitle {
                Button(actionTitle) {
                    weatherModel.refresh()
                }
                .buttonStyle(.plain)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 4)
    }

    private func sectionHeader(title: String, countText: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))

            Spacer(minLength: 10)

            Text(countText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.05))
                )
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

    private func openLocationSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(settingsURL)
    }

    private var filterCalendar: Calendar {
        Calendar(identifier: .gregorian)
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
        recordDateSet
            .union(pendingReminderDateSet)
            .union(notifiedReminderDateSet)
    }

    private var selectedDateWeather: CalendarDayWeather? {
        weatherModel.dayWeather(for: selectedDate)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.white.opacity(0.92))
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
