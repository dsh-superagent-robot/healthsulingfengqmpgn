import SwiftUI
import CoreData

struct JourneyView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>

    @State private var popup: JourneyPopup?

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var states: [JourneyLevelState] {
        JourneyEngine.levelStates(snapshot: snapshot)
    }

    private var currentLevel: JourneyLevelState? {
        JourneyEngine.currentLevel(states: states)
    }

    private var completedLevels: Int {
        states.filter { $0.isCompleted && !$0.isLocked }.count
    }

    private var currentChapter: JourneyChapterDefinition? {
        currentLevel.flatMap { JourneyCatalog.chapter($0.definition.chapterId) }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    PremiumBanner(
                        title: "Unlock Pro Journey Tasks",
                        subtitle: "Go further with every chapter",
                        context: .journey
                    )
                    chapters
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("My Journey")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $popup) { popup in
            Alert(title: Text(popup.title), message: Text(popup.message), dismissButton: .default(Text("Continue")))
        }
        .onAppear {
            JourneyEngine.persist(states: states)
            checkProgress(announce: false)
        }
        .onChange(of: app.showMeasurementFlow) { showing in
            if !showing {
                JourneyEngine.persist(states: states)
                checkProgress(announce: true)
            }
        }
        .onChange(of: app.readArticleIDs) { _ in
            JourneyEngine.persist(states: states)
            checkProgress(announce: true)
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("YOUR JOURNEY")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.4)
                        .foregroundColor(.white.opacity(0.5))
                    Text(currentChapter?.title ?? "Heart Mastery")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("\(completedLevels) of \(JourneyCatalog.levelCount) levels complete")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 7)
                        .frame(width: 64, height: 64)
                    Circle()
                        .trim(from: 0, to: Double(completedLevels) / Double(JourneyCatalog.levelCount))
                        .stroke(AppColors.teal, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(Double(completedLevels) / Double(JourneyCatalog.levelCount) * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            if let currentLevel {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Current · \(currentLevel.definition.id)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(currentLevel.completedCoreCount)/\(currentLevel.coreTasks.count) core")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    ProgressView(value: currentLevel.progress)
                        .tint(AppColors.teal)
                    ForEach(currentLevel.coreTasks) { task in
                        HStack(spacing: 7) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11))
                                .foregroundColor(task.isCompleted ? AppColors.teal : .white.opacity(0.4))
                            Text(task.definition.requirementTitle)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                            Spacer()
                            Text("\(task.currentValue)/\(task.target)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(13)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                NavigationLink {
                    JourneyLevelView(levelId: currentLevel.definition.id)
                } label: {
                    Text("Continue \(currentLevel.definition.id)")
                }
                .buttonStyle(PrimaryButtonStyle(tint: AppColors.teal))
            }
        }
        .padding(18)
        .background(
            LinearGradient(colors: [Color(hex: 0x29231F), Color(hex: 0x161412)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    private var chapters: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters")
                .sectionTitle()
            VStack(spacing: 10) {
                ForEach(JourneyCatalog.chapters) { chapter in
                    let chapterStates = states.filter { $0.definition.chapterId == chapter.id }
                    let completed = chapterStates.filter { $0.isCompleted && !$0.isLocked }.count
                    let unlocked = chapterStates.contains { !$0.isLocked }
                    NavigationLink {
                        JourneyChapterView(chapterId: chapter.id)
                    } label: {
                        HStack(spacing: 13) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(unlocked ? AppColors.teal.opacity(0.13) : AppColors.surfaceMuted)
                                    .frame(width: 50, height: 50)
                                Image(systemName: chapter.icon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(unlocked ? AppColors.teal : AppColors.inkSecondary.opacity(0.5))
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text("Chapter \(chapter.index)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppColors.inkSecondary)
                                    if completed == chapter.levels.count {
                                        PillLabel(text: "Completed", tint: AppColors.success)
                                    } else if unlocked {
                                        PillLabel(text: "Current", tint: AppColors.coral)
                                    }
                                }
                                Text(chapter.title)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.ink)
                                Text("Levels: \(completed)/\(chapter.levels.count)")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppColors.inkSecondary)
                            }
                            Spacer()
                            if !unlocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppColors.inkSecondary.opacity(0.45))
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.inkSecondary.opacity(0.5))
                            }
                        }
                        .padding(14)
                        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func checkProgress(announce: Bool) {
        guard let currentLevel else { return }
        let key = "journeyLastCurrentLevel"
        let previous = UserDefaults.standard.string(forKey: key)
        if let previous, previous != currentLevel.definition.id, announce {
            let oldChapter = JourneyCatalog.level(previous)?.chapterId
            let newChapter = currentLevel.definition.chapterId
            if oldChapter != newChapter {
                let chapter = JourneyCatalog.chapter(newChapter)
                popup = JourneyPopup(
                    title: "New Chapter Unlocked",
                    message: "Chapter \(chapter?.index ?? 0) · \(chapter?.title ?? "")"
                )
            } else {
                popup = JourneyPopup(
                    title: "Congratulations!",
                    message: "Level \(currentLevel.definition.id) Unlocked!"
                )
            }
        }
        UserDefaults.standard.set(currentLevel.definition.id, forKey: key)
    }
}

