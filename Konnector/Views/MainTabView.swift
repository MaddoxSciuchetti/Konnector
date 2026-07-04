import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(ContactSyncService.self) private var syncService
    @State private var searchText = ""
    @State private var selectedContact: SystemContact?
    @State private var isContactUnavailablePresented = false

    var body: some View {
        TabView {
            Tab("Contacts", systemImage: "person.2") {
                ContactListView(onSelect: open)
            }

            Tab("Follow Up", systemImage: "checklist") {
                FollowUpView()
            }

            Tab(role: .search) {
                SearchContactsView(searchText: $searchText, onSelect: open)
            }
        }
        .searchable(text: $searchText, prompt: "Name, phone, or email")
        .sheet(item: $selectedContact) { contact in
            SystemContactView(contact: contact)
                .ignoresSafeArea()
        }
        .alert("Contact unavailable", isPresented: $isContactUnavailablePresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This contact is no longer available in Apple Contacts.")
        }
    }

    private func open(_ snapshot: ContactSnapshot) {
        Task {
            do {
                selectedContact = try await syncService.contact(identifier: snapshot.sourceIdentifier)
                if selectedContact == nil {
                    isContactUnavailablePresented = true
                }
            } catch {
                isContactUnavailablePresented = true
            }
        }
    }
}

private struct FollowUpView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing to follow up", systemImage: "checklist")
            } description: {
                Text("Suggested actions you can review and confirm will appear here in a future update.")
            }
            .navigationTitle("Follow Up")
        }
    }
}

private struct SearchContactsView: View {
    @Binding var searchText: String
    let onSelect: (ContactSnapshot) -> Void
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]

    private var results: [ContactSnapshot] {
        contacts.filter { $0.matches(search: searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if searchText.isEmpty {
                    ContentUnavailableView {
                        Label("Search Contacts", systemImage: "magnifyingglass")
                    } description: {
                        Text("Find a contact by name, organization, phone, or email.")
                    }
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(results) { contact in
                        Button {
                            onSelect(contact)
                        } label: {
                            ContactRow(contact: contact)
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Search")
        }
    }
}
