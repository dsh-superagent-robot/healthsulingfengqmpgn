import SwiftUI

enum Ribbon: String {
    case blue, red, purple

    var color: Color {
        switch self {
        case .blue: return Color(hex: 0x6B9ACF)
        case .red: return Color(hex: 0xD9534F)
        case .purple: return Color(hex: 0xA982D9)
        }
    }
}

enum AchievementUnit: String {
    case measurements, days, daysStreak, weeks, pairsClosed, articles, aiComments, allTagsSets, streak30days, streak90days, appleHealth

    var label: String {
        switch self {
        case .measurements: return "measurements"
        case .days: return "days"
        case .daysStreak: return "days streak"
        case .weeks: return "weeks"
        case .pairsClosed: return "pairs closed"
        case .articles: return "articles"
        case .aiComments: return "AI comments"
        case .allTagsSets: return "tagged sets"
        case .streak30days: return "30-day streaks"
        case .streak90days: return "90-day streaks"
        case .appleHealth: return "connection"
        }
    }
}

struct AchievementTier: Hashable {
    let target: Int
    let ribbon: Ribbon?
}

enum AchievementCategory: String, CaseIterable, Identifiable {
    case dailyRhythm = "Daily Rhythm"
    case sleep = "Sleep & Night Routine"
    case mentalLoad = "Mental Load & Stress"
    case activity = "Activity & Fitness"
    case insights = "Self-Tracking & Insights"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dailyRhythm: return "sun.max.fill"
        case .sleep: return "moon.stars.fill"
        case .mentalLoad: return "bolt.heart.fill"
        case .activity: return "figure.run"
        case .insights: return "lightbulb.fill"
        }
    }
    var color: Color {
        switch self {
        case .dailyRhythm: return AppColors.gold
        case .sleep: return AppColors.periwinkle
        case .mentalLoad: return AppColors.coral
        case .activity: return AppColors.mint
        case .insights: return AppColors.teal
        }
    }
}

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let category: AchievementCategory
    let shape: BadgeShape
    let unit: AchievementUnit
    let tiers: [AchievementTier]
    let rewardTitle: String

    var maxTarget: Int { tiers.last?.target ?? 1 }

    func tierReached(for value: Int) -> AchievementTier? {
        tiers.last(where: { value >= $0.target })
    }

    func nextTier(after value: Int) -> AchievementTier? {
        tiers.first(where: { value < $0.target })
    }

    func progress(for value: Int) -> Double {
        let next = nextTier(after: value)?.target ?? maxTarget
        let previous = tierReached(for: value)?.target ?? 0
        guard next > previous else { return 1 }
        return min(1, max(0, Double(value - previous) / Double(next - previous)))
    }
}

enum AchievementCatalog {
    static let all: [AchievementDefinition] = build()

    static func achievement(_ id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }

    static func achievements(in category: AchievementCategory) -> [AchievementDefinition] {
        all.filter { $0.category == category }
    }

