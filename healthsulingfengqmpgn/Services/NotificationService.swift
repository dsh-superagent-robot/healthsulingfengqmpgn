import Foundation
import UserNotifications
import UIKit

enum ReminderType: String, CaseIterable, Identifiable {
    case pulse
    case pulseCSI
    case glucose
    case oxygen
    case pressure
    case heartAge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .pulseCSI: return "Pulse + CSI"
        case .glucose: return "Glucose"
        case .oxygen: return "Oxygen"
        case .pressure: return "Pressure"
        case .heartAge: return "Heart Age"
        }
    }

    var notificationTitle: String {
        switch self {
        case .pulse: return "Time to check your pulse"
        case .pulseCSI: return "Continue your Chronic Stress Index"
        case .glucose: return "Log your blood sugar"
        case .oxygen: return "Log your blood oxygen"
        case .pressure: return "Log your blood pressure"
        case .heartAge: return "Keep your Heart Age updated"
        }
    }

    var icon: String {
        switch self {
        case .pulse: return "heart.fill"
        case .pulseCSI: return "chart.bar.doc.horizontal"
        case .glucose: return "drop.fill"
        case .oxygen: return "lungs.fill"
        case .pressure: return "gauge.medium"
        case .heartAge: return "hourglass"
        }
    }

    var accent: Color {
        switch self {
        case .pulse: return AppColors.coral
        case .pulseCSI: return AppColors.periwinkle
        case .glucose: return AppColors.orange
        case .oxygen: return AppColors.info
        case .pressure: return AppColors.rose
        case .heartAge: return AppColors.gold
        }
    }

    var subtitle: String { "Time to add a new measurement!" }
}

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var reminders: [ReminderMO] = []

    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {
        registerCategories()
        Task {
            await refreshAuthorization()
            refreshReminders()
        }
    }

    func refreshAuthorization() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    var isDenied: Bool {
        authorizationStatus == .denied
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorization()
            return granted
        } catch {
            await refreshAuthorization()
            return false
        }
    }

    func refreshReminders() {
        reminders = PersistenceController.shared.fetch(ReminderMO.self, sortBy: "time", ascending: true)
    }

    func addReminder(type: ReminderType, time: Date) async {
        let reminder = ReminderMO(context: PersistenceController.shared.context)
        reminder.id = UUID()
        reminder.type = type.rawValue
        reminder.time = time
        PersistenceController.shared.save()
        refreshReminders()
        await schedule(reminder)
    }

    func delete(_ reminder: ReminderMO) {
        center.removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        PersistenceController.shared.context.delete(reminder)
        PersistenceController.shared.save()
        refreshReminders()
    }

    func scheduleAll() async {
        for reminder in reminders {
            await schedule(reminder)
        }
    }

    private func schedule(_ reminder: ReminderMO) async {
        guard let type = ReminderType(rawValue: reminder.type) else { return }
        let granted = await ensureAuthorization()
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = type.notificationTitle
        content.subtitle = type.subtitle
        content.sound = .default
        content.categoryIdentifier = "REMINDER_\(type.rawValue.uppercased())"
        let components = Calendar.current.dateComponents([.hour, .minute], from: reminder.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    private func ensureAuthorization() async -> Bool {
        if isAuthorized { return true }
        if authorizationStatus == .notDetermined {
            return await requestAuthorization()
        }
        return false
    }

    private func registerCategories() {
        let categories = ReminderType.allCases.map { type in
            UNNotificationCategory(
                identifier: "REMINDER_\(type.rawValue.uppercased())",
                actions: [
                    UNNotificationAction(identifier: "MEASURE", title: "Measure Now", options: [.foreground]),
                    UNNotificationAction(identifier: "LATER", title: "Remind Me Later", options: [])
                ],
                intentIdentifiers: [],
                options: []
            )
        }
        center.setNotificationCategories(Set(categories))
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

import SwiftUI
