import SwiftUI
import CoreData

struct MeView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>

    @State private var period: StatsPeriod = .week
    @State private var filterTagID: String?
    @State private var showFilter = false

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var filtered: [HeartRateMeasurementMO] {
        let base = period.filter(Array(measurements))
        guard let filterTagID else { return base }
        return base.filter { $0.tagId == filterTagID }
    }

    private var achievementProgress: [AchievementProgress] {
        AchievementEngine.progress(snapshot: snapshot)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileCard
                    premium
                    statisticsSection
                    filterRow
                    achievementsSection
                    journalSection
                    settingsLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilter) {
            TagFilterSheet(selectedTagID: $filterTagID)
                .presentationDetents([.large])
        }
    }

    private var premium: some View {
        PremiumBanner(context: .settings)
    }

    private var profileCard: some View {
        NavigationLink {
            ProfileView()
        } label: {
            HStack(spacing: 14) {
                AvatarView(profile: app.profile, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.profile.displayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text(profileSubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                    HStack(spacing: 6) {
                        PillLabel(text: "\(DataStats.distinctDays(Array(measurements))) days with \(Brand.name)", tint: AppColors.teal)
                    }
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            .padding(16)
            .cardStyle()
        }
        .buttonStyle(.plain)
    }

    private var profileSubtitle: String {
        var parts: [String] = []
        if let age = app.profile.age { parts.append("\(age) yrs") }
        if app.profile.gender != .notSet { parts.append(app.profile.gender.label) }
        if let bmi = app.profile.bmi { parts.append(String(format: "BMI %.1f", bmi)) }
        return parts.isEmpty ? "Tap to add your profile details" : parts.joined(separator: " · ")
    }

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Statistics")
                    .sectionTitle()
                Spacer()
                Text(period.label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            PeriodSelector(periods: StatsPeriod.mePeriods, selection: $period)
            HStack(spacing: 10) {
                statCard("Pulse", value: average(.pulse), unit: "bpm", color: AppColors.coral, icon: "heart.fill")
                statCard("HRV", value: average(.hrv), unit: "ms", color: AppColors.teal, icon: "waveform.path.ecg")
            }
            HStack(spacing: 10) {
                statCard("Stress", value: average(.stress), unit: "%", color: AppColors.periwinkle, icon: "bolt.fill")
                statCard("Energy", value: average(.energy), unit: "%", color: AppColors.gold, icon: "battery.75")
            }
        }
    }

    private func average(_ kind: MetricKind) -> Double? {
        let values = filtered.map { kind.value(from: $0) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func statCard(_ title: String, value: Double?, unit: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Text(period.shortLabel)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value.map { String(format: "%.0f", $0) } ?? "—")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundColor(AppColors.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: 13)
    }

    private var filterRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(AppColors.coral)
            Text("Filter")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.ink)
            Spacer()
            Button {
                showFilter = true
            } label: {
                Text(filterTagID.flatMap { TagCatalog.info(for: $0)?.name } ?? "All Data")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            .buttonStyle(.plain)
            if filterTagID != nil {
                Button {
                    filterTagID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.inkSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .cardStyle(padding: 0)
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink {
                AchievementsView()
            } label: {
                HStack {
                    Text("Achievements")
                        .sectionTitle()
                    Spacer()
                    Text("\(achievementProgress.filter { $0.reachedTier != nil }.count) completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.inkSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.inkSecondary.opacity(0.6))
                }
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                ForEach(achievementProgress.prefix(3)) { item in
                    NavigationLink {
                        AchievementDetailView(achievementId: item.definition.id)
                    } label: {
                        VStack(spacing: 7) {
                            ZStack {
                                item.definition.shape.shape(in: 46)
                                    .foregroundColor(item.definition.category.color.opacity(0.2))
                                Image(systemName: item.reachedTier != nil ? "checkmark" : "lock")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(item.reachedTier != nil ? AppColors.success : AppColors.inkSecondary.opacity(0.6))
                            }
                            .frame(width: 52, height: 52)
                            Text(item.definition.title)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.ink)
                                .lineLimit(1)
                            Text("\(Int(item.progress * 100))%")
                                .font(.system(size: 9))
                                .foregroundColor(AppColors.inkSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Journal")
                .sectionTitle()
            VStack(spacing: 0) {
                NavigationLink {
                    WatchDataView()
                } label: {
                    InfoRow(icon: "applewatch", title: "Apple Watch Data", value: health.lastSyncDate == nil ? "Sync" : "Synced", tint: AppColors.coral, showChevron: true)
                }
                .buttonStyle(.plain)
                DividerLine()
                NavigationLink {
                    AppleHealthSettingsView()
                } label: {
                    InfoRow(icon: "heart.text.square.fill", title: "Apple Health Sync", value: health.isAuthorized ? "On" : "Off", tint: AppColors.teal, showChevron: true)
                }
                .buttonStyle(.plain)
                DividerLine()
                NavigationLink {
                    TagsManagementView()
                } label: {
                    InfoRow(icon: "tag.fill", title: "Custom Tags", value: "\(customTags.count)", tint: AppColors.orange, showChevron: true)
                }
                .buttonStyle(.plain)
                DividerLine()
                NavigationLink {
                    MonthlyOverviewView()
                } label: {
                    InfoRow(icon: "calendar", title: "Monthly Overview", value: nil, tint: AppColors.periwinkle, showChevron: true)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .cardStyle(padding: 0)
        }
    }

    private var settingsLinks: some View {
        VStack(spacing: 0) {
            NavigationLink {
                SettingsView()
            } label: {
                InfoRow(icon: "gearshape.fill", title: "Settings", value: nil, tint: AppColors.inkSecondary, showChevron: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .cardStyle(padding: 0)
    }
}
