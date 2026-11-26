import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var customTags: FetchedResults<CustomTagMO>

    @State private var activeLog: ManualLogType?

    private var latest: HeartRateMeasurementMO? { measurements.first }

    private var hello: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var journeyStates: [JourneyLevelState] {
        JourneyEngine.levelStates(snapshot: snapshot)
    }

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var currentLevel: JourneyLevelState? {
        JourneyEngine.currentLevel(states: journeyStates)
    }

    private var csiDays: Int { CSIEngine.daysMeasured(Array(measurements)) }
    private var csiValue: Double? { csiDays >= 7 ? CSIEngine.rollingValue(Array(measurements)) : nil }
    private var heartAge: Int? { HeartAgeEngine.rollingEstimate(Array(measurements), profile: app.profile) }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    heroCard
                    PremiumBanner(context: .settings)
                    quickLogs
                    journeyCard
                    HStack(spacing: 12) {
                        csiCard
                        heartAgeCard
                    }
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 26)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeLog) { type in
            ManualLogView(type: type)
                .presentationDetents([.large])
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-DSHDemoData"),
               measurements.isEmpty {
                DemoData.seedIfNeeded()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(hello), \(app.profile.displayName)")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text(AppDate.weekdayMonthDay(Date()))
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Button {
                app.selectedTab = 3
            } label: {
                AvatarView(profile: app.profile, size: 46)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Hero

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.cardGradient)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(AppColors.coral.opacity(0.22))
                        .frame(width: 170, height: 170)
                        .blur(radius: 24)
                        .offset(x: 50, y: -55)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 120, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.05))
                        .offset(x: 26, y: 26)
                }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("TODAY'S HEART CHECK")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    if let latest {
                        PillLabel(text: AppDate.time(latest.createdAt), tint: .white.opacity(0.8))
                            .background(Color.white.opacity(0.1), in: Capsule())
                    }
                }

                if let latest {
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(latest.pulse)")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("bpm")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(String(format: "%.0f", latest.hrv))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.teal)
                            Text("HRV ms")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    Text(MetricInsights.insight(for: .hrv, value: latest.hrv).interpretation)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.68))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your first reading\nis waiting.")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Rest your finger on the camera for a calm, private heart check.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.62))
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        startMeasurement()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "heart.fill")
                            Text(latest == nil ? "Measure Now" : "Measure Again")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.coralDeep)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    if let latest {
                        NavigationLink {
                            MeasurementDetailView(measurement: latest)
                        } label: {
                            Text("Details")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 11)
                                .background(Color.white.opacity(0.12), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
    }

    private func startMeasurement() {
        if app.isMeasurementAllowed(isPremium: store.isPremium) {
            app.openMeasurement()
        } else {
            app.presentPaywall(.measurement)
        }
    }

    // MARK: Quick logs

    private var quickLogs: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeading(title: "Log Health Data")
            HStack(spacing: 10) {
                ForEach(ManualLogType.allCases) { type in
                    Button {
                        activeLog = type
                    } label: {
                        VStack(spacing: 9) {
                            Image(systemName: type.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(type.color)
                                .frame(width: 38, height: 38)
                                .background(type.color.opacity(0.12), in: Circle())
                            Text(type.shortTitle)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.ink)
                            Text(type == .glucose ? "mg/dl" : type == .oxygen ? "SpO2%" : "mmHg")
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.inkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(AppColors.separator.opacity(0.7), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Journey

    private var journeyCard: some View {
        NavigationLink {
            JourneyView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppColors.teal.opacity(0.14))
                        .frame(width: 62, height: 62)
                    Image(systemName: "map.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(AppColors.teal)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Journey")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    if let currentLevel {
                        Text("\(currentLevel.definition.chapterId) · \(currentLevel.definition.id) · \(currentLevel.completedCoreCount)/\(currentLevel.coreTasks.count) core tasks")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkSecondary)
                        ProgressView(value: currentLevel.progress)
                            .tint(AppColors.teal)
                            .padding(.top, 3)
                    } else {
                        Text("Guided programs for sleep, stress and recovery")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary.opacity(0.6))
            }
            .padding(16)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.separator.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Assessment cards

    private var csiCard: some View {
        NavigationLink {
            CSIDetailView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .foregroundColor(AppColors.periwinkle)
                    Spacer()
                    Text("\(min(csiDays, 7))/7")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                }
                Text("Chronic Stress")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.inkSecondary)
                if let csiValue {
                    Text("\(Int(csiValue.rounded()))")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text(MetricInsights.insight(for: .csi, value: csiValue).interpretation)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.inkSecondary)
                        .lineLimit(2)
                } else {
                    Text("\(max(7 - csiDays, 0)) days to go")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("Measure daily to unlock your first result.")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.inkSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var heartAgeCard: some View {
        NavigationLink {
            HeartAgeDetailView()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "hourglass")
                        .foregroundColor(AppColors.gold)
                    Spacer()
                    Text("\(min(HeartAgeEngine.daysMeasured(Array(measurements)), 3))/3")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                }
                Text("Heart Age")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.inkSecondary)
                if app.profile.age == nil {
                    Text("Add age")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("Complete your profile to unlock this estimate.")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.inkSecondary)
                        .lineLimit(2)
                } else if let heartAge {
                    Text("\(heartAge) yrs")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text(MetricInsights.insight(for: .heartAge, value: Double(heartAge), age: app.profile.age).interpretation)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.inkSecondary)
                        .lineLimit(2)
                } else {
                    Text("\(max(3 - HeartAgeEngine.daysMeasured(Array(measurements)), 0)) more days")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("Three measures create your rolling estimate.")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.inkSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    // MARK: Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent Measurements")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Spacer()
                NavigationLink {
                    HistoryView()
                } label: {
                    Text("See All")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.coral)
                }
            }

            if measurements.isEmpty {
                EmptyStateView(
                    icon: "waveform.path.ecg",
                    title: "No Records Yet",
                    message: "Start by adding your first measurement.",
                    actionTitle: "Measure Now"
                ) {
                    startMeasurement()
                }
                .cardStyle()
            } else {
                VStack(spacing: 0) {
                    let recent = Array(measurements.prefix(4))
                    ForEach(Array(recent.enumerated()), id: \.element.objectID) { index, measurement in
                        NavigationLink {
                            MeasurementDetailView(measurement: measurement)
                        } label: {
                            MeasurementRow(measurement: measurement)
                        }
                        .buttonStyle(.plain)
                        if index < recent.count - 1 {
                            DividerLine()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .cardStyle(padding: 0)
            }
        }
    }
}

struct MeasurementRow: View {
    let measurement: HeartRateMeasurementMO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.coral.opacity(0.1))
                    .frame(width: 42, height: 42)
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.coral)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("\(measurement.pulse) bpm")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("·")
                        .foregroundColor(AppColors.inkSecondary)
                    Text(String(format: "HRV %.0f ms", measurement.hrv))
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                HStack(spacing: 6) {
                    Text(AppDate.shortDateTime(measurement.createdAt))
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                    if let tagId = measurement.tagId, let tag = TagCatalog.info(for: tagId) {
                        Text(tag.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(tag.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tag.color.opacity(0.1), in: Capsule())
                    }
                    if measurement.sourceKind == .appleWatch {
                        Image(systemName: "applewatch")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.inkSecondary)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary.opacity(0.5))
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }
}

struct AvatarView: View {
    let profile: UserProfile
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let data = profile.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(AppColors.coral)
                    .frame(width: size, height: size)
                    .background(AppColors.coral.opacity(0.12))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.surface, lineWidth: 2))
    }
}
