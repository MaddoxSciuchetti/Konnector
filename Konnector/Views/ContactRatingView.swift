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
    @State private var isPhotoEditorPresented = false
    @State private var isSavingPhoto = false
    @State private var photoError: String?

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
        .sheet(isPresented: $isPhotoEditorPresented) {
            ContactPhotoEditorView(
                contactName: contact.primaryLabel,
                existingImageData: contact.thumbnailData,
                onSave: { data in
                    Task { await savePhoto(data) }
                },
                onRemove: contact.thumbnailData == nil
                    ? nil
                    : {
                        Task { await removePhoto() }
                    }
            )
        }
        .alert("Couldn’t Open Contact", isPresented: contactActionsErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(contactActionsError ?? "This contact couldn’t be opened.")
        }
        .alert("Couldn’t Update Photo", isPresented: photoErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(photoError ?? "The photo couldn’t be saved.")
        }
        .onAppear {
            markDetailOpenedAfterTransition()
        }
    }

    private var profileNoteSection: some View {
        HStack(alignment: .center, spacing: K.Spacing.md) {
            Button {
                isPhotoEditorPresented = true
            } label: {
                ContactAvatar(contact: contact, size: K.Size.Avatar.lg, showsEditBadge: true)
            }
            .buttonStyle(.plain)
            .disabled(isSavingPhoto)
            .accessibilityLabel(
                contact.thumbnailData == nil
                    ? "Add profile photo"
                    : "Change profile photo"
            )

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
        VStack(alignment: .leading, spacing: K.Spacing.xl) {
            VStack(alignment: .leading, spacing: K.Spacing.lg) {
                sectionHeader("Socials & Notes")

                HStack(spacing: K.Spacing.md) {
                    ContactLinkedInConnectView(contact: contact, layout: .button)
                    ContactVoiceNotesView(contact: contact, layout: .button)
                }

                ContactLinkedInConnectView(contact: contact, layout: .details)
                ContactVoiceNotesView(contact: contact, layout: .details)
            }

            VStack(alignment: .leading, spacing: K.Spacing.lg) {
                sectionHeader("Care")

                ContactCareView(contact: contact)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(K.Typography.sectionTitle)
            .foregroundStyle(.secondary)
    }

    private var ratingTabContent: some View {
        VStack(spacing: K.Layout.sectionSpacing) {
            ContactBadgePicker(selectedIDs: badgeSelection)
            traitScoreTriangle
        }
    }

    /// Integrity on top; Intelligence and Drive form the base — all same size.
    private var traitScoreTriangle: some View {
        let dialSize: CGFloat = 148

        return VStack(spacing: K.Spacing.xl) {
            TraitRatingSlider(
                title: "Integrity",
                value: $contact.integrityRating,
                dialSize: dialSize
            )

            HStack(alignment: .top, spacing: K.Spacing.xxl) {
                TraitRatingSlider(
                    title: "Intelligence",
                    value: $contact.intelligenceRating,
                    dialSize: dialSize
                )
                TraitRatingSlider(
                    title: "Drive",
                    value: $contact.driveRating,
                    dialSize: dialSize
                )
            }
        }
        .frame(maxWidth: .infinity)
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

    private var photoErrorBinding: Binding<Bool> {
        Binding(
            get: { photoError != nil },
            set: { isPresented in
                if !isPresented {
                    photoError = nil
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

    private func markDetailOpenedAfterTransition() {
        guard !contact.hasOpenedDetail || contact.isNewlyAdded else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            contact.markDetailOpened()
        }
    }

    @MainActor
    private func savePhoto(_ data: Data) async {
        guard !isSavingPhoto else { return }
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        contact.applyCustomThumbnail(data)

        do {
            try await syncService.updateContactPhoto(
                identifier: contact.sourceIdentifier,
                imageData: data
            )
        } catch {
            // Keep the in-app photo even if the system Contacts write fails.
            photoError = "Saved in Konnector, but couldn’t update the Contacts app: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func removePhoto() async {
        guard !isSavingPhoto else { return }
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        contact.clearCustomThumbnail()

        do {
            try await syncService.updateContactPhoto(
                identifier: contact.sourceIdentifier,
                imageData: nil
            )
        } catch {
            photoError = "Removed in Konnector, but couldn’t update the Contacts app: \(error.localizedDescription)"
        }
    }
}

private struct ContactAvatar: View {
    let contact: ContactSnapshot
    let size: CGFloat
    var showsEditBadge: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarContent

            if showsEditBadge {
                Image(systemName: contact.thumbnailData == nil ? "plus.circle.fill" : "camera.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, K.Color.primary)
                    .font(.system(size: size * 0.32))
                    .background(.white, in: .circle)
                    .offset(x: 2, y: 2)
            }
        }
    }

    @ViewBuilder
    private var avatarContent: some View {
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
                .overlay {
                    Circle()
                        .strokeBorder(K.Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
        }
    }
}
