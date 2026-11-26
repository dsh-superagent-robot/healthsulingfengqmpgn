import SwiftUI
import Combine

enum Brand {
    static let name = "HeartSense"
    static let displayName = "Heart Rate Detection Assistant"
    static let supportEmail = "sulingfeng_dev@163.com"
    static let privacyURL = URL(string: "https://idawear.xyz/xinlvjiancezhushou/privacy.html")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6823553763?action=write-review")!
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum StatsPeriod: String, CaseIterable, Identifiable, Codable {
    case lastMeasurement, day, week, month, quarter, year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lastMeasurement: return "Last measurement"
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }

    var shortLabel: String {
        switch self {
        case .lastMeasurement: return "Last"
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        case .quarter: return "3M"
        case .year: return "Y"
        }
    }

    var days: Int? {
        switch self {
        case .lastMeasurement: return nil
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }

    func interval(now: Date = Date()) -> DateInterval? {
        guard let days else { return nil }
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now
        return DateInterval(start: start, end: now)
    }

    func filter(_ measurements: [HeartRateMeasurementMO], now: Date = Date()) -> [HeartRateMeasurementMO] {
        guard self != .lastMeasurement else {
            return measurements.sorted { $0.createdAt > $1.createdAt }.prefix(1).map { $0 }
        }
        guard let interval = interval(now: now) else { return measurements }
        return measurements.filter { interval.contains($0.createdAt) }
    }

    static let mePeriods: [StatsPeriod] = [.day, .week, .month, .quarter, .year]
}

enum ChartStyle: String, Codable, CaseIterable, Identifiable {
    case bar
    case line
    case barThresholds
    case lineThresholds

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bar: return "Bar"
        case .line: return "Line"
        case .barThresholds: return "Bar + Thresholds"
        case .lineThresholds: return "Line + Thresholds"
        }
    }

    var shortLabel: String {
        switch self {
        case .bar: return "Bar"
        case .line: return "Line"
        case .barThresholds: return "Bar + Thr."
        case .lineThresholds: return "Line + Thr."
        }
    }

    var icon: String { isBar ? "chart.bar.fill" : "chart.xyaxis.line" }
    var isBar: Bool { self == .bar || self == .barThresholds }
    var includesThresholds: Bool { self == .barThresholds || self == .lineThresholds }
}

struct ChartPreferences: Codable, Equatable {
    var style: ChartStyle = .line
    var defaultRange: StatsPeriod = .week
    var showThresholds: Bool = true
    var showTrendLine: Bool = true
    var perMetric: [String: ChartStyle] = [:]

    func style(for metric: String) -> ChartStyle {
        perMetric[metric] ?? style
    }
}

enum Gender: String, Codable, CaseIterable, Identifiable {
    case notSet, male, female

    var id: String { rawValue }
    var label: String {
        switch self {
        case .notSet: return "Not Set"
        case .male: return "Male"
        case .female: return "Female"
        }
    }
    var icon: String {
        switch self {
        case .notSet: return "person.fill.questionmark"
        case .male: return "figure.stand"
        case .female: return "figure.stand.dress"
        }
    }
}

struct UserProfile: Codable, Equatable {
    var name: String = ""
    var secondName: String = ""
    var age: Int?
    var gender: Gender = .notSet
    var heightCm: Double?
    var weightKg: Double?
    var avatarData: Data?

    var displayName: String {
        let full = [name, secondName].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return full.isEmpty ? "Friend" : full.joined(separator: " ")
    }

    var bmi: Double? {
        guard let heightCm, let weightKg, heightCm > 0 else { return nil }
        return weightKg / pow(heightCm / 100, 2)
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

enum PaywallContext: String, Identifiable, CaseIterable {
    case onboarding
    case measurement
    case journey
    case monthlyOverview
    case insights
    case settings

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .onboarding: return "Unlock your heart's full story"
        case .measurement: return "Unlimited measurements are waiting"
        case .journey: return "Continue your Journey with Pro"
        case .monthlyOverview: return "See the full monthly picture"
        case .insights: return "Go deeper with Premium insights"
        case .settings: return "Unlock all features"
        }
    }

    var featureFocus: String {
        switch self {
        case .measurement: return "Unlimited Measuring"
        case .journey: return "Pro Journey Tasks"
        case .monthlyOverview: return "Monthly Insights"
        case .insights: return "Advanced Analytics"
        default: return "All Features"
        }
    }
}

final class AppModel: ObservableObject {
    private enum Key {
        static let onboarding = "hasCompletedOnboarding"
        static let cameraTutorial = "didShowCameraTutorial"
        static let appearance = "appearanceMode"
        static let profile = "userProfile"
        static let chartPreferences = "chartPreferences"
        static let readArticles = "readArticleIDs"
        static let riskScore = "heartRiskScore"
        static let lastTab = "lastSelectedTab"
    }

    private let defaults: UserDefaults

