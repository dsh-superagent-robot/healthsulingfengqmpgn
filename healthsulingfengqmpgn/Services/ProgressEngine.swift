import Foundation
import CoreData

struct DataSnapshot {
    let measurements: [HeartRateMeasurementMO]
    let articlesRead: Set<String>
    let appleHealthConnected: Bool
    let customTags: [CustomTagMO]

    init(
        measurements: [HeartRateMeasurementMO],
        articlesRead: Set<String>,
        appleHealthConnected: Bool,
        customTags: [CustomTagMO] = TagCatalog.customTags
    ) {
        self.measurements = measurements.sorted { $0.createdAt < $1.createdAt }
        self.articlesRead = articlesRead
        self.appleHealthConnected = appleHealthConnected
        self.customTags = customTags
    }

    var tagInfos: [String: TagInfo] {
        var map: [String: TagInfo] = [:]
        for info in TagCatalog.builtIns { map[info.id] = info }
        for tag in customTags { map[tag.id.uuidString] = TagCatalog.info(for: tag) }
        return map
    }
}

// MARK: - Shared statistics

enum DataStats {
    static func distinctDays(_ measurements: [HeartRateMeasurementMO]) -> Int {
        Set(measurements.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
    }

    static func longestStreak(_ measurements: [HeartRateMeasurementMO]) -> Int {
        let days = Set(measurements.map { Calendar.current.startOfDay(for: $0.createdAt) }).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for index in 1..<days.count {
            let gap = Calendar.current.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if gap == 1 {
                current += 1
            } else if gap > 1 {
                current = 1
            }
            longest = max(longest, current)
        }
        return longest
    }

    static func currentStreak(_ measurements: [HeartRateMeasurementMO]) -> Int {
        let days = Set(measurements.map { Calendar.current.startOfDay(for: $0.createdAt) }).sorted()
        guard let last = days.last else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        let gapToToday = Calendar.current.dateComponents([.day], from: last, to: today).day ?? 0
        guard gapToToday <= 1 else { return 0 }
        var streak = 1
        var index = days.count - 1
        while index > 0 {
            let gap = Calendar.current.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            guard gap == 1 else { break }
            streak += 1
            index -= 1
        }
        return streak
    }

    static func streak(
        for group: TagGroup? = nil,
        timing: TagTiming? = nil,
        measurements: [HeartRateMeasurementMO],
        tags: [String: TagInfo]
    ) -> Int {
        let filtered = measurements.filter { measurement in
            guard let id = measurement.tagId, let info = tags[id] else { return false }
            if let group, info.group != group { return false }
            if let timing, info.timing != timing { return false }
            return true
        }
        return longestStreak(filtered)
    }

    static func taggedDays(
        group: TagGroup,
        timing: TagTiming,
        measurements: [HeartRateMeasurementMO],
        tags: [String: TagInfo]
    ) -> Int {
        let filtered = measurements.filter { measurement in
            guard let id = measurement.tagId, let info = tags[id] else { return false }
            return info.group == group && info.timing == timing
        }
        return distinctDays(filtered)
    }

    static func countTiming(
        group: TagGroup,
        timing: TagTiming,
        measurements: [HeartRateMeasurementMO],
        tags: [String: TagInfo]
    ) -> Int {
        measurements.filter { measurement in
            guard let id = measurement.tagId, let info = tags[id] else { return false }
            return info.group == group && info.timing == timing
        }.count
    }

    static func restWeekCount(_ measurements: [HeartRateMeasurementMO], tags: [String: TagInfo]) -> Int {
        let rest = measurements.filter { measurement in
            guard let id = measurement.tagId, let info = tags[id] else { return false }
            return info.group == .sleep || info.group == .relax
        }
        let grouped = Dictionary(grouping: rest) { measurement -> String in
            let comps = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: measurement.createdAt)
            return "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
        }
        return grouped.values.filter { $0.count >= 3 }.count
    }

    static func distinctTagSets(_ measurements: [HeartRateMeasurementMO], tags: [String: TagInfo]) -> Int {
        var sets = Set<String>()
        for measurement in measurements {
            guard let id = measurement.tagId, let info = tags[id] else { continue }
            if let group = info.group, let timing = info.timing {
                sets.insert("\(group.rawValue).\(timing.rawValue)")
            } else {
                sets.insert("custom.\(info.cluster.rawValue)")
            }
        }
        return sets.count
    }

    static func distinctTagGroups(_ measurements: [HeartRateMeasurementMO], tags: [String: TagInfo]) -> Int {
        var groups = Set<TagGroup>()
        for measurement in measurements {
            guard let id = measurement.tagId, let info = tags[id], let group = info.group else { continue }
            groups.insert(group)
        }
        return groups.count
    }

