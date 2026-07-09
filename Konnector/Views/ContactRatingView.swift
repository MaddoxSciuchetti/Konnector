import SwiftData
import SwiftUI

private enum ContactDetailTab: String, CaseIterable, Identifiable {
    case data = "Data"
    case rating = "Scorecard"

    var id: String { rawValue }
}

struct ContactRatingView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Bindable var contact: ContactSnapshot
    @State private var selectedTab: ContactDetailTab = .data
    @State private var systemContact: SystemContact?
    @State private var isLoadingContactActions = false
    @State private var contactActionsError: String?

    private var badgeSelection: Binding<Set<String>> {
        Binding(
            get: { Set(contact.badgeIDs) },
            set: { contact.badgeIDs = Array($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: K.Layout.sectionSpacing) {
                profileNoteSection
                tabPicker

                switch selectedTab {
                case .data:
                    dataTabContent
                case .rating:
                    ratingTabContent
                }
            }
            .kScreenPadding()
        }
        .background(K.Color.screenBackground)
        .navigationTitle(contact.primaryLabel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openContactActions()
                } label: {
                    if isLoadingContactActions {
                        ProgressView()
                    } else {
                        Label("Contact Options", systemImage: "phone.and.waveform.fill")
                    }
                }
                .disabled(isLoadingContactActions)
                .accessibilityLabel("Contact options")
            }
        }
        .sheet(item: $systemContact) { systemContact in
            SystemContactView(contact: systemContact)
        }
        .alert("Couldn’t Open Contact", isPresented: contactActionsErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactActionsError ?? "This contact couldn’t be opened.")
        }
        .onAppear {
            contact.markDetailOpened()
        }
    }

    private var profileNoteSection: some View {
        HStack(alignment: .center, spacing: K.Spacing.md) {
            ZStack(alignment: .topLeading) {
                if contact.note.isEmpty {
                    Text("Care item note…")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, K.Spacing.xs + 2)
                        .padding(.vertical, K.Spacing.sm)
                }

                TextEditor(text: $contact.note)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .frame(height: K.Size.Avatar.lg)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, K.Spacing.xs)
                    .padding(.vertical, K.Spacing.xs - 2)
            }
            .background(K.Color.tileBackground, in: RoundedRectangle.k(K.Radius.sm))

            ContactAvatar(contact: contact, size: K.Size.Avatar.lg)
        }
    }

    private var tabPicker: some View {
        Picker("Section", selection: $selectedTab) {
            ForEach(ContactDetailTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    private var dataTabContent: some View {
        VStack(alignment: .leading, spacing: K.Layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: K.Spacing.md) {
                sectionHeader("Socials & Notes")

                HStack(spacing: K.Spacing.md) {
                    ContactLinkedInConnectView(contact: contact, layout: .button)
                    ContactVoiceNotesView(contact: contact, layout: .button)
                }

                ContactLinkedInConnectView(contact: contact, layout: .details)
                ContactVoiceNotesView(contact: contact, layout: .details)
            }

            VStack(alignment: .leading, spacing: K.Spacing.md) {
                sectionHeader("Care")

                ContactCareView(contact: contact)
            }

            if GraphAPIConfiguration.isEnabled {
                VStack(alignment: .leading, spacing: K.Spacing.md) {
                    sectionHeader("Network Intelligence")

                    VStack(spacing: K.Spacing.sm) {
                        NavigationLink {
                            ContactNetworkView(contact: contact)
                        } label: {
                            Label("View Network", systemImage: "point.3.connected.trianglepath.dotted")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.kSecondary(size: .medium))

                        NavigationLink {
                            ContactCommonalitiesView(contact: contact)
                        } label: {
                            Label("What Do You Have in Common?", systemImage: "person.2.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.kSecondary(size: .medium))
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(K.Typography.sectionTitle)
            .foregroundStyle(.secondary)
    }

    private var ratingTabContent: some View {
        VStack(spacing: K.Layout.sectionSpacing) {
            ContactBadgePicker(selectedIDs: badgeSelection)

            HStack(alignment: .top, spacing: K.Spacing.md) {
                TraitRatingSlider(title: "Intelligence", value: $contact.intelligenceRating)
                TraitRatingSlider(title: "Integrity", value: $contact.integrityRating)
                TraitRatingSlider(title: "Drive", value: $contact.driveRating)
            }
        }
    }

    private var contactActionsErrorBinding: Binding<Bool> {
        Binding(
            get: { contactActionsError != nil },
            set: { isPresented in
                if !isPresented {
                    contactActionsError = nil
                }
            }
        )
    }

    private func openContactActions() {
        guard !isLoadingContactActions else { return }

        Task {
            isLoadingContactActions = true
            defer { isLoadingContactActions = false }

            do {
                if let fetchedContact = try await syncService.contact(identifier: contact.sourceIdentifier) {
                    systemContact = fetchedContact
                } else {
                    contactActionsError = "This contact is no longer available in your address book."
                }
            } catch {
                contactActionsError = error.localizedDescription
            }
        }
    }
}

private struct ContactAvatar: View {
    let contact: ContactSnapshot
    let size: CGFloat

    var body: some View {
        if let data = contact.thumbnailData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(.circle)
        } else {
            Text(contact.initials)
                .font(.title2.weight(.semibold))
                .foregroundStyle(K.Color.primary)
                .frame(width: size, height: size)
                .background(K.Color.primarySoft, in: .circle)
        }
    }
}
