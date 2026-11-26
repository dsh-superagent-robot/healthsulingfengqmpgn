import SwiftUI
import CoreData

struct HistoryItem: Identifiable {
    enum Payload {
        case measurement(HeartRateMeasurementMO)
        case glucose(GlucoseLogMO)
        case oxygen(OxygenLogMO)
        case pressure(PressureLogMO)
    }

    let id: String
    let date: Date
    let payload: Payload
}

struct HistoryView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var store: SubscriptionStore

    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var measurements: FetchedResults<HeartRateMeasurementMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var glucoseLogs: FetchedResults<GlucoseLogMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var oxygenLogs: FetchedResults<OxygenLogMO>
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)])
    private var pressureLogs: FetchedResults<PressureLogMO>

    @State private var filterTagID: String?
    @State private var showFilter = false
    @State private var activeLog: ManualLogType?
    @State private var editingGlucose: GlucoseLogMO?
    @State private var editingOxygen: OxygenLogMO?
    @State private var editingPressure: PressureLogMO?
    @State private var pendingDelete: HistoryItem?

    private var items: [HistoryItem] {
        var result: [HistoryItem] = []
        for measurement in measurements {
            if let filterTagID, measurement.tagId != filterTagID { continue }
            result.append(HistoryItem(
                id: measurement.objectID.uriRepresentation().absoluteString,
                date: measurement.createdAt,
                payload: .measurement(measurement)
            ))
        }
        if filterTagID == nil {
            for log in glucoseLogs {
                result.append(HistoryItem(id: log.objectID.uriRepresentation().absoluteString, date: log.createdAt, payload: .glucose(log)))
            }
            for log in oxygenLogs {
                result.append(HistoryItem(id: log.objectID.uriRepresentation().absoluteString, date: log.createdAt, payload: .oxygen(log)))
            }
            for log in pressureLogs {
                result.append(HistoryItem(id: log.objectID.uriRepresentation().absoluteString, date: log.createdAt, payload: .pressure(log)))
            }
        }
        return result.sorted { $0.date > $1.date }
    }

    private var groups: [(day: Date, items: [HistoryItem])] {
        let grouped = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]?.sorted { $0.date > $1.date } ?? []) }
    }

    private var filterName: String {
        guard let filterTagID, let info = TagCatalog.info(for: filterTagID) else { return "Filter" }
        return info.name
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22, pinnedViews: []) {
                        if filterTagID != nil {
                            HStack(spacing: 8) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 11))
                                Text(filterName)
                                    .font(.system(size: 12, weight: .semibold))
                                Spacer()
                                Button("Reset") {
                                    filterTagID = nil
                                }
                                .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(AppColors.coral)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(AppColors.coral.opacity(0.08), in: Capsule())
                        }

                        ForEach(groups, id: \.day) { group in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(dayTitle(group.day))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.inkSecondary)
                                    .padding(.leading, 4)
                                VStack(spacing: 0) {
                                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                                        row(item)
                                        if index < group.items.count - 1 { DividerLine() }
                                    }
                                }
                                .padding(.horizontal, 14)
                                .cardStyle(padding: 0)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 14) {
                    Button {
                        showFilter = true
                    } label: {
                        Image(systemName: filterTagID == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    Menu {
                        Button {
                            startMeasurement()
                        } label: {
                            Label("Measure Heart Rate", systemImage: "heart.fill")
                        }
                        Button {
                            activeLog = .glucose
                        } label: {
                            Label("Log Glucose", systemImage: "drop.fill")
                        }
                        Button {
                            activeLog = .oxygen
                        } label: {
                            Label("Log Oxygen", systemImage: "lungs.fill")
                        }
                        Button {
                            activeLog = .pressure
                        } label: {
                            Label("Log Pressure", systemImage: "gauge.medium")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showFilter) {
            TagFilterSheet(selectedTagID: $filterTagID)
                .presentationDetents([.large])
        }
        .sheet(item: $activeLog) { type in
            ManualLogView(type: type)
                .presentationDetents([.large])
        }
        .sheet(item: $editingGlucose) { log in
            ManualLogView(type: .glucose, existingGlucose: log)
                .presentationDetents([.large])
        }
        .sheet(item: $editingOxygen) { log in
            ManualLogView(type: .oxygen, existingOxygen: log)
                .presentationDetents([.large])
        }
        .sheet(item: $editingPressure) { log in
            ManualLogView(type: .pressure, existingPressure: log)
                .presentationDetents([.large])
        }
        .alert("Delete this record?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let pendingDelete { delete(pendingDelete) }
                pendingDelete = nil
            }
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var emptyState: some View {
        Group {
            if filterTagID != nil {
                EmptyStateView(
                    icon: "tag.slash",
                    title: "Nothing Found",
                    message: "There are no measurements for the selected tags.",
                    actionTitle: "Reset Filters",
                    action: { filterTagID = nil }
                )
            } else {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "No Records Yet",
                    message: "Start by adding your first measurement.",
                    actionTitle: "Add Measurement",
                    action: { startMeasurement() }
                )
            }
        }
    }

    @ViewBuilder
    private func row(_ item: HistoryItem) -> some View {
        switch item.payload {
        case .measurement(let measurement):
            NavigationLink {
                MeasurementDetailView(measurement: measurement)
            } label: {
                MeasurementRow(measurement: measurement)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Delete", role: .destructive) { pendingDelete = item }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingDelete = item } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        case .glucose(let log):
            logRow(
                icon: ManualLogType.glucose.icon,
                color: ManualLogType.glucose.color,
                title: "Blood Sugar",
                value: String(format: "%.0f mg/dl", log.value),
                date: log.createdAt,
                subtitle: log.tagId == "builtin.eating.after" ? "After Meal" : "Before Meal"
            )
            .contentShape(Rectangle())
            .onTapGesture { editingGlucose = log }
            .contextMenu {
                Button("Edit") { editingGlucose = log }
                Button("Delete", role: .destructive) { pendingDelete = item }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingDelete = item } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        case .oxygen(let log):
            logRow(
                icon: ManualLogType.oxygen.icon,
                color: ManualLogType.oxygen.color,
                title: "Blood Oxygen",
                value: "\(log.value)%",
                date: log.createdAt,
                subtitle: "SpO2"
            )
            .contentShape(Rectangle())
            .onTapGesture { editingOxygen = log }
            .contextMenu {
                Button("Edit") { editingOxygen = log }
                Button("Delete", role: .destructive) { pendingDelete = item }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingDelete = item } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        case .pressure(let log):
            logRow(
                icon: ManualLogType.pressure.icon,
                color: ManualLogType.pressure.color,
                title: "Blood Pressure",
                value: "\(log.sys)/\(log.dia) mmHg",
                date: log.createdAt,
                subtitle: MetricInsights.bloodPressureInsight(sys: Int(log.sys), dia: Int(log.dia)).status
            )
            .contentShape(Rectangle())
            .onTapGesture { editingPressure = log }
            .contextMenu {
                Button("Edit") { editingPressure = log }
                Button("Delete", role: .destructive) { pendingDelete = item }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { pendingDelete = item } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func logRow(icon: String, color: Color, title: String, value: String, date: Date, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 42, height: 42)
                .background(color.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("\(title) - \(subtitle)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.ink)
                Text(AppDate.shortDateTime(date))
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.inkSecondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.ink)
        }
        .padding(.vertical, 11)
    }

    private func dayTitle(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "Today" }
        if Calendar.current.isDateInYesterday(day) { return "Yesterday" }
        return AppDate.date(day)
    }

    private func startMeasurement() {
        if app.isMeasurementAllowed(isPremium: store.isPremium) {
            app.openMeasurement()
        } else {
            app.presentPaywall(.measurement)
        }
    }

    private func delete(_ item: HistoryItem) {
        switch item.payload {
        case .measurement(let measurement):
            MeasurementService.delete(measurement)
        case .glucose(let log):
            PersistenceController.shared.context.delete(log)
        case .oxygen(let log):
            PersistenceController.shared.context.delete(log)
        case .pressure(let log):
            PersistenceController.shared.context.delete(log)
        }
        PersistenceController.shared.save()
    }
}

struct MeasurementDetailView: View {
    let measurement: HeartRateMeasurementMO

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @State private var aiExpanded = true
    @State private var showEditTag = false
    @State private var showDelete = false
    @State private var showTrends = false
    @State private var tag: MeasurementTagSelection = .none

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
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.inkSecondary)
                        Text(AppDate.longDateTime(measurement.createdAt))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.inkSecondary)
                        Spacer()
                        Button {
                            tag = MeasurementTagSelection(tagId: measurement.tagId, isAuto: measurement.isTagAutoGenerated)
                            showEditTag = true
                        } label: {
                            if let tagInfo {
                                TagChipView(tag: tagInfo)
                            } else {
                                Text(measurement.isTagAutoGenerated ? "Auto tag" : "Add tag")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.coral)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        MetricCardView(kind: .pulse, value: Double(measurement.pulse))
                        MetricCardView(kind: .hrv, value: measurement.hrv)
                    }
                    HStack(spacing: 12) {
                        MetricCardView(kind: .stress, value: Double(measurement.stress))
                        MetricCardView(kind: .energy, value: Double(measurement.energy))
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
                    }

                    aiCard

                    Button {
                        showTrends = true
                    } label: {
                        InfoRow(icon: "chart.xyaxis.line", title: "View Trends", value: nil, tint: AppColors.teal, showChevron: true)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .cardStyle(padding: 0)

                    Text("Source: \(measurement.sourceKind == .appleWatch ? "Apple Watch / HealthKit" : "Camera PPG")")
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 26)
            }
        }
        .navigationTitle("Measurement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showEditTag = true
                    } label: {
                        Label("Edit Tag", systemImage: "tag")
                    }
                    Button(role: .destructive) {
                        showDelete = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEditTag) {
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
        .alert("Delete this measurement?", isPresented: $showDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                MeasurementService.delete(measurement)
                dismiss()
            }
        }
        .onAppear {
            MeasurementService.markAICommentRead(measurement)
            tag = MeasurementTagSelection(tagId: measurement.tagId, isAuto: measurement.isTagAutoGenerated)
        }
        .onChange(of: tag) { newValue in
            measurement.tagId = newValue.isAuto ? TagCatalog.autoTag(for: measurement.createdAt).id : newValue.tagId
            measurement.isTagAutoGenerated = newValue.isAuto
            PersistenceController.shared.save()
        }
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI Comment", systemImage: "sparkles")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.ink)
                Spacer()
                Button(aiExpanded ? "Hide" : "Show") {
                    withAnimation(.easeOut(duration: 0.2)) { aiExpanded.toggle() }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.coral)
            }
            if aiExpanded {
                Text("Overall Health State")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.inkSecondary)
                Text(aiComment.overall)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.ink)
                Text("Current State: \(tagInfo?.name ?? "General")")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.inkSecondary)
                Text(aiComment.context)
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.ink)
                Text(aiComment.battery)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.inkSecondary)
            }
        }
        .padding(16)
        .cardStyle()
    }
}