    static func fullSpectrumSets(_ measurements: [HeartRateMeasurementMO], tags: [String: TagInfo]) -> Int {
        let byDay = Dictionary(grouping: measurements) { Calendar.current.startOfDay(for: $0.createdAt) }
        return byDay.values.filter { dayMeasurements in
            var groups = Set<TagGroup>()
            for measurement in dayMeasurements {
                if let id = measurement.tagId, let info = tags[id], let group = info.group {
                    groups.insert(group)
                }
            }
            return groups.count == TagGroup.allCases.count
        }.count
    }

    /// Counts before/after pairs. Sleep pairs span 4–12 hours; other pairs
    /// must be closed within three hours.
    static func pairCount(
        group: TagGroup? = nil,
        measurements: [HeartRateMeasurementMO],
        tags: [String: TagInfo]
    ) -> Int {
        let byDay = Dictionary(grouping: measurements) { Calendar.current.startOfDay(for: $0.createdAt) }
        var total = 0
        for day in byDay.values {
            let tagged = day.compactMap { measurement -> (Date, TagInfo)? in
                guard let id = measurement.tagId, let info = tags[id] else { return nil }
                if let group, info.group != group { return nil }
                return (measurement.createdAt, info)
            }.sorted { $0.0 < $1.0 }
            var usedAfter = Set<Int>()
            for (index, item) in tagged.enumerated() where item.1.timing == .before {
                guard let afterIndex = tagged.enumerated().first(where: { entry in
                    entry.offset > index &&
                    !usedAfter.contains(entry.offset) &&
                    entry.element.1.timing == .after &&
                    (group == nil || entry.element.1.group == item.1.group)
                })?.offset else { continue }
                let gap = tagged[afterIndex].0.timeIntervalSince(item.0)
                let valid: Bool
                if item.1.group == .sleep {
                    valid = gap >= 4 * 3600 && gap <= 12 * 3600
                } else {
                    valid = gap >= 0 && gap <= 3 * 3600
                }
                if valid {
                    total += 1
                    usedAfter.insert(afterIndex)
                }
            }
        }
        return total
    }

    /// Any context pair closed within three hours, regardless of group.
    static func anyThreeHourPairs(_ measurements: [HeartRateMeasurementMO], tags: [String: TagInfo]) -> Int {
        let sorted = measurements.sorted { $0.createdAt < $1.createdAt }
        var count = 0
        var lastBefore: (Date, String)?
        for measurement in sorted {
            guard let id = measurement.tagId, let info = tags[id] else { continue }
            if info.timing == .before {
                lastBefore = (measurement.createdAt, info.group?.rawValue ?? "custom")
            } else if info.timing == .after, let before = lastBefore,
                      measurement.createdAt.timeIntervalSince(before.0) <= 3 * 3600 {
                count += 1
                lastBefore = nil
            }
        }
        return count
    }
}

// MARK: - Achievements

struct AchievementProgress: Identifiable {
    let definition: AchievementDefinition
    let currentValue: Int
    let reachedTier: AchievementTier?
    let nextTier: AchievementTier?
    let progress: Double
    let isComplete: Bool
    let claimedTarget: Int
    let hasClaimedCurrentTier: Bool

    var id: String { definition.id }

    var isClaimable: Bool {
        if let reachedTier {
            return reachedTier.target > claimedTarget
        }
        return false
    }

    var statusText: String {
        if isComplete { return "Achieved" }
        if let nextTier { return "\(currentValue) / \(nextTier.target) \(definition.unit.label)" }
        return "In Progress"
    }

    var tierDisplay: String {
        if let reachedTier, let nextTier {
            return "Tier \(definition.tiers.firstIndex(of: reachedTier).map { $0 + 1 } ?? 1) · Next \(nextTier.target)"
        } else if let nextTier {
            return "Next \(nextTier.target) \(definition.unit.label)"
        }
        return "Complete"
    }
}

