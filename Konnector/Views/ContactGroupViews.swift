import SwiftData
import SwiftUI

struct ContactGroupModePicker: View {
    @AppStorage("contactGroupMode") private var groupMode = ContactGroupMode.list.rawValue

    private var selection: Binding<ContactGroupMode> {
        Binding(
            get: { ContactGroupMode(rawValue: groupMode) ?? .list },
            set: { groupMode = $0.rawValue }
        )
    }

    var body: some View {
        Menu {
            Picker("Filter By", selection: selection) {
                ForEach(ContactGroupMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }
        } label: {
            Text("Filter")
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.kSecondary(size: .small, corner: .prominent, expands: false))
        .accessibilityLabel("Filter contacts")
    }
}

struct ContactGroupSectionHeader: View {
    let section: ContactListSection

    var body: some View {
        HStack(spacing: K.Spacing.md) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(section.tint)
                .frame(width: 3, height: 34)

            Image(systemName: section.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(section.tint)
                .frame(width: 34, height: 34)
                .background(section.tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: K.Spacing.xs - 2) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let subtitle = section.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            Text("\(section.contacts.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(section.tint)
                .monospacedDigit()
                .padding(.horizontal, K.Spacing.sm + 1)
                .padding(.vertical, K.Spacing.xs + 1)
                .background(section.tint.opacity(0.12), in: Capsule())
        }
        .textCase(nil)
        .padding(.top, K.Spacing.sm + 2)
        .padding(.bottom, K.Spacing.sm - 2)
        .listRowInsets(EdgeInsets())
    }
}

struct GroupedContactListContent: View {
    let contacts: [ContactSnapshot]
    let groupMode: ContactGroupMode
    @Query(sort: \BadgeDefinition.sortOrder) private var badgeCatalog: [BadgeDefinition]

    private var sections: [ContactListSection] {
        ContactListGrouping.sections(for: contacts, mode: groupMode, badgeCatalog: badgeCatalog)
    }

    var body: some View {
        if groupMode == .list {
            ContactListRows(contacts: contacts)
        } else {
            ForEach(sections) { section in
                Section {
                    ContactListRows(contacts: section.contacts)
                } header: {
                    ContactGroupSectionHeader(section: section)
                }
            }
        }
    }
}

struct ContactListRows: View {
    let contacts: [ContactSnapshot]

    var body: some View {
        ForEach(contacts) { contact in
            NavigationLink {
                ContactRatingView(contact: contact)
            } label: {
                ContactRow(contact: contact)
            }
            .buttonStyle(.plain)
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(ContactListRowStyle.insets)
        }
    }
}
