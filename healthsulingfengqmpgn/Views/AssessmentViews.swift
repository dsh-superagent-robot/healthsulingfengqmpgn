import SwiftUI
import CoreData

struct CSIDetailView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>

    @AppStorage("csiStartDate") private var startDateInterval: Double = 0
    @State private var showAbout = false
    @State private var showStartOver = false
    @State private var showReminders = false
    @State private var showMeasurePaywall = false

    private var startDate: Date {
        startDateInterval > 0 ? Date(timeIntervalSince1970: startDateInterval) : .distantPast
    }

    private var relevant: [HeartRateMeasurementMO] {
        measurements.filter { $0.createdAt >= startDate }
    }

    private var days: Int { CSIEngine.daysMeasured(relevant) }
    private var rolling: Double? { days >= 7 ? CSIEngine.rollingValue(relevant) : nil }
    private var todayDone: Bool { CSIEngine.todayCompleted(relevant) }
    private var insight: MetricInsight? {
        rolling.map { MetricInsights.insight(for: .csi, value: $0) }
    }

    private var dailyPoints: [ChartPoint] {
        let grouped = Dictionary(grouping: relevant) { Calendar.current.startOfDay(for: $0.createdAt) }
        return grouped.keys.sorted().suffix(21).compactMap { day in
            guard let values = grouped[day], !values.isEmpty else { return nil }
            let average = values.map { Double($0.csi) }.reduce(0, +) / Double(values.count)
            return ChartPoint(date: day, value: average)
        }
    }

    private var exportText: String {
        var lines = ["HeartSense Chronic Stress Index", "Date,CSI"]
        for measurement in relevant {
            lines.append("\(measurement.createdAt.ISO8601Format()),\(measurement.csi)")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    progressCard
                    if let rolling, let insight {
                        resultCard(rolling: rolling, insight: insight)
                    } else {
                        pendingCard
                    }
                    milestones
                    chartSection
                    actions
                    Text("Chronic Stress Index is a wellness metric based on a Baevsky stress index estimate. It is not a diagnosis.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Chronic Stress Index")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("About Stress Index") { showAbout = true }
                    ShareLink(item: exportText) {
                        Label("Export Results", systemImage: "square.and.arrow.up")
                    }
                    Button("Set Reminder") { showReminders = true }
                    Button("Start Over", role: .destructive) { showStartOver = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAbout) { aboutSheet }
        .sheet(isPresented: $showReminders) {
            NavigationStack { RemindersView() }
        }
        .alert("Delete current results and start from Day 1?", isPresented: $showStartOver) {
            Button("Cancel", role: .cancel) {}
            Button("Start Over", role: .destructive) {
                startDateInterval = Date().timeIntervalSince1970
                app.showToast("Chronic Stress Index restarted")
            }
        }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("7-day protocol")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.inkSecondary)
                    Text(days >= 7 ? "Rolling result active" : "Day \(min(max(days, 1), 7)) of 7")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                }
                Spacer()
                Image(systemName: "chart.bar.doc.horizontal.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(AppColors.periwinkle)
            }
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Capsule()
                        .fill(index < min(days, 7) ? AppColors.periwinkle : AppColors.surfaceMuted)
                        .frame(height: 8)
                }
            }
            Text("Measure once a day. Your first result unlocks after seven days of data, then updates as a rolling seven-day average.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
        }
        .padding(18)
        .cardStyle()
    }

    private func resultCard(rolling: Double, insight: MetricInsight) -> some View {
        VStack(spacing: 10) {
            Text("Your Stress Index")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            Text("\(Int(rolling.rounded()))")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("Baevsky SI")
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
            Text(insight.headline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(insight.color)
            Text(insight.detail)
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardStyle()
    }

    private var pendingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.open.trianglebadge.exclamationmark")
                .font(.system(size: 28))
                .foregroundColor(AppColors.inkSecondary)
            Text("Your Chronic Stress Index is calculating")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
                .multilineTextAlignment(.center)
            Text("\(max(7 - days, 0)) more measurement day\(max(7 - days, 0) == 1 ? "" : "s") until the first result.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    private var milestones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .sectionTitle()
            HStack(spacing: 10) {
                milestone("Day 1", reached: days >= 1)
                milestone("Day 7", reached: days >= 7)
                milestone("Day 17", reached: days >= 17)
            }
        }
    }

    private func milestone(_ title: String, reached: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: reached ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 20))
                .foregroundColor(reached ? AppColors.periwinkle : AppColors.inkSecondary.opacity(0.5))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(reached ? AppColors.ink : AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily stress index")
                .sectionTitle()
            MetricChartView(points: dailyPoints, kind: .csi, style: .bar, height: 160)
        }
        .padding(16)
        .cardStyle()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                if todayDone {
                    app.showToast("You're done for today. Come back tomorrow.")
                } else if app.isMeasurementAllowed(isPremium: store.isPremium) {
                    app.openMeasurement(tag: MeasurementTagSelection(tagId: nil, isAuto: true))
                } else {
                    app.presentPaywall(.measurement)
                }
            } label: {
                Text(todayDone ? "Continue Tomorrow" : "Measure Now")
            }
            .buttonStyle(PrimaryButtonStyle(tint: todayDone ? AppColors.inkSecondary : AppColors.coral))
            .disabled(todayDone)

            Button {
                showReminders = true
            } label: {
                Label("Set Reminder", systemImage: "bell.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var aboutSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("The Chronic Stress Index tracks your Baevsky Stress Index (SI), a geometric HRV measure. A seven-day rolling average smooths day-to-day noise so you can see sustained strain or recovery.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.ink)
                    Text("Ranges")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    ForEach([
                        ("Low < 50", "Calm and relaxed"),
                        ("Normal 50–149", "Healthy and well-balanced"),
                        ("Elevated 150–299", "Physical and mental exertion"),
                        ("High 300–500", "Significant strain"),
                        ("Very High > 500", "Risk of burnout")
                    ], id: \.0) { item in
                        HStack {
                            Text(item.0).font(.system(size: 13, weight: .semibold)).foregroundColor(AppColors.ink)
                            Spacer()
                            Text(item.1).font(.system(size: 13)).foregroundColor(AppColors.inkSecondary)
                        }
                    }
                    Text("This is a wellness estimate, not a medical diagnosis. Persistent high readings deserve professional support.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("About Stress Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAbout = false }
                }
            }
        }
    }
}

