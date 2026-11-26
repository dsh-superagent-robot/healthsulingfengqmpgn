import SwiftUI
import CoreData

struct MeasurementFlowView: View {
    private enum Step: Equatable {
        case setup
        case tutorial
        case measuring
        case result
        case permissionDenied
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService

    @StateObject private var session = MeasurementSession()

    let initialTag: MeasurementTagSelection

    @State private var step: Step = .setup
    @State private var tag: MeasurementTagSelection = .none
    @State private var mode: MeasurementMode = .standard
    @State private var savedMeasurement: HeartRateMeasurementMO?
    @State private var showTagPicker = false
    @State private var showCancelAlert = false
    @State private var showDeleteAlert = false
    @State private var showRetakeAlert = false
    @State private var didSave = false
    @State private var aiExpanded = true
    @State private var errorMessage: String?
    @State private var didAutoStart = false
    @State private var showTrends = false

    init(initialTag: MeasurementTagSelection) {
        self.initialTag = initialTag
        _tag = State(initialValue: initialTag)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            switch step {
            case .setup:
                setupView
            case .tutorial:
                CameraTutorialView(
                    onAllow: {
                        app.didShowCameraTutorial = true
                        startMeasurement()
                    },
                    onClose: { dismiss() }
                )
            case .measuring:
                measuringView
            case .result:
                if let savedMeasurement {
                    MeasurementResultView(
                        measurement: savedMeasurement,
                        aiExpanded: $aiExpanded,
                        onContinue: { finishFlow() },
                        onRetake: { showRetakeAlert = true },
                        onDelete: { showDeleteAlert = true },
                        onTrends: { showTrends = true }
                    )
                } else {
                    ProgressView()
                }
            case .permissionDenied:
                permissionDeniedView
            }
        }
        .sheet(isPresented: $showTagPicker) {
            TagSelectionView(selection: $tag, mode: .measurement)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showTrends) {
            NavigationStack {
                TrendsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showTrends = false }
                        }
                    }
            }
        }
        .alert("Cancel measurement?", isPresented: $showCancelAlert) {
            Button("Keep Measuring", role: .cancel) {}
            Button("Cancel", role: .destructive) {
                session.cancel()
                dismiss()
            }
        } message: {
            Text("Your progress will be lost.")
        }
        .alert("Delete this measurement and take a new one?", isPresented: $showRetakeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete & Retake", role: .destructive) {
                if let savedMeasurement { MeasurementService.delete(savedMeasurement) }
                savedMeasurement = nil
                didSave = false
                startMeasurement()
            }
        }
        .alert("Are you sure you want to delete this measurement?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let savedMeasurement { MeasurementService.delete(savedMeasurement) }
                dismiss()
            }
        }
        .alert("Measurement unavailable", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("Try Again") {
                errorMessage = nil
                startMeasurement()
            }
            Button("Cancel", role: .cancel) { errorMessage = nil; step = .setup }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: session.stage) { stage in
            switch stage {
            case .finished:
                saveIfNeeded()
            case .permissionDenied:
                step = .permissionDenied
            case .failed(let message):
                errorMessage = message
            default:
                break
            }
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-DSHAutoMeasure"), !didAutoStart {
                didAutoStart = true
                mode = .fast
                app.didShowCameraTutorial = true
                startMeasurement()
            }
        }
        .onDisappear {
            session.cancel()
        }
    }

    // MARK: Setup

    private var setupView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(AppColors.surfaceMuted, in: Circle())
                }
                Spacer()
                Text("New Measurement")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.inkSecondary)
                Spacer()
                Color.clear.frame(width: 34, height: 34)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(spacing: 22) {
                    ZStack {
                        Circle().fill(AppColors.coral.opacity(0.08)).frame(width: 210, height: 210)
                        Circle().stroke(AppColors.coral.opacity(0.16), lineWidth: 1).frame(width: 168, height: 168)
                        Circle().fill(AppColors.coral.opacity(0.12)).frame(width: 118, height: 118)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(AppColors.heroGradient)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 7) {
                        Text("Ready when you are")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        Text("Find a quiet moment, rest your finger lightly over the camera and breathe normally.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    VStack(spacing: 0) {
                        Button {
                            showTagPicker = true
                        } label: {
                            InfoRow(
                                icon: tag.isAuto ? "wand.and.stars" : "tag.fill",
                                title: "Context tag",
                                value: tag.displayName,
                                tint: AppColors.periwinkle,
                                showChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Measurement mode")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        HStack(spacing: 8) {
                            ForEach(MeasurementMode.allCases) { candidate in
                                Button {
                                    withAnimation(.easeOut(duration: 0.18)) { mode = candidate }
                                } label: {
                                    VStack(spacing: 5) {
                                        Text(candidate.label)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                        Text("\(Int(candidate.measuringSeconds))s")
                                            .font(.system(size: 11))
                                    }
                                    .foregroundColor(mode == candidate ? .white : AppColors.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(mode == candidate ? AppColors.coral : AppColors.surfaceMuted)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("mode_\(candidate.rawValue)")
                            }
                        }
                        Text(mode.summary)
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkSecondary)
                    }
                    .padding(16)
                    .cardStyle()

                    if session.isSimulated || !CameraPPGSensor.hasCamera {
                        HStack(spacing: 8) {
                            Image(systemName: "desktopcomputer")
                            Text("Camera is unavailable in this simulator; a realistic demo sensor will be used.")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.inkSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(AppColors.gold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Tip")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.ink)
                            Text("Don't press too hard. Keep your hand relaxed and your breathing steady.")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.inkSecondary)
                        }
                    }
                    .padding(14)
                    .background(AppColors.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Button("Start Measurement") {
                if !app.isMeasurementAllowed(isPremium: store.isPremium) {
                    app.presentPaywall(.measurement)
                } else if app.didShowCameraTutorial {
                    startMeasurement()
                } else {
                    step = .tutorial
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            .accessibilityIdentifier("startMeasurementButton")
        }
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundColor(AppColors.inkSecondary)
                .frame(width: 108, height: 108)
                .background(AppColors.surfaceMuted, in: Circle())
            Text("No Access to Camera")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("Enable camera access to measure your heart rate.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Button("Go to Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            Button("Not Now") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
                .padding(.bottom, 24)
        }
    }

    private func startMeasurement() {
        step = .measuring
        didSave = false
        savedMeasurement = nil
        aiExpanded = true
        session.start(mode: mode)
    }

    private func saveIfNeeded() {
        guard !didSave, let metrics = session.result else { return }
        let measurement = MeasurementService.save(metrics: metrics, tag: tag)
        savedMeasurement = measurement
        didSave = true
        step = .result
        if health.isAuthorized && health.enabled {
            Task { await health.writeSDNN(metrics.sdnn) }
        }
    }

    private func finishFlow() {
        dismiss()
    }

    // MARK: Measuring

    private var measuringView: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x171513), Color(hex: 0x2A211E)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button {
                        showCancelAlert = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.1), in: Circle())
                    }
                    Spacer()
                    Text(session.isSimulated ? "DEMO SENSOR" : "CAMERA PPG")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundColor(.white.opacity(0.45))
                    Spacer()
                    Color.clear.frame(width: 34, height: 34)
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)

                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 14)
                        .frame(width: 280, height: 280)
                    Circle()
                        .trim(from: 0, to: max(0.01, session.progress))
                        .stroke(
                            AngularGradient(colors: [AppColors.coral, Color(hex: 0xF2A65A), AppColors.coral],
                                            center: .center),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 280, height: 280)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.12), value: session.progress)
                    Circle()
                        .fill(AppColors.coral.opacity(0.13))
                        .frame(width: 210, height: 210)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 74))
                        .foregroundStyle(
                            LinearGradient(colors: [Color(hex: 0xF58B84), AppColors.coral],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .scaleEffect(session.stage == .measuring ? 1.06 : 0.96)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                   value: session.stage)
                    VStack(spacing: 2) {
                        if let bpm = session.liveBPM {
                            Text("\(bpm)")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("bpm")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .offset(y: 128)
                }

                VStack(spacing: 10) {
                    Text(session.stage == .calibrating ? "Calibrating" : "Measuring")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(session.stage == .calibrating
                         ? "Finding a clean pulse signal. Keep still."
                         : "Keep your finger gently on the camera.")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.56))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)

                    HStack(spacing: 28) {
                        VStack(spacing: 3) {
                            Text(session.liveMilliseconds.map { "\($0)" } ?? "—")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("ms interval")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        VStack(spacing: 3) {
                            Text("\(Int(session.quality * 100))%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("signal quality")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        VStack(spacing: 3) {
                            Text(session.stage == .calibrating ? "Step 1" : "Step 2")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("of 2")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.45))
                        }
                    }
                    .padding(.top, 4)

                    if let message = session.frameMessage {
                        Text(message)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(hex: 0xF2A65A))
                            .padding(.top, 2)
                            .transition(.opacity)
                    }
                }
                .padding(.top, 26)

                Spacer()
                VStack(spacing: 6) {
                    HStack {
                        Text("QUICK TIP")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.4)
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                        Text("\(Int(session.progress * 100))%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text("Don't press too hard. Keep your hand relaxed and breathe steadily.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
        }
    }
}

