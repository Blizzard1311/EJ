import SwiftUI
import UIKit

struct CalendarMonthView: UIViewRepresentable {
    let selectedDate: Date
    let visibleMonth: Date
    let eventDates: Set<Date>
    let reminderDates: Set<Date>
    let notifiedDates: Set<Date>
    let weatherByDate: [Date: CalendarDayWeather]
    let calendar: Calendar
    let onDateSelected: (Date) -> Void
    let onVisibleMonthChanged: (Date) -> Void

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

        let decoratedDays = eventDates
            .union(reminderDates)
            .union(notifiedDates)
            .union(Set(weatherByDate.keys))
        let daysToReload = decoratedDays.union(context.coordinator.decoratedDays)
        context.coordinator.decoratedDays = decoratedDays
        if !daysToReload.isEmpty {
            calendarView.reloadDecorations(
                forDateComponents: Array(daysToReload).map(dateComponents(for:)),
                animated: true
            )
        }

        uiView.applyCalendarChrome()
    }

    private func dateComponents(for date: Date) -> DateComponents {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.calendar = calendar
        return components
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: CalendarMonthView
        var decoratedDays: Set<Date> = []

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
            let weather = parent.weatherByDate[day]
            let colors = decorationColors(
                hasRecord: hasRecord,
                hasPendingReminder: hasPendingReminder,
                hasNotifiedReminder: hasNotifiedReminder
            )

            guard weather != nil || !colors.isEmpty else {
                return nil
            }

            return .customView {
                self.decorationView(weather: weather, colors: colors)
            }
        }

        func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
            guard let date = parent.calendar.date(from: calendarView.visibleDateComponents) else {
                return
            }
            parent.onVisibleMonthChanged(date)
        }

        private func decorationView(weather: CalendarDayWeather?, colors: [UIColor]) -> UIView {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = weather != nil && !colors.isEmpty ? 1 : 0

            if let weather {
                let imageView = UIImageView(image: UIImage(systemName: weather.symbolName))
                imageView.tintColor = weather.accentColor
                imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
                imageView.contentMode = .scaleAspectFit
                imageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    imageView.widthAnchor.constraint(equalToConstant: 12),
                    imageView.heightAnchor.constraint(equalToConstant: 11)
                ])
                stack.addArrangedSubview(imageView)
            }

            if let dotsImage = dotDecorationImage(colors: colors) {
                let dotsView = UIImageView(image: dotsImage)
                dotsView.contentMode = .center
                stack.addArrangedSubview(dotsView)
            }

            return stack
        }

        private func dotDecorationImage(colors: [UIColor]) -> UIImage? {
            guard !colors.isEmpty else {
                return nil
            }

            let dotDiameter: CGFloat = 4
            let spacing: CGFloat = 2
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
    static let minimumCalendarHeight: CGFloat = 500
    let calendarView = UICalendarView()
    private var minimumHeightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: Self.minimumCalendarHeight)
    }

    override func systemLayoutSizeFitting(
        _ targetSize: CGSize,
        withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
        verticalFittingPriority: UILayoutPriority
    ) -> CGSize {
        CGSize(width: targetSize.width, height: Self.minimumCalendarHeight)
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

        minimumHeightConstraint = calendarView.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minimumCalendarHeight)
        minimumHeightConstraint?.priority = .required
        guard let minimumHeightConstraint else { return }

        NSLayoutConstraint.activate([
            calendarView.leadingAnchor.constraint(equalTo: leadingAnchor),
            calendarView.trailingAnchor.constraint(equalTo: trailingAnchor),
            calendarView.topAnchor.constraint(equalTo: topAnchor),
            calendarView.bottomAnchor.constraint(equalTo: bottomAnchor),
            minimumHeightConstraint
        ])
    }
}
