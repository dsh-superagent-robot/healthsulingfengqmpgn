import SwiftUI
import CoreData

struct DashboardView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>

    @State private var period: StatsPeriod = .week
    @State private var didLoadPreference = false

    private var filtered: [HeartRateMeasurementMO] {
        period.filter(Array(measurements))
    }

    private var latest: HeartRateMeasurementMO? { measurements.last }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var csiValue: Double? {
        let all = Array(measurements)
        return period == .lastMeasurement ? latest.map { Double($0.csi) } : average(all.filter {
            guard let interval = period.interval() else { return false }
            return interval.contains($0.createdAt)
        }.map { Double($0.csi) })
    }

    private var heartAgeValue: Double? {
        guard let age = app.profile.age else { return nil }
        if period == .lastMeasurement {
            guard let latest else { return nil }
            return Double(HeartAgeEngine.estimate(rmssd: latest.rmssd, age: age, gender: app.profile.gender))
        }
        let sample = filtered
        guard !sample.isEmpty else { return nil }
        let rmssd = sample.map(\.rmssd).reduce(0, +) / Double(sample.count)
        return Double(HeartAgeEngine.estimate(rmssd: rmssd, age: age, gender: app.profile.gender))
    }

    private func value(for kind: MetricKind) -> Double? {
        switch kind {
        case .csi: return csiValue
        case .heartAge: return heartAgeValue
        default:
            if period == .lastMeasurement {
                guard let latest else { return nil }
                return kind.value(from: latest)
            }
            let values = filtered.map { kind.value(from: $0) }
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    premium
                    PeriodSelector(periods: StatsPeriod.allCases, selection: $period)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(MetricKind.dashboardMetrics) { kind in
                            NavigationLink {
                                MetricDetailView(kind: kind, initialPeriod: period)
                            } label: {
                                if let value = value(for: kind) {
                                    MetricCardView(kind: kind, value: value, age: app.profile.age)
                                } else {
                                    noDataCard(kind)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    monthlyOverview
                    watchData
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !didLoadPreference {
                period = app.chartPreferences.defaultRange
                didLoadPreference = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Your averages")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("Switch periods to see how your heart is adapting.")
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
        }
    }

    private var premium: some View {
        PremiumBanner(context: .settings)
    }

    private func noDataCard(_ kind: MetricKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SoftIcon(systemName: kind.icon, tint: kind.accent, size: 34)
            Text(kind.shortTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            Text("No Data")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(kind == .heartAge ? "Add your age in Profile" : "Take a measurement to unlock")
                .font(.system(size: 10))
                .foregroundColor(AppColors.inkSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var monthlyOverview: some View {
        NavigationLink {
            MonthlyOverviewView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(AppColors.periwinkle)
                    .frame(width: 50, height: 50)
                    .background(AppColors.periwinkle.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Monthly Overview")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text(store.isPremium ? "All 14 metrics and trends" : "Unlock Premium to see full trends")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                Spacer()
                Image(systemName: store.isPremium ? "chevron.right" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var watchData: some View {
        NavigationLink {
            WatchDataView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "applewatch")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(AppColors.coral)
                    .frame(width: 50, height: 50)
                    .background(AppColors.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Apple Watch Data")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text(health.lastSyncDate.map { "Last synced \(AppDate.shortDateTime($0))" } ?? "Sync HRV, sleep and mindfulness from Apple Health")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary.opacity(0.6))
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

struct MetricDetailView: View {
    let kind: MetricKind
    @State private var period: StatsPeriod

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>

    init(kind: MetricKind, initialPeriod: StatsPeriod) {
        self.kind = kind
        _period = State(initialValue: initialPeriod == .lastMeasurement ? .week : initialPeriod)
    }

    private var filtered: [HeartRateMeasurementMO] {
        period.filter(Array(measurements))
    }

    private var value: Double? {
        if kind == .heartAge {
            guard let age = app.profile.age, let latest = filtered.last else { return nil }
            return Double(HeartAgeEngine.estimate(rmssd: latest.rmssd, age: age, gender: app.profile.gender))
        }
        if kind == .csi {
            guard let latest = filtered.last else { return nil }
            return Double(latest.csi)
        }
        guard let latest = filtered.last else { return nil }
        return kind.value(from: latest)
    }

    private var average: Double? {
        let values = filtered.map { item -> Double in
            if kind == .heartAge, let age = app.profile.age {
                return Double(HeartAgeEngine.estimate(rmssd: item.rmssd, age: age, gender: app.profile.gender))
            }
            return kind.value(from: item)
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var points: [ChartPoint] {
        filtered.map { item in
            if kind == .heartAge, let age = app.profile.age {
                return ChartPoint(date: item.createdAt, value: Double(HeartAgeEngine.estimate(rmssd: item.rmssd, age: age, gender: app.profile.gender)))
            }
            return ChartPoint(date: item.createdAt, value: kind.value(from: item))
        }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PeriodSelector(periods: StatsPeriod.mePeriods, selection: $period)

                    if let value {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text(kind.formatted(value))
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.ink)
                                Text(kind.unit)
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.inkSecondary)
                                Spacer()
                                Image(systemName: kind.icon)
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(kind.accent)
                            }
                            let insight = MetricInsights.insight(for: kind, value: value, age: app.profile.age)
                            Text(insight.headline)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(insight.color)
                            Text(insight.detail)
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .cardStyle()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(period.label) trend")
                                .sectionTitle()
                            MetricChartView(
                                points: points,
                                kind: kind,
                                style: app.chartPreferences.style(for: kind.rawValue),
                                showThresholds: app.chartPreferences.showThresholds,
                                showTrendLine: app.chartPreferences.showTrendLine
                            )
                        }
                        .padding(16)
                        .cardStyle()

                        if let average {
                            HStack(spacing: 10) {
                                Image(systemName: "scale.3d")
                                    .foregroundColor(AppColors.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Compare with your average")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.ink)
                                    Text("Latest \(kind.formatted(value)) \(kind.unit) · Average \(kind.formatted(average)) \(kind.unit)")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppColors.inkSecondary)
                                }
                                Spacer()
                            }
                            .padding(14)
                            .background(AppColors.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        HStack(spacing: 10) {
                            Button {
                                app.openMeasurement()
                            } label: {
                                Label("Measure Now", systemImage: "heart.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            NavigationLink {
                                ChartSettingsView()
                            } label: {
                                Label("Chart Settings", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    } else {
                        EmptyStateView(
                            icon: kind.icon,
                            title: "No Data",
                            message: kind == .heartAge ? "Add your age in Profile and take three measurements." : "Take a measurement to see this metric.",
                            actionTitle: "Measure Now",
                            action: { app.openMeasurement() }
                        )
                        .cardStyle()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