struct CameraTutorialView: View {
    let onAllow: () -> Void
    let onClose: () -> Void
    @State private var page = 0

    private let pages: [(title: String, subtitle: String, icon: String, color: Color)] = [
        ("Keep Your Finger\nWell Lit", "Place your fingertip gently over the rear camera and flashlight. Stay still while the pulse wave is captured.", "hand.point.up.left.fill", AppColors.coral),
        ("\(Brand.name) Works Only\nwith Camera Permission", "We need access to your camera to measure your heart rate. Your camera is used only during a measurement.", "camera.fill", AppColors.teal)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(AppColors.surfaceMuted, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 22) {
                        Spacer()
                        Image(systemName: item.icon)
                            .font(.system(size: 58, weight: .semibold))
                            .foregroundColor(item.color)
                            .frame(width: 172, height: 172)
                            .background(item.color.opacity(0.11), in: Circle())
                        Text(item.title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(AppColors.ink)
                        Text(item.subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(AppColors.inkSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 34)
                        if index == 1 {
                            VStack(alignment: .leading, spacing: 12) {
                                privacyRow("photo.on.rectangle.angled", "We never access your photo library")
                                privacyRow("lock.shield.fill", "We never take or save photos")
                                privacyRow("hand.raised.fill", "The algorithm runs only while your finger covers the camera")
                            }
                            .padding(16)
                            .cardStyle()
                            .padding(.horizontal, 28)
                        }
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            HStack(spacing: 10) {
                if page == 0 {
                    Button("Continue") { withAnimation { page = 1 } }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Allow") { onAllow() }
                        .buttonStyle(PrimaryButtonStyle())
                    Button("Not Now", action: onClose)
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(width: 120)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func privacyRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.success)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(AppColors.ink)
            Spacer()
        }
    }
}

// MARK: - Results

struct MeasurementResultView: View {
    let measurement: HeartRateMeasurementMO
    @Binding var aiExpanded: Bool
    let onContinue: () -> Void
    let onRetake: () -> Void
    let onDelete: () -> Void
    var onTrends: (() -> Void)?

    @EnvironmentObject private var app: AppModel
    @Environment(\.managedObjectContext) private var context

    private var tagInfo: TagInfo? {
        measurement.tagId.flatMap { TagCatalog.info(for: $0) }
    }

    private var aiComment: AIComment {
        let history: [HeartRateMeasurementMO] = PersistenceController.shared.fetch(
            HeartRateMeasurementMO.self, sortBy: "createdAt", ascending: false
        )
        return AICommentEngine.comment(for: measurement, history: history)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Measurement")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("Measurement Details")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.inkSecondary)
                }
                Spacer()
                Button {
                    app.selectedTab = 0
                    onContinue()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                        .frame(width: 34, height: 34)
                        .background(AppColors.surfaceMuted, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.inkSecondary)
                        Text(AppDate.shortDateTime(measurement.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkSecondary)
                        Spacer()
                        if let tagInfo {
                            TagChipView(tag: tagInfo)
                        } else {
                            Text(measurement.isTagAutoGenerated ? "Auto tag" : "No tag")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.inkSecondary)
                        }
                    }
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("At a glance")
                            .sectionTitle()
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            MetricCardView(kind: .pulse, value: Double(measurement.pulse), compact: true)
                            MetricCardView(kind: .hrv, value: measurement.hrv, compact: true)
                            MetricCardView(kind: .stress, value: Double(measurement.stress), compact: true)
                            MetricCardView(kind: .energy, value: Double(measurement.energy), compact: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Detailed metrics")
                            .sectionTitle()
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            MetricCardView(kind: .sdnn, value: measurement.sdnn, compact: true)
                            MetricCardView(kind: .rmssd, value: measurement.rmssd, compact: true)
                            MetricCardView(kind: .pnn50, value: measurement.pnn50, compact: true)
                            MetricCardView(kind: .healthIndex, value: measurement.healthIndex, compact: true)
                        }
                        MetricCardView(
                            kind: .csi,
                            value: Double(measurement.csi),
                            subtitle: "Single-measurement estimate",
                            compact: true
                        )
                    }

                    aiCommentCard

                    Text("The analysis uses artificial intelligence and is provided solely for informational and educational purposes. It is not medical advice.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    HStack(spacing: 10) {
                        Button("Delete", role: .destructive, action: onDelete)
                            .buttonStyle(SecondaryButtonStyle())
                            .foregroundColor(AppColors.danger)
                        Button("Retake", action: onRetake)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    if let onTrends {
                        Button {
                            onTrends()
                        } label: {
                            Label("View Trends", systemImage: "chart.xyaxis.line")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 22)
            }

            Button("Continue", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .accessibilityIdentifier("resultContinueButton")
        }
        .screenBackground()
        .onAppear {
            MeasurementService.markAICommentRead(measurement)
            app.showToast("Measurement saved")
        }
    }

    private var aiCommentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppColors.periwinkle)
                    Text("AI Comment")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                }
                Spacer()
                Button(aiExpanded ? "Hide" : "Show") {
                    withAnimation(.easeOut(duration: 0.2)) { aiExpanded.toggle() }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.coral)
            }
            if aiExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Overall Health State")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                    Text(aiComment.overall)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Current State: \(contextName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                        .padding(.top, 2)
                    Text(aiComment.context)
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(aiComment.battery)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var contextName: String {
        guard let tagId = measurement.tagId, let info = TagCatalog.info(for: tagId) else {
            return "General"
        }
        if let group = info.group {
            return "\(info.timing?.label ?? "") \(group.title)".trimmingCharacters(in: .whitespaces)
        }
        return info.cluster.title
    }
}