enum AchievementEngine {
    static func currentValue(
        for definition: AchievementDefinition,
        snapshot: DataSnapshot,
        tags: [String: TagInfo]
    ) -> Int {
        let measures = snapshot.measurements
        switch definition.id {
        case "achv_measure_volume":
            return measures.count
        case "achv_days_active":
            return DataStats.distinctDays(measures)
        case "achv_consistency_window":
            return DataStats.longestStreak(measures)
        case "achv_morning_check":
            return DataStats.streak(for: .sleep, timing: .after, measurements: measures, tags: tags)
        case "achv_sleep_control":
            return DataStats.streak(for: .sleep, timing: .before, measurements: measures, tags: tags)
        case "achv_morning_bird":
            return DataStats.taggedDays(group: .sleep, timing: .after, measurements: measures, tags: tags)
        case "achv_sleep_keeper":
            return DataStats.taggedDays(group: .sleep, timing: .before, measurements: measures, tags: tags)
        case "achv_perfect_pair":
            return DataStats.pairCount(group: .sleep, measurements: measures, tags: tags)
        case "achv_tagged_measures":
            return measures.filter { $0.tagId != nil }.count
        case "achv_meditation_lab":
            return DataStats.pairCount(group: .relax, measurements: measures, tags: tags)
        case "achv_resilience_loop":
            return DataStats.pairCount(group: .stress, measurements: measures, tags: tags)
        case "achv_baseline_guardian":
            return DataStats.restWeekCount(measures, tags: tags)
        case "achv_workout_reaction":
            return DataStats.pairCount(group: .activity, measurements: measures, tags: tags)
        case "achv_full_spectrum":
            return DataStats.fullSpectrumSets(measures, tags: tags)
        case "achv_3_hour_lab":
            return DataStats.anyThreeHourPairs(measures, tags: tags)
        case "achv_insight_scholar":
            return snapshot.articlesRead.count
        case "achv_ai_explorer":
            return measures.filter(\.hasReadAIComment).count
        case "achv_30_day_consistency", "achv_90_day_consistency":
            return DataStats.currentStreak(measures)
        case "achv_context_atlas":
            return DataStats.distinctTagSets(measures, tags: tags)
        case "achv_setup_health":
            return snapshot.appleHealthConnected ? 1 : 0
        default:
            return 0
        }
    }

    static func progress(snapshot: DataSnapshot) -> [AchievementProgress] {
        let tags = snapshot.tagInfos
        let rows: [AchievementTierProgressMO] = PersistenceController.shared.fetch(AchievementTierProgressMO.self)
        let byType = Dictionary(rows.map { ($0.achievementType, $0) }, uniquingKeysWith: { first, _ in first })
        return AchievementCatalog.all.map { definition in
            let value = currentValue(for: definition, snapshot: snapshot, tags: tags)
            let reached = definition.tierReached(for: value)
            let row = byType[definition.id]
            return AchievementProgress(
                definition: definition,
                currentValue: value,
                reachedTier: reached,
                nextTier: definition.nextTier(after: value),
                progress: definition.progress(for: value),
                isComplete: reached?.target == definition.maxTarget,
                claimedTarget: Int(row?.rewardValue ?? 0),
                hasClaimedCurrentTier: (reached?.target ?? 0) <= Int(row?.rewardValue ?? 0)
            )
        }
    }

    /// Upserts one progress row per achievement, preserving claim state.
    @discardableResult
    static func sync(snapshot: DataSnapshot) -> [AchievementProgress] {
        let context = PersistenceController.shared.context
        let rows: [AchievementTierProgressMO] = PersistenceController.shared.fetch(AchievementTierProgressMO.self)
        let byType = Dictionary(rows.map { ($0.achievementType, $0) }, uniquingKeysWith: { first, _ in first })
        let progress = progress(snapshot: snapshot)
        for item in progress {
            let row = byType[item.definition.id] ?? {
                let created = AchievementTierProgressMO(context: context)
                created.achievementType = item.definition.id
                created.hasReceivedReward = false
                return created
            }()
            row.currentValue = Int32(item.currentValue)
            if item.reachedTier != nil, row.completedAt == nil {
                row.completedAt = Date()
            }
            if item.reachedTier != nil, Int(row.rewardValue) == 0, row.hasReceivedReward {
                row.rewardValue = Int32(item.reachedTier!.target)
            }
        }
        PersistenceController.shared.save()
        return progress
    }

    static func claim(_ progress: AchievementProgress) {
        guard let reachedTier = progress.reachedTier, progress.isClaimable else { return }
        let context = PersistenceController.shared.context
        let rows: [AchievementTierProgressMO] = PersistenceController.shared.fetch(
            AchievementTierProgressMO.self,
            predicate: NSPredicate(format: "achievementType == %@", progress.definition.id)
        )
        let row = rows.first ?? AchievementTierProgressMO(context: context)
        row.achievementType = progress.definition.id
        row.currentValue = Int32(progress.currentValue)
        row.rewardValue = Int32(reachedTier.target)
        row.completedAt = row.completedAt ?? Date()
        row.hasReceivedReward = true
        PersistenceController.shared.save()
    }

