import SwiftUI
import UIKit
import YijiCore

struct ExpenseView: View {
    private enum SummaryPeriod: String, CaseIterable, Identifiable {
        case month
        case quarter
        case year

        var id: String { rawValue }

        var title: String {
            switch self {
            case .month: AppLocalization.text("月度")
            case .quarter: AppLocalization.text("季度")
            case .year: AppLocalization.text("年度")
            }
        }
    }

    fileprivate struct CategoryTotal: Identifiable {
        let category: ExpenseCategoryDefinition
        let amountMinorUnits: Int64
        let fraction: Double

        var id: String { category.id }
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var period: SummaryPeriod = .month
    @State private var selectedMonth = Calendar(identifier: .gregorian).component(.month, from: Date())
    @State private var selectedQuarter = (Calendar(identifier: .gregorian).component(.month, from: Date()) - 1) / 3 + 1
    @State private var selectedYear = Calendar(identifier: .gregorian).component(.year, from: Date())
    @State private var editingDraft: ExpenseDraft?
    @State private var showingDraftEditor = false
    @State private var showingCategoryPicker = false
    @State private var showingAllExpenses = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header

                if appModel.isExpenseEntryActive || appModel.expenseSpeech.isRecording {
                    entryPanel
                }

                if !appModel.expenseSpeech.isRecording, appModel.expenseDraft != nil {
                    confirmationCard
                }

                summaryCard
                recentExpensesCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDraftEditor) {
            if let editingDraft {
                ExpenseDraftEditorView(draft: editingDraft) { updatedDraft in
                    appModel.replaceExpenseDraft(updatedDraft)
                }
                .environmentObject(appModel)
            }
        }
        .sheet(isPresented: $showingCategoryPicker) {
            ExpenseCategoryPickerView(selection: draftCategoryBinding)
                .environmentObject(appModel)
        }
        .sheet(isPresented: $showingAllExpenses) {
            ExpenseLedgerView()
                .environmentObject(appModel)
        }
        .onDisappear {
            appModel.stopExpenseVoiceCapture()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text("记账"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    Text(AppLocalization.text("说一句，就记下一笔消费"))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer(minLength: 12)

                Menu {
                    ForEach(ExpenseCurrency.allCases) { currency in
                        Button {
                            appModel.selectExpenseCurrency(currency)
                            if !appModel.expenseDraftText.isEmpty {
                                appModel.updateExpenseDraftText(appModel.expenseDraftText)
                            }
                        } label: {
                            if appModel.selectedExpenseCurrency == currency {
                                Label(currency.displayName, systemImage: "checkmark")
                            } else {
                                Text(currency.displayName)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(appModel.selectedExpenseCurrency.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.bold))
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceMuted, in: Capsule())
                }
                .accessibilityLabel(AppLocalization.text("默认币种"))
            }

            HStack(spacing: 10) {
                Button {
                    toggleVoiceCapture()
                } label: {
                    Label(
                        AppLocalization.text(appModel.expenseSpeech.isRecording ? "完成识别" : "语音记一笔"),
                        systemImage: appModel.expenseSpeech.isRecording ? "stop.fill" : "mic.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ExpensePrimaryButtonStyle(isDestructive: appModel.expenseSpeech.isRecording))

                Button {
                    appModel.beginManualExpenseEntry()
                } label: {
                    Label(AppLocalization.text("文字记一笔"), systemImage: "keyboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ExpenseSecondaryButtonStyle())
            }
        }
    }

    private var entryPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: appModel.expenseSpeech.isRecording ? "waveform" : "text.bubble")
                    .foregroundStyle(appModel.expenseSpeech.isRecording ? .red : AppTheme.accent)
                Text(AppLocalization.text(appModel.expenseSpeech.isRecording ? "正在识别消费内容" : "消费描述"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if appModel.expenseSpeech.isRecording {
                    Text(AppLocalization.text("正在录音"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            TextField(
                AppLocalization.text("例如：今天买洗面奶 129 元"),
                text: Binding(
                    get: { appModel.expenseDraftText },
                    set: { value in appModel.updateExpenseDraftText(value) }
                ),
                axis: .vertical
            )
            .lineLimit(2...5)
            .textFieldStyle(.plain)
            .padding(12)
            .background(AppTheme.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if !appModel.expenseSpeech.isRecording,
               !appModel.expenseDraftText.isEmpty,
               appModel.expenseDraft == nil {
                Label(
                    AppLocalization.text("还没有识别到金额，请补充金额和币种。"),
                    systemImage: "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let errorMessage = appModel.expenseSpeech.errorMessage, !errorMessage.isEmpty {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                if appModel.expenseSpeech.authorizationStatus == .denied {
                    Button(AppLocalization.text("前往系统设置开启语音权限")) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
                    .font(.caption.weight(.medium))
                }

                Spacer()

                Button(AppLocalization.text("清除")) {
                    appModel.clearExpenseDraft()
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AppLocalization.text("确认这一笔"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let draft = appModel.expenseDraft {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(draft.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(expenseCurrencyText(draft.amountMinorUnits, currency: draft.currency))
                        .font(.title2.weight(.bold))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: draftCategory.systemImage)
                            Text(draftCategory.displayName)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(expenseCategoryColor(draftCategory))
                    }
                    .buttonStyle(.plain)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(expenseRelativeDate(draft.spentAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 12) {
                    Button(AppLocalization.text("清除")) {
                        appModel.clearExpenseDraft()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button(AppLocalization.text("修改")) {
                        editingDraft = draft
                        showingDraftEditor = true
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await appModel.saveExpenseDraft() }
                    } label: {
                        if appModel.isSavingExpense {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text(AppLocalization.text("确认记账"))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                    .disabled(appModel.isSavingExpense)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker(AppLocalization.text("汇总周期"), selection: $period) {
                ForEach(SummaryPeriod.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppLocalization.text("总支出"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(expenseCurrencyText(periodTotal, currency: appModel.selectedExpenseCurrency))
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.ink)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                periodSelectionMenu
            }

            if categoryTotals.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(AppLocalization.text("这个周期还没有该币种的支出"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 22) {
                        DonutChartView(items: categoryTotals)
                            .frame(width: 142, height: 142)
                        categoryLegend
                    }

                    VStack(spacing: 18) {
                        DonutChartView(items: categoryTotals)
                            .frame(width: 150, height: 150)
                        categoryLegend
                    }
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var categoryLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(categoryTotals.prefix(5))) { total in
                HStack(spacing: 8) {
                    Circle()
                        .fill(expenseCategoryColor(total.category))
                        .frame(width: 9, height: 9)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(total.category.displayName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(
                            AppLocalization.format(
                                "expense.legend_format",
                                Int((total.fraction * 100).rounded()),
                                expenseCurrencyText(total.amountMinorUnits, currency: appModel.selectedExpenseCurrency)
                            )
                        )
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var recentExpensesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppLocalization.text("最近帐目"))
                    .font(.headline)
                Spacer()
                if !appModel.expenses.isEmpty {
                    Button(AppLocalization.text("查看全部")) {
                        showingAllExpenses = true
                    }
                    .font(.caption.weight(.medium))
                }
            }

            if appModel.expenses.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "receipt")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(AppLocalization.text("第一笔消费会显示在这里"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
            } else {
                List(Array(appModel.expenses.prefix(5))) { expense in
                    ExpenseRow(expense: expense)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(height: CGFloat(min(appModel.expenses.count, 5)) * 60 + 16)
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            }
    }

    private var draftCategory: ExpenseCategoryDefinition {
        guard let categoryID = appModel.expenseDraft?.categoryID else {
            return ExpenseCategoryDefinition(builtIn: .uncategorized)
        }
        return appModel.expenseCategory(for: categoryID)
    }

    private var draftCategoryBinding: Binding<String> {
        Binding(
            get: { appModel.expenseDraft?.categoryID ?? BuiltInExpenseCategory.uncategorized.rawValue },
            set: { categoryID in
                appModel.updateExpenseDraft { $0.categoryID = categoryID }
            }
        )
    }

    private var periodExpenses: [Expense] {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        return appModel.expenses.filter { expense in
            guard expense.currency == appModel.selectedExpenseCurrency else { return false }
            switch period {
            case .month:
                return calendar.component(.year, from: expense.spentAt) == currentYear
                    && calendar.component(.month, from: expense.spentAt) == selectedMonth
            case .quarter:
                let expenseQuarter = (calendar.component(.month, from: expense.spentAt) - 1) / 3
                return calendar.component(.year, from: expense.spentAt) == currentYear
                    && expenseQuarter + 1 == selectedQuarter
            case .year:
                return calendar.component(.year, from: expense.spentAt) == selectedYear
            }
        }
    }

    private var periodTotal: Int64 {
        periodExpenses.reduce(into: Int64(0)) { total, expense in
            total += expense.amountMinorUnits
        }
    }

    private var categoryTotals: [CategoryTotal] {
        guard periodTotal > 0 else { return [] }
        return Dictionary(grouping: periodExpenses, by: \.categoryID)
            .map { categoryID, expenses in
                let amount = expenses.reduce(into: Int64(0)) { total, expense in
                    total += expense.amountMinorUnits
                }
                return CategoryTotal(
                    category: appModel.expenseCategory(for: categoryID),
                    amountMinorUnits: amount,
                    fraction: Double(amount) / Double(periodTotal)
                )
            }
            .sorted { $0.amountMinorUnits > $1.amountMinorUnits }
    }

    private var periodSelectionTitle: String {
        switch period {
        case .month:
            return monthTitle(selectedMonth)
        case .quarter:
            return quarterTitle(selectedQuarter)
        case .year:
            return yearTitle(selectedYear)
        }
    }

    @ViewBuilder
    private var periodSelectionMenu: some View {
        switch period {
        case .month:
            Menu {
                ForEach(1...12, id: \.self) { month in
                    Button {
                        selectedMonth = month
                    } label: {
                        if selectedMonth == month {
                            Label(monthTitle(month), systemImage: "checkmark")
                        } else {
                            Text(monthTitle(month))
                        }
                    }
                }
            } label: {
                periodSelectorLabel
            }
            .accessibilityLabel(AppLocalization.text("选择月份"))
            .accessibilityValue(monthTitle(selectedMonth))
        case .quarter:
            Menu {
                ForEach(1...4, id: \.self) { quarter in
                    Button {
                        selectedQuarter = quarter
                    } label: {
                        if selectedQuarter == quarter {
                            Label(quarterTitle(quarter), systemImage: "checkmark")
                        } else {
                            Text(quarterTitle(quarter))
                        }
                    }
                }
            } label: {
                periodSelectorLabel
            }
            .accessibilityLabel(AppLocalization.text("选择季度"))
            .accessibilityValue(quarterTitle(selectedQuarter))
        case .year:
            Menu {
                ForEach(availableExpenseYears, id: \.self) { year in
                    Button {
                        selectedYear = year
                    } label: {
                        if selectedYear == year {
                            Label(yearTitle(year), systemImage: "checkmark")
                        } else {
                            Text(yearTitle(year))
                        }
                    }
                }
            } label: {
                periodSelectorLabel
            }
            .accessibilityLabel(AppLocalization.text("选择年份"))
            .accessibilityValue(yearTitle(selectedYear))
        }
    }

    private var periodSelectorLabel: some View {
        HStack(spacing: 4) {
            Text(periodSelectionTitle)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(Color.black)
    }

    private var availableExpenseYears: [Int] {
        let calendar = Calendar(identifier: .gregorian)
        let currentYear = calendar.component(.year, from: Date())
        let expenseYears = appModel.expenses.map { calendar.component(.year, from: $0.spentAt) }
        let selectableYears = Array((currentYear - 9)...(currentYear + 10))
        return Array(Set(expenseYears + selectableYears + [selectedYear])).sorted(by: >)
    }

    private func monthTitle(_ month: Int) -> String {
        AppLocalization.format("%d 月", month)
    }

    private func quarterTitle(_ quarter: Int) -> String {
        AppLocalization.format("第 %d 季度", quarter)
    }

    private func yearTitle(_ year: Int) -> String {
        AppLocalization.format("%d 年", year)
    }

    private func toggleVoiceCapture() {
        if appModel.expenseSpeech.isRecording {
            appModel.stopExpenseVoiceCapture()
        } else {
            appModel.startExpenseVoiceCapture()
        }
    }

}

private struct ExpensePrimaryButtonStyle: ButtonStyle {
    let isDestructive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .foregroundStyle(isDestructive ? .red : .white)
            .background(
                isDestructive ? Color.red.opacity(0.14) : AppTheme.accent.opacity(configuration.isPressed ? 0.78 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }
}

private struct ExpenseSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .foregroundStyle(AppTheme.accent)
            .background(
                AppTheme.surfaceMuted.opacity(configuration.isPressed ? 0.72 : 1),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            }
    }
}

private struct DonutChartView: View {
    let items: [ExpenseView.CategoryTotal]

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                ExpenseRingSegment(
                    startFraction: items.prefix(index).reduce(0) { $0 + $1.fraction },
                    endFraction: items.prefix(index + 1).reduce(0) { $0 + $1.fraction }
                )
                .fill(expenseCategoryColor(item.category))
            }

            Circle()
                .fill(AppTheme.surface)
                .frame(width: 76, height: 76)

            VStack(spacing: 2) {
                Text(AppLocalization.text("支出"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(AppLocalization.format("共 %d 类", items.count))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppLocalization.format("支出分类圆环图，共 %d 个类别", items.count))
    }
}

private struct ExpenseRingSegment: Shape {
    let startFraction: Double
    let endFraction: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startFraction * 360 - 90),
            endAngle: .degrees(endFraction * 360 - 90),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct ExpenseDraftEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var workingDraft: ExpenseDraft
    @State private var amountText: String
    @State private var showingCategoryPicker = false
    @State private var amountIsInvalid = false
    let onDelete: (() -> Void)?
    let onSave: (ExpenseDraft) -> Void

    init(
        draft: ExpenseDraft,
        onDelete: (() -> Void)? = nil,
        onSave: @escaping (ExpenseDraft) -> Void
    ) {
        _workingDraft = State(initialValue: draft)
        _amountText = State(initialValue: expenseDecimalText(draft.decimalAmount, currency: draft.currency))
        self.onDelete = onDelete
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(AppLocalization.text("消费")) {
                    TextField(AppLocalization.text("消费内容"), text: $workingDraft.title)
                    TextField(AppLocalization.text("金额"), text: $amountText)
                        .keyboardType(.decimalPad)

                    Picker(AppLocalization.text("币种"), selection: $workingDraft.currency) {
                        ForEach(ExpenseCurrency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }

                    if amountIsInvalid {
                        Text(AppLocalization.text("请输入有效的正数金额。"))
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(AppLocalization.text("归类")) {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        HStack {
                            Label(category.displayName, systemImage: category.systemImage)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    DatePicker(
                        AppLocalization.text("日期"),
                        selection: $workingDraft.spentAt,
                        displayedComponents: .date
                    )
                }

                if let onDelete {
                    Section {
                        Button(AppLocalization.text("删除帐目"), role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(AppLocalization.text("修改帐目"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.text("完成")) { save() }
                        .disabled(workingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                ExpenseCategoryPickerView(selection: $workingDraft.categoryID)
                    .environmentObject(appModel)
            }
        }
    }

    private var category: ExpenseCategoryDefinition {
        appModel.expenseCategory(for: workingDraft.categoryID)
    }

    private func save() {
        guard let amount = expenseDecimal(from: amountText),
              let minorUnits = workingDraft.currency.minorUnits(from: amount) else {
            amountIsInvalid = true
            return
        }
        workingDraft.title = workingDraft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        workingDraft.amountMinorUnits = minorUnits
        amountIsInvalid = false
        onSave(workingDraft)
        dismiss()
    }
}

private struct ExpenseCategoryPickerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: String
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""
    @State private var selectedColorHex = "D9C9E8"

    private let availableColors = ["B7C79F", "F29A92", "B8DDEA", "D9C9E8", "F3D8A6"]

    var body: some View {
        NavigationStack {
            List {
                Section(AppLocalization.text("类别")) {
                    ForEach(appModel.selectableExpenseCategories) { category in
                        Button {
                            selection = category.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.systemImage)
                                    .foregroundStyle(expenseCategoryColor(category))
                                    .frame(width: 24)
                                Text(category.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selection == category.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(AppTheme.accent)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        newCategoryName = ""
                        showingNewCategory = true
                    } label: {
                        Label(AppLocalization.text("新增自定义类别"), systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(AppLocalization.text("选择类别"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppLocalization.text("取消")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                NavigationStack {
                    Form {
                        Section(AppLocalization.text("名称")) {
                            TextField(AppLocalization.text("例如：收藏"), text: $newCategoryName)
                        }
                        Section(AppLocalization.text("颜色")) {
                            HStack(spacing: 18) {
                                ForEach(availableColors, id: \.self) { hex in
                                    Button {
                                        selectedColorHex = hex
                                    } label: {
                                        Circle()
                                            .fill(expenseColor(hex: hex))
                                            .frame(width: 32, height: 32)
                                            .overlay {
                                                if selectedColorHex == hex {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.bold())
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .navigationTitle(AppLocalization.text("新增类别"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(AppLocalization.text("取消")) { showingNewCategory = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(AppLocalization.text("新增")) {
                                Task {
                                    if let categoryID = await appModel.addCustomExpenseCategory(
                                        named: newCategoryName,
                                        colorHex: selectedColorHex
                                    ) {
                                        selection = categoryID
                                        showingNewCategory = false
                                        dismiss()
                                    }
                                }
                            }
                            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}

private struct ExpenseLedgerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(appModel.expenses) { expense in
                    ExpenseRow(expense: expense)
                }
            }
            .overlay {
                if appModel.expenses.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "receipt")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text(AppLocalization.text("暂无帐目"))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(AppLocalization.text("全部帐目"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppLocalization.text("完成")) { dismiss() }
                }
            }
        }
    }
}

private struct ExpenseRow: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var showingEditor = false
    let expense: Expense
    var showsSwipeActions = true

    var body: some View {
        let category = appModel.expenseCategory(for: expense.categoryID)
        HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(expenseCategoryColor(category))
                .frame(width: 36, height: 36)
                .background(
                    expenseCategoryColor(category).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(category.displayName) · \(expenseRelativeDate(expense.spentAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(expenseCurrencyText(expense.amountMinorUnits, currency: expense.currency))
                .font(.subheadline.weight(.semibold))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if showsSwipeActions {
                Button(AppLocalization.text("编辑")) {
                    showingEditor = true
                }
                .tint(AppTheme.accent)
            }
        }
        .sheet(isPresented: $showingEditor) {
            ExpenseDraftEditorView(
                draft: expenseDraft(from: expense),
                onDelete: {
                    Task { await appModel.deleteExpense(id: expense.id) }
                },
                onSave: { draft in
                    Task { await appModel.updateExpense(expense, with: draft) }
                }
            )
            .environmentObject(appModel)
        }
    }
}

private func expenseCurrencyText(_ minorUnits: Int64, currency: ExpenseCurrency) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency.rawValue
    formatter.locale = Locale(identifier: AppLocalization.languageCode)
    formatter.minimumFractionDigits = currency.minorUnitDigits
    formatter.maximumFractionDigits = currency.minorUnitDigits
    let decimal = currency.decimalAmount(from: minorUnits)
    return formatter.string(from: NSDecimalNumber(decimal: decimal))
        ?? "\(currency.rawValue) \(decimal)"
}

private func expenseDecimalText(_ amount: Decimal, currency: ExpenseCurrency) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: AppLocalization.languageCode)
    formatter.minimumFractionDigits = currency.minorUnitDigits
    formatter.maximumFractionDigits = currency.minorUnitDigits
    formatter.usesGroupingSeparator = false
    return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
}

private func expenseDecimal(from text: String) -> Decimal? {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: AppLocalization.languageCode)
    formatter.generatesDecimalNumbers = true
    if let number = formatter.number(from: text) as? NSDecimalNumber {
        return number.decimalValue
    }

    let normalized = text.replacingOccurrences(of: ",", with: ".")
    return Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
}

private func expenseRelativeDate(_ date: Date) -> String {
    let calendar = Calendar(identifier: .gregorian)
    if calendar.isDateInToday(date) { return AppLocalization.text("今天") }
    if calendar.isDateInYesterday(date) { return AppLocalization.text("昨天") }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: AppLocalization.languageCode)
    formatter.setLocalizedDateFormatFromTemplate("MMMd")
    return formatter.string(from: date)
}

private func expenseDraft(from expense: Expense) -> ExpenseDraft {
    ExpenseDraft(
        title: expense.title,
        amountMinorUnits: expense.amountMinorUnits,
        currency: expense.currency,
        categoryID: expense.categoryID,
        spentAt: expense.spentAt,
        originalTranscript: expense.originalTranscript ?? expense.title
    )
}

@MainActor
private func expenseCategoryColor(_ category: ExpenseCategoryDefinition) -> Color {
    expenseColor(hex: category.colorHex)
}

@MainActor
private func expenseColor(hex: String) -> Color {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    guard let value = UInt64(cleaned, radix: 16), cleaned.count == 6 else {
        return AppTheme.accent
    }
    return Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

#Preview("记账 - iPhone 16 Pro") {
    PreviewSupport.canvas {
        NavigationStack {
            ExpenseView()
        }
    }
}
