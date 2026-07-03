import ContactsUI
import SwiftData
import SwiftUI

struct ContactListView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]
    @State private var searchText = ""
    @State private var isAccessPickerPresented = false
    @State private var selectedContact: SystemContact?
    @State private var isContactUnavailablePresented = false

    private var filteredContacts: [ContactSnapshot] {
        contacts.filter { $0.matches(search: searchText) }
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

                        ForEach(filteredContacts) { contact in
                            Button {
                                open(contact)
                            } label: {
                                ContactRow(contact: contact)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.plain)
                    .overlay {
                        if filteredContacts.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $searchText, prompt: "Name, phone, or email")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    syncToolbarContent
                }
            }
            .contactAccessPicker(isPresented: $isAccessPickerPresented) { _ in
                Task {
                    await syncService.refreshAuthorization()
                }
            }
            .sheet(item: $selectedContact) { contact in
                SystemContactView(contact: contact.value)
                    .ignoresSafeArea()
            }
            .alert("Contact unavailable", isPresented: $isContactUnavailablePresented) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This contact is no longer available in Apple Contacts.")
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
                .buttonStyle(.borderedProminent)
            } else if syncService.syncState != .syncing {
                Button("Sync Again") { syncService.scheduleSync() }
                    .buttonStyle(.bordered)
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

    @ViewBuilder
    private var syncToolbarContent: some View {
        if syncService.syncState == .syncing {
            ProgressView()
                .accessibilityLabel("Syncing contacts")
        } else {
            Button("Sync", systemImage: "arrow.clockwise") {
                syncService.scheduleSync()
            }
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

    private func open(_ contact: ContactSnapshot) {
        Task {
            do {
                selectedContact = try await syncService.contact(identifier: contact.sourceIdentifier)
                if selectedContact == nil {
                    isContactUnavailablePresented = true
                }
            } catch {
                isContactUnavailablePresented = true
            }
        }
    }
}

private struct ContactRow: View {
    let contact: ContactSnapshot

    var body: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                Text(contact.displayName)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                if let subtitle = contact.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = contact.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(.circle)
        } else {
            Text(contact.initials)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.12), in: .circle)
        }
    }
}

extension SystemContact: Identifiable {
    var id: String { value.identifier }
}
