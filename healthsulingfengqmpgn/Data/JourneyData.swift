import Foundation

enum JourneyTaskType: String, Codable, CaseIterable {
    case core, optional, pro

    var title: String {
        switch self {
        case .core: return "Main"
        case .optional: return "Optional"
        case .pro: return "Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .core: return "Required to finish this level"
        case .optional: return "Extra credit for your practice"
        case .pro: return "Included with Premium"
        }
    }
}

struct JourneyTaskDefinition: Identifiable, Hashable {
    let id: String
    let type: JourneyTaskType
    let category: String
    let target: Int
    let referenceId: String?

    var ctaTitle: String {
        if category == "read_article" { return "Read Article" }
        if category == "apple_health" { return "Go to Settings" }
        return "Take Measurement"
    }

    var icon: String {
        if category == "read_article" { return "book.fill" }
        if category == "apple_health" { return "heart.text.square.fill" }
        switch category {
        case _ where category.contains("sleep"): return "moon.stars.fill"
        case _ where category.contains("meditate") || category.contains("rest"): return "leaf.fill"
        case _ where category.contains("exersice") || category.contains("activity"): return "figure.run"
        case _ where category.contains("stress") || category.contains("load"): return "bolt.fill"
        default: return "waveform.path.ecg"
        }
    }

    var requirementTitle: String {
        if category == "read_article" {
            let key = (referenceId ?? "").replacingOccurrences(of: ".title", with: "")
            if let article = ArticleCatalog.article(forReference: key) {
                return "Read “\(article.title)”"
            }
            return "Read an article"
        }
        if category == "apple_health" { return "Connect Apple Health" }
        switch category {
        case "any_measures_vol": return "Take \(target) measurements"
        case "any_measures_days": return "Measure on \(target) days"
        case "any_activity_vol": return "Log \(target) activity measurements"
        case "any_rest_vol": return "Log \(target) rest measurements"
        case "load_measures_vol": return "Log \(target) high-load measurements"
        case "all_tags_vol": return "Tag \(target) measurements"
        case "ai_comments_vol": return "Read \(target) AI comments"
        case "sleep_before": return "Measure before sleep \(target) times"
        case "sleep_after": return "Measure after sleep \(target) times"
        case "sleep_before_days": return "Measure before sleep on \(target) days"
        case "sleep_after_days": return "Measure after sleep on \(target) days"
        case "sleep_before_streak_days": return "\(target)-day before-sleep streak"
        case "sleep_after_streak_days": return "\(target)-day after-sleep streak"
        case "exersice_before": return "Measure before exercise \(target) times"
        case "exersice_after": return "Measure after exercise \(target) times"
        case "meditate_before_vol": return "Measure before mindfulness \(target) times"
        case "meditate_after_vol": return "Measure after mindfulness \(target) times"
        case "stress_before": return "Measure before stress \(target) times"
        case "stress_during": return "Measure during stress \(target) times"
        case "stress_after": return "Measure after stress \(target) times"
        case "sleep_pairs": return "Close \(target) sleep pairs"
        case "exersice_pairs": return "Close \(target) exercise pairs"
        case "meditate_pairs": return "Close \(target) mindfulness pairs"
        case "stress_pairs": return "Close \(target) stress pairs"
        case "any_pairs": return "Close \(target) context pairs"
        case "any_rest_pairs": return "Close \(target) rest pairs"
        case "consistency_7": return "Keep a \(target)-day streak"
        case "consistency_30": return "Keep a \(target)-day streak"
        case "consistency_90": return "Keep a \(target)-day streak"
        case "all_tag_groups": return target == 1 ? "Use 1 different tag group" : "Use \(target) different tag groups"
        case "all_tags_sets": return target == 1 ? "Complete 1 tagged set" : "Complete \(target) tagged sets"
        case "any_rest_weeks_with_3": return "\(target) week(s) with 3+ rest measures"
        case "full_spectrum_sets": return "Complete \(target) full-spectrum sets"
        default: return "Progress \(target)"
        }
    }
}

struct JourneyLevelDefinition: Identifiable, Hashable {
    let id: String
    let chapterId: String
    let index: Int
    let tasks: [JourneyTaskDefinition]

