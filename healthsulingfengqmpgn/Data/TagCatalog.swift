import SwiftUI

enum TagTiming: String, Codable, CaseIterable {
    case before, during, after

    var label: String {
        switch self {
        case .before: return "Before"
        case .during: return "During"
        case .after: return "After"
        }
    }
}

enum TagGroup: String, Codable, CaseIterable, Identifiable {
    case sleep
    case activity
    case stress
    case relax
    case eating

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .activity: return "Activity"
        case .stress: return "Stress"
        case .relax: return "Mindfulness"
        case .eating: return "Eating"
        }
    }

    var subtitle: String {
        switch self {
        case .sleep: return "How your night affects recovery"
        case .activity: return "Exercise load and recovery"
        case .stress: return "Pressure at work and life"
        case .relax: return "Meditation and calm moments"
        case .eating: return "Meals and metabolism"
        }
    }

    var icon: String {
        switch self {
        case .sleep: return "moon.stars.fill"
        case .activity: return "figure.run"
        case .stress: return "bolt.fill"
        case .relax: return "leaf.fill"
        case .eating: return "fork.knife"
        }
    }

    var color: Color {
        switch self {
        case .sleep: return AppColors.periwinkle
        case .activity: return AppColors.mint
        case .stress: return AppColors.coral
        case .relax: return AppColors.teal
        case .eating: return AppColors.orange
        }
    }

    var timings: [TagTiming] {
        switch self {
        case .sleep: return [.before, .after]
        case .activity: return [.before, .after]
        case .stress: return [.before, .during, .after]
        case .relax: return [.before, .after]
        case .eating: return [.before, .after]
        }
    }

    /// Semantic cluster used by the AI comment engine.
    var commentContext: String {
        switch self {
        case .eating: return "food"
        case .activity: return "performance"
        case .stress: return "load"
        case .sleep, .relax: return "rest"
        }
    }
}

enum TagCluster: String, CaseIterable, Identifiable {
    case food
    case readiness
    case rest
    case load
    case general

    var id: String { rawValue }

    var title: String {
        switch self {
        case .food: return "Food Impact"
        case .readiness: return "Readiness"
        case .rest: return "Rest & Recovery"
        case .load: return "Load & Stress"
        case .general: return "General"
        }
    }

    var subtitle: String {
        switch self {
        case .food: return "Before / After Meal"
        case .readiness: return "Before Exercise / Meditation / Stress / Meal"
        case .rest: return "Before / After Sleep · After Meditation"
        case .load: return "After Exercise · During / After Stress"
        case .general: return "Any moment"
        }
    }

    var color: Color {
        switch self {
        case .food: return AppColors.orange
        case .readiness: return AppColors.periwinkle
        case .rest: return AppColors.teal
        case .load: return AppColors.coral
        case .general: return AppColors.mint
        }
    }
}

enum TagPalette: String, CaseIterable, Identifiable {
    case green, blue, purple, yellow, orange, red, pink, teal, lavender

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .green: return Color(hex: 0x75D09E)
        case .blue: return Color(hex: 0x82B2D9)
        case .purple: return Color(hex: 0xA982D9)
        case .yellow: return Color(hex: 0xD5CF65)
        case .orange: return Color(hex: 0xD9A982)
        case .red: return Color(hex: 0xD98287)
        case .pink: return Color(hex: 0xD982B2)
        case .teal: return Color(hex: 0x6CD1CC)
        case .lavender: return Color(hex: 0xD482D9)
        }
    }

    var label: String { rawValue.capitalized }
}

