import Foundation
import Combine
import OSLog
import UserNotifications
import YijiCore

@MainActor
final class LocalNotificationScheduler: ObservableObject {
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.blizzard1311.yiji",
        category: "LocalNotificationScheduler"
    )

    enum AuthorizationStatus: String {
        case unknown
        case granted
        case denied

        var displayName: String {
            switch self {
            case .unknown:
                AppLocalization.text("未请求")
            case .granted:
                AppLocalization.text("已授权")
            case .denied:
                AppLocalization.text("未授权")
            }
        }
    }

    enum SchedulerError: LocalizedError {
        case permissionDenied
        case pastDue

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                AppLocalization.text("通知权限未开启，请到系统设置中允许通知。")
            case .pastDue:
                AppLocalization.text("提醒时间已过，无法创建一次性本地通知。")
            }
        }
    }

    @Published var authorizationStatus: AuthorizationStatus = .unknown
    @Published var scheduledIdentifiers: Set<String> = []

    private let center: UNUserNotificationCenter
    private let calendar = Calendar(identifier: .gregorian)

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationStatus = .granted
        case .denied:
            authorizationStatus = .denied
        case .notDetermined:
            authorizationStatus = .unknown
        @unknown default:
            authorizationStatus = .unknown
        }
    }

    func refreshScheduledIdentifiers() async {
        let requests = await center.pendingNotificationRequests()
        scheduledIdentifiers = Set(requests.map(\.identifier))
    }

    func ensureAuthorization() async throws {
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            authorizationStatus = .granted
        case .denied:
            authorizationStatus = .denied
            throw SchedulerError.permissionDenied
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            authorizationStatus = granted ? .granted : .denied
            if !granted {
                throw SchedulerError.permissionDenied
            }
        @unknown default:
            authorizationStatus = .denied
            throw SchedulerError.permissionDenied
        }
    }

    func schedule(reminder: Reminder) async throws {
        try await ensureAuthorization()

        if reminder.repeatRule == .none && reminder.remindAt <= Date() {
            logger.error(
                "schedule rejected as pastDue reminderID=\(reminder.id.uuidString, privacy: .public) remindAt=\(reminder.remindAt.formatted(date: .numeric, time: .shortened), privacy: .public)"
            )
            throw SchedulerError.pastDue
        }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body.isEmpty
            ? AppLocalization.text("你设置的提醒时间到了。")
            : reminder.body
        content.sound = .default

        let trigger = try makeTrigger(for: reminder)
        let request = UNNotificationRequest(
            identifier: identifier(for: reminder.id),
            content: content,
            trigger: trigger
        )

        try await center.add(request)
        scheduledIdentifiers.insert(identifier(for: reminder.id))
    }

    func cancel(reminderID: UUID) {
        let requestID = identifier(for: reminderID)
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        center.removeDeliveredNotifications(withIdentifiers: [requestID])
        scheduledIdentifiers.remove(requestID)
    }

    func sync(reminders: [Reminder]) async {
        await refreshAuthorizationStatus()
        await refreshScheduledIdentifiers()
        clearManagedNotifications()

        guard authorizationStatus == .granted else {
            return
        }

        for reminder in reminders where reminder.status == .pending {
            do {
                try await schedule(reminder: reminder)
            } catch {
                continue
            }
        }

        await refreshScheduledIdentifiers()
    }

    func isScheduled(reminderID: UUID) -> Bool {
        scheduledIdentifiers.contains(identifier(for: reminderID))
    }

    private func makeTrigger(for reminder: Reminder) throws -> UNNotificationTrigger {
        let date = reminder.remindAt
        let repeats = reminder.repeatRule != .none

        var components = DateComponents()
        switch reminder.repeatRule {
        case .none:
            components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        case .daily:
            components = calendar.dateComponents([.hour, .minute], from: date)
        case .weekly:
            components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        case .monthly:
            components = calendar.dateComponents([.day, .hour, .minute], from: date)
        case .yearly:
            components = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
        }

        return UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
    }

    private func identifier(for reminderID: UUID) -> String {
        "yiji.reminder.\(reminderID.uuidString)"
    }

    private var legacyDiagnosticsIdentifier: String {
        "yiji.test-notification"
    }

    private func clearManagedNotifications() {
        let managedIdentifiers = scheduledIdentifiers.filter {
            $0.hasPrefix("yiji.reminder.") || $0 == legacyDiagnosticsIdentifier
        }

        guard !managedIdentifiers.isEmpty else { return }

        let identifiers = Array(managedIdentifiers)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        scheduledIdentifiers.subtract(managedIdentifiers)
    }
}
