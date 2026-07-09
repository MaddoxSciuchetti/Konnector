import SwiftUI

struct ContactNetworkView: View {
    @Environment(GraphSyncService.self) private var graphSyncService
    let contact: ContactSnapshot

    @State private var network: GraphNetworkResponse?
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading network…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let network {
                networkContent(network)
            } else {
                ContentUnavailableView {
                    Label("No Network Data", systemImage: "point.3.connected.trianglepath.dotted")
                } description: {
                    Text(errorMessage ?? "Sync contacts to the graph service to explore relationships.")
                }
            }
        }
        .navigationTitle("Network")
        .navigationBarTitleDisplayMode(.inline)
        .background(K.Color.screenBackground)
        .task {
            await loadNetwork()
        }
    }

    @ViewBuilder
    private func networkContent(_ network: GraphNetworkResponse) -> some View {
        List {
            Section("Center") {
                networkRow(network.center, emphasized: true)
            }

            if !relationshipContacts(in: network).isEmpty {
                Section("People") {
                    ForEach(relationshipContacts(in: network)) { node in
                        networkRow(node, emphasized: false)
                    }
                }
            }

            if !organizationNodes(in: network).isEmpty {
                Section("Organizations") {
                    ForEach(organizationNodes(in: network)) { node in
                        Label(node.title, systemImage: "building.2")
                    }
                }
            }

            if !network.edges.isEmpty {
                Section("Connections") {
                    ForEach(network.edges) { edge in
                        VStack(alignment: .leading, spacing: K.Spacing.xs) {
                            Text(edgeTitle(edge))
                                .font(.subheadline.weight(.medium))
                            if let label = edge.label, !label.isEmpty {
                                Text(label)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func relationshipContacts(in network: GraphNetworkResponse) -> [GraphNetworkNode] {
        network.nodes.filter { $0.kind == "contact" && $0.isCenter != true }
    }

    private func organizationNodes(in network: GraphNetworkResponse) -> [GraphNetworkNode] {
        network.nodes.filter { $0.kind == "organization" }
    }

    private func networkRow(_ node: GraphNetworkNode, emphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: K.Spacing.xs) {
            Text(node.title)
                .font(emphasized ? .headline : .body)
            if let organizationName = node.organizationName, !organizationName.isEmpty {
                Text(organizationName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let jobTitle = node.jobTitle, !jobTitle.isEmpty {
                Text(jobTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func edgeTitle(_ edge: GraphNetworkEdge) -> String {
        switch edge.type {
        case "KNOWS":
            "Knows \(edge.to)"
        case "KNOWS_EXTERNAL":
            "Knows \(edge.to) (external)"
        case "WORKS_AT":
            "Works at \(edge.to)"
        default:
            "\(edge.type) → \(edge.to)"
        }
    }

    private func loadNetwork() async {
        isLoading = true
        defer { isLoading = false }
        do {
            network = try await graphSyncService.fetchNetwork(for: contact)
            errorMessage = nil
        } catch {
            network = nil
            errorMessage = error.localizedDescription
        }
    }
}
