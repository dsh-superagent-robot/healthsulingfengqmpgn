import SwiftUI

struct OnboardingView: View {
    private enum Stage: Equatable {
        case welcome
        case feature(Int)
        case personalize
        case terms
        case healthConnect
        case questionnaire
        case calculating
        case risk
        case notifications
    }

    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var notifications: NotificationService

    @State private var stage: Stage = .welcome
    @State private var featurePage = 0
    @State private var name = ""
    @State private var age = ""
    @State private var gender: Gender = .notSet
    @State private var height = ""
    @State private var weight = ""

    @State private var anxiety = 0
    @State private var doctorAdvice = 0
    @State private var diagnosed = 0
    @State private var calcStep = 0
    @State private var riskScore = 0
    @State private var isConnectingHealth = false
    @State private var isRequestingNotifications = false

    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-DSHOnboardingStage"), args.indices.contains(index + 1) {
            switch args[index + 1] {
            case "feature": _stage = State(initialValue: .feature(0))
            case "personalize": _stage = State(initialValue: .personalize)
            case "terms": _stage = State(initialValue: .terms)
            case "health": _stage = State(initialValue: .healthConnect)
            case "questionnaire": _stage = State(initialValue: .questionnaire)
            case "calculating": _stage = State(initialValue: .calculating)
            case "risk":
                _stage = State(initialValue: .risk)
                _riskScore = State(initialValue: 58)
            case "notifications": _stage = State(initialValue: .notifications)
            default: break
            }
        }
        #endif
    }

    private let features: [(title: String, subtitle: String, icon: String, color: Color)] = [
        ("Check Heart Rate", "Measure your pulse and HRV with the camera in under a minute.", "heart.fill", AppColors.coral),
        ("Reveal Heart Health", "See heart age, stress and recovery in language you can use.", "waveform.path.ecg", AppColors.teal),
        ("Monitor Health Metrics", "Track blood oxygen, glucose and pressure alongside your heart.", "square.grid.2x2.fill", AppColors.periwinkle),
        ("Log Blood Pressure & Glucose", "Keep a simple diary and understand your personal ranges.", "drop.fill", AppColors.orange),
        ("Reduce Stress", "Follow guided Journeys, mindful check-ins and a chronic stress index.", "leaf.fill", AppColors.mint)
    ]

    private let facts = [
        "Your heart beats about 100,000 times a day.",
        "HRV is a window into how your nervous system recovers.",
        "A 20-second slow breathing pause can shift your heart rhythm.",
        "Sleep is one of the most powerful recovery tools you own."
    ]

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            Group {
                switch stage {
                case .welcome: welcome
                case .feature(let index): featureView(index)
                case .personalize: personalize
                case .terms: terms
                case .healthConnect: healthConnect
                case .questionnaire: questionnaire
                case .calculating: calculating
                case .risk: riskResult
                case .notifications: notificationsView
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity))
        }
        .animation(.easeInOut(duration: 0.3), value: stage)
    }

    // MARK: Welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.coral.opacity(0.12))
                    .frame(width: 190, height: 190)
                Circle()
                    .fill(AppColors.coral.opacity(0.18))
                    .frame(width: 140, height: 140)
                Image(systemName: "heart.fill")
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundStyle(AppColors.heroGradient)
                    .shadow(color: AppColors.coral.opacity(0.35), radius: 18, x: 0, y: 8)
            }
            VStack(spacing: 12) {
                Text(Brand.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .tracking(2)
                    .foregroundColor(AppColors.coral)
                Text("Know your heart,\none day at a time.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.ink)
                Text("A calm, private space for measuring, understanding and improving your heart health.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 34)
            Spacer()
            Button("Get Started") {
                stage = .feature(0)
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            Text("Wellness and educational use only. Not a medical device.")
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkSecondary)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
    }

    // MARK: Features

    private func featureView(_ index: Int) -> some View {
        let feature = features[index]
        return VStack(spacing: 0) {
            HStack {
                Button("Skip") { stage = .personalize }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
                Spacer()
                Text("\(index + 1) / \(features.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.inkSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)

            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 46, style: .continuous)
                    .fill(feature.color.opacity(0.12))
                    .frame(width: 230, height: 230)
                    .rotationEffect(.degrees(index % 2 == 0 ? 8 : -8))
                RoundedRectangle(cornerRadius: 38, style: .continuous)
                    .fill(feature.color.opacity(0.18))
                    .frame(width: 170, height: 170)
                Image(systemName: feature.icon)
                    .font(.system(size: 68, weight: .semibold))
                    .foregroundColor(feature.color)
            }
            VStack(spacing: 12) {
                Text(feature.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.ink)
                Text(feature.subtitle)
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(.top, 30)
            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<features.count, id: \.self) { dot in
                    Capsule()
                        .fill(dot == index ? AppColors.coral : AppColors.separator)
                        .frame(width: dot == index ? 22 : 7, height: 7)
                }
            }
            .padding(.bottom, 22)
            Button(index == features.count - 1 ? "Continue" : "Next") {
                if index == features.count - 1 {
                    stage = .personalize
                } else {
                    stage = .feature(index + 1)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: Personalize

    private var personalize: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Let's Personalize\nYour Journey")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("Age and gender help estimate Heart Age. Height and weight help calculate BMI. Everything stays on this device.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.inkSecondary)

                    VStack(spacing: 16) {
                        LabeledField(title: "Name", placeholder: "Your name", text: $name)
                        HStack(spacing: 12) {
                            LabeledField(title: "Age", placeholder: "32", text: $age, keyboard: .numberPad)
                            LabeledField(title: "Height (cm)", placeholder: "170", text: $height, keyboard: .decimalPad)
                        }
                        LabeledField(title: "Weight (kg)", placeholder: "65", text: $weight, keyboard: .decimalPad)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Gender")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.inkSecondary)
                            Picker("Gender", selection: $gender) {
                                ForEach(Gender.allCases) { value in
                                    Text(value.label).tag(value)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(18)
                    .cardStyle()

                    Text("You can update this later in Me → Profile.")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            VStack(spacing: 10) {
                Button("Continue") {
                    saveProfile()
                    stage = .terms
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Skip for now") {
                    stage = .terms
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    private func saveProfile() {
        app.profile.name = name.trimmingCharacters(in: .whitespaces)
        app.profile.age = Int(age)
        app.profile.gender = gender
        app.profile.heightCm = Double(height.replacingOccurrences(of: ",", with: "."))
        app.profile.weightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
    }

    // MARK: Terms

    private var terms: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "doc.text.fill")
                .font(.system(size: 44))
                .foregroundColor(AppColors.teal)
                .frame(width: 96, height: 96)
                .background(AppColors.teal.opacity(0.12), in: Circle())
            Text("Your data, your rules")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text("By proceeding, you accept our Terms of Use and Privacy Policy. Measurements and AI comments are for wellness and education only and do not replace medical advice.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 26)
            HStack(spacing: 16) {
                Link("Terms of Use", destination: Brand.termsURL)
                Link("Privacy Policy", destination: Brand.privacyURL)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColors.coral)
            Spacer()
            Button("I Accept & Continue") { stage = .healthConnect }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }

    // MARK: Health connect

    private var healthConnect: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(AppColors.coral.opacity(0.1)).frame(width: 150, height: 150)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 58))
                    .foregroundColor(AppColors.coral)
            }
            Text("Get 2× More\nHealth Data")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.ink)
            Text("Connect Apple Health to bring in HRV, sleep and mindfulness records. It takes less than 10 seconds and stays private on your device.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                Text("You choose exactly what to share")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppColors.inkSecondary)
            Spacer()
            Button {
                guard !isConnectingHealth else { return }
                isConnectingHealth = true
                Task {
                    await health.requestAuthorization()
                    isConnectingHealth = false
                    stage = .questionnaire
                }
            } label: {
                if isConnectingHealth {
                    ProgressView().tint(.white)
                } else {
                    Text("Connect Apple Health")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            Button("Not now") { stage = .questionnaire }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
                .padding(.bottom, 24)
        }
    }

    // MARK: Questionnaire

    private var questionnaire: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("A quick heart check")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text("Three questions help us personalize your starting point. This is not a diagnosis.")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.inkSecondary)

                    questionBlock(
                        number: 1,
                        title: "How often do you feel anxious or overwhelmed?",
                        options: ["Rarely", "Sometimes", "Often"],
                        selection: $anxiety
                    )
                    questionBlock(
                        number: 2,
                        title: "Has a doctor advised you to monitor your heart?",
                        options: ["No", "Yes"],
                        selection: $doctorAdvice
                    )
                    questionBlock(
                        number: 3,
                        title: "Have you ever been diagnosed with a heart condition?",
                        options: ["No", "Yes"],
                        selection: $diagnosed
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 20)
            }
            Button("See My Risk Score") { startCalculation() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
        }
    }

    private func questionBlock(number: Int, title: String, options: [String], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.coral)
                    .frame(width: 26, height: 26)
                    .background(AppColors.coral.opacity(0.12), in: Circle())
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.ink)
            }
            HStack(spacing: 8) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    Button {
                        selection.wrappedValue = index
                    } label: {
                        Text(option)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selection.wrappedValue == index ? .white : AppColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selection.wrappedValue == index ? AppColors.coral : AppColors.surfaceMuted)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    private func startCalculation() {
        saveProfile()
        stage = .calculating
        calcStep = 0
        Task { @MainActor in
            for step in 0..<4 {
                try? await Task.sleep(nanoseconds: 550_000_000)
                withAnimation { calcStep = step + 1 }
            }
            riskScore = computeRisk()
            app.riskScore = riskScore
            try? await Task.sleep(nanoseconds: 350_000_000)
            stage = .risk
        }
    }

    private func computeRisk() -> Int {
        var score = 24
        let profileAge = Int(age) ?? app.profile.age
        if let profileAge {
            if profileAge >= 60 { score += 24 }
            else if profileAge >= 45 { score += 15 }
            else if profileAge >= 35 { score += 7 }
        }
        score += anxiety * 9
        score += doctorAdvice * 12
        score += diagnosed * 22
        if let heightValue = Double(height.replacingOccurrences(of: ",", with: ".")),
           let weightValue = Double(weight.replacingOccurrences(of: ",", with: ".")),
           heightValue > 0 {
            let bmi = weightValue / pow(heightValue / 100, 2)
            if bmi >= 30 { score += 14 } else if bmi >= 25 { score += 7 }
        }
        return min(96, max(8, score))
    }

    private var riskBand: (String, Color) {
        switch riskScore {
        case ..<35: return ("Low", AppColors.success)
        case ..<60: return ("Moderate", AppColors.gold)
        case ..<80: return ("Elevated", AppColors.orange)
        default: return ("High", AppColors.danger)
        }
    }

    private var calculating: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().stroke(AppColors.surfaceMuted, lineWidth: 10).frame(width: 140, height: 140)
                Circle()
                    .trim(from: 0, to: min(1, Double(calcStep) / 4))
                    .stroke(AppColors.heroGradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: calcStep)
                Image(systemName: "heart.fill")
                    .font(.system(size: 44))
                    .foregroundColor(AppColors.coral)
            }
            Text(calcStep < 4 ? "Calculating your risk score" : "Almost ready")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            VStack(alignment: .leading, spacing: 10) {
                calculationRow("Reading your profile", done: calcStep >= 1)
                calculationRow("Checking stress signals", done: calcStep >= 2)
                calculationRow("Estimating cardiovascular load", done: calcStep >= 3)
                calculationRow("Preparing your result", done: calcStep >= 4)
            }
            .padding(18)
            .cardStyle()
            .padding(.horizontal, 30)
            Text(facts[calcStep % facts.count])
                .font(.system(size: 13))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .transition(.opacity)
            Spacer()
        }
    }

    private func calculationRow(_ title: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dotted")
                .foregroundColor(done ? AppColors.success : AppColors.inkSecondary)
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(AppColors.ink)
            Spacer()
        }
    }

    // MARK: Risk result

    private var riskResult: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("Your Heart Health\nRisk Score")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.ink)
                ZStack {
                    Circle()
                        .stroke(AppColors.surfaceMuted, lineWidth: 14)
                        .frame(width: 190, height: 190)
                    Circle()
                        .trim(from: 0, to: Double(riskScore) / 100)
                        .stroke(riskBand.1, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .frame(width: 190, height: 190)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(riskScore)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        Text("\(riskBand.0) risk")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(riskBand.1)
                    }
                }
                .padding(.vertical, 6)

                VStack(spacing: 0) {
                    riskRow("Age-Related Risk", value: ageRiskText)
                    DividerLine()
                    riskRow("Stress & Anxiety Risk", value: anxietyRiskText)
                    DividerLine()
                    riskRow("Blood Pressure", value: "Not measured")
                    DividerLine()
                    riskRow("BMI", value: bmiText)
                }
                .padding(.horizontal, 16)
                .cardStyle()

                Text("This estimate is educational and based on your answers and profile. It is not a diagnosis. Measure your heart rate to start building a real baseline.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                Button("Measure Heart Rate") {
                    stage = .notifications
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 4)

                Button("Skip for now") { stage = .notifications }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            .padding(.bottom, 30)
        }
    }

    private var ageRiskText: String {
        guard let ageValue = Int(age) ?? app.profile.age else { return "Not set" }
        if ageValue >= 60 { return "Higher" }
        if ageValue >= 45 { return "Moderate" }
        return "Lower"
    }

    private var anxietyRiskText: String {
        ["Lower", "Moderate", "Higher"][min(anxiety, 2)]
    }

    private var bmiText: String {
        if let bmi = app.profile.bmi {
            return String(format: "%.1f", bmi)
        }
        return "Not set"
    }

    private func riskRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14)).foregroundColor(AppColors.ink)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(AppColors.inkSecondary)
        }
        .padding(.vertical, 12)
    }

    // MARK: Notifications

    private var notificationsView: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 52))
                .foregroundColor(AppColors.gold)
                .frame(width: 118, height: 118)
                .background(AppColors.gold.opacity(0.14), in: Circle())
            Text("Gentle reminders,\nbetter habits")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.ink)
            Text("Allow reminders to measure at the times that suit you. You can change or turn them off at any time.")
                .font(.system(size: 15))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Button {
                guard !isRequestingNotifications else { return }
                isRequestingNotifications = true
                Task {
                    await notifications.requestAuthorization()
                    isRequestingNotifications = false
                    finish()
                }
            } label: {
                if isRequestingNotifications {
                    ProgressView().tint(.white)
                } else {
                    Text("Allow Reminders")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            Button("Maybe later") { finish() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
                .padding(.bottom, 24)
        }
    }

    private func finish() {
        app.completeOnboarding()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 550_000_000)
            if !store.isPremium {
                app.presentPaywall(.onboarding)
            }
        }
    }
}

struct LabeledField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboard)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundColor(AppColors.ink)
        }
    }
}