    @Published var selectedTab: Int {
        didSet { defaults.set(selectedTab, forKey: Key.lastTab) }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.onboarding) }
    }
    @Published var didShowCameraTutorial: Bool {
        didSet { defaults.set(didShowCameraTutorial, forKey: Key.cameraTutorial) }
    }
    @Published var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
    }
    @Published var profile: UserProfile {
        didSet { saveProfile() }
    }
    @Published var chartPreferences: ChartPreferences {
        didSet { saveChartPreferences() }
    }
    @Published var readArticleIDs: Set<String> {
        didSet { defaults.set(Array(readArticleIDs), forKey: Key.readArticles) }
    }
    @Published var riskScore: Int? {
        didSet { defaults.set(riskScore, forKey: Key.riskScore) }
    }

    @Published var showMeasurementFlow = false
    @Published var measurementTag: MeasurementTagSelection = .none
    @Published var activePaywall: PaywallContext?
    @Published var toast: ToastMessage?
    @Published var showingHistory = false
    @Published var historyFilterTagID: String?
    @Published var debugRoute: DebugRoute?

    private var toastTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-DSHResetOnboarding") {
            defaults.removeObject(forKey: Key.onboarding)
            defaults.removeObject(forKey: Key.cameraTutorial)
        }
        if args.contains("-DSHDemoData") {
            DemoData.seedIfNeeded()
        }
        selectedTab = defaults.object(forKey: Key.lastTab) as? Int ?? 0
        if let index = args.firstIndex(of: "-DSHTab"), args.indices.contains(index + 1), let tab = Int(args[index + 1]) {
            selectedTab = tab
        }
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarding)
        didShowCameraTutorial = defaults.bool(forKey: Key.cameraTutorial)
        appearance = AppearanceMode(rawValue: defaults.string(forKey: Key.appearance) ?? "system") ?? .system
        if let data = defaults.data(forKey: Key.profile),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data) {
            profile = decoded
        } else {
            profile = UserProfile()
        }
        if let data = defaults.data(forKey: Key.chartPreferences),
           let decoded = try? JSONDecoder().decode(ChartPreferences.self, from: data) {
            chartPreferences = decoded
        } else {
            chartPreferences = ChartPreferences()
        }
        readArticleIDs = Set(defaults.stringArray(forKey: Key.readArticles) ?? [])
        riskScore = defaults.object(forKey: Key.riskScore) as? Int

        if args.contains("-DSHOnboarding") {
            hasCompletedOnboarding = false
        } else if args.contains("-DSHDemoData") {
            hasCompletedOnboarding = true
        }
        if args.contains("-DSHSkipCameraTutorial") {
            didShowCameraTutorial = true
        }
        if args.contains("-DSHShowMeasurement") || args.contains("-DSHAutoMeasure") {
            showMeasurementFlow = true
        }
        if args.contains("-DSHShowPaywall") {
            activePaywall = .onboarding
        }
        if let index = args.firstIndex(of: "-DSHRoute"), args.indices.contains(index + 1) {
            debugRoute = DebugRoute(rawValue: args[index + 1])
        }
        if let index = args.firstIndex(of: "-DSHSetIcon"), args.indices.contains(index + 1) {
            let value = args[index + 1]
            let identifier = value == "default" ? nil : "AppIcon-v\(value)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                UIApplication.shared.setAlternateIconName(identifier) { error in
                    DispatchQueue.main.async {
                        if let error {
                            self?.showToast("Icon error: \(error.localizedDescription)")
                        } else {
                            self?.showToast("App icon updated")
                        }
                    }
                }
            }
        }
    }

    // MARK: Profile and preferences

    private func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: Key.profile)
    }

    private func saveChartPreferences() {
        guard let data = try? JSONEncoder().encode(chartPreferences) else { return }
        defaults.set(data, forKey: Key.chartPreferences)
    }

    func resetChartPreferences() {
        chartPreferences = ChartPreferences()
    }

    // MARK: Navigation and presentation

    func openMeasurement(tag: MeasurementTagSelection = .none) {
        measurementTag = tag
        showMeasurementFlow = true
    }

    func presentPaywall(_ context: PaywallContext) {
        activePaywall = context
    }

    func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            toast = ToastMessage(text: text)
        }
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self?.toast = nil
            }
        }
    }

    // MARK: Articles

    func isArticleRead(_ key: String) -> Bool {
        readArticleIDs.contains(key)
    }

    func markArticleRead(_ key: String) {
        readArticleIDs.insert(key)
    }

    // MARK: Measurement allowance

    /// Free members receive three measurements per day. Premium is unlimited.
    /// The quota is intentionally generous enough to experience the full flow.
    var freeMeasurementsUsedToday: Int {
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = NSPredicate(format: "createdAt >= %@ AND source == %@", start as NSDate, MeasurementSource.inApp.rawValue)
        return PersistenceController.shared.count(HeartRateMeasurementMO.self, predicate: predicate)
    }

    var freeMeasurementsRemaining: Int {
        max(0, 3 - freeMeasurementsUsedToday)
    }

    func isMeasurementAllowed(isPremium: Bool) -> Bool {
        isPremium || freeMeasurementsRemaining > 0
    }

    // MARK: Lifecycle helpers

    func completeOnboarding() {
        hasCompletedOnboarding = true
        selectedTab = 0
    }
}

enum DebugRoute: String, Identifiable {
    case journey, achievements, monthly, watch, appleHealth, reminders, profile, settings, history, csi, heartAge, tags, charts, article, journeyLevel, glucose, oxygen, pressure

    var id: String { rawValue }
}
