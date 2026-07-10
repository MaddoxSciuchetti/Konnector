import ContactsUI
import SwiftData
import SwiftUI

struct ContactListView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]
    @AppStorage("contactGroupMode") private var groupModeRawValue = ContactGroupMode.list.rawValue
    @State private var isAccessPickerPresented = false
    @State private var navigationPath = NavigationPath()
    @State private var peekContactID: String?

    private var groupMode: ContactGroupMode {
        ContactGroupMode(rawValue: groupModeRawValue) ?? .list
    }

    private var peekContact: ContactSnapshot? {
        guard let peekContactID else { return nil }
        return contacts.first { $0.sourceIdentifier == peekContactID }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if contacts.isEmpty {
                    emptyState
                } else {
                    contactList
                }
            }
            .navigationTitle("Contacts")
            .toolbar {
                if !contacts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        ContactGroupModePicker()
                    }
                }
            }
            .contactAccessPicker(isPresented: $isAccessPickerPresented) { _ in
                Task {
                    await syncService.refreshAuthorization()
                }
            }
            .alert("Couldn’t sync contacts", isPresented: syncErrorBinding) {
                Button("Try Again") { syncService.retry() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(syncErrorMessage)
            }
            .navigationDestination(for: String.self) { contactID in
                ContactDetailDestination(contactID: contactID, contacts: contacts)
            }
        }
        .overlay {
            if let peekContact {
                ContactPeekOverlay(
                    contact: peekContact,
                    onOpen: {
                        let id = peekContact.sourceIdentifier
                        peekContactID = nil
                        navigationPath.append(id)
                    },
                    onDismiss: { peekContactID = nil }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.snappy(duration: 0.22), value: peekContactID)
    }

    private var contactList: some View {
        List {
            if syncService.authorization == .limited {
                limitedAccessSection
            }

            GroupedContactListContent(
                contacts: contacts,
                groupMode: groupMode,
                peekContactID: $peekContactID,
                onSelectContact: { contactID in
                    navigationPath.append(contactID)
                }
            )
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(K.Color.screenBackground)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Contacts", systemImage: "person.2")
        } description: {
            if syncService.syncState == .syncing {
                Text("Importing your contacts…")
            } else if syncService.authorization == .limited {
                Text("Choose contacts to share with Konnector.")
            } else {
                Text("No contacts are currently available to import.")
            }
        } actions: {
            if syncService.authorization == .limited {
                Button("Choose Contacts") {
                    isAccessPickerPresented = true
                }
                .buttonStyle(.kPrimary(size: .medium))
            } else if syncService.syncState != .syncing {
                Button("Sync Again") { syncService.scheduleSync() }
                    .buttonStyle(.kSecondary(size: .medium))
            }
        }
    }

    private var limitedAccessSection: some View {
        Section {
            Button {
                isAccessPickerPresented = true
            } label: {
                Label("Manage Shared Contacts", systemImage: "person.badge.plus")
            }
        } footer: {
            Text("Konnector can only see the contacts you selected.")
        }
    }

    private var syncErrorBinding: Binding<Bool> {
        Binding(
            get: {
                if case .failed = syncService.syncState { true } else { false }
            },
            set: { isPresented in
                if !isPresented {
                    syncService.dismissError()
                }
            }
        )
    }

    private var syncErrorMessage: String {
        if case let .failed(message) = syncService.syncState { message }
        else { "An unknown error occurred." }
    }
}

struct ContactRow: View {
    let contact: ContactSnapshot

    var body: some View {
        HStack(spacing: K.Spacing.md) {
            avatar

            VStack(alignment: .leading, spacing: K.Spacing.xs) {
                HStack(spacing: K.Spacing.sm) {
                    Text(contact.primaryLabel)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if contact.isNewlyAdded {
                        ContactTagPill(
                            icon: "sparkles",
                            title: "New",
                            tint: K.Color.primary,
                            style: .compact
                        )
                    }
                }

                ContactBadgesRow(badgeIDs: contact.badgeIDs, style: .compact, displayLimit: 3)

                ContactScoreProgressBar(score: contact.overallScore)
            }
        }
        .padding(.horizontal, K.Spacing.md)
        .padding(.vertical, K.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(K.Color.cardBackground, in: RoundedRectangle.k(K.Radius.md))
        .overlay {
            RoundedRectangle.k(K.Radius.md)
                .strokeBorder(K.Color.border, lineWidth: K.Stroke.hairline)
        }
    }

    @ViewBuilder
    private var avatar: some View {
        ContactListAvatar(contact: contact, size: K.Size.Avatar.sm)
    }
}

/// Long-press peek showing trait scores and badges without opening the contact.
enum ContactPeekLayout {
    static let width: CGFloat = 300
}

struct ContactPeekPreview: View {
    let contact: ContactSnapshot

    private let traitRingSize: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: K.Layout.sectionSpacing) {
            header

            VStack(spacing: K.Spacing.md) {
                TraitScoreCircle(
                    title: "Integrity",
                    value: Double(contact.integrityRating),
                    size: traitRingSize
                )

                HStack(alignment: .top, spacing: K.Spacing.lg) {
                    TraitScoreCircle(
                        title: "Intelligence",
                        value: Double(contact.intelligenceRating),
                        size: traitRingSize
                    )
                    TraitScoreCircle(
                        title: "Drive",
                        value: Double(contact.driveRating),
                        size: traitRingSize
                    )
                }
            }
            .frame(maxWidth: .infinity)

            badgesSection
        }
        .padding(K.Layout.cardPadding)
        .frame(width: ContactPeekLayout.width)
        .background(K.Color.cardBackground)
        .clipShape(RoundedRectangle.k(K.Radius.lg))
    }

    private var header: some View {
        HStack(spacing: K.Spacing.md) {
            ContactListAvatar(contact: contact, size: K.Size.Avatar.md)

            VStack(alignment: .leading, spacing: K.Spacing.xs) {
                Text(contact.primaryLabel)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                ContactScoreProgressBar(score: contact.overallScore)
            }
        }
    }

    @ViewBuilder
    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: K.Spacing.sm) {
            Text("Badges")
                .font(K.Typography.sectionTitle)
                .foregroundStyle(.secondary)

            if contact.badgeIDs.isEmpty {
                Text("No badges yet")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    ContactBadgesRow(badgeIDs: contact.badgeIDs, style: .regular)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ContactListAvatar: View {
    let contact: ContactSnapshot
    let size: CGFloat

    var body: some View {
        if let data = contact.thumbnailData, let image = UIImage(data: data) {
            ZStack {
                Circle()
                    .fill(K.Color.primarySoft)

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipped()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .contentShape(Circle())
        } else {
            Text(contact.initials)
                .font(size >= K.Size.Avatar.md ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(K.Color.primary)
                .frame(width: size, height: size)
                .background(K.Color.primarySoft, in: .circle)
        }
    }
}

enum ContactListRowStyle {
    static var insets: EdgeInsets {
        EdgeInsets(
            top: K.Spacing.xs,
            leading: K.Layout.screenHorizontal,
            bottom: K.Spacing.xs,
            trailing: K.Layout.screenHorizontal
        )
    }
}
