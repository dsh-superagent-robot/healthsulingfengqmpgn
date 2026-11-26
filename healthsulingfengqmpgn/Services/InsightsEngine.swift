import Foundation
import SwiftUI

enum MetricKind: String, CaseIterable, Identifiable {
    case pulse, hrv, sdnn, rmssd, pnn50, stress, energy, healthIndex, csi, heartAge
    case oxygen, glucoseBefore, glucoseAfter, pressureSys, pressureDia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .hrv: return "HRV"
        case .sdnn: return "SDNN"
        case .rmssd: return "RMSSD"
        case .pnn50: return "pNN50"
        case .stress: return "Stress"
        case .energy: return "Energy"
        case .healthIndex: return "Health Index"
        case .csi: return "Chronic Stress Index"
        case .heartAge: return "Heart Age"
        case .oxygen: return "Blood Oxygen"
        case .glucoseBefore: return "Glucose (Before Meal)"
        case .glucoseAfter: return "Glucose (After Meal)"
        case .pressureSys: return "Pressure SYS"
        case .pressureDia: return "Pressure DIA"
        }
    }

    var shortTitle: String {
        switch self {
        case .healthIndex: return "Health"
        case .csi: return "CSI"
        case .glucoseBefore: return "Glucose Before"
        case .glucoseAfter: return "Glucose After"
        case .pressureSys: return "SYS"
        case .pressureDia: return "DIA"
        default: return title
        }
    }

    var unit: String {
        switch self {
        case .pulse: return "bpm"
        case .hrv, .sdnn, .rmssd: return "ms"
        case .pnn50, .stress, .energy: return "%"
        case .healthIndex: return "lnRMSSD"
        case .csi: return "SI"
        case .heartAge: return "years"
        case .oxygen: return "%"
        case .glucoseBefore, .glucoseAfter: return "mg/dl"
        case .pressureSys, .pressureDia: return "mmHg"
        }
    }

    var icon: String {
        switch self {
        case .pulse: return "heart.fill"
        case .hrv, .sdnn, .rmssd: return "waveform.path.ecg"
        case .pnn50: return "percent"
        case .stress: return "bolt.fill"
        case .energy: return "battery.75"
        case .healthIndex: return "heart.text.square.fill"
        case .csi: return "chart.bar.doc.horizontal"
        case .heartAge: return "hourglass"
        case .oxygen: return "lungs.fill"
        case .glucoseBefore, .glucoseAfter: return "drop.fill"
        case .pressureSys, .pressureDia: return "gauge.medium"
        }
    }

    var accent: Color {
        switch self {
        case .pulse, .heartAge: return AppColors.coral
        case .hrv, .sdnn, .rmssd, .pnn50: return AppColors.teal
        case .stress, .csi: return AppColors.periwinkle
        case .energy: return AppColors.gold
        case .healthIndex: return AppColors.mint
        case .oxygen: return AppColors.info
        case .glucoseBefore, .glucoseAfter: return AppColors.orange
        case .pressureSys, .pressureDia: return AppColors.rose
        }
    }

    static let dashboardMetrics: [MetricKind] = [.csi, .energy, .healthIndex, .heartAge, .hrv, .pnn50, .rmssd, .stress]

    static let monthlyMetrics: [MetricKind] = [.pulse, .hrv, .sdnn, .rmssd, .pnn50, .stress, .csi, .energy, .healthIndex,
                                               .oxygen, .glucoseBefore, .glucoseAfter, .pressureSys, .pressureDia]

    func value(from measurement: HeartRateMeasurementMO) -> Double {
        switch self {
        case .pulse: return Double(measurement.pulse)
        case .hrv: return measurement.hrv
        case .sdnn: return measurement.sdnn
        case .rmssd: return measurement.rmssd
        case .pnn50: return measurement.pnn50
        case .stress: return Double(measurement.stress)
        case .energy: return Double(measurement.energy)
        case .healthIndex: return measurement.healthIndex
        case .csi: return Double(measurement.csi)
        case .heartAge, .oxygen, .glucoseBefore, .glucoseAfter, .pressureSys, .pressureDia:
            return 0
        }
    }

    func formatted(_ value: Double) -> String {
        switch self {
        case .pulse, .pnn50, .stress, .energy, .csi, .heartAge, .oxygen,
             .glucoseBefore, .glucoseAfter, .pressureSys, .pressureDia:
            return String(Int(value.rounded()))
        default:
            return String(format: "%.1f", value)
        }
    }
}

