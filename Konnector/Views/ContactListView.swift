import ContactsUI
import SwiftData
import SwiftUI

struct ContactListView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]
    @AppStorage("contactGroupMode") private var groupModeRawValue = ContactGroupMode.list.rawValue
    @State private var isAccessPickerPresented = false

    private var groupMode: ContactGroupMode {
        ContactGroupMode(rawValue: groupModeRawValue) ?? .list
    }

    var body: some View {
        NavigationStack {
            Group {
                if contacts.isEmpty {
                    emptyState
                } else {
                    List {
                        if syncService.authorization == .limited {
                            limitedAccessSection
                        }

                        GroupedContactListContent(contacts: contacts, groupMode: groupMode)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(K.Color.screenBackground)
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
        }
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

            VStack(alignment: .leading, spacing: K.Spacing.sm) {
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

                ContactBadgesRow(badgeIDs: contact.badgeIDs, style: .compact)
            }

            Spacer(minLength: K.Spacing.xs)

            ContactScoreBadge(score: contact.overallScore, size: K.Size.ScoreBadge.regular)
        }
        .kContactCard()
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = contact.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: K.Size.Avatar.sm, height: K.Size.Avatar.sm)
                .clipShape(.circle)
        } else {
            Text(contact.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(K.Color.primary)
                .frame(width: K.Size.Avatar.sm, height: K.Size.Avatar.sm)
                .background(K.Color.primarySoft, in: .circle)
        }
    }
}

enum ContactListRowStyle {
    static var insets: EdgeInsets {
        EdgeInsets(
            top: K.Spacing.sm,
            leading: K.Layout.screenHorizontal,
            bottom: K.Spacing.sm,
            trailing: K.Layout.screenHorizontal
        )
    }
}
