import SwiftUI

struct CalendarInlineItem: Identifiable, Equatable {
    enum Tone {
        case record
        case pending
        case completed
    }

    let id: String
    let time: String
    let title: String
    let status: String
    let tone: Tone
}

struct CalendarMonthView: View {
    let selectedDate: Date
    let visibleMonth: Date
    let eventDates: Set<Date>
    let reminderDates: Set<Date>
    let notifiedDates: Set<Date>
    let weatherByDate: [Date: CalendarDayWeather]
    let calendar: Calendar
    let inlineItems: [CalendarInlineItem]
    let onDateSelected: (Date) -> Void
    let onVisibleMonthChanged: (Date) -> Void

    @State private var expandedDate: Date?

    init(
        selectedDate: Date,
        visibleMonth: Date,
        eventDates: Set<Date>,
        reminderDates: Set<Date>,
        notifiedDates: Set<Date>,
        weatherByDate: [Date: CalendarDayWeather],
        calendar: Calendar,
        inlineItems: [CalendarInlineItem] = [],
        onDateSelected: @escaping (Date) -> Void,
        onVisibleMonthChanged: @escaping (Date) -> Void
    ) {
        self.selectedDate = selectedDate
        self.visibleMonth = visibleMonth
        self.eventDates = eventDates
        self.reminderDates = reminderDates
        self.notifiedDates = notifiedDates
        self.weatherByDate = weatherByDate
        self.calendar = calendar
        self.inlineItems = inlineItems
        self.onDateSelected = onDateSelected
        self.onVisibleMonthChanged = onVisibleMonthChanged
        _expandedDate = State(initialValue: calendar.startOfDay(for: selectedDate))
    }