struct MetricInsight {
    let status: String
    let interpretation: String
    let detail: String
    let color: Color
    let emoji: String

    var headline: String { "\(emoji) \(status) — \(interpretation)" }
}

enum MetricInsights {
    static func insight(for kind: MetricKind, value: Double, age: Int? = nil) -> MetricInsight {
        switch kind {
        case .hrv:
            if value > 100 {
                return .init(status: "High", interpretation: "Excellent variability",
                             detail: "A high HRV at rest usually reflects a flexible, well-recovered nervous system.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 50 {
                return .init(status: "Normal", interpretation: "Moderate stress",
                             detail: "Your variability sits in a balanced range. Keep watching the trend across days.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "Low", interpretation: "Possible chronic stress",
                             detail: "Low variability can follow poor sleep, illness or sustained load. Rest and re-measure.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .sdnn:
            if value > 100 {
                return .init(status: "High", interpretation: "Excellent variability",
                             detail: "SDNN captures overall variability across the recording and looks strong.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 50 {
                return .init(status: "Normal", interpretation: "Moderate stress",
                             detail: "A mid-range SDNN is common and best interpreted alongside your baseline.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "Low", interpretation: "Possible chronic stress",
                             detail: "Lower overall variability may reflect fatigue or ongoing stress.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .rmssd:
            if value > 80 {
                return .init(status: "Excellent", interpretation: "Elite athlete",
                             detail: "Short-term variability is high, a pattern often seen in well-trained, well-rested people.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 50 {
                return .init(status: "Good", interpretation: "Well-trained individual",
                             detail: "Your recovery signal is solid. Keep the balance of load and rest.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 30 {
                return .init(status: "Average", interpretation: "Balanced state",
                             detail: "A typical range for many people. Context and trends matter more than one reading.",
                             color: AppColors.gold, emoji: "🟡")
            } else if value >= 20 {
                return .init(status: "Low", interpretation: "Possible chronic stress",
                             detail: "Reduced short-term variability may indicate accumulated stress or poor recovery.",
                             color: AppColors.orange, emoji: "🟠")
            } else {
                return .init(status: "Very Low", interpretation: "High stress",
                             detail: "This is a low reading. Rest, hydrate and consider re-measuring after a calm pause.",
                             color: AppColors.danger, emoji: "🔴")
            }
        case .pnn50:
            if value > 30 {
                return .init(status: "Excellent", interpretation: "Good stress recovery",
                             detail: "A high share of successive beats differ meaningfully — a sign of parasympathetic activity.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 20 {
                return .init(status: "Normal", interpretation: "Healthy level",
                             detail: "Your recovery pattern is within a healthy range.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 10 {
                return .init(status: "Reduced", interpretation: "Possible mild stress",
                             detail: "Beat-to-beat change is somewhat reduced. Sleep and stress may be influencing it.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "Low", interpretation: "Chronic stress",
                             detail: "Very little beat-to-beat change can appear during sustained stress or fatigue.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .pulse:
            if value > 120 {
                return .init(status: "Very High", interpretation: "Severe Tachycardia",
                             detail: "A resting pulse above 120 bpm is unusual. Re-measure calmly and seek medical advice if it persists.",
                             color: AppColors.danger, emoji: "🔴")
            } else if value >= 100 {
                return .init(status: "High", interpretation: "Mild Tachycardia",
                             detail: "A resting pulse in this range can follow caffeine, stress or movement. Re-measure at rest.",
                             color: AppColors.orange, emoji: "🟠")
            } else if value >= 60 {
                return .init(status: "Normal", interpretation: "Normal Heart Rate",
                             detail: "Your resting pulse sits in the typical adult range.",
                             color: AppColors.success, emoji: "🟢")
            } else {
                return .init(status: "Low", interpretation: "Bradycardia",
                             detail: "A lower resting pulse is common in trained people, but discuss persistent low readings with a clinician.",
                             color: AppColors.info, emoji: "🔵")
            }
        case .stress:
            if value >= 80 {
                return .init(status: "Very High", interpretation: "Highly tense",
                             detail: "Your stress index is high. Take a slow breathing break and prioritise recovery.",
                             color: AppColors.danger, emoji: "🔴")
            } else if value >= 70 {
                return .init(status: "High", interpretation: "Slightly tense",
                             detail: "Stress is elevated. A short walk or mindful pause may help you reset.",
                             color: AppColors.orange, emoji: "🟠")
            } else if value >= 35 {
                return .init(status: "Average", interpretation: "Mildly calm",
                             detail: "A middle-of-the-road reading. Watch how it changes with your tags.",
                             color: AppColors.gold, emoji: "🟡")
            } else if value >= 25 {
                return .init(status: "Low", interpretation: "Quite relaxed",
                             detail: "Your body is showing a relaxed pattern right now.",
                             color: AppColors.success, emoji: "🔵")
            } else {
                return .init(status: "Relaxed", interpretation: "Deeply relaxed",
                             detail: "Very low stress signal. This is a good moment to notice what helped.",
                             color: AppColors.success, emoji: "🔵")
            }
        case .energy:
            if value > 100 {
                return .init(status: "Excellent", interpretation: "Strong recovery",
                             detail: "Your energy estimate is above the typical recovery band.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 80 {
                return .init(status: "Good", interpretation: "Balanced state",
                             detail: "A healthy energy reading. Keep balancing activity and rest.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 60 {
                return .init(status: "Average", interpretation: "Increased stress",
                             detail: "Energy is a little lower than usual. Consider an easier pace today.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "Low", interpretation: "High stress",
                             detail: "Your recovery signal is low. Prioritise sleep, hydration and a calmer load.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .healthIndex:
            if value > 6.5 {
                return .init(status: "Athlete", interpretation: "Strong recovery",
                             detail: "A very high lnRMSSD value, usually paired with excellent recovery.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 5.5 {
                return .init(status: "Excellent", interpretation: "Optimal recovery",
                             detail: "Your health index suggests a well-recovered state.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 4.5 {
                return .init(status: "Good", interpretation: "Normal recovery",
                             detail: "A healthy, balanced reading. Use trends to guide your day.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 3.5 {
                return .init(status: "Average", interpretation: "Moderate stress",
                             detail: "Recovery is moderate. A calm moment and another reading later may help.",
                             color: AppColors.gold, emoji: "🟡")
            } else if value >= 2.5 {
                return .init(status: "Low", interpretation: "High stress",
                             detail: "Low recovery signal. Consider rest and re-measure when calm.",
                             color: AppColors.orange, emoji: "🟠")
            } else {
                return .init(status: "Very Low", interpretation: "Very high stress",
                             detail: "This is a very low recovery reading. Take care of yourself and seek support if this persists.",
                             color: AppColors.danger, emoji: "🔴")
            }
        case .csi:
            if value > 500 {
                return .init(status: "Very High", interpretation: "Risk of burnout",
                             detail: "A high chronic stress index over several days deserves deliberate recovery.",
                             color: AppColors.danger, emoji: "🔴")
            } else if value >= 300 {
                return .init(status: "High", interpretation: "Significant strain",
                             detail: "Your weekly stress signal is elevated. Protect sleep and reduce extra load.",
                             color: AppColors.orange, emoji: "🟠")
            } else if value >= 150 {
                return .init(status: "Elevated", interpretation: "Physical and mental exertion",
                             detail: "This is a busy range. Watch the trend over the next few days.",
                             color: AppColors.gold, emoji: "🟡")
            } else if value >= 50 {
                return .init(status: "Normal", interpretation: "Healthy and well-balanced",
                             detail: "Your rolling chronic stress index is in a balanced range.",
                             color: AppColors.success, emoji: "🟢")
            } else {
                return .init(status: "Low", interpretation: "Calm and relaxed",
                             detail: "A low chronic stress signal — a good time to note what is supporting you.",
                             color: AppColors.info, emoji: "🔵")
            }
        case .heartAge:
            let actual = age ?? 40
            if value <= Double(actual - 2) {
                return .init(status: "Good", interpretation: "Younger than your age",
                             detail: "Your estimated heart age is below your actual age, a positive recovery signal.",
                             color: AppColors.success, emoji: "🟢")
            } else if value <= Double(actual + 2) {
                return .init(status: "Equal", interpretation: "Close to your age",
                             detail: "Your estimated heart age is close to your actual age.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "High", interpretation: "Higher than your age",
                             detail: "The estimate is above your actual age. Focus on sleep, movement and stress recovery.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .oxygen:
            if value >= 96 {
                return .init(status: "Normal", interpretation: "Healthy oxygen level",
                             detail: "Your SpO2 reading is in the normal range.",
                             color: AppColors.success, emoji: "🟢")
            } else if value >= 90 {
                return .init(status: "Low", interpretation: "Below normal",
                             detail: "A low-normal reading. Sit calmly and repeat the measurement.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "Very Low", interpretation: "Seek medical advice",
                             detail: "A reading below 90% needs prompt medical attention if it repeats.",
                             color: AppColors.danger, emoji: "🔴")
            }
        case .glucoseBefore:
            if value < 70 {
                return .init(status: "Low", interpretation: "Low blood sugar",
                             detail: "A fasting value below 70 mg/dl should be discussed with a clinician.",
                             color: AppColors.info, emoji: "🔵")
            } else if value <= 100 {
                return .init(status: "Normal", interpretation: "Fasting normal range",
                             detail: "70–100 mg/dl is the typical fasting range.",
                             color: AppColors.success, emoji: "🟢")
            } else if value <= 125 {
                return .init(status: "Elevated", interpretation: "Fasting elevated range",
                             detail: "100–125 mg/dl is often described as elevated fasting glucose.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "High", interpretation: "Fasting high range",
                             detail: "126 mg/dl and above warrants a conversation with a clinician.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .glucoseAfter:
            if value < 70 {
                return .init(status: "Low", interpretation: "Low blood sugar",
                             detail: "A post-meal value below 70 mg/dl is unusual and should be discussed with a clinician.",
                             color: AppColors.info, emoji: "🔵")
            } else if value < 140 {
                return .init(status: "Normal", interpretation: "Post-meal normal range",
                             detail: "Below 140 mg/dl is the usual post-meal target range.",
                             color: AppColors.success, emoji: "🟢")
            } else if value < 200 {
                return .init(status: "Elevated", interpretation: "Post-meal elevated range",
                             detail: "140–199 mg/dl is elevated. Note what you ate and re-check later.",
                             color: AppColors.gold, emoji: "🟡")
            } else {
                return .init(status: "High", interpretation: "Post-meal high range",
                             detail: "200 mg/dl and above warrants a conversation with a clinician.",
                             color: AppColors.orange, emoji: "🟠")
            }
        case .pressureSys, .pressureDia:
            return .init(status: "Blood Pressure", interpretation: "Check SYS and DIA together",
                         detail: "Blood pressure is interpreted as a pair of values.", color: AppColors.rose, emoji: "🩺")
        }
    }

    static func bloodPressureInsight(sys: Int, dia: Int) -> MetricInsight {
        if sys >= 140 || dia >= 90 {
            return .init(status: "Very High", interpretation: "Above the high range",
                         detail: "A reading at or above 140/90 mmHg is high. Rest and re-measure; seek care if it repeats.",
                         color: AppColors.danger, emoji: "🔴")
        } else if sys >= 130 || dia >= 80 {
            return .init(status: "High", interpretation: "High blood pressure range",
                         detail: "130–139/80–89 mmHg is above normal. Discuss repeated readings with a clinician.",
                         color: AppColors.orange, emoji: "🟠")
        } else if sys >= 120 || dia >= 80 {
            return .init(status: "Elevated", interpretation: "Elevated blood pressure",
                         detail: "120–129/80 mmHg is considered elevated.",
                         color: AppColors.gold, emoji: "🟡")
        } else if sys < 90 || dia < 60 {
            return .init(status: "Low", interpretation: "Below the usual range",
                         detail: "Below 90/60 mmHg can be normal for some people. Re-check if you feel dizzy.",
                         color: AppColors.info, emoji: "🔵")
        } else {
            return .init(status: "Normal", interpretation: "Healthy blood pressure range",
                         detail: "90–120/60–80 mmHg is the usual healthy range.",
                         color: AppColors.success, emoji: "🟢")
        }
    }

    /// Lower/upper reference boundaries used to draw chart threshold lines.
    static func thresholds(for kind: MetricKind) -> [Double] {
        switch kind {
        case .hrv, .sdnn: return [50, 100]
        case .rmssd: return [20, 30, 50, 80]
        case .pnn50: return [10, 20, 30]
        case .pulse: return [60, 100, 120]
        case .stress: return [25, 35, 70, 80]
        case .energy: return [60, 80, 100]
        case .healthIndex: return [3.5, 4.5, 5.5, 6.5]
        case .csi: return [50, 150, 300, 500]
        case .oxygen: return [90, 96]
        case .glucoseBefore: return [70, 100, 126]
        case .glucoseAfter: return [70, 140, 200]
        case .pressureSys: return [90, 120, 130, 140]
        case .pressureDia: return [60, 80, 90]
        case .heartAge: return []
        }
    }
}

// MARK: - AI comment

struct AIComment {
    let overall: String
    let context: String
    let battery: String
    let generalKey: String
    let contextKey: String
}

enum AICommentEngine {
    static func comment(for measurement: HeartRateMeasurementMO, history: [HeartRateMeasurementMO]) -> AIComment {
        let hrv = measurement.hrv
        let tier: String
        if hrv > 100 { tier = "high" } else if hrv >= 50 { tier = "normal" } else { tier = "low" }

        let contextInfo = measurement.tagId.flatMap { TagCatalog.info(for: $0) }
        let contextGroup = contextInfo?.context ?? "general"
        let prior = history.filter { $0.createdAt < measurement.createdAt && $0.objectID != measurement.objectID }
        let baseline = average(prior.prefix(20).map(\.hrv))
        let delta: String
        if let baseline, baseline > 0 {
            let change = (hrv - baseline) / baseline
            if change > 0.05 { delta = "up" } else if change < -0.05 { delta = "down" } else { delta = "flat" }
        } else {
            delta = "flat"
        }

        let recent = history.filter {
            $0.createdAt >= Calendar.current.date(byAdding: .day, value: -7, to: measurement.createdAt)!
        }
        let older = history.filter {
            $0.createdAt < Calendar.current.date(byAdding: .day, value: -7, to: measurement.createdAt)! &&
            $0.createdAt >= Calendar.current.date(byAdding: .day, value: -37, to: measurement.createdAt)!
        }
        let recentAvg = average(recent.map(\.hrv))
        let olderAvg = average(older.map(\.hrv))
        var battery = "normalBattery"
        if let recentAvg, let olderAvg, olderAvg > 0 {
            if recentAvg > olderAvg * 1.05 { battery = "highBattery" }
            else if recentAvg < olderAvg * 0.95 { battery = "lowBattery" }
        }

        let seed = abs(measurement.createdAt.timeIntervalSince1970.hashValue)
        let overall = overallPool[tier]?[seed % (overallPool[tier]?.count ?? 1)] ?? ""
        let key = "\(contextGroup)_\(delta)"
        let contextPool = contextComments[key] ?? contextComments["general_flat"]!
        let context = contextPool[seed % contextPool.count]
        let batteryText = batteryComments[battery] ?? ""
        let generalKey = "hrv.\(tier).\(battery)"
        let contextKey = "context.\(key)"
        return AIComment(overall: overall, context: context, battery: batteryText,
                         generalKey: generalKey, contextKey: contextKey)
    }

    static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static let overallPool: [String: [String]] = [
        "high": [
            "Your HRV is currently above 100 ms, which points to a flexible, well-recovered autonomic system. Days like this are a good opportunity to take on a meaningful challenge, while still protecting your wind-down routine.",
            "Your heart rhythm shows high variability right now. That usually means your body has capacity to adapt. Enjoy the energy, but continue to check in with yourself rather than pushing through every signal.",
            "This is a strong variability reading. It often follows good sleep, gentle movement and low emotional load. Note what is working so you can return to it on less rested days."
        ],
        "normal": [
            "Your HRV sits in the moderate range. This is a common and healthy place to be, and it is best read as a conversation between your recent load and your recovery.",
            "A mid-range variability reading suggests your system is balancing activation and rest. There is no need to chase a perfect number — look at the direction of travel across the week.",
            "Your heart is showing a balanced pattern today. Keep your routines steady, hydrate, and use your tags to understand what moves this number up or down."
        ],
        "low": [
            "Your HRV is below 50 ms today. That can follow short sleep, illness, travel or a stretch of sustained stress. Treat it as a request for recovery rather than a failure.",
            "A lower variability reading is often a signal that your body is working harder than usual. Consider a lighter day, extra sleep and a calm re-measure later.",
            "Your system looks less flexible right now. Slow breathing, daylight and a gentle walk can help. If low readings persist for several days, talk with a healthcare professional."
        ]
    ]

    private static let contextComments: [String: [String]] = [
        "food_up": [
            "Compared with your baseline, HRV is higher around this meal context. It may reflect good recovery rather than the food itself — keep tagging so your own pattern becomes clearer.",
            "This reading is above your recent baseline. Meal timing, hydration and how relaxed you felt all play a part, so treat it as one helpful clue rather than a rule."
        ],
        "food_flat": [
            "Your reading is in line with your baseline around this meal context. That consistency is useful: it suggests your body is handling the moment without extra strain.",
            "This value is close to your usual level. Continue pairing before and after meal readings to see whether specific foods or portions shift your response."
        ],
        "food_down": [
            "Your HRV is lower than your baseline around this meal context. Digestion, portion size and timing can all influence the reading, as can stress from the day.",
            "This is below your recent baseline. Try a lighter meal or a short walk afterwards and compare how the next reading looks."
        ],
        "general_up": [
            "Your variability is above your recent baseline. Something in your routine is supporting recovery — notice sleep, movement and mood from the last day.",
            "This reading is higher than usual. Keep the context tag consistent so you can confirm the pattern over several readings."
        ],
        "general_flat": [
            "Your variability is close to your personal baseline. Stability is valuable, and it makes any real change easier to spot.",
            "This reading is in line with your recent data. Continue measuring at similar times to keep the signal clean."
        ],
        "general_down": [
            "Your variability is below your recent baseline. A single lower reading is normal; look at the last few days before drawing conclusions.",
            "This is lower than your own baseline. Consider whether sleep, hydration, stress or activity changed, and re-measure when you feel settled."
        ],
        "load_up": [
            "Around this high-load context your variability is above baseline. That may mean you recovered well from the preceding effort. Keep an eye on tomorrow's reading.",
            "This reading is higher than your recent baseline despite the load context. Good recovery is encouraging, but continue to pace the next session."
        ],
        "load_flat": [
            "Your variability is in line with baseline around this load context. Your body appears to be managing the demand without a large swing.",
            "This is close to your usual level. Pairing before and after readings will show whether the load is accumulating across the week."
        ],
        "load_down": [
            "This reading is below your baseline around a demanding context. It may reflect accumulated load. An easier session and extra sleep can help.",
            "Lower variability around stress or exercise is common. Prioritise recovery today and check whether the dip lasts more than a couple of readings."
        ],
        "performance_up": [
            "Your reading is above baseline around activity. That often means you are recovering well and can approach the next session with confidence.",
            "Good variability after movement is a positive recovery signal. Keep the warm-up and cool-down consistent to protect the trend."
        ],
        "performance_flat": [
            "Your variability matches your baseline around activity. This is a steady response and a useful reference point for future sessions.",
            "This is in line with your usual pattern. Continue pairing before and after exercise to see how different intensities affect you."
        ],
        "performance_down": [
            "Your variability is below baseline around activity. The session may have been harder than expected, or sleep and hydration may be playing a role.",
            "A lower reading after movement can be a normal training response. Give yourself an easier day and watch how quickly you return to baseline."
        ],
        "rest_up": [
            "This reading is above baseline in a rest context. Your recovery routine seems to be working — note what helped so you can repeat it.",
            "Higher variability around rest is a good sign. Protect this time and keep the routine consistent."
        ],
        "rest_flat": [
            "Your variability is in line with baseline around rest. A stable pattern is a useful foundation for spotting change.",
            "This is close to your usual recovery level. Continue measuring at the same point in your routine for the clearest comparison."
        ],
        "rest_down": [
            "Your variability is below baseline even in a rest context. That can happen with poor sleep or lingering stress. Be gentle with yourself today.",
            "This reading is lower than usual for rest. Consider a longer wind-down and re-measure after a few calm minutes."
        ]
    ]

    private static let batteryComments: [String: String] = [
        "highBattery": "Your seven-day trend is above your longer baseline, so your recovery battery looks well charged.",
        "normalBattery": "Your recent trend is close to your longer baseline, suggesting a steady recovery battery.",
        "lowBattery": "Your recent trend is below your longer baseline. A few easier days may help your recovery battery recharge."
    ]
}

// MARK: - Heart age and CSI

enum HeartAgeEngine {
    static func estimate(rmssd: Double, age: Int, gender: Gender) -> Int {
        let adjustment = gender == .female ? -1.0 : 0.0
        let estimate = Double(age) + (55 - rmssd) * 0.35 + adjustment
        return max(18, min(95, Int(estimate.rounded())))
    }

    static func rollingMeasurements(_ measurements: [HeartRateMeasurementMO]) -> [HeartRateMeasurementMO] {
        var seenDays = Set<Date>()
        var sample: [HeartRateMeasurementMO] = []
        for measurement in measurements.sorted(by: { $0.createdAt > $1.createdAt }) {
            let day = Calendar.current.startOfDay(for: measurement.createdAt)
            guard !seenDays.contains(day) else { continue }
            seenDays.insert(day)
            sample.append(measurement)
            if sample.count == 3 { break }
        }
        return sample
    }

    static func rollingEstimate(_ measurements: [HeartRateMeasurementMO], profile: UserProfile) -> Int? {
        guard let age = profile.age else { return nil }
        let sample = rollingMeasurements(measurements)
        guard !sample.isEmpty else { return nil }
        let rmssd = sample.map(\.rmssd).reduce(0, +) / Double(sample.count)
        return estimate(rmssd: rmssd, age: age, gender: profile.gender)
    }

    static func daysMeasured(_ measurements: [HeartRateMeasurementMO]) -> Int {
        Set(measurements.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
    }
}

enum CSIEngine {
    static let requiredDays = 7

    static func daysMeasured(_ measurements: [HeartRateMeasurementMO]) -> Int {
        Set(measurements.map { Calendar.current.startOfDay(for: $0.createdAt) }).count
    }

    static func rollingValue(_ measurements: [HeartRateMeasurementMO], now: Date = Date()) -> Double? {
        guard measurements.count >= 3 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let recent = measurements.filter { $0.createdAt >= cutoff }
        guard !recent.isEmpty else { return nil }
        return recent.map { Double($0.csi) }.reduce(0, +) / Double(recent.count)
    }

    static func todayCompleted(_ measurements: [HeartRateMeasurementMO]) -> Bool {
        guard let latest = measurements.max(by: { $0.createdAt < $1.createdAt }) else { return false }
        return Calendar.current.isDateInToday(latest.createdAt)
    }

    static func milestone(for days: Int) -> String? {
        switch days {
        case 1: return "Day 1"
        case 7: return "Day 7 · First result"
        case 17: return "Day 17"
        default: return nil
        }
    }
}