    var number: Int { Int(id.dropFirst()) ?? index }
}

struct JourneyChapterDefinition: Identifiable, Hashable {
    let id: String
    let index: Int
    let title: String
    let subtitle: String
    let levels: [JourneyLevelDefinition]

    var icon: String {
        switch index {
        case 1: return "flag.checkered"
        case 2: return "moon.stars.fill"
        case 3: return "waveform.path.ecg"
        case 4: return "bed.double.fill"
        case 5: return "leaf.fill"
        case 6: return "figure.run"
        case 7: return "bolt.heart.fill"
        case 8: return "circle.hexagongrid.fill"
        case 9: return "sparkles"
        case 10: return "chart.line.uptrend.xyaxis"
        case 11: return "flame.fill"
        default: return "trophy.fill"
        }
    }
}

enum JourneyCatalog {
    static let chapters: [JourneyChapterDefinition] = buildChapters()

    static var levels: [JourneyLevelDefinition] {
        chapters.flatMap(\.levels)
    }

    static var levelCount: Int { levels.count }

    static func level(_ id: String) -> JourneyLevelDefinition? {
        levels.first { $0.id == id }
    }

    static func chapter(_ id: String) -> JourneyChapterDefinition? {
        chapters.first { $0.id == id }
    }

    private static func buildChapters() -> [JourneyChapterDefinition] {
        let definitions: [(String, String, String, Int)] = [
            ("CH01", "First Signals", "Build the habit and learn what your heart is telling you.", 3),
            ("CH02", "Listen & Label", "Use context tags to turn single readings into a story.", 5),
            ("CH03", "Recovery Rhythm", "Discover how sleep, rest and stress shape recovery.", 6),
            ("CH04", "Sleep Mastery", "Turn consistent sleep measurements into a nightly ritual.", 5),
            ("CH05", "Mindful Reset", "Train your nervous system with mindful check-ins.", 10),
            ("CH06", "Move & Recover", "Pair movement with recovery so training stays sustainable.", 10),
            ("CH07", "Stress Systems", "Understand the many ways stress shows up in your body.", 10),
            ("CH08", "Balance", "Blend sleep, movement and mindfulness into one practice.", 10),
            ("CH09", "Deep Practice", "Raise the bar with longer streaks and full context sets.", 10),
            ("CH10", "Load & Rebound", "See how load and recovery interact over weeks.", 10),
            ("CH11", "Advanced Insight", "Use your data to make confident everyday decisions.", 10),
            ("CH12", "Heart Mastery", "Complete the full Journey and own your heart health.", 11)
        ]

        var parsed: [String: [JourneyTaskDefinition]] = [:]
        for line in journeyCSV.split(separator: "\n") {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 3 else { continue }
            let levelId = String(parts[1])
            let tasks = parts[2].split(separator: ";").compactMap { value -> JourneyTaskDefinition? in
                let fields = value.split(separator: ":", omittingEmptySubsequences: false)
                guard fields.count >= 4 else { return nil }
                let type = JourneyTaskType(rawValue: String(fields[1])) ?? .core
                let target = Int(fields[3]) ?? 1
                let reference = fields.count > 4 ? String(fields[4]) : nil
                return JourneyTaskDefinition(
                    id: String(fields[0]),
                    type: type,
                    category: String(fields[2]),
                    target: target,
                    referenceId: reference
                )
            }
            parsed[levelId] = tasks
        }

        var chapterResult: [JourneyChapterDefinition] = []
        var globalIndex = 0
        for definition in definitions {
            var levels: [JourneyLevelDefinition] = []
            for _ in 0..<definition.3 {
                globalIndex += 1
                let levelId = String(format: "L%02d", globalIndex)
                let tasks = parsed[levelId] ?? []
                levels.append(JourneyLevelDefinition(
                    id: levelId,
                    chapterId: definition.0,
                    index: globalIndex,
                    tasks: tasks
                ))
            }
            chapterResult.append(JourneyChapterDefinition(
                id: definition.0,
                index: Int(definition.0.dropFirst(2)) ?? 0,
                title: definition.1,
                subtitle: definition.2,
                levels: levels
            ))
        }
        return chapterResult
    }