    static func claimAll(snapshot: DataSnapshot) {
        for progress in AchievementEngine.progress(snapshot: snapshot) where progress.isClaimable {
            claim(progress)
        }
    }

    static func completedCount(snapshot: DataSnapshot) -> Int {
        progress(snapshot: snapshot).filter { $0.reachedTier != nil }.count
    }
}

// MARK: - Journey

struct JourneyTaskState: Identifiable {
    let definition: JourneyTaskDefinition
    let currentValue: Int
    let target: Int
    let isCompleted: Bool

    var id: String { definition.id }
    var progress: Double {
        guard target > 0 else { return isCompleted ? 1 : 0 }
        return min(1, Double(currentValue) / Double(target))
    }
}

struct JourneyLevelState: Identifiable {
    let definition: JourneyLevelDefinition
    let tasks: [JourneyTaskState]
    let isLocked: Bool
    let isCompleted: Bool

    var id: String { definition.id }

    var coreTasks: [JourneyTaskState] { tasks.filter { $0.definition.type == .core } }
    var optionalTasks: [JourneyTaskState] { tasks.filter { $0.definition.type == .optional } }
    var proTasks: [JourneyTaskState] { tasks.filter { $0.definition.type == .pro } }

    var completedCoreCount: Int { coreTasks.filter(\.isCompleted).count }
    var completedTaskCount: Int { tasks.filter(\.isCompleted).count }

    var progress: Double {
        guard !coreTasks.isEmpty else { return isCompleted ? 1 : 0 }
        return Double(completedCoreCount) / Double(coreTasks.count)
    }
}

enum JourneyEngine {
    static func levelStates(snapshot: DataSnapshot) -> [JourneyLevelState] {
        let tags = snapshot.tagInfos
        var cache: [String: Int] = [:]
        var states: [JourneyLevelState] = []
        var canUnlock = true

        for level in JourneyCatalog.levels {
            var taskStates: [JourneyTaskState] = []
            for task in level.tasks {
                let value = taskValue(
                    category: task.category,
                    referenceId: task.referenceId,
                    target: task.target,
                    snapshot: snapshot,
                    tags: tags,
                    cache: &cache
                )
                taskStates.append(JourneyTaskState(
                    definition: task,
                    currentValue: min(value, task.target),
                    target: task.target,
                    isCompleted: value >= task.target
                ))
            }
            let coreDone = taskStates.filter { $0.definition.type == .core }.allSatisfy(\.isCompleted)
            let completed = coreDone && taskStates.contains { $0.definition.type == .core }
            let locked = !canUnlock
            states.append(JourneyLevelState(
                definition: level,
                tasks: taskStates,
                isLocked: locked,
                isCompleted: completed
            ))
            if !completed {
                canUnlock = false
            }
        }
        return states
    }

