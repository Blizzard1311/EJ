import SwiftUI
import UIKit

struct CalendarMonthView: UIViewRepresentable {
    let selectedDate: Date
    let visibleMonth: Date
    let eventDates: Set<Date>
    let reminderDates: Set<Date>
    let notifiedDates: Set<Date>
    let calendar: Calendar
    let onDateSelected: (Date) -> Void
    let onVisibleMonthChanged: (Date) -> Void
    let onHeightChanged: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> CalendarContainerView {
        let container = CalendarContainerView()
        let calendarView = container.calendarView

        calendarView.calendar = calendar
        calendarView.locale = Locale(identifier: "zh_CN")
        calendarView.fontDesign = .rounded
        calendarView.wantsDateDecorations = true
        calendarView.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        selection.selectedDate = dateComponents(for: selectedDate)
        calendarView.selectionBehavior = selection
        calendarView.visibleDateComponents = dateComponents(for: visibleMonth)

        container.applyCalendarChrome()
        return container
    }

    func updateUIView(_ uiView: CalendarContainerView, context: Context) {
        context.coordinator.parent = self

        let calendarView = uiView.calendarView
        calendarView.calendar = calendar
        calendarView.locale = Locale(identifier: "zh_CN")

        let selectedComponents = dateComponents(for: selectedDate)
        if let selection = calendarView.selectionBehavior as? UICalendarSelectionSingleDate,
           selection.selectedDate != selectedComponents {
            selection.setSelected(selectedComponents, animated: true)
        }

        let visibleComponents = dateComponents(for: visibleMonth)
        if calendarView.visibleDateComponents.year != visibleComponents.year
            || calendarView.visibleDateComponents.month != visibleComponents.month {
            calendarView.setVisibleDateComponents(visibleComponents, animated: true)
        }

        let decoratedDays = eventDates.union(reminderDates).union(notifiedDates)
        let daysToReload = decoratedDays.union(context.coordinator.decoratedDays)
        context.coordinator.decoratedDays = decoratedDays
        if !daysToReload.isEmpty {
            calendarView.reloadDecorations(
                forDateComponents: Array(daysToReload).map(dateComponents(for:)),
                animated: true
            )
        }

        uiView.applyCalendarChrome()
        calendarView.setNeedsLayout()
        calendarView.layoutIfNeeded()
        uiView.layoutIfNeeded()
        updateMeasuredHeight(for: uiView, coordinator: context.coordinator)
    }

    private func dateComponents(for date: Date) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.calendar = calendar
        return components
    }

    private func updateMeasuredHeight(for container: CalendarContainerView, coordinator: Coordinator) {
        let calendarView = container.calendarView
        let targetWidth = max(calendarView.bounds.width, container.bounds.width)

        let intrinsicHeight = calendarView.intrinsicContentSize.height
        let fittingHeight = calendarView.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height

        let measuredHeight = max(intrinsicHeight, fittingHeight) + 8
        guard measuredHeight.isFinite, measuredHeight > 0 else {
            return
        }

        let roundedHeight = ceil(measuredHeight)
        guard abs(coordinator.lastReportedHeight - roundedHeight) > 1 else {
            return
        }

        coordinator.lastReportedHeight = roundedHeight
        DispatchQueue.main.async {
            onHeightChanged(roundedHeight)
        }
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarMonthView
        var decoratedDays: Set<Date> = []
        var lastReportedHeight: CGFloat = 0

        init(_ parent: CalendarMonthView) {
            self.parent = parent
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents,
                  let date = parent.calendar.date(from: dateComponents) else {
                return
            }
            parent.onDateSelected(parent.calendar.startOfDay(for: date))
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let date = parent.calendar.date(from: dateComponents) else {
                return nil
            }

            let day = parent.calendar.startOfDay(for: date)
            let hasRecord = parent.eventDates.contains(day)
            let hasPendingReminder = parent.reminderDates.contains(day)
            let hasNotifiedReminder = parent.notifiedDates.contains(day)

            guard hasRecord || hasPendingReminder || hasNotifiedReminder else {
                return nil
            }

            return .image(
                decorationImage(
                    hasRecord: hasRecord,
                    hasPendingReminder: hasPendingReminder,
                    hasNotifiedReminder: hasNotifiedReminder
                ),
                size: .medium
            )
        }

        func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
            guard let date = parent.calendar.date(from: calendarView.visibleDateComponents) else {
                return
            }
            parent.onVisibleMonthChanged(date)
        }

        private func decorationImage(
            hasRecord: Bool,
            hasPendingReminder: Bool,
            hasNotifiedReminder: Bool
        ) -> UIImage? {
            let colors = decorationColors(
                hasRecord: hasRecord,
                hasPendingReminder: hasPendingReminder,
                hasNotifiedReminder: hasNotifiedReminder
            )

            guard !colors.isEmpty else {
                return nil
            }

            let dotDiameter: CGFloat = 6
            let spacing: CGFloat = 3
            let width = CGFloat(colors.count) * dotDiameter + CGFloat(max(colors.count - 1, 0)) * spacing
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: dotDiameter))

            return renderer.image { context in
                for (index, color) in colors.enumerated() {
                    let originX = CGFloat(index) * (dotDiameter + spacing)
                    let dotRect = CGRect(x: originX, y: 0, width: dotDiameter, height: dotDiameter)
                    context.cgContext.setFillColor(color.cgColor)
                    context.cgContext.fillEllipse(in: dotRect)
                }
            }
            .withRenderingMode(.alwaysOriginal)
        }

        private func decorationColors(
            hasRecord: Bool,
            hasPendingReminder: Bool,
            hasNotifiedReminder: Bool
        ) -> [UIColor] {
            var colors: [UIColor] = []

            if hasRecord {
                colors.append(.systemBlue)
            }

            if hasPendingReminder {
                colors.append(.systemOrange)
            }

            if hasNotifiedReminder {
                colors.append(.systemGreen)
            }

            return colors
        }
    }
}

final class CalendarContainerView: UIView {
    let calendarView = UICalendarView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyCalendarChrome() {
        backgroundColor = .clear
        layer.cornerRadius = 22
        clipsToBounds = true

        calendarView.backgroundColor = .clear
    }

    private func setup() {
        backgroundColor = .clear
        clipsToBounds = true

        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.backgroundColor = .clear
        calendarView.setContentHuggingPriority(.required, for: .vertical)
        calendarView.setContentCompressionResistancePriority(.required, for: .vertical)
        addSubview(calendarView)

        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            calendarView.topAnchor.constraint(equalTo: topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