struct HeartAgeDetailView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>

    @AppStorage("heartAgeStartDate") private var startDateInterval: Double = 0
    @State private var showAbout = false
    @State private var showStartOver = false
    @State private var showReminders = false

    private var startDate: Date {
        startDateInterval > 0 ? Date(timeIntervalSince1970: startDateInterval) : .distantPast
    }

    private var relevant: [HeartRateMeasurementMO] {
        measurements.filter { $0.createdAt >= startDate }
    }

    private var estimate: Int? {
        HeartAgeEngine.rollingEstimate(relevant, profile: app.profile)
    }

    private var points: [ChartPoint] {
        guard let age = app.profile.age else { return [] }
        let calendar = Calendar.current
        var weekly: [Date: [Double]] = [:]
        for measurement in relevant {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: measurement.createdAt)?.start else { continue }
            let estimate = Double(HeartAgeEngine.estimate(
                rmssd: measurement.rmssd,
                age: age,
                gender: app.profile.gender
            ))
            weekly[week, default: []].append(estimate)
        }
        return weekly.keys.sorted().compactMap { week in
            guard let values = weekly[week], !values.isEmpty else { return nil }
            return ChartPoint(date: week, value: values.reduce(0, +) / Double(values.count))
        }
    }

    private var exportText: String {
        var lines = ["HeartSense Heart Age", "Date,Estimated Heart Age"]
        if let age = app.profile.age {
            for measurement in relevant {
                let value = HeartAgeEngine.estimate(rmssd: measurement.rmssd, age: age, gender: app.profile.gender)
                lines.append("\(measurement.createdAt.ISO8601Format()),\(value)")
            }
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    if app.profile.age == nil {
                        missingProfileCard
                    } else if let estimate, let age = app.profile.age {
                        resultCard(estimate: estimate, age: age)
                    } else {
                        pendingCard
                    }
                    chartSection
                    actions
                    Text("Heart Age is a simplified estimate based on RMSSD and your profile. It is for wellness and education only and is not a medical assessment.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Heart Age")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("About Heart Age") { showAbout = true }
                    ShareLink(item: exportText) {
                        Label("Export Results", systemImage: "square.and.arrow.up")
                    }
                    Button("Set Reminder") { showReminders = true }
                    Button("Start Over", role: .destructive) { showStartOver = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAbout) { aboutSheet }
        .sheet(isPresented: $showReminders) {
            NavigationStack { RemindersView() }
        }
        .alert("Delete current results and start from Day 1?", isPresented: $showStartOver) {
            Button("Cancel", role: .cancel) {}
            Button("Start Over", role: .destructive) {
                startDateInterval = Date().timeIntervalSince1970
                app.showToast("Heart Age restarted")
            }
        }
    }

    private var missingProfileCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 30))
                .foregroundColor(AppColors.gold)
            Text("Add Your Age and Gender")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("Heart Age needs your age and gender to compare your estimate with your real age.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
            NavigationLink {
                ProfileView()
            } label: {
                Text("Go to Profile")
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .cardStyle()
    }

    private func resultCard(estimate: Int, age: Int) -> some View {
        let insight = MetricInsights.insight(for: .heartAge, value: Double(estimate), age: age)
        return VStack(spacing: 10) {
            Text("Your estimated heart age")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(estimate)")
                    .font(.system(size: 68, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text("yrs")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Text("Actual age \(age) · \(insight.status)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(insight.color)
            Text(insight.detail)
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 13) {
                protocolBadge(value: "\(min(HeartAgeEngine.daysMeasured(relevant), 3))/3", label: "days")
                protocolBadge(value: "\(min(relevant.count, 3))/3", label: "rolling")
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .cardStyle()
    }

    private var pendingCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 28))
                .foregroundColor(AppColors.gold)
            Text("Three measurements unlock your estimate")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
                .multilineTextAlignment(.center)
            Text("\(max(3 - HeartAgeEngine.daysMeasured(relevant), 0)) more measurement day\(max(3 - HeartAgeEngine.daysMeasured(relevant), 0) == 1 ? "" : "s") needed.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cardStyle()
    }

    private func protocolBadge(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(AppColors.ink)
            Text(label).font(.system(size: 10)).foregroundColor(AppColors.inkSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(AppColors.surfaceMuted, in: Capsule())
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly average")
                .sectionTitle()
            MetricChartView(points: points, kind: .heartAge, style: .line, height: 160)
        }
        .padding(16)
        .cardStyle()
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                if app.isMeasurementAllowed(isPremium: store.isPremium) {
                    app.openMeasurement()
                } else {
                    app.presentPaywall(.measurement)
                }
            } label: {
                Label("Measure Heart Rate", systemImage: "heart.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
            Button {
                showReminders = true
            } label: {
                Label("Set Reminder", systemImage: "bell.fill")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var aboutSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Heart Age estimates cardiovascular age from RMSSD using a simplified linear model. It compares the estimate with the age in your profile and updates as a rolling average of your three latest measurements.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.ink)
                    Text("A lower heart age than your actual age is labelled Good; a close value is Equal; a higher value is High. Context tags, sleep and stress all influence the result.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.inkSecondary)
                    Text("This feature is for wellness and education only. It is not a medical assessment of cardiovascular health.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(20)
            }
            .background(AppColors.background)
            .navigationTitle("About Heart Age")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAbout = false }
                }
            }
        }
    }
}

