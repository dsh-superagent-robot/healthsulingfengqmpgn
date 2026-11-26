import SwiftUI
import CoreData

struct MonthlyOverviewView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var glucose: FetchedResults<GlucoseLogMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var oxygen: FetchedResults<OxygenLogMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var pressure: FetchedResults<PressureLogMO>

    @State private var monthOffset = 0

    private var monthDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var interval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: monthDate)
            ?? DateInterval(start: monthDate, duration: 86400 * 30)
    }

    private var monthMeasurements: [HeartRateMeasurementMO] {
        measurements.filter { interval.contains($0.createdAt) }
    }

    private var hasAnyData: Bool {
        !monthMeasurements.isEmpty || !glucoseInMonth.isEmpty || !oxygenInMonth.isEmpty || !pressureInMonth.isEmpty
    }

    private var glucoseInMonth: [GlucoseLogMO] { glucose.filter { interval.contains($0.createdAt) } }
    private var oxygenInMonth: [OxygenLogMO] { oxygen.filter { interval.contains($0.createdAt) } }
    private var pressureInMonth: [PressureLogMO] { pressure.filter { interval.contains($0.createdAt) } }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    monthPicker
                    if !store.isPremium {
                        LockedPanel(action: { app.presentPaywall(.monthlyOverview) })
                        previewGrid(blurred: true)
                    } else if !hasAnyData {
                        EmptyStateView(
                            icon: "calendar",
                            title: "No Data",
                            message: "There are no records for this month yet. Take a measurement or log a health value.",
                            actionTitle: "Measure Now",
                            action: { app.openMeasurement() }
                        )
                        .cardStyle()
                    } else {
                        overviewGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Monthly Overview")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthPicker: some View {
        HStack {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceMuted, in: Circle())
            }
            Spacer()
            VStack(spacing: 2) {
                Text(AppDate.monthYear(monthDate))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Text("\(monthMeasurements.count) measurements")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Button {
                monthOffset += 1
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceMuted, in: Circle())
            }
            .disabled(monthOffset >= 0)
            .opacity(monthOffset >= 0 ? 0.35 : 1)
        }
        .foregroundColor(AppColors.ink)
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(MetricKind.monthlyMetrics) { kind in
                if let value = metricValue(kind) {
                    MetricCardView(kind: kind, value: value, age: app.profile.age, compact: true)
                } else {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(kind.shortTitle)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.inkSecondary)
                        Text("No Data")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 14)
                }
            }
        }
    }

    private func previewGrid(blurred: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(MetricKind.monthlyMetrics) { kind in
                VStack(alignment: .leading, spacing: 5) {
                    Text(kind.shortTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.inkSecondary)
                    Text("—")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.ink)
                    Text(kind.unit)
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(padding: 14)
                .blur(radius: blurred ? 2.5 : 0)
                .opacity(blurred ? 0.55 : 1)
            }
        }
        .allowsHitTesting(false)
    }

    private func metricValue(_ kind: MetricKind) -> Double? {
        switch kind {
        case .oxygen:
            return average(oxygenInMonth.map { Double($0.value) })
        case .glucoseBefore:
            return average(glucoseInMonth.filter { $0.tagId != "builtin.eating.after" }.map(\.value))
        case .glucoseAfter:
            return average(glucoseInMonth.filter { $0.tagId == "builtin.eating.after" }.map(\.value))
        case .pressureSys:
            return average(pressureInMonth.map { Double($0.sys) })
        case .pressureDia:
            return average(pressureInMonth.map { Double($0.dia) })
        case .csi:
            return average(monthMeasurements.map { Double($0.csi) })
        case .heartAge:
            guard let age = app.profile.age, !monthMeasurements.isEmpty else { return nil }
            let rmssd = monthMeasurements.map(\.rmssd).reduce(0, +) / Double(monthMeasurements.count)
            return Double(HeartAgeEngine.estimate(rmssd: rmssd, age: age, gender: app.profile.gender))
        default:
            return average(monthMeasurements.map { kind.value(from: $0) })
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
