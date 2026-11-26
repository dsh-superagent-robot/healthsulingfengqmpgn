import SwiftUI
import UIKit

/// Central design tokens for the app. The visual language pairs warm paper tones
/// with a coral accent, rounded cards and geometric achievement badges.
enum AppColors {
    static let coral = Color(hex: 0xE96A63)
    static let coralDeep = Color(hex: 0xD4514A)
    static let teal = Color(hex: 0x6CD1CC)
    static let mint = Color(hex: 0x84D47F)
    static let periwinkle = Color(hex: 0x8287D9)
    static let gold = Color(hex: 0xD5CF65)
    static let orange = Color(hex: 0xD9A982)
    static let rose = Color(hex: 0xD982B2)
    static let lavender = Color(hex: 0xA982D9)

    static let background = Color(light: 0xFAF8F4, dark: 0x111110)
    static let surface = Color(light: 0xFFFFFF, dark: 0x1D1C1A)
    static let surfaceMuted = Color(light: 0xF0ECE5, dark: 0x2A2825)
    static let ink = Color(light: 0x1B1A18, dark: 0xF7F4EF)
    static let inkSecondary = Color(light: 0x76716A, dark: 0xA8A39B)
    static let separator = Color(light: 0xE7E1D8, dark: 0x35322E)
    static let success = Color(hex: 0x5BB98C)
    static let warning = Color(hex: 0xE3A23B)
    static let danger = Color(hex: 0xD9534F)
    static let info = Color(hex: 0x6B9ACF)

    static let cardGradient = LinearGradient(
        colors: [Color(hex: 0x2C2A27), Color(hex: 0x171614)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let heroGradient = LinearGradient(
        colors: [Color(hex: 0xE96A63), Color(hex: 0xD97A55)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(AppColors.separator.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    func screenBackground() -> some View {
        self.background(AppColors.background.ignoresSafeArea())
    }

    func sectionTitle() -> some View {
        self.font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(AppColors.ink)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = AppColors.coral
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint)
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundColor(AppColors.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppColors.surfaceMuted)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

// MARK: - Geometric language

struct PolygonShape: Shape {
    var sides: Int
    var rotation: Angle = .degrees(-90)

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<sides {
            let angle = rotation.radians + (Double(index) / Double(sides)) * 2 * .pi
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY * 0.82)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.minX, y: rect.maxY * 0.82)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.18))
        path.closeSubpath()
        return path
    }
}

enum BadgeShape: String, Codable, CaseIterable {
    case hexagon, circle, square, rhombus, shield, capsule

    @ViewBuilder
    func shape(in size: CGFloat) -> some View {
        switch self {
        case .hexagon:
            PolygonShape(sides: 6).frame(width: size, height: size)
        case .circle:
            Circle().frame(width: size, height: size)
        case .square:
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).frame(width: size, height: size)
        case .rhombus:
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .frame(width: size * 0.78, height: size * 0.78)
                .rotationEffect(.degrees(45))
        case .shield:
            ShieldShape().frame(width: size * 0.88, height: size)
        case .capsule:
            Capsule().frame(width: size, height: size * 0.62)
        }
    }
}

struct SoftIcon: View {
    let systemName: String
    var tint: Color = AppColors.coral
    var size: CGFloat = 42

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }
}

struct PillLabel: View {
    let text: String
    var tint: Color = AppColors.coral

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .light))
                .foregroundColor(AppColors.inkSecondary)
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(message)
                .font(.system(size: 15))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 240)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
    }
}

struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.black.opacity(0.82), in: Capsule())
            .shadow(radius: 6)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// Date presentation is intentionally pinned to English because the app copy is
// English even when the device language is not.
enum AppDate {
    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let longFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    static func shortDateTime(_ date: Date) -> String { shortFormatter.string(from: date) }
    static func time(_ date: Date) -> String { timeFormatter.string(from: date) }
    static func date(_ date: Date) -> String { dateFormatter.string(from: date) }
    static func longDateTime(_ date: Date) -> String { longFormatter.string(from: date) }
    static func monthYear(_ date: Date) -> String { monthYearFormatter.string(from: date) }
    static func weekdayMonthDay(_ date: Date) -> String { weekdayFormatter.string(from: date) }
}
