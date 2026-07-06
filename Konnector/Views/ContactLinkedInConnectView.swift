import SwiftUI

enum ContactLinkedInConnectLayout {
    case button
    case details
}

struct ContactLinkedInConnectView: View {
    @Bindable var contact: ContactSnapshot
    var layout: ContactLinkedInConnectLayout = .details
    @Environment(\.scenePhase) private var scenePhase

    @State private var linkedInError: String?
    @State private var isConnectConfirmationPresented = false
    @State private var awaitingConnectConfirmation = false

    var body: some View {
        Group {
            switch layout {
            case .button:
                connectButton
            case .details:
                if contact.isLinkedInConnected {
                    connectedContent
                }
            }
        }
        .alert("Couldn’t Open LinkedIn", isPresented: linkedInErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(linkedInError ?? "LinkedIn couldn’t be opened.")
        }
        .confirmationDialog(
            "Connected on LinkedIn?",
            isPresented: $isConnectConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Yes, we connected") {
                contact.markLinkedInConnected(profileURL: contact.detectedLinkedInProfileURL)
            }
            Button("Not yet", role: .cancel) {}
        } message: {
            Text("If you scanned \(contact.primaryLabel)’s QR code and sent a connection request, save that link here.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, awaitingConnectConfirmation else { return }
            awaitingConnectConfirmation = false
            isConnectConfirmationPresented = true
        }
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: K.Spacing.md) {
            Label("Connected on LinkedIn", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)

            if let connectedAt = contact.linkedInConnectedAt {
                Text("Saved \(connectedAt.formatted(date: .abbreviated, time: .omitted)).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !contact.linkedInProfileURL.isEmpty {
                Text(contact.linkedInProfileURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: K.Spacing.sm) {
                if !contact.linkedInProfileURL.isEmpty {
                    Button {
                        openLinkedInProfile()
                    } label: {
                        Label("Open Profile", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.kSecondary(size: .medium, corner: .standard, expands: true))
                }

                Button {
                    connectOnLinkedIn()
                } label: {
                    Label("Scan Again", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.kTertiary(size: .medium, corner: .standard, expands: true))
            }
        }
    }

    private var connectButton: some View {
        Group {
            if contact.isLinkedInConnected {
                if !contact.linkedInProfileURL.isEmpty {
                    Button {
                        openLinkedInProfile()
                    } label: {
                        Label("Open Profile", systemImage: "arrow.up.right.square")
                    }
                } else {
                    Button {
                        connectOnLinkedIn()
                    } label: {
                        Label("Scan Again", systemImage: "qrcode.viewfinder")
                    }
                }
            } else {
                Button {
                    connectOnLinkedIn()
                } label: {
                    Label("LinkedIn", systemImage: "qrcode.viewfinder")
                }
            }
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

    private func connectOnLinkedIn() {
        do {
            try LinkedInConnectionService.openQRScannerOrAppStore()
            awaitingConnectConfirmation = true
        } catch {
            linkedInError = error.localizedDescription
        }
    }

    private func openLinkedInProfile() {
        do {
            try LinkedInConnectionService.openProfile(contact.linkedInProfileURL)
        } catch {
            linkedInError = error.localizedDescription
        }
    }
}
