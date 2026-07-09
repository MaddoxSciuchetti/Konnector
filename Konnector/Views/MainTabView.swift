import SwiftData
import SwiftUI

enum ContactSearchMode: String, CaseIterable {
    case standard
    case ai
    case graph

    static var allCases: [ContactSearchMode] {
        var modes: [ContactSearchMode] = [.standard, .ai]
        if GraphAPIConfiguration.isEnabled {
            modes.append(.graph)
        }
        return modes
    }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .ai: "AI Search"
        case .graph: "Graph"
        }
    }

    var systemImage: String {
        switch self {
        case .standard: "magnifyingglass"
        case .ai: "sparkles"
        }
    }
}

struct MainTabView: View {
    @State private var searchText = ""
    @State private var searchMode = ContactSearchMode.standard

    var body: some View {
        TabView {
            Tab("Contacts", systemImage: "person.2") {
                ContactListView()
            }

            Tab("Follow Up", systemImage: "checklist") {
                FollowUpView()
            }

            Tab("Search", systemImage: "magnifyingglass") {
                SearchContactsView(
                    searchText: $searchText,
                    searchMode: $searchMode
                )
            }
        }
    }
}

private struct FollowUpView: View {
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]

    private var followUps: [ContactCareFollowUpService.FollowUp] {
        ContactCareFollowUpService.upcomingFollowUps(contacts: contacts)
    }

    var body: some View {
        NavigationStack {
            Group {
                if followUps.isEmpty {
                    emptyState
                } else {
                    followUpList
                }
            }
            .navigationTitle("Follow Up")
            .background(K.Color.screenBackground)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to follow up", systemImage: "checklist")
        } description: {
            Text("Add birthdays and appointments in a contact’s Care section and they’ll appear here when they’re coming up.")
        }
    }

    private var followUpList: some View {
        List {
            Section {
                ForEach(followUps) { followUp in
                    NavigationLink {
                        ContactRatingView(contact: followUp.contact)
                    } label: {
                        FollowUpRow(followUp: followUp)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: K.Spacing.xs,
                        leading: K.Layout.screenHorizontal,
                        bottom: K.Spacing.xs,
                        trailing: K.Layout.screenHorizontal
                    ))
                }
            } header: {
                Text("Coming Up")
            } footer: {
                Text("Reminders from Care items in the next 60 days.")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct FollowUpRow: View {
    let followUp: ContactCareFollowUpService.FollowUp

    var body: some View {
        HStack(spacing: K.Spacing.md) {
            Image(systemName: followUp.careItem.kind.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(K.Color.primary)
                .frame(width: 40, height: 40)
                .background(K.Color.primarySoft, in: .circle)

            VStack(alignment: .leading, spacing: K.Spacing.xs - 2) {
                Text(followUp.headline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(followUp.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: K.Spacing.xs)

            Text(followUp.relativeLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(followUp.daysUntil <= 7 ? K.Color.primary : .secondary)
                .padding(.horizontal, K.Spacing.sm)
                .padding(.vertical, K.Spacing.xs)
                .background(
                    (followUp.daysUntil <= 7 ? K.Color.primarySoft : K.Color.tileBackground),
                    in: .capsule
                )
        }
        .kContactCard()
    }
}

struct SearchContactsView: View {
    @Environment(GraphSyncService.self) private var graphSyncService
    @Binding var searchText: String
    @Binding var searchMode: ContactSearchMode
    @AppStorage("contactGroupMode") private var groupModeRawValue = ContactGroupMode.list.rawValue
    @Query(sort: \ContactSnapshot.sortName) private var contacts: [ContactSnapshot]
    @Query(sort: \BadgeDefinition.sortOrder) private var badgeCatalog: [BadgeDefinition]
    @State private var aiQuery = ""
    @State private var aiResults: [ContactAISearchService.Match] = []
    @State private var aiSearchTask: Task<Void, Never>?
    @State private var graphQuery = ""
    @State private var graphResults: GraphSearchResponse?
    @State private var graphErrorMessage: String?
    @State private var graphSearchTask: Task<Void, Never>?

    private var groupMode: ContactGroupMode {
        ContactGroupMode(rawValue: groupModeRawValue) ?? .list
    }

    private var standardResults: [ContactSnapshot] {
        contacts.filter { $0.matches(search: searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchModeToggle(selection: $searchMode)

                Group {
                    switch searchMode {
                    case .standard:
                        standardSearchContent
                    case .ai:
                        aiSearchContent
                    case .graph:
                        graphSearchContent
                    }
                }
            }
            .navigationTitle(searchMode == .ai ? "AI Search" : searchMode == .graph ? "Graph Search" : "Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(searchMode == .ai ? K.Color.primarySoft.opacity(0.55) : .clear, for: .navigationBar)
            .toolbarBackground(searchMode == .ai ? .visible : .automatic, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if hasResults {
                        ContactGroupModePicker()
                    }
                }
            }
            .animation(.snappy, value: searchMode)
            .onChange(of: searchMode) { _, newMode in
                if newMode == .standard {
                    aiSearchTask?.cancel()
                    aiQuery = ""
                    aiResults = []
                    graphSearchTask?.cancel()
                    graphQuery = ""
                    graphResults = nil
                    graphErrorMessage = nil
                } else if newMode == .ai {
                    searchText = ""
                    graphSearchTask?.cancel()
                    graphQuery = ""
                    graphResults = nil
                    graphErrorMessage = nil
                } else {
                    searchText = ""
                    aiSearchTask?.cancel()
                    aiQuery = ""
                    aiResults = []
                }
            }
        }
        .tint(searchMode == .ai ? K.Color.primary : nil)
    }

    private var standardSearchField: some View {
        HStack(spacing: K.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(K.Color.secondary)

            TextField("Name, phone, or email", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, K.Spacing.md)
        .padding(.vertical, K.Spacing.sm + 2)
        .background(K.Color.tileBackground, in: RoundedRectangle.k(K.ButtonRadius.standard))
        .padding(.horizontal, K.Layout.screenHorizontal)
        .padding(.top, K.Spacing.sm)
        .padding(.bottom, K.Spacing.md)
    }

    private var hasResults: Bool {
        switch searchMode {
        case .standard:
            !searchText.isEmpty && !standardResults.isEmpty
        case .ai:
            !aiQuery.isEmpty && !aiResults.isEmpty
        case .graph:
            !graphQuery.isEmpty && graphResults != nil
        }
    }

    @ViewBuilder
    private var graphSearchContent: some View {
        List {
            Section {
                TextField("Organization, badge, or name", text: $graphQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: graphQuery) { _, newValue in
                        scheduleGraphSearch(for: newValue)
                    }
            } header: {
                Label("Explore relationships", systemImage: "point.3.connected.trianglepath.dotted")
            } footer: {
                Text("Find coworkers, badge communities, and related contacts from the graph.")
            }

            if graphQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("Graph Search", systemImage: "point.3.connected.trianglepath.dotted")
                    } description: {
                        Text("Try “mentor”, “Bletchley”, or a contact name.")
                    }
                    .listRowBackground(Color.clear)
                }
            } else if let graphErrorMessage {
                Section {
                    Text(graphErrorMessage)
                        .foregroundStyle(.secondary)
                }
            } else if let graphResults {
                if !graphResults.coworkers.isEmpty {
                    Section("Coworkers") {
                        ForEach(graphResults.coworkers) { match in
                            graphResultRow(
                                title: match.displayName,
                                subtitle: "\(match.organizationName) · via \(match.anchorName)"
                            )
                        }
                    }
                }

                if !graphResults.byBadge.isEmpty {
                    Section("By Badge") {
                        ForEach(graphResults.byBadge) { match in
                            graphResultRow(
                                title: match.displayName,
                                subtitle: match.badgeTitle
                            )
                        }
                    }
                }

                if !graphResults.related.isEmpty {
                    Section("Related") {
                        ForEach(graphResults.related) { match in
                            graphResultRow(
                                title: match.displayName,
                                subtitle: "Related to \(match.anchorName)"
                            )
                        }
                    }
                }

                if graphResults.coworkers.isEmpty
                    && graphResults.byBadge.isEmpty
                    && graphResults.related.isEmpty {
                    Section {
                        ContentUnavailableView {
                            Label("No Graph Matches", systemImage: "person.crop.circle.badge.questionmark")
                        } description: {
                            Text("No relationship matches for that query.")
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func graphResultRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: K.Spacing.xs) {
            Text(title)
                .font(.body.weight(.medium))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func scheduleGraphSearch(for query: String) {
        graphSearchTask?.cancel()
        graphSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else {
                graphResults = nil
                graphErrorMessage = nil
                return
            }

            do {
                graphResults = try await graphSyncService.searchGraph(query: trimmedQuery)
                graphErrorMessage = nil
            } catch {
                graphResults = nil
                graphErrorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var standardSearchContent: some View {
        VStack(spacing: 0) {
            standardSearchField

            if searchText.isEmpty {
                ContentUnavailableView {
                    Label("Search Contacts", systemImage: "magnifyingglass")
                } description: {
                    Text("Find a contact by name, organization, phone, or email.")
                }
                .frame(maxHeight: .infinity)
            } else if standardResults.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    GroupedContactListContent(contacts: standardResults, groupMode: groupMode)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(K.Color.screenBackground)
            }
        }
    }

    @ViewBuilder
    private var aiSearchContent: some View {
        List {
            Section {
                ZStack(alignment: .topLeading) {
                    if aiQuery.isEmpty {
                        Text("Describe who you’re looking for…")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, K.Spacing.xs + 2)
                            .padding(.vertical, K.Spacing.sm + 2)
                    }

                    TextEditor(text: $aiQuery)
                        .frame(minHeight: 96)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, K.Spacing.xs)
                        .padding(.vertical, K.Spacing.xs)
                        .onChange(of: aiQuery) { _, newValue in
                            scheduleAISearch(for: newValue)
                        }
                }
            } header: {
                Label("Describe this person", systemImage: "sparkles")
            } footer: {
                Text("AI search looks through names, notes, organizations, locations, and every other filled contact field.")
            }

            if aiQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("AI Search", systemImage: "sparkles")
                    } description: {
                        Text("Try “mathematician in London” or “CEO at a cloud company”.")
                    }
                    .listRowBackground(Color.clear)
                }
            } else if aiResults.isEmpty {
                Section {
                    ContentUnavailableView {
                        Label("No Matches", systemImage: "person.crop.circle.badge.questionmark")
                    } description: {
                        Text("No contacts closely match that description.")
                    }
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(aiResults) { match in
                        NavigationLink {
                            ContactRatingView(contact: match.contact)
                        } label: {
                            AISearchMatchRow(match: match)
                        }
                        .buttonStyle(.plain)
                        .navigationLinkIndicatorVisibility(.hidden)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(ContactListRowStyle.insets)
                    }
                } header: {
                    Text("Best Matches")
                } footer: {
                    Text("\(aiResults.count) contact\(aiResults.count == 1 ? "" : "s") ranked by relevance.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(K.Color.primarySoft.opacity(0.08))
    }

    private func scheduleAISearch(for query: String) {
        aiSearchTask?.cancel()
        aiSearchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedQuery.isEmpty else {
                aiResults = []
                return
            }

            aiResults = ContactAISearchService.search(
                contacts: contacts,
                badgeCatalog: badgeCatalog,
                query: trimmedQuery
            )
        }
    }
}

private struct SearchModeToggle: View {
    @Binding var selection: ContactSearchMode
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: K.Spacing.xs) {
            ForEach(ContactSearchMode.allCases, id: \.self) { mode in
                toggleOption(mode)
            }
        }
        .padding(K.Spacing.xs)
        .background(K.Color.tileBackground, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: K.Stroke.hairline)
        }
        .padding(.horizontal, K.Layout.screenHorizontal)
        .padding(.top, K.Spacing.sm)
        .padding(.bottom, K.Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search mode")
    }

    private func toggleOption(_ mode: ContactSearchMode) -> some View {
        let isSelected = selection == mode

        return Button {
            selection = mode
        } label: {
            HStack(spacing: K.Spacing.sm) {
                Image(systemName: mode.systemImage)
                    .font(.subheadline.weight(.semibold))

                Text(mode.title)
                    .font(K.Typography.buttonMedium)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity)
            .frame(height: K.Size.Button.sm)
            .background {
                if isSelected {
                    Capsule()
                        .fill(mode == .ai ? K.Color.primary : mode == .graph ? K.Color.primary.opacity(0.85) : K.Color.secondary)
                        .matchedGeometryEffect(id: "searchModeSelection", in: selectionNamespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct AISearchMatchRow: View {
    let match: ContactAISearchService.Match

    var body: some View {
        HStack(alignment: .center, spacing: K.Spacing.md) {
            VStack(alignment: .leading, spacing: K.Spacing.sm) {
                Text(match.contact.primaryLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                ContactBadgesRow(badgeIDs: match.contact.badgeIDs, style: .compact)

                if !match.matchedTerms.isEmpty {
                    Text("Matched: \(match.matchedTerms.prefix(4).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: K.Spacing.xs)

            VStack(alignment: .trailing, spacing: K.Spacing.xs) {
                ContactScoreBadge(score: match.contact.overallScore, size: K.Size.ScoreBadge.regular)

                Text(match.score, format: .number.precision(.fractionLength(1)))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(K.Color.primary)
                    .monospacedDigit()
                    .padding(.horizontal, K.Spacing.sm - 2)
                    .padding(.vertical, K.Spacing.xs - 2)
                    .background(K.Color.primarySoft, in: .capsule)
                    .accessibilityLabel("Match score \(match.score, format: .number.precision(.fractionLength(1)))")
            }
        }
        .kContactCard()
    }
}
