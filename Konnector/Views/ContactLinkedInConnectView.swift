import SwiftUI

enum ContactLinkedInConnectLayout {
    case button
    case details
}

struct ContactLinkedInConnectView: View {
    @Bindable var contact: ContactSnapshot
    var layout: ContactLinkedInConnectLayout = .details

    @State private var linkedInError: String?
    @State private var isEditorPresented = false

    var body: some View {
        Group {
            switch layout {
            case .button:
                linkedInButton
            case .details:
                if contact.savedOrDetectedLinkedInProfileURL != nil {
                    profileContent
                }
            }
        }
        .alert("Couldn’t Open LinkedIn", isPresented: linkedInErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkedInError ?? "LinkedIn couldn’t be opened.")
        }
        .sheet(isPresented: $isEditorPresented) {
            LinkedInProfileEditorSheet(contact: contact)
        }
    }

    private var profileContent: some View {
        VStack(alignment: .leading, spacing: K.Spacing.md) {
            Label("LinkedIn profile", systemImage: "link")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(K.Color.primary)

            if let savedAt = contact.linkedInConnectedAt, !contact.linkedInProfileURL.isEmpty {
                Text("Saved \(savedAt.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let profileURL = contact.savedOrDetectedLinkedInProfileURL {
                Text(profileURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: K.Spacing.sm) {
                if contact.savedOrDetectedLinkedInProfileURL != nil {
                    Button {
                        openLinkedInProfile()
                    } label: {
                        Label("Open Profile", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.kSecondary(size: .medium, corner: .standard, expands: true))
                }

                Button {
                    isEditorPresented = true
                } label: {
                    Label(contact.linkedInProfileURL.isEmpty ? "Save Link" : "Edit Link", systemImage: "square.and.pencil")
                }
                .buttonStyle(.kTertiary(size: .medium, corner: .standard, expands: true))
            }
        }
    }

    private var linkedInButton: some View {
        Button {
            if contact.savedOrDetectedLinkedInProfileURL != nil {
                openLinkedInProfile()
            } else {
                isEditorPresented = true
            }
        } label: {
            Label(
                contact.savedOrDetectedLinkedInProfileURL == nil ? "Add LinkedIn" : "LinkedIn",
                systemImage: contact.savedOrDetectedLinkedInProfileURL == nil ? "qrcode.viewfinder" : "arrow.up.right.square"
            )
        }
        .buttonStyle(.kPrimary(size: .medium, corner: .prominent, expands: true))
    }

    private var linkedInErrorBinding: Binding<Bool> {
        Binding(
            get: { linkedInError != nil },
            set: { isPresented in
                if !isPresented {
                    linkedInError = nil
                }
            }
        )
    }

    private func openLinkedInProfile() {
        do {
            guard let profileURL = contact.savedOrDetectedLinkedInProfileURL else {
                isEditorPresented = true
                return
            }
            try LinkedInConnectionService.openProfile(profileURL)
        } catch {
            linkedInError = error.localizedDescription
        }
    }
}

private struct LinkedInProfileEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var contact: ContactSnapshot

    @State private var profileValue = ""
    @State private var validationError: String?
    @State private var isScannerPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("linkedin.com/in/username", text: $profileValue)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    if let validationError {
                        Text(validationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Profile Link")
                }

                Section {
                    Button {
                        isScannerPresented = true
                    } label: {
                        Label("Scan LinkedIn QR Code", systemImage: "qrcode.viewfinder")
                    }

                    Button {
                        openLinkedInSearch()
                    } label: {
                        Label("Search LinkedIn", systemImage: "magnifyingglass")
                    }

                    if !contact.linkedInProfileURL.isEmpty {
                        Button(role: .destructive) {
                            contact.clearLinkedInProfileURL()
                            dismiss()
                        } label: {
                            Label("Clear Saved Link", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("LinkedIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfileValue(profileValue)
                    }
                }
            }
            .onAppear {
                profileValue = contact.savedOrDetectedLinkedInProfileURL ?? ""
            }
            .sheet(isPresented: $isScannerPresented) {
                QRCodeScannerView(
                    onCodeScanned: { scannedValue in
                        saveProfileValue(scannedValue)
                        isScannerPresented = false
                    },
                    onCancel: {
                        isScannerPresented = false
                    }
                )
            }
        }
    }

    private func saveProfileValue(_ rawValue: String) {
        guard let normalized = LinkedInConnectionService.normalizedPersonProfileURL(from: rawValue) else {
            validationError = "Scan or enter a valid LinkedIn profile link."
            return
        }

        profileValue = normalized
        contact.saveLinkedInProfileURL(normalized)
        validationError = nil
        dismiss()
    }

    private func openLinkedInSearch() {
        do {
            try LinkedInConnectionService.openPeopleSearch(query: linkedInSearchQuery)
        } catch {
            validationError = error.localizedDescription
        }
    }

    private var linkedInSearchQuery: String {
        [
            contact.primaryLabel,
            contact.organizationName,
            contact.jobTitle
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }
}