    var body: some View {
        VStack(spacing: 0) {
            monthHeader
                .padding(.bottom, 18)

            weekdayHeader
                .padding(.bottom, 8)

            VStack(spacing: 4) {
                ForEach(Array(monthWeeks.enumerated()), id: \.offset) { _, week in
                    weekRow(week)

                    if let expandedDate,
                       week.contains(where: { date in
                           guard let date else { return false }
                           return displayCalendar.isDate(date, inSameDayAs: expandedDate)
                       }) {
                        expandedDetails(for: expandedDate)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            ))
                    }
                }
            }
        }
        .onChange(of: selectedDate) { newValue in
            let day = displayCalendar.startOfDay(for: newValue)
            guard expandedDate.map({ !displayCalendar.isDate($0, inSameDayAs: day) }) ?? true else {
                return
            }
            expandedDate = day
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 12) {
            Text(monthTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppTheme.ink)

            Spacer()

            monthButton(systemImage: "chevron.left") {
                moveMonth(by: -1)
            }

            monthButton(systemImage: "chevron.right") {
                moveMonth(by: 1)
            }
        }
    }

    private func monthButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.ink)
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppTheme.canvas))
                .overlay(Circle().stroke(AppTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(weekdayNames, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func weekRow(_ week: [Date?]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                if let date {
                    dayButton(date)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
        }
    }

    private func dayButton(_ date: Date) -> some View {
        let day = displayCalendar.startOfDay(for: date)
        let isSelected = displayCalendar.isDate(day, inSameDayAs: selectedDate)
        let isExpanded = expandedDate.map { displayCalendar.isDate(day, inSameDayAs: $0) } ?? false

        return Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                if isExpanded {
                    expandedDate = nil
                } else {
                    expandedDate = day
                    onDateSelected(day)
                }
            }
        } label: {
            VStack(spacing: 3) {
                Text(dayNumberFormatter.string(from: day))
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : dayTextColor(day))
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(isSelected ? AppTheme.accent : Color.clear)
                    )

                HStack(spacing: 2) {
                    statusDot(visible: eventDates.contains(day), color: AppTheme.accent)
                    statusDot(visible: reminderDates.contains(day), color: AppTheme.reminder)
                    statusDot(visible: notifiedDates.contains(day), color: AppTheme.completed)
                    statusDot(visible: weatherByDate[day] != nil, color: Color(red: 0.40, green: 0.54, blue: 0.60))
                }
                .frame(height: 3)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDateFormatter.string(from: day))
        .accessibilityValue(isExpanded ? "已展开" : "未展开")
    }

    private func statusDot(visible: Bool, color: Color) -> some View {
        Circle()
            .fill(visible ? color : Color.clear)
            .frame(width: 3, height: 3)
    }

    private func expandedDetails(for date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(detailDateFormatter.string(from: date))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.ink)

                    Text(AppLocalization.format("records_for_day_count", inlineItems.count))
                        .font(.caption2)
                        .foregroundStyle(AppTheme.muted)
                }

                Spacer()

                if let weather = weatherByDate[displayCalendar.startOfDay(for: date)] {
                    Label(weatherSummary(weather), systemImage: weather.symbolName)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                        .lineLimit(1)
                }
            }

            if inlineItems.isEmpty {
                Text("当天暂无记录，可以按住语音添加")
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(inlineItems.prefix(4)) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.time)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.muted)

                            Text(item.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.ink)
                                .lineLimit(1)

                            Text(item.status)
                                .font(.caption2)
                                .foregroundStyle(toneColor(item.tone))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(AppTheme.surface.opacity(0.82))
                        )
                    }
                }
            }
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surfaceMuted)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
        .padding(.vertical, 6)
    }

    private func toneColor(_ tone: CalendarInlineItem.Tone) -> Color {
        switch tone {
        case .record:
            AppTheme.accent
        case .pending:
            AppTheme.reminder
        case .completed:
            AppTheme.completed
        }
    }

    private func dayTextColor(_ date: Date) -> Color {
        displayCalendar.isDateInToday(date) ? AppTheme.accent : AppTheme.ink
    }

    private func weatherSummary(_ weather: CalendarDayWeather) -> String {
        "\(weather.highTemperatureText) · \(weather.conditionDescription)"
    }

    private func moveMonth(by value: Int) {
        guard let month = displayCalendar.date(byAdding: .month, value: value, to: monthStart) else {
            return
        }
        expandedDate = nil
        onVisibleMonthChanged(month)
    }

    private var displayCalendar: Calendar {
        var value = calendar
        value.locale = calendarLocale
        value.firstWeekday = 1
        return value
    }

    private var monthStart: Date {
        let components = displayCalendar.dateComponents([.year, .month], from: visibleMonth)
        return displayCalendar.date(from: components) ?? visibleMonth
    }

    private var monthWeeks: [[Date?]] {
        guard let dayRange = displayCalendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let weekday = displayCalendar.component(.weekday, from: monthStart)
        let leadingCount = (weekday - displayCalendar.firstWeekday + 7) % 7
        var days = Array<Date?>(repeating: nil, count: leadingCount)

        for day in dayRange {
            days.append(displayCalendar.date(byAdding: .day, value: day - 1, to: monthStart))
        }

        let trailingCount = (7 - days.count % 7) % 7
        days.append(contentsOf: Array<Date?>(repeating: nil, count: trailingCount))

        return stride(from: 0, to: days.count, by: 7).map { index in
            Array(days[index..<min(index + 7, days.count)])
        }
    }

    private var monthTitle: String {
        monthTitleFormatter.string(from: monthStart)
    }

    private var weekdayNames: [String] {
        ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
            .map(AppLocalization.text)
    }

    private var monthTitleFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = calendarLocale
        formatter.dateFormat = usesEnglish ? "MMMM yyyy" : "yyyy 年 M 月"
        return formatter
    }

    private var detailDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = calendarLocale
        formatter.dateFormat = usesEnglish ? "MMMM d" : "M 月 d 日"
        return formatter
    }

    private var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = calendarLocale
        formatter.dateFormat = "d"
        return formatter
    }

    private var accessibilityDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = calendarLocale
        formatter.dateStyle = .long
        return formatter
    }

    private var usesEnglish: Bool {
        AppLocalization.languageCode.lowercased().hasPrefix("en")
    }

    private var calendarLocale: Locale {
        Locale(identifier: usesEnglish ? "en_US" : "zh_CN")
    }
}