    private static func build() -> [AchievementDefinition] {
        [
            make(
                id: "achv_measure_volume", title: "Total Measurements", subtitle: "Every reading builds your personal baseline.",
                category: .dailyRhythm, shape: .hexagon, unit: .measurements,
                tiers: "10,20,30,45,60,75,100,150,200(blue),300,400,500(red),750,1000,1500(purple)",
                reward: "Pulse Collector"
            ),
            make(
                id: "achv_days_active", title: "Days Active", subtitle: "Measure on different days to build a habit.",
                category: .dailyRhythm, shape: .circle, unit: .days,
                tiers: "3,7,14,30,50,75,100,150,200(blue),250,300,350(red),400,450,500(purple)",
                reward: "Habit Builder"
            ),
            make(
                id: "achv_consistency_window", title: "Daily Consistency", subtitle: "Keep your measurement streak alive.",
                category: .dailyRhythm, shape: .square, unit: .daysStreak,
                tiers: "3,5,10,15,20,30(blue),60,90,120(red),180,270,365(purple)",
                reward: "Daily Keeper"
            ),
            make(
                id: "achv_morning_check", title: "Morning Check", subtitle: "Measure After Sleep on consecutive days.",
                category: .sleep, shape: .rhombus, unit: .daysStreak,
                tiers: "2,3,7,14,21,30(blue),45,60,90(red),120,150,180(purple)",
                reward: "Day Starter"
            ),
            make(
                id: "achv_sleep_control", title: "Sleep Control", subtitle: "Measure Before Sleep on consecutive days.",
                category: .sleep, shape: .shield, unit: .daysStreak,
                tiers: "2,3,7,14,21,30,45,60,90(blue),120,150,180(red),210,240,270(purple)",
                reward: "Sleep Guardian"
            ),
            make(
                id: "achv_morning_bird", title: "After Sleep", subtitle: "Collect measurements after waking up.",
                category: .sleep, shape: .circle, unit: .days,
                tiers: "1,3,5,7,14,21(blue),30,45,60(red),90,120,150(purple)",
                reward: "Morning Bird"
            ),
            make(
                id: "achv_sleep_keeper", title: "Before Sleep", subtitle: "Collect measurements before going to bed.",
                category: .sleep, shape: .circle, unit: .days,
                tiers: "1,3,5,7,14,21(blue),30,45,60(red),90,120,150(purple)",
                reward: "Sleep Owl"
            ),
            make(
                id: "achv_perfect_pair", title: "Perfect Pair", subtitle: "Close sleep before-and-after pairs within 4–12 hours.",
                category: .activity, shape: .hexagon, unit: .pairsClosed,
                tiers: "1,3,5,7,14,21(blue),30,45,60(red),90,120,150(purple)",
                reward: "Pair Master"
            ),
            make(
                id: "achv_tagged_measures", title: "Tagged Measures", subtitle: "Add context tags to your measurements.",
                category: .insights, shape: .square, unit: .allTagsSets,
                tiers: "10,20,30,45,60,75,100,150,200(blue),300,400,500(red),750,1000,1500(purple)",
                reward: "Tag Tactician"
            ),
            make(
                id: "achv_meditation_lab", title: "Meditation Lab", subtitle: "Pair before and after mindfulness sessions.",
                category: .mentalLoad, shape: .capsule, unit: .pairsClosed,
                tiers: "1,3,5,7,14,21(blue),30,45,60(red),90,120,150(purple)",
                reward: "Meditation Guru"
            ),
            make(
                id: "achv_resilience_loop", title: "Resilience Loop", subtitle: "Pair before and after stressful moments.",
                category: .mentalLoad, shape: .circle, unit: .pairsClosed,
                tiers: "1,3,5,7,14,21(blue),30,45,60(red),90,120,150(purple)",
                reward: "Stress Warrior"
            ),
            make(
                id: "achv_baseline_guardian", title: "Rest Control", subtitle: "Weeks with at least three rest measurements.",
                category: .mentalLoad, shape: .shield, unit: .weeks,
                tiers: "1,2,3,5,7,9,12,15,18(blue),21,24,27(red),30,40,50(purple)",
                reward: "Baseline Guardian"
            ),
            make(
                id: "achv_workout_reaction", title: "Exercise Response", subtitle: "Pair measurements around exercise.",
                category: .activity, shape: .capsule, unit: .pairsClosed,
                tiers: "1,3,5,10,20,30,45,60,75(blue),100,150,200(red),300,400,500(purple)",
                reward: "Activity Engine"
            ),
            make(
                id: "achv_full_spectrum", title: "Full Spectrum", subtitle: "Complete sets across all five context groups.",
                category: .activity, shape: .hexagon, unit: .allTagsSets,
                tiers: "1,2,3,5,7,9,12,15,18(blue),21,24,30(red),50,75,100(purple)",
                reward: "Full Set Winner"
            ),
            make(
                id: "achv_3_hour_lab", title: "3-Hour Lab", subtitle: "Close context pairs within three hours.",
                category: .mentalLoad, shape: .capsule, unit: .pairsClosed,
                tiers: "10,20,30,45,60,75(blue),100,150,200(red),300,400,500(purple)",
                reward: "3-Hour Hero"
            ),
            make(
                id: "achv_insight_scholar", title: "Learning Hub", subtitle: "Read articles to understand your data.",
                category: .insights, shape: .square, unit: .articles,
                tiers: "3,5,7,10,15,20(blue),30,40,50(red),60,70,80(purple)",
                reward: "Dedicated Learner"
            ),
            make(
                id: "achv_ai_explorer", title: "AI Comments", subtitle: "Read the AI comment on your measurements.",
                category: .insights, shape: .square, unit: .aiComments,
                tiers: "10,20,30,45,60,75(blue),100,150,200(red),300,400,500(purple)",
                reward: "Context Explorer"
            ),
            make(
                id: "achv_30_day_consistency", title: "30-Day Consistency", subtitle: "Build a streak toward 30 days.",
                category: .dailyRhythm, shape: .circle, unit: .streak30days,
                tiers: "3,4,5,6,7,8(blue),10,12,15(red),20,25,30(purple)",
                reward: "30-Day Chaser"
            ),
            make(
                id: "achv_90_day_consistency", title: "90-Day Consistency", subtitle: "Build a long streak over months.",
                category: .dailyRhythm, shape: .circle, unit: .streak90days,
                tiers: "30,35,40,45,50,55(blue),60,65,70(red),75,80,90(purple)",
                reward: "90-Day Chaser"
            ),
            make(
                id: "achv_context_atlas", title: "Tagged Measures", subtitle: "Explore different tagged measurement sets.",
                category: .insights, shape: .square, unit: .allTagsSets,
                tiers: "1,2,3,4,5,6,7,8,9(blue),10,11,12(red),15,18,25(purple)",
                reward: "Tag Master"
            ),
            make(
                id: "achv_setup_health", title: "Setup", subtitle: "Connect Apple Health to enrich your data.",
                category: .dailyRhythm, shape: .square, unit: .appleHealth,
                tiers: "1",
                reward: "Watch Sync Master"
            )
        ]
    }

    private static func make(
        id: String, title: String, subtitle: String, category: AchievementCategory,
        shape: BadgeShape, unit: AchievementUnit, tiers: String, reward: String
    ) -> AchievementDefinition {
        AchievementDefinition(
            id: id,
            title: title,
            subtitle: subtitle,
            category: category,
            shape: shape,
            unit: unit,
            tiers: parseTiers(tiers),
            rewardTitle: reward
        )
    }

    private static func parseTiers(_ value: String) -> [AchievementTier] {
        value.split(separator: ",").compactMap { raw in
            var target = String(raw)
            var ribbon: Ribbon?
            if let open = raw.firstIndex(of: "("), let close = raw.firstIndex(of: ")") {
                let ribbonValue = raw[raw.index(after: open)..<close]
                ribbon = Ribbon(rawValue: String(ribbonValue))
                target = String(raw[..<open])
            }
            guard let number = Int(target) else { return nil }
            return AchievementTier(target: number, ribbon: ribbon)
        }
    }
}
