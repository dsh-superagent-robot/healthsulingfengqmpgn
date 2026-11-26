import SwiftUI

enum ManualLogType: String, CaseIterable, Identifiable {
    case glucose, oxygen, pressure

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glucose: return "Log Glucose"
        case .oxygen: return "Log Oxygen"
        case .pressure: return "Log Pressure"
        }
    }

    var shortTitle: String {
        switch self {
        case .glucose: return "Glucose"
        case .oxygen: return "Oxygen"
        case .pressure: return "Pressure"
        }
    }

    var icon: String {
        switch self {
        case .glucose: return "drop.fill"
        case .oxygen: return "lungs.fill"
        case .pressure: return "gauge.medium"
        }
    }

    var color: Color {
        switch self {
        case .glucose: return AppColors.orange
        case .oxygen: return AppColors.info
        case .pressure: return AppColors.rose
        }
    }

    var unit: String {
        switch self {
        case .glucose: return "mg/dl"
        case .oxygen: return "SpO2%"
        case .pressure: return "mmHg"
        }
    }
}

struct ManualLogView: View {
    let type: ManualLogType
    var existingGlucose: GlucoseLogMO?
    var existingOxygen: OxygenLogMO?
    var existingPressure: PressureLogMO?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel

    @State private var glucoseIndex = 48
    @State private var oxygenIndex = 18
    @State private var sysIndex = 76
    @State private var diaIndex = 40
    @State private var mealContext = 0

    private let glucoseValues = Array(40...400)
    private let oxygenValues = Array(1...100)
    private let sysValues = Array(50...230)
    private let diaValues = Array(40...140)

    init(
        type: ManualLogType,
        existingGlucose: GlucoseLogMO? = nil,
        existingOxygen: OxygenLogMO? = nil,
        existingPressure: PressureLogMO? = nil
    ) {
        self.type = type
        self.existingGlucose = existingGlucose
        self.existingOxygen = existingOxygen
        self.existingPressure = existingPressure
        let glucoseValues = Array(40...400)
        let oxygenValues = Array(1...100)
        let sysValues = Array(50...230)
        let diaValues = Array(40...140)
        _glucoseIndex = State(initialValue: glucoseValues.firstIndex(of: Int(existingGlucose?.value ?? 95)) ?? 55)
        _oxygenIndex = State(initialValue: oxygenValues.firstIndex(of: Int(existingOxygen?.value ?? 98)) ?? 97)
        _sysIndex = State(initialValue: sysValues.firstIndex(of: Int(existingPressure?.sys ?? 120)) ?? 70)
        _diaIndex = State(initialValue: diaValues.firstIndex(of: Int(existingPressure?.dia ?? 80)) ?? 40)
        _mealContext = State(initialValue: existingGlucose?.tagId == "builtin.eating.after" ? 1 : 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    wheelCard
                    if type == .glucose { mealContextCard }
                    if type == .pressure { pressureInsightCard }
                    if type == .oxygen { oxygenInsightCard }
                    if type == .glucose { glucoseInsightCard }
                    Text("These values are educational and do not replace a medical device or professional advice.")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: type.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(type.color)
                .frame(width: 78, height: 78)
                .background(type.color.opacity(0.12), in: Circle())
            Text(type.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            if type == .glucose {
                Text("Choose your reading and whether it was before or after a meal.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
            } else if type == .pressure {
                Text("Use a validated cuff and rest for five minutes before measuring.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Place the sensor on a warm, clean finger and stay still.")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var wheelCard: some View {
        VStack(spacing: 8) {
            if type == .glucose {
                HStack(spacing: 0) {
                    ValueWheel(values: glucoseValues.map(String.init), index: $glucoseIndex, width: 150)
                    VStack(spacing: 2) {
                        Text("mg/dl")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.inkSecondary)
                    }
                }
                Text("\(glucoseValues[glucoseIndex]) mg/dl")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
            } else if type == .oxygen {
                HStack(spacing: 0) {
                    ValueWheel(values: oxygenValues.map(String.init), index: $oxygenIndex, width: 150)
                    Text("SpO2%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.inkSecondary)
                }
                Text("\(oxygenValues[oxygenIndex])%")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
            } else {
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("SYS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.inkSecondary)
                        ValueWheel(values: sysValues.map(String.init), index: $sysIndex, width: 110)
                    }
                    VStack(spacing: 2) {
                        Text("DIA")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppColors.inkSecondary)
                        ValueWheel(values: diaValues.map(String.init), index: $diaIndex, width: 110)
                    }
                }
                Text("\(sysValues[sysIndex]) / \(diaValues[diaIndex]) mmHg")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
            }
            Text(type == .pressure ? "SYS 50–230 · DIA 40–140" : type == .oxygen ? "1–100%" : "40–400 mg/dl")
                .font(.system(size: 11))
                .foregroundColor(AppColors.inkSecondary)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private var mealContextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Meal context")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
            Picker("Meal context", selection: $mealContext) {
                Text("Before Meal").tag(0)
                Text("After Meal").tag(1)
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .cardStyle()
    }

    private var glucoseInsight: MetricInsight {
        MetricInsights.insight(
            for: mealContext == 0 ? .glucoseBefore : .glucoseAfter,
            value: Double(glucoseValues[glucoseIndex])
        )
    }

    private var glucoseInsightCard: some View {
        insightCard(title: glucoseInsight.headline, detail: glucoseInsight.detail, color: glucoseInsight.color)
    }

    private var oxygenInsight: MetricInsight {
        MetricInsights.insight(for: .oxygen, value: Double(oxygenValues[oxygenIndex]))
    }

    private var oxygenInsightCard: some View {
        insightCard(title: oxygenInsight.headline, detail: oxygenInsight.detail, color: oxygenInsight.color)
    }

    private var pressureInsight: MetricInsight {
        MetricInsights.bloodPressureInsight(sys: sysValues[sysIndex], dia: diaValues[diaIndex])
    }

    private var pressureInsightCard: some View {
        insightCard(title: pressureInsight.headline, detail: pressureInsight.detail, color: pressureInsight.color)
    }

    private func insightCard(title: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(detail)
                .font(.system(size: 12))
                .foregroundColor(AppColors.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func save() {
        switch type {
        case .glucose:
            let value = Double(glucoseValues[glucoseIndex])
            let context = mealContext == 0 ? "builtin.eating.before" : "builtin.eating.after"
            if let existingGlucose {
                existingGlucose.value = value
                existingGlucose.tagId = context
            } else {
                _ = HealthLogService.saveGlucose(value: value, tagId: context)
            }
            app.showToast("Glucose logged")
        case .oxygen:
            if let existingOxygen {
                existingOxygen.value = Int32(oxygenValues[oxygenIndex])
            } else {
                _ = HealthLogService.saveOxygen(value: oxygenValues[oxygenIndex])
            }
            app.showToast("Oxygen logged")
        case .pressure:
            if let existingPressure {
                existingPressure.sys = Int32(sysValues[sysIndex])
                existingPressure.dia = Int32(diaValues[diaIndex])
            } else {
                _ = HealthLogService.savePressure(sys: sysValues[sysIndex], dia: diaValues[diaIndex])
            }
            app.showToast("Pressure logged")
        }
        PersistenceController.shared.save()
        dismiss()
    }
}
