import SwiftUI
import Charts

struct SheetHeader: View {
    let title: String
    var subtitle: String?
    var onClose: (() -> Void)?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.inkSecondary)
                }
            }
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppColors.inkSecondary)
                        .frame(width: 32, height: 32)
                        .background(AppColors.surfaceMuted, in: Circle())
                }
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

struct SectionHeading: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.coral)
            }
        }
    }
}

struct MetricCardView: View {
    let kind: MetricKind
    let value: Double
    var age: Int?
    var subtitle: String?
    var compact = false

    private var insight: MetricInsight {
        MetricInsights.insight(for: kind, value: value, age: age)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack {
                SoftIcon(systemName: kind.icon, tint: kind.accent, size: compact ? 34 : 38)
                Spacer()
                Text(insight.emoji)
                    .font(.system(size: compact ? 13 : 15))
            }
            Text(kind.shortTitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(kind.formatted(value))
                    .font(.system(size: compact ? 25 : 29, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(kind.unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Text(insight.interpretation)
                .font(.system(size: compact ? 11 : 12, weight: .medium))
                .foregroundColor(insight.color)
                .lineLimit(2)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: compact ? 13 : 16, radius: 20)
    }
}

struct PremiumBanner: View {
    var title: String = "Unlock All Features"
    var subtitle: String = "Try Premium for free"
    var context: PaywallContext = .settings
    var onTap: (() -> Void)?

    @EnvironmentObject private var store: SubscriptionStore
    @EnvironmentObject private var app: AppModel

    var body: some View {
        if !store.isPremium {
            Button {
                if let onTap { onTap() } else { app.presentPaywall(context) }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Color(hex: 0x3B2D13))
                        .frame(width: 42, height: 42)
                        .background(Color(hex: 0xF7D37A), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.78))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(16)
                .background(
                    LinearGradient(colors: [Color(hex: 0x3B3324), Color(hex: 0x1C1915)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(hex: 0xE7C36B).opacity(0.35), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("premiumBanner")
        }
    }
}

struct PeriodSelector: View {
    let periods: [StatsPeriod]
    @Binding var selection: StatsPeriod

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(periods) { period in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { selection = period }
                    } label: {
                        Text(period.label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(selection == period ? .white : AppColors.inkSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(selection == period ? AppColors.ink : AppColors.surfaceMuted)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

enum TagChipStyle {
    case selectable(isSelected: Bool)
    case `static`
}

struct TagChipView: View {
    let tag: TagInfo
    var selected = false
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tag.icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(tag.name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
            }
            .foregroundColor(selected ? .white : tag.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(selected ? tag.color : tag.color.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

struct ChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct MetricChartView: View {
    let points: [ChartPoint]
    let kind: MetricKind
    var style: ChartStyle = .line
    var showThresholds = true
    var showTrendLine = true
    var height: CGFloat = 170

    private var trendPoints: [ChartPoint] {
        guard points.count >= 2 else { return [] }
        let xs = points.enumerated().map { Double($0.offset) }
        let ys = points.map(\.value)
        let meanX = xs.reduce(0, +) / Double(xs.count)
        let meanY = ys.reduce(0, +) / Double(ys.count)
        let numerator = zip(xs, ys).map { ($0 - meanX) * ($1 - meanY) }.reduce(0, +)
        let denominator = xs.map { pow($0 - meanX, 2) }.reduce(0, +)
        guard denominator != 0 else { return [] }
        let slope = numerator / denominator
        let intercept = meanY - slope * meanX
        return points.enumerated().map { index, point in
            ChartPoint(date: point.date, value: intercept + slope * Double(index))
        }
    }

    var body: some View {
        if points.isEmpty {
            EmptyStateView(
                icon: "chart.xyaxis.line",
                title: "No Data",
                message: "Take a measurement to see your trend here."
            )
            .frame(height: height)
        } else {
            Chart {
                if style.isBar {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Date", point.date),
                            y: .value(kind.title, point.value)
                        )
                        .foregroundStyle(kind.accent.gradient)
                        .cornerRadius(3)
                    }
                } else {
                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value(kind.title, point.value)
                        )
                        .foregroundStyle(
                            LinearGradient(colors: [kind.accent.opacity(0.25), kind.accent.opacity(0.01)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value(kind.title, point.value)
                        )
                        .foregroundStyle(kind.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value(kind.title, point.value)
                        )
                        .foregroundStyle(kind.accent)
                        .symbolSize(16)
                    }
                }

                if showTrendLine {
                    ForEach(trendPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Trend", point.value),
                            series: .value("Series", "trend")
                        )
                        .foregroundStyle(AppColors.inkSecondary.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                }

                if showThresholds || style.includesThresholds {
                    ForEach(MetricInsights.thresholds(for: kind).prefix(3), id: \.self) { threshold in
                        RuleMark(y: .value("Threshold", threshold))
                            .foregroundStyle(AppColors.inkSecondary.opacity(0.18))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(AppColors.separator.opacity(0.5))
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US")))
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.inkSecondary)
                }
            }
            .frame(height: height)
        }
    }
}

struct LockedPanel: View {
    var title: String = "Monthly Insights"
    var message: String = "Unlock Premium to see full trends"
    var actionTitle: String = "Unlock"
    var action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color(hex: 0xB99247))
                .frame(width: 52, height: 52)
                .background(Color(hex: 0xF7D37A).opacity(0.2), in: Circle())
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppColors.inkSecondary)
                .multilineTextAlignment(.center)
            Button(actionTitle, action: action)
                .buttonStyle(PrimaryButtonStyle(tint: AppColors.ink))
                .frame(maxWidth: 190)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .cardStyle()
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    var value: String?
    var tint: Color = AppColors.coral
    var showChevron = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.ink)
            Spacer()
            if let value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.inkSecondary)
            }
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.inkSecondary.opacity(0.6))
            }
        }
        .padding(.vertical, 9)
    }
}

struct PrimaryHeaderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppColors.coral.opacity(0.18), AppColors.background.opacity(0)],
            startPoint: .top, endPoint: .bottom
        )
        .frame(height: 260)
        .ignoresSafeArea()
    }
}

struct ValueWheel: View {
    let values: [String]
    @Binding var index: Int
    var width: CGFloat = 120

    var body: some View {
        Picker("", selection: $index) {
            ForEach(values.indices, id: \.self) { i in
                Text(values[i]).tag(i)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: width, height: 150, alignment: .center)
        .clipped()
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.separator)
            .frame(height: 1)
    }
}
