import SwiftUI
import CoreData

struct RemindersView: View {
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var app: AppModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "time", ascending: true)])
    private var reminders: FetchedResults<ReminderMO>

    @State private var showNewReminder = false
    @State private var pendingDelete: ReminderMO?
    @State private var showDeniedAlert = false
    @State private var isRequesting = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if notifications.isDenied {
                        permissionBanner
                    }
                    if reminders.isEmpty {
                        EmptyStateView(
                            icon: "bell.slash",
                            title: "No Reminders Yet",
                            message: "Set a gentle daily reminder to measure, log or continue a Journey.",
                            actionTitle: "Set Reminder",
                            action: { requestNew() }
                        )
                        .cardStyle()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(reminders.enumerated()), id: \.element.objectID) { index, reminder in
                                reminderRow(reminder)
                                if index < reminders.count - 1 { DividerLine() }
                            }
                        }
                        .padding(.horizontal, 14)
                        .cardStyle(padding: 0)
                    }
                    Text("Reminders repeat daily at the time you choose. You can turn them off at any time from Settings or this page.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Daily Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    requestNew()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewReminder) {
            NewReminderView { type, time in
                Task { await create(type: type, time: time) }
            }
            .presentationDetents([.medium, .large])
        }
        .alert("Delete this reminder?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let pendingDelete { notifications.delete(pendingDelete) }
                pendingDelete = nil
            }
        }
        .alert("Notifications Disabled", isPresented: $showDeniedAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Go to Settings") { notifications.openSettings() }
        } message: {
            Text("Enable notifications in Settings to receive your daily reminders.")
        }
        .onAppear {
            notifications.refreshReminders()
            Task { await notifications.refreshAuthorization() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("A nudge at the right time")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("Daily reminders help you keep the habit without pressure. Choose a type and a time that fits your routine.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .foregroundColor(AppColors.danger)
                .frame(width: 38, height: 38)
                .background(AppColors.danger.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications Disabled")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.ink)
                Text("Enable them in system settings to receive reminders.")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Button("Settings") { notifications.openSettings() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.coral)
        }
        .padding(13)
        .background(AppColors.danger.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func reminderRow(_ reminder: ReminderMO) -> some View {
        let type = ReminderType(rawValue: reminder.type) ?? .pulse
        return HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(type.accent)
                .frame(width: 40, height: 40)
                .background(type.accent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.ink)
                Text("Daily · \(type.subtitle)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Text(AppDate.time(reminder.time))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Delete", role: .destructive) { pendingDelete = reminder }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { pendingDelete = reminder } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func requestNew() {
        Task {
            await notifications.refreshAuthorization()
            if notifications.isDenied {
                showDeniedAlert = true
            } else {
                showNewReminder = true
            }
        }
    }

    private func create(type: ReminderType, time: Date) async {
        if notifications.authorizationStatus == .notDetermined {
            let granted = await notifications.requestAuthorization()
            guard granted else {
                showDeniedAlert = true
                return
            }
        }
        await notifications.addReminder(type: type, time: time)
        notifications.refreshReminders()
        app.showToast("Reminder set for \(AppDate.time(time))")
    }
}

struct NewReminderView: View {
    let onSave: (ReminderType, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var type: ReminderType = .pulse
    @State private var time = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Reminder type")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(ReminderType.allCases) { reminder in
                            Button {
                                type = reminder
                            } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: reminder.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(type == reminder ? .white : reminder.accent)
                                    Text(reminder.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(type == reminder ? .white : AppColors.ink)
                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .fill(type == reminder ? reminder.accent : AppColors.surfaceMuted)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(16)
                    .cardStyle()

                    Text("You'll receive “\(type.notificationTitle)” with “\(type.subtitle)”.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        onSave(type, time)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
