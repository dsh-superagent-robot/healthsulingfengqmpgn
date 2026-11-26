import Foundation

/// Deterministic sample content used by the `-DSHDemoData` launch argument for
/// screenshots and manual QA. It never runs without the explicit argument.
enum DemoData {
    private static let key = "demoDataSeeded.v1"

    static func seedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        let existing: [HeartRateMeasurementMO] = PersistenceController.shared.fetch(HeartRateMeasurementMO.self)
        guard existing.isEmpty else {
            defaults.set(true, forKey: key)
            return
        }
        defaults.set(true, forKey: key)

        seedCustomTags()
        seedMeasurements()
        seedWatchMeasurements()
        seedLogs()
        seedReminders()
        seedArticles()
        seedHealthConnection()

        if defaults.data(forKey: "userProfile") == nil {
            var profile = UserProfile()
            profile.name = "Alex"
            profile.age = 34
            profile.gender = .female
            profile.heightCm = 168
            profile.weightKg = 61
            if let data = try? JSONEncoder().encode(profile) {
                defaults.set(data, forKey: "userProfile")
            }
        }
        defaults.set(58, forKey: "heartRiskScore")
        defaults.set(true, forKey: "hasCompletedOnboarding")
        PersistenceController.shared.save()
    }

    private static func seedCustomTags() {
        let context = PersistenceController.shared.context
        let tags: [(String, String, String)] = [
            ("Morning coffee", "food", "orange"),
            ("Deep work", "load", "red"),
            ("Evening walk", "readiness", "green")
        ]
        for (name, cluster, color) in tags {
            let tag = CustomTagMO(context: context)
            tag.id = UUID()
            tag.name = name
            tag.cluster = cluster
            tag.colorName = color
            tag.createdAt = Date()
        }
    }

    private static func seedMeasurements() {
        var generator = SeededGenerator(seed: 0xC0FFEE)
        let calendar = Calendar.current
        let now = Date()
        var inserted: [HeartRateMeasurementMO] = []

        for dayOffset in stride(from: 59, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let pulse = 68 + Int.random(in: -7...9, using: &generator)
            let hrv = 58 + Double.random(in: -16...26, using: &generator)
            let sdnn = hrv * Double(1.35 + Double.random(in: 0...0.3, using: &generator))
            let rmssd = hrv * Double(0.9 + Double.random(in: 0...0.2, using: &generator))
            let pnn50 = max(2, min(48, (rmssd - 18) * 0.9 + Double.random(in: -4...4, using: &generator)))
            let stress = max(0, min(100, Int((100 - (sdnn - 20) * 1.15).rounded())))
            let energy = max(30, min(118, Int((log(max(rmssd, 1)) / log(110) * 100).rounded())))
            let health = (log(max(rmssd, 1)) * 100).rounded() / 100
            let csi = max(30, min(620, Int((150 + (100 - rmssd) * 2.8).rounded())))
            let metrics = MeasurementMetrics(
                pulse: pulse,
                hrv: (hrv * 10).rounded() / 10,
                sdnn: (sdnn * 10).rounded() / 10,
                rmssd: (rmssd * 10).rounded() / 10,
                pnn50: (pnn50 * 10).rounded() / 10,
                stress: stress,
                healthIndex: health,
                csi: csi,
                energy: energy
            )
            var time = calendar.date(bySettingHour: 8 + Int.random(in: 0...12, using: &generator),
                                     minute: Int.random(in: 0...59, using: &generator),
                                     second: 0, of: day) ?? day
            if time > now {
                time = now.addingTimeInterval(-Double(Int.random(in: 60...1800, using: &generator)))
            }
            let tag: MeasurementTagSelection
            if dayOffset % 7 == 0 {
                tag = MeasurementTagSelection(tagId: "builtin.sleep.after", isAuto: false)
            } else if dayOffset % 5 == 0 {
                tag = MeasurementTagSelection(tagId: "builtin.relax.before", isAuto: false)
            } else if dayOffset % 3 == 0 {
                tag = MeasurementTagSelection(tagId: "builtin.activity.after", isAuto: false)
            } else if dayOffset % 4 == 0 {
                tag = MeasurementTagSelection(tagId: nil, isAuto: true)
            } else {
                tag = .none
            }
            let measurement = MeasurementService.save(metrics: metrics, tag: tag, createdAt: time)
            if dayOffset % 4 == 0 { measurement.hasReadAIComment = true }
            inserted.append(measurement)
        }

        // Before/after pairs for context achievements and Journey progress.
        if let lastWeek = calendar.date(byAdding: .day, value: -3, to: now) {
            let categories: [(TagGroup, Int, Int)] = [
                (.sleep, 23, 7),
                (.activity, 17, 18),
                (.relax, 12, 13),
                (.stress, 9, 10),
                (.sleep, 22, 6)
            ]
            for (group, beforeHour, afterHour) in categories {
                guard let before = calendar.date(bySettingHour: beforeHour, minute: 0, second: 0, of: lastWeek),
                      let after = calendar.date(bySettingHour: afterHour, minute: 20, second: 0, of: lastWeek) else { continue }
                for (date, timing) in [(before, TagTiming.before), (after, TagTiming.after)] {
                    let metrics = MeasurementMetrics(
                        pulse: 70, hrv: 62, sdnn: 84, rmssd: 55, pnn50: 24,
                        stress: 48, healthIndex: 4.01, csi: 260, energy: 84
                    )
                    _ = MeasurementService.save(
                        metrics: metrics,
                        tag: MeasurementTagSelection(tagId: "builtin.\(group.rawValue).\(timing.rawValue)", isAuto: false),
                        createdAt: date
                    )
                }
            }
        }
    }

    private static func seedWatchMeasurements() {
        var generator = SeededGenerator(seed: 0xBEEF)
        let calendar = Calendar.current
        let now = Date()
        for index in 0..<10 {
            guard let day = calendar.date(byAdding: .day, value: -index * 2, to: now) else { continue }
            let time = calendar.date(bySettingHour: 7, minute: 30, second: 0, of: day) ?? day
            let sdnn = 48 + Double.random(in: -8...24, using: &generator)
            let rmssd = sdnn * 0.72
            let metrics = MeasurementMetrics(
                pulse: 62 + Int.random(in: -4...10, using: &generator),
                hrv: (sdnn * 10).rounded() / 10,
                sdnn: (sdnn * 10).rounded() / 10,
                rmssd: (rmssd * 10).rounded() / 10,
                pnn50: max(2, min(50, (rmssd - 18) * 0.8)),
                stress: max(0, min(100, Int((100 - (sdnn - 20) * 1.2).rounded()))),
                healthIndex: (log(max(rmssd, 1)) * 100).rounded() / 100,
                csi: max(30, min(650, Int((150 + (100 - rmssd) * 2.8).rounded()))),
                energy: max(30, min(118, Int((log(max(rmssd, 1)) / log(110) * 100).rounded())))
            )
            let measurement = MeasurementService.save(
                metrics: metrics,
                tag: MeasurementTagSelection(tagId: "builtin.sleep.after", isAuto: false),
                source: .appleWatch,
                healthKitID: "demo-watch-\(index)",
                createdAt: time
            )
            measurement.hasReadAIComment = index % 3 == 0
        }
    }

    private static func seedLogs() {
        let calendar = Calendar.current
        let now = Date()
        for offset in stride(from: 21, through: 0, by: -3) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            _ = HealthLogService.saveGlucose(value: Double(88 + (offset % 5) * 6), createdAt: day)
            _ = HealthLogService.saveOxygen(value: 96 + (offset % 3), createdAt: day)
            _ = HealthLogService.savePressure(sys: 116 + (offset % 5) * 2, dia: 74 + (offset % 3), createdAt: day)
        }
    }

    private static func seedReminders() {
        let context = PersistenceController.shared.context
        let samples: [(ReminderType, Int)] = [(.pulse, 9), (.pulseCSI, 21), (.glucose, 8)]
        for (type, hour) in samples {
            let reminder = ReminderMO(context: context)
            reminder.id = UUID()
            reminder.type = type.rawValue
            reminder.time = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        }
    }

    private static func seedArticles() {
        let keys = ArticleCatalog.allArticles.prefix(14).map(\.id)
        UserDefaults.standard.set(Array(keys), forKey: "readArticleIDs")
    }

    private static func seedHealthConnection() {
        UserDefaults.standard.set(true, forKey: "appleHealthConnected")
        UserDefaults.standard.set(true, forKey: "appleHealthSyncEnabled")
        UserDefaults.standard.set(Date(), forKey: "appleHealthLastSync")
    }
}