    /// Complete task configuration from the product requirements (12 chapters,
    /// 100 levels, 5 tasks per level: 3 core + 1 optional + 1 pro).
    private static let journeyCSV = """
CH01|L01|L01_1:core:any_measures_vol:3;L01_2:core:read_article:1:article.hrv.basics.what_is_hrv.title;L01_3:core:all_tags_vol:2;L01_4:optional:apple_health:1;L01_5:pro:all_tags_sets:1
CH01|L02|L02_1:core:sleep_after:2;L02_2:core:any_measures_days:2;L02_3:core:read_article:1:article.hrv.basics.what_affects_hrv.title;L02_4:optional:any_activity_vol:2;L02_5:pro:any_pairs:3
CH01|L03|L03_1:core:sleep_before:2;L03_2:core:sleep_after:2;L03_3:core:read_article:1:article.hrv.context.why_context_matters.title;L03_4:optional:ai_comments_vol:3;L03_5:pro:all_tag_groups:1
CH02|L04|L04_1:core:sleep_after:3;L04_2:core:all_tags_vol:10;L04_3:core:read_article:1:article.hrv.context.rest_and_recovery.title;L04_4:optional:sleep_before:3;L04_5:pro:all_tag_groups:2
CH02|L05|L05_1:core:all_tag_groups:1;L05_2:core:all_tags_vol:10;L05_3:core:read_article:1:article.hrv.context.personalization_and_tags.title;L05_4:optional:any_activity_vol:2;L05_5:pro:all_tags_sets:1
CH02|L06|L06_1:core:exersice_before:2;L06_2:core:exersice_after:2;L06_3:core:read_article:1:article.activity.howtostart.title;L06_4:optional:read_article:1:article.activity.benefits.title;L06_5:pro:any_activity_vol:12
CH02|L07|L07_1:core:sleep_pairs:2;L07_2:core:exersice_pairs:1;L07_3:core:read_article:1:article.hrv.context.decrease_interpretation.title;L07_4:optional:all_tags_sets:1;L07_5:pro:any_pairs:7
CH02|L08|L08_1:core:sleep_after:2;L08_2:core:consistency_7:3;L08_3:core:read_article:1:article.sleep.about.title;L08_4:optional:ai_comments_vol:12;L08_5:pro:consistency_7:7
CH03|L09|L09_1:core:consistency_7:3;L09_2:core:sleep_pairs:2;L09_3:core:read_article:1:article.hrv.context.food_and_metabolism.title;L09_4:optional:ai_comments_vol:12;L09_5:pro:any_pairs:10
CH03|L10|L10_1:core:consistency_7:5;L10_2:core:sleep_after_days:3;L10_3:core:read_article:1:article.hrv.explained.psychological_aspects.title;L10_4:optional:meditate_pairs:1;L10_5:pro:consistency_7:7
CH03|L11|L11_1:core:any_rest_vol:8;L11_2:core:sleep_pairs:2;L11_3:core:read_article:1:article.sleep.disorder.title;L11_4:optional:any_rest_weeks_with_3:1;L11_5:pro:any_rest_pairs:5
CH03|L12|L12_1:core:sleep_before_days:3;L12_2:core:sleep_after_days:3;L12_3:core:read_article:1:article.hrv.basics.improving_hrv.title;L12_4:optional:load_measures_vol:4;L12_5:pro:all_tags_sets:2
CH03|L13|L13_1:core:sleep_pairs:2;L13_2:core:exersice_pairs:2;L13_3:core:read_article:1:article.sleep.timing.title;L13_4:optional:meditate_pairs:2;L13_5:pro:any_pairs:20
CH03|L14|L14_1:core:any_rest_vol:4;L14_2:core:any_rest_pairs:2;L14_3:core:read_article:1:article.hrv.context.readiness_and_load.title;L14_4:optional:any_measures_days:7;L14_5:pro:all_tags_sets:2
CH04|L15|L15_1:core:sleep_after:3;L15_2:core:sleep_after_days:2;L15_3:core:read_article:1:article.sleep.benefits.title;L15_4:optional:sleep_pairs:2;L15_5:pro:sleep_after_streak_days:3
CH04|L16|L16_1:core:sleep_before:3;L16_2:core:sleep_before_streak_days:2;L16_3:core:read_article:1:article.sleep.sleepy.title;L16_4:optional:sleep_pairs:3;L16_5:pro:sleep_after_streak_days:4
CH04|L17|L17_1:core:sleep_before:3;L17_2:core:sleep_before_days:3;L17_3:core:read_article:1:article.sleep.science.title;L17_4:optional:sleep_pairs:4;L17_5:pro:sleep_before_streak_days:5
CH04|L18|L18_1:core:sleep_after:3;L18_2:core:sleep_after_streak_days:2;L18_3:core:read_article:1:article.sleep.tips.title;L18_4:optional:meditate_pairs:3;L18_5:pro:sleep_after_streak_days:6
CH04|L19|L19_1:core:ai_comments_vol:10;L19_2:core:sleep_pairs:2;L19_3:core:read_article:1:article.sleep.disrupt.title;L19_4:optional:any_pairs:5;L19_5:pro:sleep_after_streak_days:7
CH05|L20|L20_1:core:meditate_pairs:1;L20_2:core:meditate_after_vol:2;L20_3:core:read_article:1:article.stress.managing.title;L20_4:optional:any_pairs:7;L20_5:pro:meditate_pairs:7
CH05|L21|L21_1:core:any_rest_vol:4;L21_2:core:meditate_before_vol:3;L21_3:core:meditate_after_vol:3;L21_4:optional:any_pairs:7;L21_5:pro:any_rest_weeks_with_3:1
CH05|L22|L22_1:core:any_rest_vol:5;L22_2:core:meditate_pairs:2;L22_3:core:any_rest_pairs:3;L22_4:optional:any_pairs:7;L22_5:pro:consistency_7:7
CH05|L23|L23_1:core:sleep_pairs:2;L23_2:core:sleep_after_streak_days:2;L23_3:core:meditate_pairs:2;L23_4:optional:ai_comments_vol:10;L23_5:pro:sleep_after_streak_days:5
CH05|L24|L24_1:core:stress_after:1;L24_2:core:meditate_pairs:2;L24_3:core:read_article:1:article.hrv.explained.physiological_correlates.title;L24_4:optional:any_rest_pairs:5;L24_5:pro:sleep_pairs:5
CH05|L25|L25_1:core:meditate_after_vol:4;L25_2:core:sleep_after_streak_days:3;L25_3:core:meditate_pairs:2;L25_4:optional:any_pairs:10;L25_5:pro:sleep_pairs:7
CH05|L26|L26_1:core:sleep_before:2;L26_2:core:meditate_before_vol:2;L26_3:core:read_article:1:article.stress.cognition.title;L26_4:optional:any_rest_pairs:5;L26_5:pro:any_rest_weeks_with_3:1
CH05|L27|L27_1:core:meditate_before_vol:4;L27_2:core:meditate_after_vol:4;L27_3:core:read_article:1:article.hrv.basics.how_hrv_works.title;L27_4:optional:meditate_pairs:10;L27_5:pro:sleep_pairs:10
CH05|L28|L28_1:core:any_rest_vol:6;L28_2:core:sleep_after_streak_days:3;L28_3:core:read_article:1:article.activity.intensity.title;L28_4:optional:any_pairs:10;L28_5:pro:consistency_30:15
CH05|L29|L29_1:core:any_rest_pairs:6;L29_2:core:sleep_after_streak_days:3;L29_3:core:meditate_pairs:3;L29_4:optional:any_pairs:10;L29_5:pro:sleep_pairs:12
CH06|L30|L30_1:core:sleep_after_days:2;L30_2:core:exersice_before:3;L30_3:core:read_article:1:article.activity.firststeps.title;L30_4:optional:ai_comments_vol:5;L30_5:pro:exersice_pairs:3
CH06|L31|L31_1:core:exersice_pairs:2;L31_2:core:sleep_after_streak_days:2;L31_3:core:read_article:1:article.activity.motivation.title;L31_4:optional:ai_comments_vol:6;L31_5:pro:load_measures_vol:6
CH06|L32|L32_1:core:exersice_before:3;L32_2:core:sleep_after_streak_days:4;L32_3:core:read_article:1:article.activity.push.title;L32_4:optional:load_measures_vol:4;L32_5:pro:exersice_pairs:5
CH06|L33|L33_1:core:exersice_after:2;L33_2:core:sleep_before_days:2;L33_3:core:read_article:1:article.activity.movement.title;L33_4:optional:meditate_after_vol:2;L33_5:pro:any_rest_weeks_with_3:2
CH06|L34|L34_1:core:exersice_pairs:3;L34_2:core:sleep_after_streak_days:4;L34_3:core:read_article:1:article.activity.types.title;L34_4:optional:any_activity_vol:10;L34_5:pro:any_rest_weeks_with_3:1
CH06|L35|L35_1:core:exersice_after:2;L35_2:core:sleep_before_streak_days:2;L35_3:core:read_article:1:article.activity.recforadults.title;L35_4:optional:any_rest_pairs:3;L35_5:pro:sleep_after_streak_days:4
CH06|L36|L36_1:core:exersice_after:4;L36_2:core:ai_comments_vol:6;L36_3:core:any_rest_pairs:2;L36_4:optional:all_tags_vol:10;L36_5:pro:load_measures_vol:10
CH06|L37|L37_1:core:load_measures_vol:4;L37_2:core:sleep_after_streak_days:4;L37_3:core:consistency_7:1;L37_4:optional:all_tag_groups:1;L37_5:pro:any_pairs:5
CH06|L38|L38_1:core:exersice_after:2;L38_2:core:sleep_after_streak_days:3;L38_3:core:exersice_before:2;L38_4:optional:any_rest_weeks_with_3:1;L38_5:pro:sleep_before_streak_days:5
CH06|L39|L39_1:core:any_activity_vol:4;L39_2:core:sleep_before_streak_days:4;L39_3:core:any_rest_vol:4;L39_4:optional:ai_comments_vol:12;L39_5:pro:exersice_pairs:5
CH07|L40|L40_1:core:stress_during:1;L40_2:core:stress_after:2;L40_3:core:read_article:1:article.stress.about.title;L40_4:optional:stress_pairs:2;L40_5:pro:sleep_after_streak_days:5
CH07|L41|L41_1:core:stress_before:2;L41_2:core:stress_after:1;L41_3:core:read_article:1:article.stress.cardio.title;L41_4:optional:ai_comments_vol:5;L41_5:pro:stress_pairs:2
CH07|L42|L42_1:core:stress_pairs:1;L42_2:core:any_rest_pairs:2;L42_3:core:read_article:1:article.stress.brain.title;L42_4:optional:all_tags_vol:10;L42_5:pro:stress_pairs:3
CH07|L43|L43_1:core:sleep_pairs:2;L43_2:core:sleep_after_streak_days:3;L43_3:core:read_article:1:article.stress.memory.title;L43_4:optional:ai_comments_vol:12;L43_5:pro:any_rest_weeks_with_3:2
CH07|L44|L44_1:core:stress_after:2;L44_2:core:sleep_after_streak_days:3;L44_3:core:read_article:1:article.stress.hormones.title;L44_4:optional:any_activity_vol:4;L44_5:pro:any_rest_pairs:5
CH07|L45|L45_1:core:stress_after:3;L45_2:core:meditate_before_vol:4;L45_3:core:read_article:1:article.stress.allsystems.title;L45_4:optional:sleep_before_days:2;L45_5:pro:stress_during:3
CH07|L46|L46_1:core:load_measures_vol:4;L46_2:core:sleep_pairs:3;L46_3:core:read_article:1:article.stress.managing.title;L46_4:optional:all_tag_groups:2;L46_5:pro:any_rest_weeks_with_3:2
CH07|L47|L47_1:core:any_measures_vol:10;L47_2:core:sleep_after_streak_days:3;L47_3:core:read_article:1:article.stress.gastro.title;L47_4:optional:any_rest_pairs:4;L47_5:pro:full_spectrum_sets:2
CH07|L48|L48_1:core:load_measures_vol:4;L48_2:core:sleep_after_streak_days:3;L48_3:core:read_article:1:article.stress.immunity.title;L48_4:optional:ai_comments_vol:12;L48_5:pro:consistency_7:7
CH07|L49|L49_1:core:consistency_30:7;L49_2:core:sleep_after_streak_days:5;L49_3:core:read_article:1:article.hrv.explained.clinical_significance.title;L49_4:optional:sleep_after_streak_days:5;L49_5:pro:consistency_30:15
CH08|L50|L50_1:core:sleep_pairs:3;L50_2:core:meditate_pairs:2;L50_3:core:ai_comments_vol:10;L50_4:optional:any_rest_weeks_with_3:2;L50_5:pro:all_tags_sets:2
CH08|L51|L51_1:core:sleep_after:3;L51_2:core:any_rest_pairs:2;L51_3:core:read_article:1:article.hrv.explained.variability.title;L51_4:optional:sleep_before:3;L51_5:pro:any_rest_weeks_with_3:2
CH08|L52|L52_1:core:exersice_after:2;L52_2:core:stress_pairs:1;L52_3:core:read_article:1:article.hrv.explained.analysis_methods.title;L52_4:optional:exersice_pairs:2;L52_5:pro:full_spectrum_sets:1
CH08|L53|L53_1:core:sleep_before_days:2;L53_2:core:sleep_after_streak_days:2;L53_3:core:read_article:1:article.sleep.myths.title;L53_4:optional:any_rest_pairs:2;L53_5:pro:sleep_pairs:4
CH08|L54|L54_1:core:sleep_after:3;L54_2:core:sleep_after_streak_days:2;L54_3:core:meditate_after_vol:2;L54_4:optional:sleep_pairs:2;L54_5:pro:sleep_after_streak_days:5
CH08|L55|L55_1:core:sleep_after:3;L55_2:core:sleep_pairs:2;L55_3:core:exersice_pairs:1;L55_4:optional:meditate_pairs:1;L55_5:pro:any_rest_weeks_with_3:2
CH08|L56|L56_1:core:exersice_before:2;L56_2:core:sleep_pairs:2;L56_3:core:meditate_pairs:2;L56_4:optional:consistency_7:5;L56_5:pro:all_tags_sets:1
CH08|L57|L57_1:core:consistency_7:4;L57_2:core:sleep_before_days:2;L57_3:core:sleep_after_days:2;L57_4:optional:consistency_30:10;L57_5:pro:full_spectrum_sets:1
CH08|L58|L58_1:core:consistency_30:7;L58_2:core:any_rest_vol:6;L58_3:core:any_activity_vol:4;L58_4:optional:all_tag_groups:1;L58_5:pro:consistency_30:15
CH08|L59|L59_1:core:any_rest_vol:7;L59_2:core:any_activity_vol:7;L59_3:core:any_pairs:3;L59_4:optional:ai_comments_vol:15;L59_5:pro:any_pairs:10
CH09|L60|L60_1:core:any_pairs:3;L60_2:core:ai_comments_vol:10;L60_3:core:all_tag_groups:1;L60_4:optional:any_measures_vol:20;L60_5:pro:full_spectrum_sets:2
CH09|L61|L61_1:core:meditate_pairs:3;L61_2:core:any_rest_weeks_with_3:2;L61_3:core:sleep_after_days:2;L61_4:optional:any_rest_vol:10;L61_5:pro:sleep_after_days:21
CH09|L62|L62_1:core:exersice_before:3;L62_2:core:exersice_after:3;L62_3:core:ai_comments_vol:6;L62_4:optional:sleep_pairs:3;L62_5:pro:sleep_after_days:5
CH09|L63|L63_1:core:load_measures_vol:4;L63_2:core:stress_pairs:2;L63_3:core:meditate_pairs:1;L63_4:optional:all_tags_vol:10;L63_5:pro:sleep_after_days:7
CH09|L64|L64_1:core:any_activity_vol:4;L64_2:core:exersice_pairs:2;L64_3:core:sleep_pairs:2;L64_4:optional:meditate_before_vol:4;L64_5:pro:sleep_before_streak_days:5
CH09|L65|L65_1:core:any_measures_vol:12;L65_2:core:all_tags_vol:12;L65_3:core:ai_comments_vol:10;L65_4:optional:all_tag_groups:1;L65_5:pro:all_tags_sets:2
CH09|L66|L66_1:core:meditate_pairs:3;L66_2:core:exersice_pairs:2;L66_3:core:stress_pairs:1;L66_4:optional:any_pairs:7;L66_5:pro:sleep_after_days:90
CH09|L67|L67_1:core:sleep_after:5;L67_2:core:sleep_after_days:4;L67_3:core:sleep_after_streak_days:3;L67_4:optional:sleep_before:5;L67_5:pro:sleep_pairs:10
CH09|L68|L68_1:core:sleep_before:5;L68_2:core:sleep_before_days:4;L68_3:core:sleep_before_streak_days:3;L68_4:optional:sleep_after:5;L68_5:pro:sleep_pairs:10
CH09|L69|L69_1:core:consistency_30:10;L69_2:core:all_tag_groups:1;L69_3:core:any_rest_weeks_with_3:1;L69_4:optional:any_rest_weeks_with_3:2;L69_5:pro:consistency_7:7
CH10|L70|L70_1:core:all_tag_groups:1;L70_2:core:all_tags_sets:1;L70_3:core:ai_comments_vol:10;L70_4:optional:any_rest_weeks_with_3:2;L70_5:pro:any_activity_vol:10
CH10|L71|L71_1:core:consistency_7:5;L71_2:core:consistency_30:7;L71_3:core:sleep_after_streak_days:3;L71_4:optional:sleep_pairs:3;L71_5:pro:full_spectrum_sets:2
CH10|L72|L72_1:core:meditate_before_vol:4;L72_2:core:meditate_after_vol:5;L72_3:core:any_rest_vol:7;L72_4:optional:all_tags_vol:10;L72_5:pro:meditate_pairs:10
CH10|L73|L73_1:core:stress_pairs:2;L73_2:core:load_measures_vol:4;L73_3:core:meditate_before_vol:3;L73_4:optional:meditate_after_vol:3;L73_5:pro:meditate_pairs:7
CH10|L74|L74_1:core:load_measures_vol:8;L74_2:core:exersice_pairs:2;L74_3:core:stress_pairs:1;L74_4:optional:any_rest_vol:8;L74_5:pro:sleep_after_days:7
CH10|L75|L75_1:core:sleep_pairs:3;L75_2:core:meditate_pairs:3;L75_3:core:load_measures_vol:3;L75_4:optional:ai_comments_vol:20;L75_5:pro:any_pairs:30
CH10|L76|L76_1:core:stress_before:3;L76_2:core:stress_during:1;L76_3:core:stress_after:3;L76_4:optional:stress_pairs:4;L76_5:pro:meditate_pairs:5
CH10|L77|L77_1:core:any_rest_pairs:4;L77_2:core:all_tag_groups:1;L77_3:core:ai_comments_vol:10;L77_4:optional:load_measures_vol:6;L77_5:pro:full_spectrum_sets:3
CH10|L78|L78_1:core:ai_comments_vol:10;L78_2:core:sleep_before_days:3;L78_3:core:sleep_after_days:3;L78_4:optional:all_tag_groups:1;L78_5:pro:consistency_30:14
CH10|L79|L79_1:core:any_rest_vol:10;L79_2:core:all_tags_sets:1;L79_3:core:ai_comments_vol:15;L79_4:optional:meditate_pairs:3;L79_5:pro:consistency_7:7
CH11|L80|L80_1:core:consistency_30:10;L80_2:core:ai_comments_vol:20;L80_3:core:any_pairs:7;L80_4:optional:any_measures_vol:30;L80_5:pro:consistency_90:15
CH11|L81|L81_1:core:any_rest_weeks_with_3:2;L81_2:core:all_tag_groups:1;L81_3:core:full_spectrum_sets:1;L81_4:optional:full_spectrum_sets:2;L81_5:pro:consistency_90:30
CH11|L82|L82_1:core:sleep_after:5;L82_2:core:sleep_after_streak_days:3;L82_3:core:sleep_pairs:3;L82_4:optional:any_rest_vol:14;L82_5:pro:any_rest_weeks_with_3:3
CH11|L83|L83_1:core:sleep_before:4;L83_2:core:sleep_pairs:4;L83_3:core:sleep_before_streak_days:3;L83_4:optional:any_rest_vol:7;L83_5:pro:sleep_before_streak_days:10
CH11|L84|L84_1:core:load_measures_vol:8;L84_2:core:stress_before:4;L84_3:core:stress_after:4;L84_4:optional:stress_during:3;L84_5:pro:consistency_90:21
CH11|L85|L85_1:core:exersice_before:4;L85_2:core:exersice_after:4;L85_3:core:load_measures_vol:10;L85_4:optional:any_rest_vol:10;L85_5:pro:consistency_7:7
CH11|L86|L86_1:core:meditate_before_vol:4;L86_2:core:meditate_after_vol:4;L86_3:core:meditate_pairs:10;L86_4:optional:full_spectrum_sets:1;L86_5:pro:any_rest_weeks_with_3:4
CH11|L87|L87_1:core:full_spectrum_sets:1;L87_2:core:load_measures_vol:6;L87_3:core:any_rest_vol:10;L87_4:optional:ai_comments_vol:30;L87_5:pro:all_tags_sets:3
CH11|L88|L88_1:core:sleep_before:7;L88_2:core:exersice_before:5;L88_3:core:full_spectrum_sets:1;L88_4:optional:meditate_pairs:5;L88_5:pro:consistency_90:30
CH11|L89|L89_1:core:ai_comments_vol:20;L89_2:core:any_measures_vol:30;L89_3:core:any_pairs:10;L89_4:optional:sleep_after_days:10;L89_5:pro:any_measures_days:21
CH12|L90|L90_1:core:sleep_before:10;L90_2:core:sleep_after:10;L90_3:core:any_rest_weeks_with_3:2;L90_4:optional:any_activity_vol:10;L90_5:pro:consistency_90:45
CH12|L91|L91_1:core:load_measures_vol:10;L91_2:core:any_rest_pairs:7;L91_3:core:any_measures_days:14;L91_4:optional:all_tag_groups:1;L91_5:pro:any_measures_days:90
CH12|L92|L92_1:core:any_pairs:14;L92_2:core:all_tags_sets:1;L92_3:core:ai_comments_vol:25;L92_4:optional:consistency_90:45;L92_5:pro:all_tags_sets:50
CH12|L93|L93_1:core:sleep_after:7;L93_2:core:sleep_after_streak_days:5;L93_3:core:ai_comments_vol:10;L93_4:optional:sleep_pairs:7;L93_5:pro:sleep_after_streak_days:14
CH12|L94|L94_1:core:meditate_before_vol:7;L94_2:core:meditate_after_vol:7;L94_3:core:ai_comments_vol:10;L94_4:optional:any_rest_pairs:10;L94_5:pro:consistency_90:60
CH12|L95|L95_1:core:sleep_before:7;L95_2:core:sleep_before_streak_days:5;L95_3:core:ai_comments_vol:10;L95_4:optional:any_rest_weeks_with_3:2;L95_5:pro:sleep_before_streak_days:14
CH12|L96|L96_1:core:stress_before:5;L96_2:core:stress_after:5;L96_3:core:meditate_after_vol:5;L96_4:optional:stress_during:3;L96_5:pro:any_rest_weeks_with_3:4
CH12|L97|L97_1:core:exersice_before:7;L97_2:core:exersice_after:7;L97_3:core:sleep_before:5;L97_4:optional:any_rest_vol:7;L97_5:pro:load_measures_vol:30
CH12|L98|L98_1:core:full_spectrum_sets:1;L98_2:core:ai_comments_vol:30;L98_3:core:any_rest_weeks_with_3:2;L98_4:optional:load_measures_vol:20;L98_5:pro:any_rest_weeks_with_3:8
CH12|L99|L99_1:core:sleep_after:14;L99_2:core:exersice_after:7;L99_3:core:meditate_after_vol:14;L99_4:optional:consistency_90:75;L99_5:pro:any_measures_days:150
CH12|L100|L100_1:core:any_rest_weeks_with_3:5;L100_2:core:consistency_30:21;L100_3:core:full_spectrum_sets:3;L100_4:optional:any_pairs:100;L100_5:pro:consistency_90:90
"""
}
