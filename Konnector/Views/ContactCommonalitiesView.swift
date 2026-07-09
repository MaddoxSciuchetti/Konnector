import SwiftData
import SwiftUI

struct ContactCommonalitiesView: View {
    @Environment(GraphSyncService.self) private var graphSyncService
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]

    let contact: ContactSnapshot

    @State private var selectedContactID: String?
    @State private var commonalities: GraphCommonalitiesResponse?
    @State private var errorMessage: String?
    @State private var isLoading = false

    private var otherContacts: [ContactSnapshot] {
        contacts.filter { $0.sourceIdentifier != contact.sourceIdentifier }
    }

    private var selectedContact: ContactSnapshot? {
        guard let selectedContactID else { return nil }
        return contacts.first { $0.sourceIdentifier == selectedContactID }
    }

    var body: some View {
        Form {
            Section("Compare With") {
                Picker("Contact", selection: $selectedContactID) {
                    Text("Choose a contact").tag(String?.none)
                    ForEach(otherContacts) { candidate in
                        Text(candidate.primaryLabel).tag(Optional(candidate.sourceIdentifier))
                    }
                }
            }

            if isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let commonalities {
                if !commonalities.sharedOrganizations.isEmpty {
                    Section("Shared Organizations") {
                        ForEach(commonalities.sharedOrganizations, id: \.self) { organization in
                            Label(organization, systemImage: "building.2")
                        }
                    }
                }

                if !commonalities.sharedBadges.isEmpty {
                    Section("Shared Badges") {
                        ForEach(commonalities.sharedBadges, id: \.self) { badge in
                            Label(badge, systemImage: "tag")
                        }
                    }
                }

                if !commonalities.mutualConnections.isEmpty {
                    Section("Mutual Connections") {
                        ForEach(commonalities.mutualConnections) { connection in
                            Label(connection.displayName, systemImage: "person.2")
                        }
                    }
                }

                if commonalities.sharedOrganizations.isEmpty
                    && commonalities.sharedBadges.isEmpty
                    && commonalities.mutualConnections.isEmpty {
                    Section {
                        Text("No shared organizations, badges, or mutual connections yet.")
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("In Common")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedContactID) { _, _ in
            Task { await loadCommonalities() }
        }
    }

    private func loadCommonalities() async {
        guard let selectedContact else {
            commonalities = nil
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            commonalities = try await graphSyncService.fetchCommonalities(
                between: contact,
                and: selectedContact
            )
            errorMessage = nil
        } catch {
            commonalities = nil
            errorMessage = error.localizedDescription
        }
    }
}
