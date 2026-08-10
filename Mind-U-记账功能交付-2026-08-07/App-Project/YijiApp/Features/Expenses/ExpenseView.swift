import SwiftUI
import UIKit
import YijiCore

struct ExpenseView: View {
    private enum SummaryPeriod: String, CaseIterable, Identifiable {
        case month = "月度"
        case quarter = "季度"
        case year = "年度"

        var id: String { rawValue }
    }

    fileprivate struct CategoryTotal: Identifiable {
        let category: ExpenseCategoryDefinition
        let amount: Double
        let fraction: Double

        var id: String { category.id }
    }

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.openURL) private var openURL
    @State private var period: SummaryPeriod = .month
    @State private var showingDraftEditor = false
    @State private var showingCategoryPicker = false
    @State private var showingAllExpenses = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header

                if appModel.expenseSpeech.isRecording || !appModel.expenseDraftText.isEmpty {
                    voicePanel
                }

                if !appModel.expenseSpeech.isRecording, appModel.expenseDraft != nil {
                    confirmationCard
                }

                summaryCard
                recentExpensesCard
            }
            .padding(16)
            .padding(.bottom, 12)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDraftEditor) {
            ExpenseDraftEditorView()
                .environmentObject(appModel)
        }
        .sheet(isPresented: $showingCategoryPicker) {
            ExpenseCategoryPickerView(selection: draftCategoryBinding)
                .environmentObject(appModel)
        }
        .sheet(isPresented: $showingAllExpenses) {
            ExpenseLedgerView()
                .environmentObject(appModel)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("记账")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.ink)

                Text("说一句，就记下一笔消费")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }

            Spacer(minLength: 0)

            Button {
                toggleVoiceCapture()
            } label: {
                Label(
                    appModel.expenseSpeech.isRecording ? "完成" : "语音记一笔",
                    systemImage: appModel.expenseSpeech.isRecording ? "stop.fill" : "mic.fill"
                )
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(appModel.expenseSpeech.isRecording ? Color.red.opacity(0.14) : AppTheme.accent.opacity(0.14))
                )
                .foregroundStyle(appModel.expenseSpeech.isRecording ? .red : AppTheme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    private var voicePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: appModel.expenseSpeech.isRecording ? "waveform" : "text.bubble")
                    .foregroundStyle(appModel.expenseSpeech.isRecording ? .red : AppTheme.accent)
                Text(appModel.expenseSpeech.isRecording ? "正在识别消费内容" : "识别文字")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            TextField(
                "例如：今天买洗面奶 129 元",
                text: Binding(
                    get: { appModel.expenseDraftText },
                    set: appModel.updateExpenseDraftText
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
                Label("还没有识别到金额，请补充“129 元”这样的金额。", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appModel.expenseSpeech.authorizationStatus == .denied {
                Button("前往系统设置开启语音权限") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .font(.caption.weight(.medium))
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var confirmationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("确认这一笔")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let draft = appModel.expenseDraft {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(draft.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(currency(draft.amount))
                        .font(.title2.weight(.bold))
                }

                HStack(spacing: 5) {
                    Button {
                        showingCategoryPicker = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: draftCategory.systemImage)
                            Text(draftCategory.name)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(color(for: draftCategory))
                    }
                    .buttonStyle(.plain)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    Text(relativeDate(draft.spentAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack(spacing: 12) {
                    Button("清除") {
                        appModel.clearExpenseDraft()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("修改") {
                        showingDraftEditor = true
                    }
                    .buttonStyle(.bordered)

                    Button("确认记账") {
                        Task {
                            await appModel.saveExpenseDraft()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("汇总周期", selection: $period) {
                ForEach(SummaryPeriod.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(currency(periodTotal))
                        .font(.title.bold())
                        .foregroundStyle(AppTheme.ink)
                }
                Spacer()
                Text("共 \(periodExpenses.count) 笔")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if categoryTotals.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("这个周期还没有支出")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                HStack(alignment: .center, spacing: 22) {
                    DonutChartView(items: categoryTotals)
                        .frame(width: 148, height: 148)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(categoryTotals.prefix(5))) { total in
                            categoryLegendRow(total)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private var recentExpensesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近帐目")
                    .font(.headline)
                Spacer()
                if !appModel.expenses.isEmpty {
                    Button("查看全部") {
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
                    Text("第一笔消费会显示在这里")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 26)
            } else {
                ForEach(Array(appModel.expenses.prefix(5).enumerated()), id: \.element.id) { index, expense in
                    if index > 0 {
                        Divider()
                    }
                    expenseRow(expense)
                }
            }
        }
        .padding(18)
        .background(cardBackground)
    }

    private func categoryLegendRow(_ total: CategoryTotal) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color(for: total.category))
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 1) {
                Text(total.category.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                Text("\(Int((total.fraction * 100).rounded()))% · \(currency(total.amount))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        let category = appModel.expenseCategory(for: expense.categoryID)
        return HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color(for: category))
                .frame(width: 36, height: 36)
                .background(color(for: category).opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(expense.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(category.name) · \(relativeDate(expense.spentAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(currency(expense.amount))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("删除", systemImage: "trash", role: .destructive) {
                Task {
                    await appModel.deleteExpense(id: expense.id)
                }
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
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
        return appModel.expenses.filter { expense in
            switch period {
            case .month:
                return calendar.isDate(expense.spentAt, equalTo: now, toGranularity: .month)
            case .quarter:
                let expenseQuarter = (calendar.component(.month, from: expense.spentAt) - 1) / 3
                let currentQuarter = (calendar.component(.month, from: now) - 1) / 3
                return calendar.component(.year, from: expense.spentAt) == calendar.component(.year, from: now)
                    && expenseQuarter == currentQuarter
            case .year:
                return calendar.isDate(expense.spentAt, equalTo: now, toGranularity: .year)
            }
        }
    }

    private var periodTotal: Double {
        periodExpenses.reduce(0) { $0 + $1.amount }
    }

    private var categoryTotals: [CategoryTotal] {
        guard periodTotal > 0 else { return [] }
        let grouped = Dictionary(grouping: periodExpenses, by: \.categoryID)
        return grouped.map { categoryID, expenses in
            let amount = expenses.reduce(0) { $0 + $1.amount }
            return CategoryTotal(
                category: appModel.expenseCategory(for: categoryID),
                amount: amount,
                fraction: amount / periodTotal
            )
        }
        .sorted { $0.amount > $1.amount }
    }

    private var periodTitle: String {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        let year = calendar.component(.year, from: now)
        switch period {
        case .month:
            return "\(calendar.component(.month, from: now)) 月总支出"
        case .quarter:
            return "\(year) 年第 \((calendar.component(.month, from: now) - 1) / 3 + 1) 季度"
        case .year:
            return "\(year) 年总支出"
        }
    }

    private func toggleVoiceCapture() {
        if appModel.expenseSpeech.isRecording {
            appModel.stopExpenseVoiceCapture()
        } else {
            appModel.startExpenseVoiceCapture()
        }
    }
}

private struct DonutChartView: View {
    let items: [ExpenseView.CategoryTotal]

    var body: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                RingSegmentShape(
                    startFraction: items.prefix(index).reduce(0) { $0 + $1.fraction },
                    endFraction: items.prefix(index + 1).reduce(0) { $0 + $1.fraction }
                )
                .fill(color(for: item.category))
            }

            Circle()
                .fill(AppTheme.surface)
                .frame(width: 78, height: 78)

            VStack(spacing: 2) {
                Text("支出")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(items.count) 类")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("支出分类圆环图，共 \(items.count) 个类别")
    }
}

private struct RingSegmentShape: Shape {
    let startFraction: Double
    let endFraction: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle.degrees(startFraction * 360 - 90)
        let endAngle = Angle.degrees(endFraction * 360 - 90)
        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct ExpenseDraftEditorView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCategoryPicker = false

    var body: some View {
        NavigationStack {
            Form {
                if appModel.expenseDraft != nil {
                    Section("消费") {
                        TextField("消费内容", text: titleBinding)
                        TextField("金额", value: amountBinding, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                    }

                    Section("归类") {
                        Button {
                            showingCategoryPicker = true
                        } label: {
                            HStack {
                                Label(category.name, systemImage: category.systemImage)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        DatePicker("日期", selection: dateBinding, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("修改帐目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .disabled(appModel.expenseDraft == nil)
                }
            }
            .sheet(isPresented: $showingCategoryPicker) {
                ExpenseCategoryPickerView(selection: categoryBinding)
                    .environmentObject(appModel)
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { appModel.expenseDraft?.title ?? "" },
            set: { value in appModel.updateExpenseDraft { $0.title = value } }
        )
    }

    private var amountBinding: Binding<Double> {
        Binding(
            get: { appModel.expenseDraft?.amount ?? 0 },
            set: { value in appModel.updateExpenseDraft { $0.amount = value } }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { appModel.expenseDraft?.spentAt ?? Date() },
            set: { value in appModel.updateExpenseDraft { $0.spentAt = value } }
        )
    }

    private var categoryBinding: Binding<String> {
        Binding(
            get: { appModel.expenseDraft?.categoryID ?? BuiltInExpenseCategory.uncategorized.rawValue },
            set: { value in appModel.updateExpenseDraft { $0.categoryID = value } }
        )
    }

    private var category: ExpenseCategoryDefinition {
        appModel.expenseCategory(for: categoryBinding.wrappedValue)
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
                Section("类别") {
                    ForEach(appModel.expenseCategories) { category in
                        Button {
                            selection = category.id
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: category.systemImage)
                                    .foregroundStyle(color(for: category))
                                    .frame(width: 24)
                                Text(category.name)
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
                        Label("新增自定义类别", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("选择类别")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                NavigationStack {
                    Form {
                        Section("名称") {
                            TextField("例如：收藏", text: $newCategoryName)
                        }
                        Section("颜色") {
                            HStack(spacing: 18) {
                                ForEach(availableColors, id: \.self) { hex in
                                    Button {
                                        selectedColorHex = hex
                                    } label: {
                                        Circle()
                                            .fill(color(hex: hex))
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
                    .navigationTitle("新增类别")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") { showingNewCategory = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("新增") {
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
                    let category = appModel.expenseCategory(for: expense.categoryID)
                    HStack(spacing: 12) {
                        Image(systemName: category.systemImage)
                            .foregroundStyle(color(for: category))
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(expense.title)
                            Text("\(category.name) · \(relativeDate(expense.spentAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(currency(expense.amount))
                            .font(.subheadline.weight(.semibold))
                    }
                    .swipeActions {
                        Button("删除", role: .destructive) {
                            Task {
                                await appModel.deleteExpense(id: expense.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("全部帐目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private func currency(_ amount: Double) -> String {
    amount.formatted(.currency(code: "CNY").precision(.fractionLength(amount.rounded() == amount ? 0 : 2)))
}

private func relativeDate(_ date: Date) -> String {
    let calendar = Calendar(identifier: .gregorian)
    if calendar.isDateInToday(date) { return "今天" }
    if calendar.isDateInYesterday(date) { return "昨天" }
    return date.formatted(.dateTime.month().day())
}

private func color(for category: ExpenseCategoryDefinition) -> Color {
    color(hex: category.colorHex)
}

private func color(hex: String) -> Color {
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

#Preview("记账") {
    PreviewSupport.canvas {
        NavigationStack {
            ExpenseView()
        }
    }
}
