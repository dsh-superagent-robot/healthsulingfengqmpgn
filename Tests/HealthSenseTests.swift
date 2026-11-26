import XCTest
@testable import healthsulingfengqmpgn

final class HealthSenseCatalogTests: XCTestCase {
    func testArticleCatalogMatchesProductSpecification() {
        XCTAssertEqual(ArticleCatalog.categories.count, 10)
        XCTAssertEqual(ArticleCatalog.allArticles.count, 83)
        XCTAssertEqual(ArticleCatalog.category("hrv.basics")?.articles.count, 5)
        XCTAssertEqual(ArticleCatalog.category("hrv.explained")?.articles.count, 7)
        XCTAssertEqual(ArticleCatalog.category("hrv.context")?.articles.count, 6)
        XCTAssertEqual(ArticleCatalog.category("ppg.explained")?.articles.count, 5)
        XCTAssertEqual(ArticleCatalog.category("ecg")?.articles.count, 10)
        XCTAssertEqual(ArticleCatalog.category("arrhythmia")?.articles.count, 10)
        XCTAssertEqual(ArticleCatalog.category("heartattack")?.articles.count, 10)
        XCTAssertEqual(ArticleCatalog.category("sleep")?.articles.count, 10)
        XCTAssertEqual(ArticleCatalog.category("stress")?.articles.count, 10)
        XCTAssertEqual(ArticleCatalog.category("activity")?.articles.count, 10)
        XCTAssertEqual(ArticleCatalog.categories.filter { $0.layout == .horizontal }.count, 3)
        for article in ArticleCatalog.allArticles {
            let pages = ArticleCatalog.pages(for: article)
            XCTAssertEqual(pages.count, article.pageCount)
            XCTAssertFalse(pages.isEmpty)
            XCTAssertTrue(pages.allSatisfy { !$0.title.isEmpty && !$0.lead.isEmpty && !$0.body.isEmpty })
        }
    }

    func testJourneyHasTwelveChaptersAndOneHundredLevels() {
        XCTAssertEqual(JourneyCatalog.chapters.count, 12)
        XCTAssertEqual(JourneyCatalog.levels.count, 100)
        let expectedChapterCounts = [3, 5, 6, 5, 10, 10, 10, 10, 10, 10, 10, 11]
        XCTAssertEqual(JourneyCatalog.chapters.map { $0.levels.count }, expectedChapterCounts)
        XCTAssertEqual(JourneyCatalog.levels.reduce(0) { $0 + $1.tasks.count }, 500)
        for level in JourneyCatalog.levels {
            XCTAssertEqual(level.tasks.count, 5, level.id)
            XCTAssertEqual(level.tasks.filter { $0.type == .core }.count, 3, level.id)
            XCTAssertEqual(level.tasks.filter { $0.type == .optional }.count, 1, level.id)
            XCTAssertEqual(level.tasks.filter { $0.type == .pro }.count, 1, level.id)
        }
    }

    func testJourneyArticleReferencesResolve() {
        for level in JourneyCatalog.levels {
            for task in level.tasks where task.category == "read_article" {
                XCTAssertNotNil(ArticleCatalog.article(forReference: task.referenceId ?? ""))
            }
        }
    }

    func testAchievementCatalogMatchesSpecification() {
        XCTAssertEqual(AchievementCatalog.all.count, 21)
        XCTAssertEqual(AchievementCategory.allCases.count, 5)
        for achievement in AchievementCatalog.all {
            XCTAssertFalse(achievement.tiers.isEmpty)
            XCTAssertFalse(achievement.rewardTitle.isEmpty)
            XCTAssertEqual(achievement.tiers.map(\.target), achievement.tiers.map(\.target).sorted())
        }
        XCTAssertEqual(AchievementCatalog.achievement("achv_measure_volume")?.tiers.last?.target, 1500)
        XCTAssertEqual(AchievementCatalog.achievement("achv_measure_volume")?.tiers.last?.ribbon, .purple)
        XCTAssertEqual(AchievementCatalog.achievement("achv_setup_health")?.tiers.count, 1)
    }

