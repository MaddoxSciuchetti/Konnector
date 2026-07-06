import SwiftData
import SwiftUI

struct ContactTagPill: View {
    enum Style {
        case compact
        case regular
    }

    let icon: String
    let title: String
    let tint: Color
    var style: Style = .regular

    private var font: Font {
        style == .compact ? K.Typography.badgeCompact : K.Typography.badgeRegular
    }

    private var horizontalPadding: CGFloat {
        style == .compact ? K.Spacing.sm + 2 : K.Spacing.md
    }

    private var verticalPadding: CGFloat {
        style == .compact ? K.Spacing.sm - 2 : K.Spacing.sm
    }

    var body: some View {
        HStack(spacing: K.Spacing.xs) {
            Image(systemName: icon)
                .font(font)
            Text(title)
                .font(font)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

struct BadgeDefinitionLabel: View {
    let badge: BadgeDefinition
    var style: ContactTagPill.Style = .regular

    var body: some View {
        ContactTagPill(
            icon: badge.systemImage,
            title: badge.title,
            tint: badge.tint,
            style: style
        )
    }
}

struct ContactBadgesRow: View {
    let badgeIDs: [String]
    var style: ContactTagPill.Style = .compact
    @Query(sort: \BadgeDefinition.sortOrder) private var catalog: [BadgeDefinition]

    private var assignedBadges: [BadgeDefinition] {
        let selected = Set(badgeIDs)
        return catalog
            .filter { selected.contains($0.identifier) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        if !assignedBadges.isEmpty {
            HStack(spacing: K.Spacing.sm) {
                ForEach(assignedBadges, id: \.identifier) { badge in
                    BadgeDefinitionLabel(badge: badge, style: style)
                }
            }
        }
    }
}

struct ContactBadgePicker: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BadgeDefinition.sortOrder) private var catalog: [BadgeDefinition]
    @Binding var selectedIDs: Set<String>
    @State private var isAddBadgePresented = false

    private var selectedBadges: [BadgeDefinition] {
        catalog.filter { selectedIDs.contains($0.identifier) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: K.Spacing.md) {
            if !selectedBadges.isEmpty {
                FlowLayout(spacing: K.Spacing.sm) {
                    ForEach(selectedBadges, id: \.identifier) { badge in
                        BadgeDefinitionLabel(badge: badge, style: .regular)
                    }
                }
            }

            Menu {
                ForEach(catalog, id: \.identifier) { badge in
                    Button {
                        toggle(badge.identifier)
                    } label: {
                        if selectedIDs.contains(badge.identifier) {
                            Label(badge.title, systemImage: "checkmark")
                        } else {
                            Label(badge.title, systemImage: badge.systemImage)
                        }
                    }
                }

                Divider()

                Button {
                    isAddBadgePresented = true
                } label: {
                    Label("Add Custom Badge…", systemImage: "plus")
                }
            } label: {
                Label("Choose Badges", systemImage: "tag")
            }
            .buttonStyle(.kPrimary(size: .medium, corner: .prominent, expands: true))
        }
        .sheet(isPresented: $isAddBadgePresented) {
            AddCustomBadgeSheet()
        }
    }

    private func toggle(_ identifier: String) {
        if selectedIDs.contains(identifier) {
            selectedIDs.remove(identifier)
        } else {
            selectedIDs.insert(identifier)
        }
    }
}

struct AddCustomBadgeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<BadgeDefinition> { $0.isCustom }, sort: \BadgeDefinition.sortOrder)
    private var customBadges: [BadgeDefinition]

    @State private var title = ""
    @State private var selectedIcon = AddCustomBadgeSheet.iconOptions[0]
    @State private var usesPrimaryTint = true
    @State private var errorMessage: String?

    static let iconOptions = [
        "tag.fill", "star.fill", "heart.fill", "bolt.fill", "flag.fill",
        "bookmark.fill", "person.fill", "building.2.fill", "graduationcap.fill",
        "sportscourt.fill", "airplane", "leaf.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Badge name", text: $title)
                        .textInputAutocapitalization(.words)

                    Picker("Color", selection: $usesPrimaryTint) {
                        Text("Primary").tag(true)
                        Text("Secondary").tag(false)
                    }
                } header: {
                    Text("New Badge")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: K.Spacing.sm) {
                        ForEach(Self.iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(selectedIcon == icon ? .white : K.Color.primary)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedIcon == icon ? K.Color.primary : K.Color.primarySoft,
                                        in: Circle()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, K.Spacing.xs)
                } header: {
                    Text("Icon")
                }

                if !customBadges.isEmpty {
                    Section {
                        ForEach(customBadges, id: \.identifier) { badge in
                            HStack(spacing: K.Spacing.sm) {
                                Image(systemName: badge.systemImage)
                                    .foregroundStyle(badge.tint)
                                Text(badge.title)
                            }
                        }
                        .onDelete(perform: deleteCustomBadges)
                    } header: {
                        Text("Your Custom Badges")
                    }
                }
            }
            .navigationTitle("Custom Badge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addBadge() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Couldn’t Add Badge", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func addBadge() {
        do {
            _ = try BadgeCatalogService.createCustom(
                title: title,
                systemImage: selectedIcon,
                usesPrimaryTint: usesPrimaryTint,
                in: modelContext
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCustomBadges(at offsets: IndexSet) {
        for index in offsets {
            let badge = customBadges[index]
            try? BadgeCatalogService.delete(badge, in: modelContext)
        }
    }
}

/// Simple horizontal flow for badge pills.
private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
