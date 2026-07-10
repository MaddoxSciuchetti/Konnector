import SwiftData
import SwiftUI
import UIKit

struct ContactDetailDestination: View {
    let contactID: String
    let contacts: [ContactSnapshot]

    var body: some View {
        if let contact = contacts.first(where: { $0.sourceIdentifier == contactID }) {
            ContactRatingView(contact: contact)
                .id(contact.sourceIdentifier)
        }
    }
}

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
    @Binding var peekContactID: String?
    var onSelectContact: (String) -> Void
    @Query(sort: \BadgeDefinition.sortOrder) private var badgeCatalog: [BadgeDefinition]

    private var sections: [ContactListSection] {
        ContactListGrouping.sections(for: contacts, mode: groupMode, badgeCatalog: badgeCatalog)
    }

    var body: some View {
        Group {
            if groupMode == .list {
                ContactListRows(
                    contacts: contacts,
                    peekContactID: $peekContactID,
                    onSelectContact: onSelectContact
                )
            } else {
                ForEach(sections) { section in
                    Section {
                        ContactListRows(
                            contacts: section.contacts,
                            peekContactID: $peekContactID,
                            onSelectContact: onSelectContact
                        )
                    } header: {
                        ContactGroupSectionHeader(section: section)
                    }
                }
            }
        }
    }
}

struct ContactListRows: View {
    let contacts: [ContactSnapshot]
    @Binding var peekContactID: String?
    var onSelectContact: (String) -> Void

    var body: some View {
        ForEach(contacts) { contact in
            ContactRow(contact: contact)
                .contentShape(RoundedRectangle.k(K.Radius.md))
                .gesture(rowGesture(for: contact))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    onSelectContact(contact.sourceIdentifier)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(ContactListRowStyle.insets)
        }
    }

    private func rowGesture(for contact: ContactSnapshot) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first(true):
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 1)
                    peekContactID = contact.sourceIdentifier
                case .second:
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.7)
                    onSelectContact(contact.sourceIdentifier)
                case .first(false):
                    break
                }
            }
    }
}

/// Screen-centered peek card with a full-bleed dimmed backdrop.
struct ContactPeekOverlay: View {
    let contact: ContactSnapshot
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.4))
                .ignoresSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(spacing: K.Spacing.sm) {
                ContactPeekPreview(contact: contact)

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.8)
                    onOpen()
                } label: {
                    Label("Open Contact", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.kPrimary(size: .medium, corner: .standard))
                .frame(width: ContactPeekLayout.width)
            }
            .padding(K.Spacing.sm)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.all)
        .accessibilityAddTraits(.isModal)
    }
}