struct JourneyPopup: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct JourneyChapterView: View {
    let chapterId: String
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var chapter: JourneyChapterDefinition? { JourneyCatalog.chapter(chapterId) }
    private var states: [JourneyLevelState] { JourneyEngine.levelStates(snapshot: snapshot) }
    private var chapterStates: [JourneyLevelState] {
        states.filter { $0.definition.chapterId == chapterId }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                if let chapter {
                    VStack(alignment: .leading, spacing: 16) {
                        header(chapter)
                        VStack(spacing: 10) {
                            ForEach(chapterStates) { state in
                                levelRow(state)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle(chapter.map { "Chapter \($0.index)" } ?? "Chapter")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { JourneyEngine.persist(states: states) }
    }

    private func header(_ chapter: JourneyChapterDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: chapter.icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(AppColors.teal)
                .frame(width: 66, height: 66)
                .background(AppColors.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            Text(chapter.title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(chapter.subtitle)
                .font(.system(size: 14))
                .foregroundColor(AppColors.inkSecondary)
            let completed = chapterStates.filter { $0.isCompleted && !$0.isLocked }.count
            Text("\(Int(Double(completed) / Double(max(chapter.levels.count, 1)) * 100))% Completed · Levels: \(completed)/\(chapter.levels.count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.teal)
        }
    }

    private func levelRow(_ state: JourneyLevelState) -> some View {
        Group {
            if state.isLocked {
                Button {
                    app.showToast("Finish your current level to unlock the next one")
                } label: {
                    levelCard(state)
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    JourneyLevelView(levelId: state.definition.id)
                } label: {
                    levelCard(state)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func levelCard(_ state: JourneyLevelState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(state.isCompleted ? AppColors.success.opacity(0.13) :
                            state.isLocked ? AppColors.surfaceMuted : AppColors.coral.opacity(0.12))
                    .frame(width: 42, height: 42)
                if state.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppColors.success)
                } else if state.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.inkSecondary.opacity(0.5))
                } else {
                    Text("\(state.definition.number)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.coral)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Level \(state.definition.number)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text("Tasks: \(state.completedTaskCount) / \(state.tasks.count)")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
                ProgressView(value: state.progress)
                    .tint(state.isCompleted ? AppColors.success : AppColors.coral)
            }
            Spacer()
            Text("\(Int(state.progress * 100))%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(state.isCompleted ? AppColors.success : AppColors.inkSecondary)
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .opacity(state.isLocked ? 0.6 : 1)
    }
}

struct JourneyLevelView: View {
    let levelId: String

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>

    @State private var selectedArticle: ArticleDefinition?
    @State private var showAppleHealth = false
    @State private var popup: JourneyPopup?

    private var snapshot: DataSnapshot {
        DataSnapshot(
            measurements: Array(measurements),
            articlesRead: app.readArticleIDs,
            appleHealthConnected: health.isAuthorized,
            customTags: Array(customTags)
        )
    }

    private var states: [JourneyLevelState] { JourneyEngine.levelStates(snapshot: snapshot) }
    private var state: JourneyLevelState? { states.first { $0.definition.id == levelId } }
    private var level: JourneyLevelDefinition? { JourneyCatalog.level(levelId) }
    private var chapter: JourneyChapterDefinition? {
        level.flatMap { JourneyCatalog.chapter($0.chapterId) }
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                if let state, let level, let chapter {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Chapter \(chapter.index) · \(chapter.title)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(AppColors.teal)
                            Text("Level \(level.number)")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.ink)
                            Text("\(state.completedTaskCount) of \(state.tasks.count) tasks complete")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.inkSecondary)
                            ProgressView(value: state.progress)
                                .tint(AppColors.teal)
                                .padding(.top, 4)
                        }

                        if state.isCompleted {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(AppColors.success)
                                Text("Level complete — the next level is unlocked.")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppColors.ink)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        taskSection(title: "Main", subtitle: "Required to finish this level", tasks: state.coreTasks)
                        taskSection(title: "Optional", subtitle: "Extra credit for your practice", tasks: state.optionalTasks)
                        taskSection(title: "Pro", subtitle: "Included with Premium", tasks: state.proTasks)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                } else {
                    EmptyStateView(icon: "map", title: "Level unavailable", message: "This level could not be found.")
                }
            }
        }
        .navigationTitle(levelId)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedArticle) { article in
            NavigationStack {
                ArticleDetailView(article: article)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { selectedArticle = nil }
                        }
                    }
            }
        }
        .navigationDestination(isPresented: $showAppleHealth) {
            AppleHealthSettingsView()
        }
        .alert(item: $popup) { popup in
            Alert(title: Text(popup.title), message: Text(popup.message), dismissButton: .default(Text("Continue")))
        }
        .onAppear { JourneyEngine.persist(states: states) }
        .onChange(of: app.showMeasurementFlow) { showing in
            if !showing {
                JourneyEngine.persist(states: states)
                checkLevelUp(announce: true)
            }
        }
        .onChange(of: app.readArticleIDs) { _ in
            JourneyEngine.persist(states: states)
            checkLevelUp(announce: true)
        }
    }