    static func taskValue(
        category: String,
        referenceId: String?,
        target: Int,
        snapshot: DataSnapshot,
        tags: [String: TagInfo],
        cache: inout [String: Int]
    ) -> Int {
        let measures = snapshot.measurements
        if category == "read_article" {
            guard let referenceId else { return 0 }
            let key = referenceId.replacingOccurrences(of: ".title", with: "")
            return snapshot.articlesRead.contains(key) || snapshot.articlesRead.contains("article." + key) ? 1 : 0
        }
        if category == "apple_health" {
            return snapshot.appleHealthConnected ? 1 : 0
        }
        if let cached = cache[category] { return cached }
        let value: Int
        switch category {
        case "any_measures_vol": value = measures.count
        case "any_measures_days": value = DataStats.distinctDays(measures)
        case "any_activity_vol":
            value = measures.filter { $0.tagId.flatMap { tags[$0] }?.group == .activity }.count
        case "any_rest_vol":
            value = measures.filter {
                guard let info = $0.tagId.flatMap({ tags[$0] }) else { return false }
                return info.group == .sleep || info.group == .relax
            }.count
        case "load_measures_vol":
            value = measures.filter {
                guard let info = $0.tagId.flatMap({ tags[$0] }) else { return false }
                return info.group == .stress || (info.group == .activity && info.timing == .after)
            }.count
        case "all_tags_vol":
            value = measures.filter { $0.tagId != nil }.count
        case "ai_comments_vol":
            value = measures.filter(\.hasReadAIComment).count
        case "sleep_before":
            value = DataStats.countTiming(group: .sleep, timing: .before, measurements: measures, tags: tags)
        case "sleep_after":
            value = DataStats.countTiming(group: .sleep, timing: .after, measurements: measures, tags: tags)
        case "sleep_before_days":
            value = DataStats.taggedDays(group: .sleep, timing: .before, measurements: measures, tags: tags)
        case "sleep_after_days":
            value = DataStats.taggedDays(group: .sleep, timing: .after, measurements: measures, tags: tags)
        case "sleep_before_streak_days":
            value = DataStats.streak(for: .sleep, timing: .before, measurements: measures, tags: tags)
        case "sleep_after_streak_days":
            value = DataStats.streak(for: .sleep, timing: .after, measurements: measures, tags: tags)
        case "exersice_before":
            value = DataStats.countTiming(group: .activity, timing: .before, measurements: measures, tags: tags)
        case "exersice_after":
            value = DataStats.countTiming(group: .activity, timing: .after, measurements: measures, tags: tags)
        case "meditate_before_vol":
            value = DataStats.countTiming(group: .relax, timing: .before, measurements: measures, tags: tags)
        case "meditate_after_vol":
            value = DataStats.countTiming(group: .relax, timing: .after, measurements: measures, tags: tags)
        case "stress_before":
            value = DataStats.countTiming(group: .stress, timing: .before, measurements: measures, tags: tags)
        case "stress_during":
            value = DataStats.countTiming(group: .stress, timing: .during, measurements: measures, tags: tags)
        case "stress_after":
            value = DataStats.countTiming(group: .stress, timing: .after, measurements: measures, tags: tags)
        case "sleep_pairs":
            value = DataStats.pairCount(group: .sleep, measurements: measures, tags: tags)
        case "exersice_pairs":
            value = DataStats.pairCount(group: .activity, measurements: measures, tags: tags)
        case "meditate_pairs":
            value = DataStats.pairCount(group: .relax, measurements: measures, tags: tags)
        case "stress_pairs":
            value = DataStats.pairCount(group: .stress, measurements: measures, tags: tags)
        case "any_pairs":
            value = DataStats.pairCount(measurements: measures, tags: tags) + DataStats.anyThreeHourPairs(measures, tags: tags)
        case "any_rest_pairs":
            value = DataStats.pairCount(group: .sleep, measurements: measures, tags: tags)
                + DataStats.pairCount(group: .relax, measurements: measures, tags: tags)
        case "consistency_7", "consistency_30", "consistency_90":
            value = DataStats.longestStreak(measures)
        case "all_tag_groups":
            value = DataStats.distinctTagGroups(measures, tags: tags)
        case "all_tags_sets":
            value = DataStats.distinctTagSets(measures, tags: tags)
        case "any_rest_weeks_with_3":
            value = DataStats.restWeekCount(measures, tags: tags)
        case "full_spectrum_sets":
            value = DataStats.fullSpectrumSets(measures, tags: tags)
        default:
            value = 0
        }
        cache[category] = value
        return value
    }

    static func currentLevel(states: [JourneyLevelState]) -> JourneyLevelState? {
        states.first { !$0.isCompleted } ?? states.last
    }

    static func completedLevelCount(states: [JourneyLevelState]) -> Int {
        states.filter { $0.isCompleted && !$0.isLocked }.count
    }

    /// Persists the started part of the Journey using the Core Data entities.
    static func persist(states: [JourneyLevelState]) {
        let context = PersistenceController.shared.context
        let levels: [JourneyLevelProgressMO] = PersistenceController.shared.fetch(JourneyLevelProgressMO.self)
        var byId = Dictionary(levels.map { ($0.levelId, $0) }, uniquingKeysWith: { first, _ in first })
        let currentIndex = states.firstIndex(where: { !$0.isCompleted }) ?? states.count - 1
        let persistRange = 0...max(0, currentIndex)
        for state in states[persistRange] {
            let level = byId[state.definition.id] ?? {
                let created = JourneyLevelProgressMO(context: context)
                created.levelId = state.definition.id
                created.startedAt = Date()
                return created
            }()
            byId[state.definition.id] = level
            let taskRows = (level.tasks as? Set<JourneyTaskProgressMO>) ?? []
            var taskById = Dictionary(taskRows.map { ($0.taskId, $0) }, uniquingKeysWith: { first, _ in first })
            for task in state.tasks {
                let row = taskById[task.definition.id] ?? {
                    let created = JourneyTaskProgressMO(context: context)
                    created.taskId = task.definition.id
                    created.level = level
                    return created
                }()
                taskById[task.definition.id] = row
                row.currentValue = Int32(task.currentValue)
                row.targetValue = Int32(task.target)
                row.category = task.definition.category
                row.type = task.definition.type.rawValue
                row.referenceId = task.definition.referenceId
                if task.isCompleted, row.completedAt == nil {
                    row.completedAt = Date()
                }
            }
        }
        PersistenceController.shared.save()
    }
}
