import SwiftUI
import CoreData

struct AppleHealthSettingsView: View {
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var app: AppModel
    @State private var isRequesting = false
    @State private var showDisconnectAlert = false

    private let steps: [(String, String)] = [
        ("1", "Open the Health app on your iPhone."),
        ("2", "Tap your profile picture in the top-right corner."),
        ("3", "Choose Devices, then select your Apple Watch."),
        ("4", "Make sure Health is enabled for heart rate variability, sleep and mindfulness."),
        ("5", "Return to \(Brand.name) and tap Sync Now.")
    ]

    private let watchSteps: [(String, String)] = [
        ("1", "Open the Breathe app on Apple Watch."),
        ("2", "Breathe with the animation for one minute."),
        ("3", "Open Health on iPhone and confirm the session was saved."),
        ("4", "Come back here and tap Sync Now.")
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    toggleCard
                    stepsCard
                    watchCard
                    if health.isAuthorized {
                        syncCard
                    }
                    privacyNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Apple Health Sync")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Disconnect Apple Health?", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) { health.disconnect() }
        } message: {
            Text("Existing measurements stay on your device. New data will not sync until you reconnect.")
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(AppColors.coral)
                .frame(width: 100, height: 100)
                .background(AppColors.coral.opacity(0.1), in: Circle())
            Text("Sync with Apple Health")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(health.authorizationSummary)
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
            if !health.isAvailable {
                Text("Health data is not available on this device.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.danger)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var toggleCard: some View {
        Toggle(isOn: Binding(
            get: { health.enabled },
            set: { value in
                if value {
                    Task {
                        isRequesting = true
                        await health.requestAuthorization()
                        isRequesting = false
                    }
                } else {
                    showDisconnectAlert = true
                }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Apple Health Sync")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text(health.isSyncing ? "Syncing…" : health.isAuthorized ? "Connected" : "Off")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
        }
        .tint(AppColors.coral)
        .padding(16)
        .cardStyle()
        .disabled(!health.isAvailable || isRequesting)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect Apple Watch")
                .sectionTitle()
            Text("Five steps to make sure your watch data is available.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
            ForEach(steps, id: \.0) { step in
                HStack(alignment: .top, spacing: 10) {
                    Text(step.0)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(AppColors.coral, in: Circle())
                    Text(step.1)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
            Button {
                health.openHealthApp()
            } label: {
                Label("Open Health App", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(SecondaryButtonStyle())
            if !health.isAuthorized {
                Button {
                    Task { await health.requestAuthorization() }
                } label: {
                    Text(isRequesting ? "Connecting…" : "Connect Apple Health")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRequesting)
            }
            Text("I don't have Apple Watch")
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkSecondary)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .cardStyle()
    }

    private var watchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Measure with Apple Watch")
                .sectionTitle()
            Text("Use the Breathe app to create a mindful session, then sync your HRV.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
            ForEach(watchSteps, id: \.0) { step in
                HStack(alignment: .top, spacing: 10) {
                    Text(step.0)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.teal)
                        .frame(width: 22, height: 22)
                        .background(AppColors.teal.opacity(0.12), in: Circle())
                    Text(step.1)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var syncCard: some View {
        VStack(spacing: 10) {
            if let last = health.lastSyncDate {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                    Text("Synced \(AppDate.shortDateTime(last))")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
            }
            Button {
                Task {
                    let result = await health.sync()
                    app.showToast(result.message)
                }
            } label: {
                if health.isSyncing {
                    ProgressView().tint(.white)
                } else {
                    Text("Sync Now")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(health.isSyncing)
        }
        .padding(16)
        .cardStyle()
    }

    private var privacyNote: some View {
        Text("Providing access to your Health Data allows the app to deliver personalized and detailed health insights. Your health data stays on this device and is never uploaded by this build.")
            .font(.system(size: 11))
            .foregroundColor(AppColors.inkSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}

struct WatchDataView: View {
    enum WatchMetric: String, CaseIterable, Identifiable {
        case pulse, stress, energy, health
        var id: String { rawValue }
        var title: String {
            switch self {
            case .pulse: return "Pulse"
            case .stress: return "Stress"
            case .energy: return "Energy"
            case .health: return "Health"
            }
        }
        var unit: String {
            switch self {
            case .pulse: return "bpm"
            case .stress, .energy: return "%"
            case .health: return "lnRMSSD"
            }
        }
        var color: Color {
            switch self {
            case .pulse: return AppColors.coral
            case .stress: return AppColors.periwinkle
            case .energy: return AppColors.gold
            case .health: return AppColors.teal
            }
        }
        var icon: String {
            switch self {
            case .pulse: return "heart.fill"
            case .stress: return "bolt.fill"
            case .energy: return "battery.75"
            case .health: return "heart.text.square.fill"
            }
        }
        func value(from measurement: HeartRateMeasurementMO) -> Double {
            switch self {
            case .pulse: return Double(measurement.pulse)
            case .stress: return Double(measurement.stress)
            case .energy: return Double(measurement.energy)
            case .health: return measurement.healthIndex
            }
        }
    }

    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var app: AppModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>

    @State private var metric: WatchMetric = .pulse

    private var watchMeasurements: [HeartRateMeasurementMO] {
        measurements.filter { $0.sourceKind == .appleWatch }
    }

    private var grouped: [(month: Date, items: [HeartRateMeasurementMO])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: watchMeasurements) {
            calendar.date(from: calendar.dateComponents([.year, .month], from: $0.createdAt)) ?? $0.createdAt
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]?.sorted { $0.createdAt > $1.createdAt } ?? []) }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    syncBar
                    metricPicker
                    if watchMeasurements.isEmpty {
                        EmptyStateView(
                            icon: "applewatch.slash",
                            title: "No Watch Data",
                            message: "Connect Apple Health and sync to bring Apple Watch HRV measurements here.",
                            actionTitle: health.isAuthorized ? "Sync Now" : "Connect Apple Health",
                            action: {
                                if health.isAuthorized {
                                    Task { await sync() }
                                } else {
                                    Task {
                                        let granted = await health.requestAuthorization()
                                        if granted { await sync() }
                                    }
                                }
                            }
                        )
                        .cardStyle()
                    } else {
                        summaryCard
                        ForEach(grouped, id: \.month) { group in
                            VStack(alignment: .leading, spacing: 9) {
                                Text(AppDate.monthYear(group.month))
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.inkSecondary)
                                VStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.objectID) { index, measurement in
                                        watchRow(measurement)
                                        if index < group.items.count - 1 { DividerLine() }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .cardStyle(padding: 0)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Apple Watch Data")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if health.enabled && health.isAuthorized {
                Task { await sync() }
            }
        }
    }

    private var syncBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "applewatch")
                .font(.system(size: 22))
                .foregroundColor(AppColors.coral)
                .frame(width: 48, height: 48)
                .background(AppColors.coral.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(health.isAuthorized ? "Apple Health connected" : "Apple Health not connected")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text(health.lastSyncDate.map { "Last synced \(AppDate.shortDateTime($0))" } ?? "No sync yet")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Button {
                Task {
                    if !health.isAuthorized {
                        _ = await health.requestAuthorization()
                    }
                    await sync()
                }
            } label: {
                Text(health.isSyncing ? "Syncing…" : health.lastSyncDate == nil ? "Sync Now" : "Synced")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.coral, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(health.isSyncing)
        }
        .padding(14)
        .cardStyle(padding: 0)
    }

    private var metricPicker: some View {
        HStack(spacing: 7) {
            ForEach(WatchMetric.allCases) { item in
                Button {
                    metric = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(metric == item ? .white : item.color)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(metric == item ? item.color : item.color.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summaryCard: some View {
        let values = watchMeasurements.map { metric.value(from: $0) }.filter { $0 > 0 }
        let average = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
        return VStack(alignment: .leading, spacing: 8) {
            Text("\(metric.title) average")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", average))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text(metric.unit)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.inkSecondary)
                Spacer()
                Text("\(watchMeasurements.count) records")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func watchRow(_ measurement: HeartRateMeasurementMO) -> some View {
        HStack(spacing: 12) {
            Image(systemName: metric.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(metric.color)
                .frame(width: 34, height: 34)
                .background(metric.color.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(AppDate.shortDateTime(measurement.createdAt))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.ink)
                Text("HRV \(String(format: "%.0f", measurement.hrv)) ms · SDNN \(String(format: "%.0f", measurement.sdnn))")
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Text(String(format: "%.0f", metric.value(from: measurement)))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(metric.unit)
                .font(.system(size: 9))
                .foregroundColor(AppColors.inkSecondary)
        }
        .padding(.vertical, 10)
    }

    private func sync() async {
        let result = await health.sync()
        app.showToast(result.message)
    }
}