    func testMetricThresholds() {
        XCTAssertEqual(MetricInsights.insight(for: .hrv, value: 120).status, "High")
        XCTAssertEqual(MetricInsights.insight(for: .hrv, value: 75).status, "Normal")
        XCTAssertEqual(MetricInsights.insight(for: .hrv, value: 40).status, "Low")
        XCTAssertEqual(MetricInsights.insight(for: .rmssd, value: 90).status, "Excellent")
        XCTAssertEqual(MetricInsights.insight(for: .rmssd, value: 15).status, "Very Low")
        XCTAssertEqual(MetricInsights.insight(for: .pnn50, value: 35).status, "Excellent")
        XCTAssertEqual(MetricInsights.insight(for: .pulse, value: 130).status, "Very High")
        XCTAssertEqual(MetricInsights.insight(for: .pulse, value: 55).status, "Low")
        XCTAssertEqual(MetricInsights.insight(for: .stress, value: 85).status, "Very High")
        XCTAssertEqual(MetricInsights.insight(for: .stress, value: 10).status, "Relaxed")
        XCTAssertEqual(MetricInsights.insight(for: .energy, value: 55).status, "Low")
        XCTAssertEqual(MetricInsights.insight(for: .healthIndex, value: 6.8).status, "Athlete")
        XCTAssertEqual(MetricInsights.insight(for: .csi, value: 550).status, "Very High")
        XCTAssertEqual(MetricInsights.insight(for: .oxygen, value: 85).status, "Very Low")
        XCTAssertEqual(MetricInsights.insight(for: .glucoseBefore, value: 130).status, "High")
        XCTAssertEqual(MetricInsights.insight(for: .glucoseAfter, value: 250).status, "High")
        XCTAssertEqual(MetricInsights.bloodPressureInsight(sys: 150, dia: 95).status, "Very High")
        XCTAssertEqual(MetricInsights.bloodPressureInsight(sys: 115, dia: 75).status, "Normal")
    }

    func testHeartAgeModelRespondsToRMSSD() {
        let younger = HeartAgeEngine.estimate(rmssd: 90, age: 40, gender: .male)
        let older = HeartAgeEngine.estimate(rmssd: 25, age: 40, gender: .male)
        XCTAssertLessThan(younger, older)
        XCTAssertGreaterThanOrEqual(younger, 18)
        XCTAssertLessThanOrEqual(older, 95)
    }

    func testSimulatedMetricsArePlausible() {
        let metrics = PPGProcessor.fallbackMetrics(mode: .fast, seed: 42)
        XCTAssertTrue((35...200).contains(metrics.pulse))
        XCTAssertTrue((1...150).contains(metrics.rmssd))
        XCTAssertTrue((0...100).contains(metrics.pnn50))
        XCTAssertTrue((0...100).contains(metrics.stress))
        XCTAssertTrue((0...120).contains(metrics.energy))
        XCTAssertTrue((0...700).contains(metrics.csi))
    }

    func testBuiltInTagCatalog() {
        XCTAssertEqual(TagCatalog.builtIns.count, 11)
        XCTAssertEqual(TagGroup.sleep.timings.count, 2)
        XCTAssertEqual(TagGroup.stress.timings.count, 3)
        XCTAssertEqual(TagCatalog.builtIns.filter { $0.group == .stress }.count, 3)
        XCTAssertEqual(TagCatalog.autoTag(for: Date(timeIntervalSince1970: 0)).isCustom, false)
    }

    func testChartPreferencesCodable() {
        var preferences = ChartPreferences()
        preferences.style = .barThresholds
        preferences.defaultRange = .month
        preferences.perMetric["hrv"] = .line
        let data = try! JSONEncoder().encode(preferences)
        let decoded = try! JSONDecoder().decode(ChartPreferences.self, from: data)
        XCTAssertEqual(decoded, preferences)
        XCTAssertEqual(decoded.style(for: "hrv"), .line)
        XCTAssertEqual(decoded.style(for: "pulse"), .barThresholds)
        XCTAssertTrue(decoded.style(for: "pulse").includesThresholds)
    }
}