struct TagInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let group: TagGroup?
    let timing: TagTiming?
    let cluster: TagCluster
    let color: Color
    let isCustom: Bool

    var isBuiltIn: Bool { !isCustom }

    var context: String {
        if let group { return group.commentContext }
        return cluster.commentContext
    }

    var icon: String {
        if let group { return group.icon }
        return "tag.fill"
    }

    static func builtIn(_ group: TagGroup, _ timing: TagTiming) -> TagInfo {
        TagInfo(
            id: "builtin.\(group.rawValue).\(timing.rawValue)",
            name: "\(timing.label) \(group.title)",
            group: group,
            timing: timing,
            cluster: TagCatalog.cluster(for: group, timing: timing),
            color: group.color,
            isCustom: false
        )
    }
}

extension TagCluster {
    var commentContext: String {
        switch self {
        case .food: return "food"
        case .readiness: return "performance"
        case .rest: return "rest"
        case .load: return "load"
        case .general: return "general"
        }
    }
}

enum TagCatalog {
    static let builtIns: [TagInfo] = TagGroup.allCases.flatMap { group in
        group.timings.map { TagInfo.builtIn(group, $0) }
    }

    static func cluster(for group: TagGroup, timing: TagTiming) -> TagCluster {
        switch group {
        case .eating: return .food
        case .activity: return timing == .after ? .load : .readiness
        case .stress: return .load
        case .sleep: return .rest
        case .relax: return .rest
        }
    }

    static func info(for id: String) -> TagInfo? {
        if let builtIn = builtIns.first(where: { $0.id == id }) { return builtIn }
        guard let uuid = UUID(uuidString: id) else { return nil }
        let tags: [CustomTagMO] = PersistenceController.shared.fetch(CustomTagMO.self)
        guard let tag = tags.first(where: { $0.id == uuid }) else { return nil }
        return info(for: tag)
    }

    static func info(for id: String, customTags: [CustomTagMO]) -> TagInfo? {
        if let builtIn = builtIns.first(where: { $0.id == id }) { return builtIn }
        guard let uuid = UUID(uuidString: id),
              let tag = customTags.first(where: { $0.id == uuid }) else { return nil }
        return info(for: tag)
    }

    static func all(customTags: [CustomTagMO]) -> [TagInfo] {
        builtIns + customTags.map(info(for:))
    }

    static func info(for tag: CustomTagMO) -> TagInfo {
        let cluster = TagCluster(rawValue: tag.cluster) ?? .general
        let palette = TagPalette(rawValue: tag.colorName) ?? .green
        return TagInfo(
            id: tag.id.uuidString,
            name: tag.name,
            group: nil,
            timing: nil,
            cluster: cluster,
            color: palette.color,
            isCustom: true
        )
    }

    static var customTags: [CustomTagMO] {
        PersistenceController.shared.fetch(CustomTagMO.self, sortBy: "createdAt", ascending: true)
    }

    static var customTagInfos: [TagInfo] {
        customTags.map(info(for:))
    }

    static var all: [TagInfo] {
        builtIns + customTagInfos
    }

    /// Auto tagging is intentionally transparent: it uses the time of day as a
    /// lightweight context signal and flags the measurement as auto-generated.
    static func autoTag(for date: Date, calendar: Calendar = .current) -> TagInfo {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11: return .builtIn(.sleep, .after)
        case 11..<14: return .builtIn(.eating, .before)
        case 14..<18: return .builtIn(.relax, .before)
        case 18..<21: return .builtIn(.eating, .after)
        default: return .builtIn(.sleep, .before)
        }
    }

    static func group(for tagId: String?) -> TagGroup? {
        guard let tagId, let info = info(for: tagId) else { return nil }
        return info.group
    }

    static func timing(for tagId: String?) -> TagTiming? {
        guard let tagId, let info = info(for: tagId) else { return nil }
        return info.timing
    }
}

struct MeasurementTagSelection: Equatable {
    var tagId: String?
    var isAuto: Bool

    static let none = MeasurementTagSelection(tagId: nil, isAuto: false)

    var displayName: String {
        if isAuto { return "Auto" }
        if let tagId, let info = TagCatalog.info(for: tagId) { return info.name }
        return "No Tag"
    }
}
