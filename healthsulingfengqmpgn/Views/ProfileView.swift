import SwiftUI
import PhotosUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var secondName = ""
    @State private var age = ""
    @State private var gender: Gender = .notSet
    @State private var height = ""
    @State private var weight = ""
    @State private var avatarData: Data?
    @State private var showCamera = false
    @State private var showPhotoOptions = false
    @State private var showCameraUnavailable = false
    @State private var showLibrary = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection
                    VStack(spacing: 16) {
                        LabeledField(title: "Name", placeholder: "Not Set", text: $name)
                        LabeledField(title: "Second Name", placeholder: "Not Set", text: $secondName)
                        HStack(spacing: 12) {
                            LabeledField(title: "Age", placeholder: "Not Set", text: $age, keyboard: .numberPad)
                            LabeledField(title: "Height (cm)", placeholder: "Not Set", text: $height, keyboard: .decimalPad)
                        }
                        LabeledField(title: "Weight (kg)", placeholder: "Not Set", text: $weight, keyboard: .decimalPad)
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

                    if let bmi = bmiValue {
                        HStack {
                            Image(systemName: "figure")
                                .foregroundColor(AppColors.teal)
                            Text("BMI \(String(format: "%.1f", bmi))")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.ink)
                            Spacer()
                        }
                        .padding(14)
                        .background(AppColors.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Used for")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.inkSecondary)
                        Text("Age and gender personalize Heart Age. Height and weight calculate BMI. Your data stays on this device.")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
        .onAppear(perform: load)
        .photosPicker(isPresented: $showLibrary, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let normalized = image.jpegData(compressionQuality: 0.8) {
                    await MainActor.run { avatarData = normalized }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            ImagePicker(sourceType: .camera) { image in
                if let data = image.jpegData(compressionQuality: 0.8) {
                    avatarData = data
                }
            }
        }
        .confirmationDialog("Profile Photo", isPresented: $showPhotoOptions, titleVisibility: .visible) {
            Button("Take a Photo") {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showCamera = true
                } else {
                    showCameraUnavailable = true
                }
            }
            Button("Choose from Library") { showLibrary = true }
            if avatarData != nil {
                Button("Delete", role: .destructive) { avatarData = nil }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Camera not available", isPresented: $showCameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device has no camera available. Choose a photo from your library instead.")
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 10) {
            avatarImage
                .frame(width: 110, height: 110)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.surface, lineWidth: 3))
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 5)
            Button("Add / Change Photo") {
                showPhotoOptions = true
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(AppColors.coral)
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let avatarData, let image = UIImage(data: avatarData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "person.fill")
                .font(.system(size: 44))
                .foregroundColor(AppColors.coral)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.coral.opacity(0.12))
        }
    }

    private var bmiValue: Double? {
        guard let h = Double(height.replacingOccurrences(of: ",", with: ".")),
              let w = Double(weight.replacingOccurrences(of: ",", with: ".")), h > 0 else { return nil }
        return w / pow(h / 100, 2)
    }

    private func load() {
        name = app.profile.name
        secondName = app.profile.secondName
        age = app.profile.age.map(String.init) ?? ""
        gender = app.profile.gender
        height = app.profile.heightCm.map { String(format: "%.0f", $0) } ?? ""
        weight = app.profile.weightKg.map { String(format: "%.1f", $0) } ?? ""
        avatarData = app.profile.avatarData
    }

    private func save() {
        app.profile.name = name.trimmingCharacters(in: .whitespaces)
        app.profile.secondName = secondName.trimmingCharacters(in: .whitespaces)
        app.profile.age = Int(age)
        app.profile.gender = gender
        app.profile.heightCm = Double(height.replacingOccurrences(of: ",", with: "."))
        app.profile.weightKg = Double(weight.replacingOccurrences(of: ",", with: "."))
        app.profile.avatarData = avatarData
        app.showToast("Profile saved")
        dismiss()
    }

}


struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.openURL) private var openURL

    @State private var restoreMessage: String?
    @State private var showRestoreAlert = false
    @State private var showContactUnavailable = false
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PremiumBanner(context: .settings)
                    appearance
                    appIconSection
                    settingsGroup1
                    settingsGroup2
                    aboutSection
                    version
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Restore Purchase", isPresented: $showRestoreAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Mail not available", isPresented: $showContactUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No mail app is configured on this device. You can reach us at \(Brand.supportEmail).")
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Picker("Appearance", selection: $app.appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .cardStyle()
    }

    private var appIconSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Icon")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    iconOption(title: "Default", imageName: "IconPreviewDefault", name: nil)
                    ForEach(1...6, id: \.self) { index in
                        iconOption(
                            title: iconNames[index - 1],
                            imageName: "IconPreview\(index)",
                            name: "AppIcon-v\(index)"
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            Text("Alternate icons are cosmetic and keep all your data.")
                .font(.system(size: 10))
                .foregroundColor(AppColors.inkSecondary)
        }
        .padding(16)
        .cardStyle()
    }

    private var iconNames: [String] {
        ["Coral", "Amber", "Mint", "Aqua", "Indigo", "Violet"]
    }

    private func iconOption(title: String, imageName: String?, name: String?) -> some View {
        let selected = currentIconName == name
        return Button {
            setIcon(name)
        } label: {
            VStack(spacing: 5) {
                Group {
                    if let imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(AppColors.heroGradient)
                    }
                }
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(selected ? AppColors.coral : AppColors.separator, lineWidth: selected ? 2.5 : 1)
                )
                Text(title)
                    .font(.system(size: 9, weight: selected ? .bold : .medium))
                    .foregroundColor(selected ? AppColors.coral : AppColors.inkSecondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func setIcon(_ name: String?) {
        guard UIApplication.shared.supportsAlternateIcons else {
            app.showToast("Alternate icons are not supported")
            return
        }
        UIApplication.shared.setAlternateIconName(name) { error in
            DispatchQueue.main.async {
                if error == nil {
                    currentIconName = name
                    app.showToast(name == nil ? "Default icon restored" : "App icon updated")
                } else {
                    app.showToast("Unable to change app icon")
                }
            }
        }
    }

    private var settingsGroup1: some View {
        VStack(spacing: 0) {
            NavigationLink {
                RemindersView()
            } label: {
                InfoRow(icon: "bell.fill", title: "Manage Reminders", value: nil, tint: AppColors.gold, showChevron: true)
            }
            .buttonStyle(.plain)
            DividerLine()
            NavigationLink {
                ChartSettingsView()
            } label: {
                InfoRow(icon: "chart.xyaxis.line", title: "Chart Settings", value: nil, tint: AppColors.teal, showChevron: true)
            }
            .buttonStyle(.plain)
            DividerLine()
            NavigationLink {
                AppleHealthSettingsView()
            } label: {
                InfoRow(icon: "heart.text.square.fill", title: "Apple Health Sync", value: health.enabled ? "On" : "Off", tint: AppColors.coral, showChevron: true)
            }
            .buttonStyle(.plain)
            DividerLine()
            NavigationLink {
                TagsManagementView()
            } label: {
                InfoRow(icon: "tag.fill", title: "Custom Tags", value: nil, tint: AppColors.orange, showChevron: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .cardStyle(padding: 0)
    }

    private var settingsGroup2: some View {
        VStack(spacing: 0) {
            Button {
                openURL(Brand.appStoreReviewURL)
            } label: {
                InfoRow(icon: "star.fill", title: "Rate Us", value: nil, tint: AppColors.gold, showChevron: true)
            }
            .buttonStyle(.plain)
            DividerLine()
            ShareLink(item: URL(string: "https://apps.apple.com/app/id6823553763")!) {
                InfoRow(icon: "square.and.arrow.up", title: "Share App", value: nil, tint: AppColors.teal, showChevron: true)
            }
            DividerLine()
            Button {
                contactSupport()
            } label: {
                InfoRow(icon: "envelope.fill", title: "Contact Us", value: nil, tint: AppColors.periwinkle, showChevron: true)
            }
            .buttonStyle(.plain)
            DividerLine()
            Button {
                Task {
                    await store.restore()
                    restoreMessage = store.isPremium ? "Your purchase has been restored." : "No purchases to be restored."
                    showRestoreAlert = true
                }
            } label: {
                InfoRow(icon: "arrow.clockwise", title: "Restore Purchase", value: store.isRestoring ? "Restoring…" : nil, tint: AppColors.mint, showChevron: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .cardStyle(padding: 0)
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            Link(destination: Brand.privacyURL) {
                InfoRow(icon: "hand.raised.fill", title: "Privacy Policy", value: nil, tint: AppColors.info, showChevron: true)
            }
            DividerLine()
            Link(destination: Brand.termsURL) {
                InfoRow(icon: "doc.text.fill", title: "Terms of Use", value: nil, tint: AppColors.inkSecondary, showChevron: true)
            }
        }
        .padding(.horizontal, 14)
        .cardStyle(padding: 0)
    }

    private var version: some View {
        VStack(spacing: 5) {
            Text("\(Brand.name) · \(Brand.displayName)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.inkSecondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkSecondary)
            Text("User ID \(health.userID.prefix(8))")
                .font(.system(size: 10))
                .foregroundColor(AppColors.inkSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private func contactSupport() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let subject = "\(Brand.name) Support"
        let body = "App Version: \(version) (\(build))\nUser ID: \(health.userID)\n\nHow can we help?\n"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Brand.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url, UIApplication.shared.canOpenURL(url) {
            openURL(url)
        } else {
            showContactUnavailable = true
        }
    }
}
