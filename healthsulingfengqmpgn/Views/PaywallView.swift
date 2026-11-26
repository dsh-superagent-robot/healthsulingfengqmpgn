import SwiftUI

struct PaywallView: View {
    let context: PaywallContext

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var app: AppModel

    @State private var selectedPlanID = SubscriptionStore.weeklyID
    @State private var showCancelSurvey = false
    @State private var showError = false
    @State private var isPurchasing = false
    @State private var cancellationStep = 0

    private var selectedPlan: SubscriptionStore.Plan {
        selectedPlanID == SubscriptionStore.weeklyID ? store.weeklyPlan : store.yearlyPlan
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x241E18), Color(hex: 0x100E0C)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    topBar
                    hero
                    featureGrid
                    planOptions
                    purchaseButton
                    restoreAndLegal
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $showCancelSurvey) {
            CancellationSurveyView { dismiss() }
                .presentationDetents([.medium, .large])
        }
        .alert("Unable to Purchase", isPresented: $showError) {
            Button("Try Again") {
                Task { await purchase() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "Please try again in a moment.")
        }
        .onChange(of: store.errorMessage) { message in
            if message != nil, !store.isPremium { showError = true }
        }
        .onChange(of: store.isPremium) { premium in
            if premium {
                app.showToast("Welcome to Premium")
                dismiss()
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundColor(Color(hex: 0xF7D37A))
                Text("PREMIUM")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundColor(Color(hex: 0xF7D37A))
            }
            Spacer()
            Button {
                showCancelSurvey = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(hex: 0xF7D37A).opacity(0.12))
                    .frame(width: 120, height: 120)
                Image(systemName: "crown.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0xF7E0A2), Color(hex: 0xD5A542)],
                                       startPoint: .top, endPoint: .bottom)
                    )
            }
            Text(context.headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Your heart data deserves the full picture. Unlock unlimited measuring, deeper analysis and every Journey task.")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(store.featureList, id: \.1) { feature in
                HStack(spacing: 8) {
                    Image(systemName: feature.0)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: 0xF7D37A))
                    Text(feature.1)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var planOptions: some View {
        VStack(spacing: 10) {
            planRow(store.weeklyPlan)
            planRow(store.yearlyPlan)
        }
    }

    private func planRow(_ plan: SubscriptionStore.Plan) -> some View {
        let selected = selectedPlanID == plan.id
        return Button {
            withAnimation(.easeOut(duration: 0.18)) { selectedPlanID = plan.id }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(selected ? Color(hex: 0xF7D37A) : Color.white.opacity(0.25), lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if selected {
                        Circle()
                            .fill(Color(hex: 0xF7D37A))
                            .frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(hex: 0x2B2110))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: 0xF7D37A), in: Capsule())
                        }
                    }
                    Text(plan.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.55))
                }
                Spacer()
                Text(plan.price)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Color(hex: 0xF7D37A).opacity(0.1) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color(hex: 0xF7D37A).opacity(0.7) : Color.white.opacity(0.1),
                            lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        VStack(spacing: 8) {
            Button {
                Task { await purchase() }
            } label: {
                HStack {
                    if isPurchasing || store.isLoading {
                        ProgressView().tint(Color(hex: 0x2B2110))
                    } else {
                        Text(primaryCTA)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                }
                .foregroundColor(Color(hex: 0x2B2110))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(colors: [Color(hex: 0xF7E0A2), Color(hex: 0xE2B85B)],
                                   startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing || store.isLoading)
            .accessibilityIdentifier("purchaseButton")

            Text(selectedPlanID == SubscriptionStore.weeklyID
                 ? "3-day free trial, then \(store.weeklyPlan.price). Cancel anytime."
                 : "Billed annually. Cancel anytime.")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
    }

    private var primaryCTA: String {
        if selectedPlanID == SubscriptionStore.weeklyID {
            return "Start 3-Day Free Trial"
        }
        return "Continue with Yearly Pro"
    }

    private var restoreAndLegal: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                Button("Restore Purchase") {
                    Task {
                        await store.restore()
                        if store.isPremium { dismiss() }
                        else { showError = true }
                    }
                }
                Button("Maybe Later") {
                    showCancelSurvey = true
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white.opacity(0.65))

            HStack(spacing: 14) {
                Link("Privacy Policy", destination: Brand.privacyURL)
                Link("Terms of Use", destination: Brand.termsURL)
            }
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.4))

            Text("Payment will be charged to your Apple Account. Subscription renews automatically unless cancelled at least 24 hours before the period ends. Manage in App Store settings.")
                .font(.system(size: 9))
                .foregroundColor(.white.opacity(0.32))
                .multilineTextAlignment(.center)
        }
    }

    private func purchase() async {
        isPurchasing = true
        let success = await store.purchase(selectedPlan)
        isPurchasing = false
        if success { dismiss() }
    }
}

struct CancellationSurveyView: View {
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Int?
    @State private var feedback = ""
    @State private var submitted = false

    private let options = [
        "I don't use it enough",
        "It's too expensive",
        "I'm switching to another app",
        "I forgot about the charge",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if submitted {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(AppColors.success)
                            Text("Thank you")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.ink)
                            Text("Your feedback helps us make \(Brand.name) better.")
                                .font(.system(size: 14))
                                .foregroundColor(AppColors.inkSecondary)
                                .multilineTextAlignment(.center)
                            Button("Continue with limited access") {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onClose() }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        Text("Before you go")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        Text("What is the main reason you're not upgrading right now?")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.inkSecondary)
                        ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                            Button {
                                selected = index
                            } label: {
                                HStack {
                                    Text(option)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(AppColors.ink)
                                    Spacer()
                                    Image(systemName: selected == index ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selected == index ? AppColors.coral : AppColors.separator)
                                }
                                .padding(13)
                                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Anything else? (optional)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.inkSecondary)
                            TextField("Tell us more", text: $feedback, axis: .vertical)
                                .lineLimit(2...4)
                                .font(.system(size: 14))
                                .padding(12)
                                .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        Button("Submit") {
                            submitted = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(selected == nil)
                        .opacity(selected == nil ? 0.5 : 1)
                        Button("No thanks, continue with limited access") {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onClose() }
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.inkSecondary)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(20)
            }
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onClose() }
                    }
                }
            }
        }
    }
}
