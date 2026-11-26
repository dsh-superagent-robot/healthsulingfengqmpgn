import SwiftUI

@main
struct HealthSulingfengQmpgnApp: App {
    private let persistence = PersistenceController.shared
    @StateObject private var app = AppModel()
    @StateObject private var store = SubscriptionStore()
    @StateObject private var health = HealthKitService.shared
    @StateObject private var notifications = NotificationService.shared
    @StateObject private var updates = UpdateService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(store)
                .environmentObject(health)
                .environmentObject(notifications)
                .environmentObject(updates)
                .environment(\.managedObjectContext, persistence.context)
                .environment(\.locale, Locale(identifier: "en_US"))
                .preferredColorScheme(app.appearance.colorScheme)
                .tint(AppColors.coral)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task {
                    await store.refreshEntitlements()
                    await notifications.refreshAuthorization()
                    await updates.check()
                }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var updates: UpdateService

    var body: some View {
        Group {
            if app.hasCompletedOnboarding {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: app.hasCompletedOnboarding)
        .overlay(alignment: .top) {
            if let toast = app.toast {
                ToastBanner(message: toast.text)
                    .padding(.top, 8)
                    .zIndex(10)
            }
        }
        .sheet(item: $app.activePaywall) { context in
            PaywallView(context: context)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $app.showMeasurementFlow) {
            MeasurementFlowView(initialTag: app.measurementTag)
        }
        .alert("Time to Update!", isPresented: $updates.isUpdateRequired) {
            Button("Go to App Store") { updates.openStore() }
        } message: {
            Text("A new version of \(Brand.name) is available. Update to keep using the app with the latest health features and fixes.")
        }
        .sheet(item: $app.debugRoute) { route in
            NavigationStack {
                DebugRouteView(route: route)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { app.debugRoute = nil }
                        }
                    }
            }
        }
    }
}

struct DebugRouteView: View {
    let route: DebugRoute

    var body: some View {
        switch route {
        case .journey: JourneyView()
        case .achievements: AchievementsView()
        case .monthly: MonthlyOverviewView()
        case .watch: WatchDataView()
        case .appleHealth: AppleHealthSettingsView()
        case .reminders: RemindersView()
        case .profile: ProfileView()
        case .settings: SettingsView()
        case .history: HistoryView()
        case .csi: CSIDetailView()
        case .heartAge: HeartAgeDetailView()
        case .tags: TagsManagementView()
        case .charts: ChartSettingsView()
        case .article:
            if let article = ArticleCatalog.popular.first {
                ArticleDetailView(article: article)
            } else {
                EmptyStateView(icon: "book", title: "No Articles", message: "")
            }
        case .journeyLevel: JourneyLevelView(levelId: "L01")
        case .glucose: ManualLogView(type: .glucose)
        case .oxygen: ManualLogView(type: .oxygen)
        case .pressure: ManualLogView(type: .pressure)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            TabView(selection: $app.selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tag(0)

                NavigationStack {
                    DashboardView()
                }
                .tag(1)

                NavigationStack {
                    InsightsView()
                }
                .tag(2)

                NavigationStack {
                    MeView()
                }
                .tag(3)
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar()
        }
    }
}

struct CustomTabBar: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore

    private let tabs: [(index: Int, title: String, icon: String)] = [
        (0, "Home", "house.fill"),
        (1, "Dashboard", "square.grid.2x2.fill"),
        (2, "Insights", "book.fill"),
        (3, "Me", "person.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            tabButton(tabs[0])
            tabButton(tabs[1])
            measureButton
            tabButton(tabs[2])
            tabButton(tabs[3])
        }
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(
            AppColors.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(AppColors.separator.opacity(0.7)).frame(height: 0.7)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: (index: Int, title: String, icon: String)) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) { app.selectedTab = tab.index }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundColor(app.selectedTab == tab.index ? AppColors.coral : AppColors.inkSecondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var measureButton: some View {
        Button {
            if app.isMeasurementAllowed(isPremium: store.isPremium) {
                app.openMeasurement()
            } else {
                app.presentPaywall(.measurement)
            }
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(AppColors.heroGradient)
                        .frame(width: 58, height: 58)
                        .shadow(color: AppColors.coral.opacity(0.35), radius: 10, x: 0, y: 5)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
                .offset(y: -14)
                Text("Measure")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.coral)
                    .offset(y: -10)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("measureTabButton")
    }
}
