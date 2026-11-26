import SwiftUI
import CoreData

struct AchievementsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "achievementType", ascending: true)])
    private var progressRows: FetchedResults<AchievementTierProgressMO>

    @State private var showPopup = false
    @State private var popupAchievement: AchievementProgress?
    @State private var didCheckPopup = false

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var progress: [AchievementProgress] {
        AchievementEngine.progress(snapshot: snapshot)
    }

    private var claimable: [AchievementProgress] {
        progress.filter(\.isClaimable)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    if !claimable.isEmpty {
                        claimBanner
                    }
                    ForEach(AchievementCategory.allCases) { category in
                        categorySection(category)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            if showPopup, let popupAchievement {
                popupOverlay(popupAchievement)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _ = AchievementEngine.sync(snapshot: snapshot)
            if !didCheckPopup, let first = claimable.first {
                popupAchievement = first
                showPopup = true
                didCheckPopup = true
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            summaryTile(
                value: "\(DataStats.distinctDays(Array(measurements)))",
                label: "Days with \(Brand.name)",
                color: AppColors.teal
            )
            summaryTile(
                value: "\(progress.filter { $0.reachedTier != nil }.count)",
                label: "Total Completed",
                color: AppColors.coral
            )
        }
    }

    private func summaryTile(value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var claimBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .foregroundColor(AppColors.gold)
                .frame(width: 40, height: 40)
                .background(AppColors.gold.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("New achievement!")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text("\(claimable.count) reward\(claimable.count == 1 ? "" : "s") ready to claim")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Button("Claim All") {
                AchievementEngine.claimAll(snapshot: snapshot)
                app.showToast("Rewards claimed")
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(AppColors.coral, in: Capsule())
        }
        .padding(13)
        .background(AppColors.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func categorySection(_ category: AchievementCategory) -> some View {
        let items = progress.filter { $0.definition.category == category }
        let completed = items.filter { $0.reachedTier != nil }.count
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.color)
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Spacer()
                Text("\(completed) / \(items.count) achievements")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    NavigationLink {
                        AchievementDetailView(achievementId: item.definition.id)
                    } label: {
                        achievementCard(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func achievementCard(_ item: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                ZStack {
                    item.definition.shape.shape(in: 46)
                        .foregroundColor(item.definition.category.color.opacity(item.reachedTier != nil ? 0.9 : 0.22))
                    if item.reachedTier != nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: item.definition.category.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(item.definition.category.color)
                    }
                }
                .frame(width: 52, height: 52)
                Spacer()
                if let tier = item.reachedTier, let ribbon = tier.ribbon {
                    Circle()
                        .fill(ribbon.color)
                        .frame(width: 9, height: 9)
                }
            }
            Text(item.definition.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
                .lineLimit(1)
            Text(item.statusText)
                .font(.system(size: 10))
                .foregroundColor(AppColors.inkSecondary)
                .lineLimit(1)
            ProgressView(value: item.progress)
                .tint(item.reachedTier != nil ? AppColors.success : item.definition.category.color)
            HStack {
                Text(item.reachedTier != nil ? "Achieved" : "In Progress")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(item.reachedTier != nil ? AppColors.success : AppColors.inkSecondary)
                Spacer()
                if item.isClaimable {
                    Text("Claim")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.coral)
                }
            }
        }
        .padding(13)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(item.isClaimable ? AppColors.gold.opacity(0.5) : AppColors.separator.opacity(0.6),
                        lineWidth: item.isClaimable ? 1.5 : 1)
        )
    }

    private func popupOverlay(_ item: AchievementProgress) -> some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { showPopup = false }
            VStack(spacing: 14) {
                ZStack {
                    item.definition.shape.shape(in: 78)
                        .foregroundColor(item.definition.category.color)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 88, height: 88)
                Text("New achievement!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text(item.definition.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
                Text("\(item.reachedTier?.target ?? item.currentValue) \(item.definition.unit.label) reached")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.inkSecondary)
                Button {
                    AchievementEngine.claimAll(snapshot: snapshot)
                    app.showToast("Rewards claimed")
                    showPopup = false
                } label: {
                    Text("Claim All (\(claimable.count))")
                }
                .buttonStyle(PrimaryButtonStyle())
                ShareLink(item: shareText(for: item)) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                Button("Later") { showPopup = false }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            .padding(22)
            .frame(maxWidth: 320)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, y: 10)
        }
        .transition(.opacity)
        .zIndex(5)
    }

    private func shareText(for item: AchievementProgress) -> String {
        "I just unlocked “\(item.definition.title)” in \(Brand.name)! \(item.definition.subtitle)"
    }
}

struct AchievementDetailView: View {
    let achievementId: String

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var health: HealthKitService
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "achievementType", ascending: true)])
    private var progressRows: FetchedResults<AchievementTierProgressMO>

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var item: AchievementProgress? {
        AchievementEngine.progress(snapshot: snapshot).first { $0.definition.id == achievementId }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            if let item {
                ScrollView {
                    VStack(spacing: 18) {
                        badge(item)
                        VStack(spacing: 6) {
                            Text(item.definition.title)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.ink)
                            Text(item.definition.subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.inkSecondary)
                                .multilineTextAlignment(.center)
                        }
                        progressCard(item)
                        tiersCard(item)
                        actions(item)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationTitle("Achievement")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { _ = AchievementEngine.sync(snapshot: snapshot) }
    }

    private func badge(_ item: AchievementProgress) -> some View {
        ZStack {
            Circle()
                .fill(item.definition.category.color.opacity(0.1))
                .frame(width: 210, height: 210)
            item.definition.shape.shape(in: 140)
                .foregroundColor(item.reachedTier != nil ? item.definition.category.color : AppColors.surfaceMuted)
            Image(systemName: item.reachedTier != nil ? "checkmark" : item.definition.category.icon)
                .font(.system(size: 44, weight: .bold))
                .foregroundColor(item.reachedTier != nil ? .white : item.definition.category.color)
        }
        .frame(height: 220)
    }

    private func progressCard(_ item: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.isComplete ? "Achieved" : (item.reachedTier != nil ? "Tier reached" : "In Progress"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(item.reachedTier != nil ? AppColors.success : AppColors.inkSecondary)
                Spacer()
                Text("\(item.currentValue) \(item.definition.unit.label)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
            }
            ProgressView(value: item.progress)
                .tint(item.definition.category.color)
            Text(item.tierDisplay)
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkSecondary)
            if let next = item.nextTier {
                Text("Next tier at \(next.target) \(item.definition.unit.label)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func tiersCard(_ item: AchievementProgress) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tiers")
                .sectionTitle()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 8)], spacing: 8) {
                ForEach(Array(item.definition.tiers.enumerated()), id: \.offset) { _, tier in
                    VStack(spacing: 3) {
                        Text("\(tier.target)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(item.currentValue >= tier.target ? .white : AppColors.ink)
                        if let ribbon = tier.ribbon {
                            Circle()
                                .fill(ribbon.color)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.currentValue >= tier.target ? item.definition.category.color : AppColors.surfaceMuted)
                    )
                }
            }
            Text("Reward: \(item.definition.rewardTitle)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.gold)
                .padding(.top, 2)
        }
        .padding(16)
        .cardStyle()
    }

    private func actions(_ item: AchievementProgress) -> some View {
        VStack(spacing: 10) {
            if item.isClaimable {
                Button {
                    AchievementEngine.claim(item)
                    app.showToast("Reward claimed")
                } label: {
                    Text("Claim Reward")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            ShareLink(item: "I just unlocked “\(item.definition.title)” in \(Brand.name)! \(item.definition.subtitle)") {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
