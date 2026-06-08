import SwiftUI
import YijiCore

struct SearchView: View {
    @Environment(AppModel.self) private var appModel

    @State private var selectedFilter: SearchFilter = .all
    @State private var deletingRecord: Record?

    var body: some View {
        List {
            searchInputSection

            if isSearching {
                resultSummarySection
            } else if !appModel.searchHistory.isEmpty {
                recentSearchSection
            } else {
                onboardingSection
            }

            resultsSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(screenBackground)
        .navigationTitle("搜索页")
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

    private var searchInputSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("搜索物品、位置、提醒和关键词")
                    .font(.headline.weight(.semibold))

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("搜索物品、位置、关键词", text: Bindable(appModel).searchText)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)
                        .onSubmit {
                            appModel.registerSearchTerm(appModel.searchText)
                        }

                    if isSearching {
                        Button("清空") {
                            appModel.searchText = ""
                            selectedFilter = .all
                        }
                        .font(.footnote)
                    }
                }

                filterPicker

                quickFilters
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

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchFilter.allCases, id: \.self) { filter in
                    Button(filter.title) {
                        selectedFilter = filter
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(selectedFilter == filter ? Color.blue.opacity(0.14) : Color(red: 0.97, green: 0.98, blue: 1.0))
                    )
                    .foregroundStyle(selectedFilter == filter ? .blue : .primary)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var quickFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                quickFilter("户口本")
                quickFilter("身份证在哪")
                quickFilter("钥匙")
                quickFilter("发票")
                quickFilter("提醒")
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var resultSummarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("查询回答", subtitle: "系统会优先展示最接近的一条记录")

                Text(answerText)
                    .font(.body)

                HStack {
                    summaryPill("\(filteredResults.count) 条结果", systemImage: "tray.full")
                    summaryPill(selectedFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var recentSearchSection: some View {
        Section {
            HStack {
                sectionTitle("最近搜索", subtitle: "点一下继续搜，点右侧可移除")
                Spacer()
                Button("清空历史") {
                    appModel.clearSearchHistory()
                }
                .font(.footnote)
            }
            .padding(.bottom, 4)

            ForEach(appModel.searchHistory, id: \.self) { term in
                HStack {
                    Button {
                        appModel.searchText = term
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        appModel.removeSearchTerm(term)
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
                )
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var onboardingSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("试试这些自然语言搜索", subtitle: "按照你真实会说的话去搜就行")
                exampleSearch("户口本在哪")
                exampleSearch("帮我找身份证")
                exampleSearch("有哪些提醒记录")
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.92))
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var resultsSection: some View {
        Section {
            sectionTitle(resultsTitle, subtitle: isSearching ? "保留最相关的记录，支持继续进入详情" : "你的全部本地记录")

            if filteredResults.isEmpty {
                emptyState
            } else {
                ForEach(filteredResults) { record in
                    NavigationLink {
                        RecordDetailView(recordID: record.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            RecordRowView(record: record)
                            if isSearching {
                                Text(record.answerSummary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.white.opacity(0.92))
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
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 18, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emptyTitle)
                .font(.headline)
            Text(emptyDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.92))
        )
    }

    private func quickFilter(_ keyword: String) -> some View {
        Button(keyword) {
            appModel.searchText = keyword
            appModel.registerSearchTerm(keyword)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func exampleSearch(_ text: String) -> some View {
        Button(text) {
            appModel.searchText = text
            appModel.registerSearchTerm(text)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
        )
    }

    private func summaryPill(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(red: 0.97, green: 0.98, blue: 1.0))
            )
            .foregroundStyle(.secondary)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var filteredResults: [Record] {
        switch selectedFilter {
        case .all:
            appModel.searchResults
        case .storage:
            appModel.searchResults.filter { $0.category == .storage }
        case .reminder:
            appModel.searchResults.filter { $0.category == .reminder }
        case .note:
            appModel.searchResults.filter { $0.category == .note }
        case .other:
            appModel.searchResults.filter { $0.category == .other }
        }
    }

    private var isSearching: Bool {
        !appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var answerText: String {
        let keyword = appModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            return "输入关键词后，这里会返回模板化回答。"
        }

        if let first = filteredResults.first {
            if filteredResults.count == 1 {
                return first.answerSummary
            }
            return "我找到了 \(filteredResults.count) 条与“\(keyword)”相关的记录，最近一条是：\(first.answerSummary)"
        }

        return "没有找到与“\(keyword)”相关的历史记录。"
    }

    private var resultsTitle: String {
        if isSearching {
            return "搜索结果"
        }
        return "全部记录"
    }

    private var emptyTitle: String {
        if isSearching {
            return "没有找到结果"
        }
        return "还没有可搜索的记录"
    }

    private var emptyDescription: String {
        if isSearching {
            return "换个关键词试试，或者减少筛选条件。"
        }
        return "先去录入一句话，之后就能在这里快速找回。"
    }
}

private enum SearchFilter: CaseIterable {
    case all
    case storage
    case reminder
    case note
    case other

    var title: String {
        switch self {
        case .all:
            "全部"
        case .storage:
            "位置"
        case .reminder:
            "提醒"
        case .note:
            "笔记"
        case .other:
            "其他"
        }
    }
}

#Preview("搜索页 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            SearchView()
        }
    }
}

#Preview("搜索页 - Dark") {
    PreviewSupport.canvas(colorScheme: .dark) {
        NavigationStack {
            SearchView()
        }
    }
}

#Preview("搜索页 - 无结果") {
    PreviewSupport.canvas(model: PreviewSupport.searchEmptyAppModel()) {
        NavigationStack {
            SearchView()
        }
    }
}

#Preview("搜索页 - 空状态") {
    PreviewSupport.canvas(model: PreviewSupport.emptyAppModel(), device: "iPhone SE (3rd generation)") {
        NavigationStack {
            SearchView()
        }
    }
}
