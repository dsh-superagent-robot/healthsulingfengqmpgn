import SwiftUI
import CoreData

struct TagSelectionView: View {
    enum Mode {
        case measurement
        case filter
    }

    @Binding var selection: MeasurementTagSelection
    var mode: Mode = .measurement
    var onSelectFilter: ((String?) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var customTags: FetchedResults<CustomTagMO>

    @State private var showCreateTag = false
    @State private var editingTag: CustomTagMO?
    @State private var showTagLimit = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(mode == .measurement ? "Select Tag" : "Filter by Tag")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.ink)
                        Text(mode == .measurement
                             ? "Tag your measurements to better understand how your lifestyle impacts your heart rate."
                             : "Only show measurements that match a tag.")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.inkSecondary)
                    }

                    if mode == .filter {
                        choiceRow(
                            icon: "square.grid.2x2",
                            title: "All Data",
                            subtitle: "Remove the tag filter",
                            selected: selection.tagId == nil && !selection.isAuto,
                            color: AppColors.ink
                        ) {
                            onSelectFilter?(nil)
                            dismiss()
                        }
                    } else {
                        choiceRow(
                            icon: "wand.and.stars",
                            title: "Auto",
                            subtitle: "Let \(Brand.name) infer context from the time of day",
                            selected: selection.isAuto && selection.tagId == nil,
                            color: AppColors.periwinkle
                        ) {
                            selection = MeasurementTagSelection(tagId: nil, isAuto: true)
                            dismiss()
                        }
                        choiceRow(
                            icon: "tag.slash",
                            title: "No Tag",
                            subtitle: "Measure without a context tag",
                            selected: selection.tagId == nil && !selection.isAuto,
                            color: AppColors.inkSecondary
                        ) {
                            selection = .none
                            dismiss()
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Context groups")
                            .sectionTitle()
                        ForEach(TagGroup.allCases) { group in
                            VStack(alignment: .leading, spacing: 9) {
                                HStack(spacing: 8) {
                                    Image(systemName: group.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(group.color)
                                    Text(group.title)
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.ink)
                                    Spacer()
                                }
                                FlowLayout(spacing: 8) {
                                    ForEach(group.timings, id: \.self) { timing in
                                        let info = TagInfo.builtIn(group, timing)
                                        TagChipView(tag: info, selected: selection.tagId == info.id) {
                                            if mode == .filter {
                                                onSelectFilter?(info.id)
                                                dismiss()
                                            } else {
                                                selection = MeasurementTagSelection(tagId: info.id, isAuto: false)
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .cardStyle(padding: 0)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Custom tags")
                                .sectionTitle()
                            Spacer()
                            Button {
                                if customTags.count >= 20 {
                                    showTagLimit = true
                                } else {
                                    showCreateTag = true
                                }
                            } label: {
                                Label("New", systemImage: "plus")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                        }
                        if customTags.isEmpty {
                            Text("Create your own tags for moments that matter to you.")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.inkSecondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(customTags) { tag in
                                    let info = TagCatalog.info(for: tag)
                                    TagChipView(tag: info, selected: selection.tagId == info.id) {
                                        if mode == .filter {
                                            onSelectFilter?(info.id)
                                            dismiss()
                                        } else {
                                            selection = MeasurementTagSelection(tagId: info.id, isAuto: false)
                                            dismiss()
                                        }
                                    }
                                    .contextMenu {
                                        Button("Edit") { editingTag = tag }
                                        Button("Delete", role: .destructive) { delete(tag) }
                                    }
                                }
                            }
                            Text("Long-press a tag to edit or delete it.")
                                .font(.system(size: 11))
                                .foregroundColor(AppColors.inkSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCreateTag) {
            TagEditorView(tag: nil)
                .presentationDetents([.large])
        }
        .sheet(item: $editingTag) { tag in
            TagEditorView(tag: tag)
                .presentationDetents([.large])
        }
        .alert("Tag limit reached 20/20", isPresented: $showTagLimit) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Delete a custom tag before creating another one.")
        }
    }

    private func choiceRow(icon: String, title: String, subtitle: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selected ? .white : color)
                    .frame(width: 38, height: 38)
                    .background(selected ? color : color.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.ink)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                }
            }
            .padding(13)
            .cardStyle(padding: 0)
        }
        .buttonStyle(.plain)
    }

    private func delete(_ tag: CustomTagMO) {
        let context = PersistenceController.shared.context
        context.delete(tag)
        PersistenceController.shared.save()
        if selection.tagId == tag.id.uuidString {
            selection = .none
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct TagFilterSheet: View {
    @Binding var selectedTagID: String?
    @Environment(\.dismiss) private var dismiss
    @State private var selection = MeasurementTagSelection.none

    var body: some View {
        TagSelectionView(selection: $selection, mode: .filter) { tagID in
            selectedTagID = tagID
        }
        .onAppear {
            selection = MeasurementTagSelection(tagId: selectedTagID, isAuto: false)
        }
    }
}

struct TagEditorView: View {
    let tag: CustomTagMO?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @State private var name = ""
    @State private var cluster: TagCluster = .general
    @State private var palette: TagPalette = .green
    @State private var showDeleteAlert = false

    init(tag: CustomTagMO?) {
        self.tag = tag
        _name = State(initialValue: tag?.name ?? "")
        _cluster = State(initialValue: TagCluster(rawValue: tag?.cluster ?? "general") ?? .general)
        _palette = State(initialValue: TagPalette(rawValue: tag?.colorName ?? "green") ?? .green)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Name")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.inkSecondary)
                        TextField("Name", text: $name)
                            .font(.system(size: 16, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Color")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.inkSecondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 9), spacing: 10) {
                            ForEach(TagPalette.allCases) { color in
                                Button {
                                    palette = color
                                } label: {
                                    Circle()
                                        .fill(color.color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle()
                                                .stroke(AppColors.ink, lineWidth: palette == color ? 2 : 0)
                                                .padding(-3)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("Tag Cluster")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.inkSecondary)
                        ForEach(TagCluster.allCases) { item in
                            Button {
                                cluster = item
                            } label: {
                                HStack(spacing: 12) {
                                    Circle().fill(item.color).frame(width: 9, height: 9)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(AppColors.ink)
                                        Text(item.subtitle)
                                            .font(.system(size: 11))
                                            .foregroundColor(AppColors.inkSecondary)
                                    }
                                    Spacer()
                                    if cluster == item {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(AppColors.coral)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(cluster == item ? AppColors.coral.opacity(0.08) : AppColors.surfaceMuted)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if tag != nil {
                        Button("Delete Tag", role: .destructive) { showDeleteAlert = true }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppColors.danger)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
            .background(AppColors.background)
            .navigationTitle(tag == nil ? "New Tag" : "Edit Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .alert("Delete this custom tag?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { delete() }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let context = PersistenceController.shared.context
        if let tag {
            tag.name = trimmed
            tag.cluster = cluster.rawValue
            tag.colorName = palette.rawValue
        } else {
            let created = CustomTagMO(context: context)
            created.id = UUID()
            created.name = trimmed
            created.cluster = cluster.rawValue
            created.colorName = palette.rawValue
            created.createdAt = Date()
        }
        PersistenceController.shared.save()
        dismiss()
    }

    private func delete() {
        guard let tag else { return }
        PersistenceController.shared.context.delete(tag)
        PersistenceController.shared.save()
        dismiss()
    }
}

struct TagsManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: true)])
    private var tags: FetchedResults<CustomTagMO>

    @State private var showEditor = false
    @State private var editing: CustomTagMO?
    @State private var showLimit = false

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Create tags for meals, workouts, deep work or anything that helps you understand your heart. You can create up to 20 custom tags.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.inkSecondary)

                    if tags.isEmpty {
                        EmptyStateView(
                            icon: "tag",
                            title: "No custom tags yet",
                            message: "Create a tag to add personal context to your measurements.",
                            actionTitle: "Create Tag",
                            action: { showEditor = true }
                        )
                        .cardStyle()
                    } else {
                        VStack(spacing: 0) {
                            ForEach(tags) { tag in
                                Button {
                                    editing = tag
                                } label: {
                                    HStack(spacing: 12) {
                                        let info = TagCatalog.info(for: tag)
                                        Circle()
                                            .fill(info.color)
                                            .frame(width: 12, height: 12)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(tag.name)
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(AppColors.ink)
                                            Text(info.cluster.title)
                                                .font(.system(size: 12))
                                                .foregroundColor(AppColors.inkSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(AppColors.inkSecondary.opacity(0.6))
                                    }
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                                if tag.id != tags.last?.id { DividerLine() }
                            }
                        }
                        .padding(.horizontal, 14)
                        .cardStyle(padding: 0)
                    }

                    Text("\(tags.count) / 20 custom tags")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.inkSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Custom Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if tags.count >= 20 { showLimit = true } else { showEditor = true }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showEditor) {
            TagEditorView(tag: nil)
                .presentationDetents([.large])
        }
        .sheet(item: $editing) { tag in
            TagEditorView(tag: tag)
                .presentationDetents([.large])
        }
        .alert("Tag limit reached 20/20", isPresented: $showLimit) {
            Button("OK", role: .cancel) {}
        }
    }
}