    private func taskSection(title: String, subtitle: String, tasks: [JourneyTaskState]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .sectionTitle()
                Spacer()
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(task)
                    if index < tasks.count - 1 { DividerLine() }
                }
            }
            .padding(.horizontal, 14)
            .cardStyle(padding: 0)
        }
    }

    private func taskRow(_ task: JourneyTaskState) -> some View {
        let isProLocked = task.definition.type == .pro && !store.isPremium
        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : task.definition.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(task.isCompleted ? AppColors.success : (isProLocked ? AppColors.gold : AppColors.teal))
                    .frame(width: 28, height: 28)
                    .background(
                        (task.isCompleted ? AppColors.success : AppColors.teal).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.definition.requirementTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.ink)
                    HStack(spacing: 6) {
                        Text("\(task.currentValue) / \(task.target)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.inkSecondary)
                        if isProLocked {
                            PillLabel(text: "PRO", tint: AppColors.gold)
                        }
                    }
                }
                Spacer()
                if task.isCompleted {
                    Text("Done")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppColors.success)
                }
            }
            if !task.isCompleted {
                ProgressView(value: task.progress)
                    .tint(isProLocked ? AppColors.gold : AppColors.teal)
                if isProLocked {
                    Button {
                        app.presentPaywall(.journey)
                    } label: {
                        Text("Unlock with Pro")
                    }
                    .buttonStyle(PrimaryButtonStyle(tint: AppColors.gold))
                } else {
                    taskAction(task)
                }
            }
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func taskAction(_ task: JourneyTaskState) -> some View {
        switch task.definition.category {
        case "read_article":
            Button {
                let key = (task.definition.referenceId ?? "").replacingOccurrences(of: ".title", with: "")
                selectedArticle = ArticleCatalog.article(forReference: key)
            } label: {
                Text("Read Article")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.teal)
            }
            .buttonStyle(.plain)
        case "apple_health":
            Button {
                showAppleHealth = true
            } label: {
                Text("Go to Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.teal)
            }
            .buttonStyle(.plain)
        default:
            Button {
                startMeasurement(for: task.definition)
            } label: {
                Text("Take Measurement")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.coral)
            }
            .buttonStyle(.plain)
        }
    }

    private func startMeasurement(for task: JourneyTaskDefinition) {
        if !app.isMeasurementAllowed(isPremium: store.isPremium) {
            app.presentPaywall(.measurement)
            return
        }
        let tag = preselectedTag(for: task)
        app.openMeasurement(tag: tag)
    }

    private func preselectedTag(for task: JourneyTaskDefinition) -> MeasurementTagSelection {
        let mapping: [String: String] = [
            "sleep_before": "builtin.sleep.before",
            "sleep_after": "builtin.sleep.after",
            "exersice_before": "builtin.activity.before",
            "exersice_after": "builtin.activity.after",
            "meditate_before_vol": "builtin.relax.before",
            "meditate_after_vol": "builtin.relax.after",
            "stress_before": "builtin.stress.before",
            "stress_during": "builtin.stress.during",
            "stress_after": "builtin.stress.after"
        ]
        if let id = mapping[task.category] {
            return MeasurementTagSelection(tagId: id, isAuto: false)
        }
        if task.category == "any_activity_vol" {
            return MeasurementTagSelection(tagId: nil, isAuto: true)
        }
        return .none
    }

    private func checkLevelUp(announce: Bool) {
        guard announce, let current = JourneyEngine.currentLevel(states: states) else { return }
        let key = "journeyLastCurrentLevel"
        let previous = UserDefaults.standard.string(forKey: key)
        if let previous, previous != current.definition.id {
            popup = JourneyPopup(
                title: "Congratulations!",
                message: "Level \(current.definition.id) Unlocked!"
            )
        }
        UserDefaults.standard.set(current.definition.id, forKey: key)
    }
}