struct ChartSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @State private var preferences = ChartPreferences()

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Chart type")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        Picker("Chart type", selection: $preferences.style) {
                            ForEach(ChartStyle.allCases) { style in
                                Text(style.shortLabel).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default time range")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        Picker("Default time range", selection: $preferences.defaultRange) {
                            ForEach(StatsPeriod.mePeriods) { period in
                                Text(period.label).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(16)
                    .cardStyle()

                    VStack(spacing: 0) {
                        Toggle("Show Thresholds", isOn: $preferences.showThresholds)
                            .padding(.vertical, 8)
                            .tint(AppColors.coral)
                        DividerLine()
                        Toggle("Show Trend Line", isOn: $preferences.showTrendLine)
                            .padding(.vertical, 8)
                            .tint(AppColors.coral)
                    }
                    .padding(16)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Per-metric style")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        ForEach([MetricKind.hrv, .pulse, .rmssd, .sdnn, .pnn50, .stress, .energy, .healthIndex]) { kind in
                            HStack {
                                Image(systemName: kind.icon)
                                    .foregroundColor(kind.accent)
                                    .frame(width: 22)
                                Text(kind.shortTitle)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.ink)
                                Spacer()
                                Picker("", selection: Binding(
                                    get: { preferences.style(for: kind.rawValue) },
                                    set: { preferences.perMetric[kind.rawValue] = $0 }
                                )) {
                                    ForEach(ChartStyle.allCases) { style in
                                        Text(style.label).tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(16)
                    .cardStyle()

                    VStack(spacing: 10) {
                        Button("Save") {
                            app.chartPreferences = preferences
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button("Reset to Default") {
                            preferences = ChartPreferences()
                            app.chartPreferences = preferences
                            app.showToast("Chart settings reset")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Chart Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { preferences = app.chartPreferences }
    }
}

struct TrendsView: View {
    @EnvironmentObject private var app: AppModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>

    @State private var metric: MetricKind = .hrv
    @State private var period: StatsPeriod = .month

    private var points: [ChartPoint] {
        period.filter(Array(measurements)).map { ChartPoint(date: $0.createdAt, value: metric.value(from: $0)) }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Menu {
                            ForEach([MetricKind.hrv, .pulse, .rmssd, .sdnn, .pnn50, .stress, .energy, .healthIndex]) { kind in
                                Button {
                                    metric = kind
                                } label: {
                                    Label(kind.title, systemImage: kind.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(metric.title)
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundColor(AppColors.ink)
                        }
                        Spacer()
                        NavigationLink {
                            ChartSettingsView()
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundColor(AppColors.inkSecondary)
                        }
                    }
                    PeriodSelector(periods: [.week, .month, .quarter, .year], selection: $period)
                    if points.isEmpty {
                        EmptyStateView(icon: "chart.xyaxis.line", title: "No Data", message: "Take a measurement to see trends.")
                            .cardStyle()
                    } else {
                        MetricChartView(
                            points: points,
                            kind: metric,
                            style: app.chartPreferences.style(for: metric.rawValue),
                            showThresholds: app.chartPreferences.showThresholds,
                            showTrendLine: app.chartPreferences.showTrendLine,
                            height: 250
                        )
                        .padding(16)
                        .cardStyle()
                    }
                    Text("Trends use only your in-app and Apple Watch measurements. Chart style follows your global preferences.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
    }
}
