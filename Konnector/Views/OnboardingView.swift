import SwiftUI

struct OnboardingView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Environment(\.openURL) private var openURL
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Your contacts, organized")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text("Konnector imports the contacts you choose into a private, on-device library. Nothing is uploaded.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            actionContent
        }
        .padding(24)
    }

    @ViewBuilder
    private var actionContent: some View {
        switch syncService.authorization {
        case .denied:
            VStack(spacing: 12) {
                Text("Contacts access is turned off. Enable it in Settings to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

        case .restricted:
            Text("Contacts access is restricted on this iPhone. Check Screen Time or device management settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

        case .authorized, .limited:
            Button("Continue") {
                hasCompletedOnboarding = true
                syncService.scheduleSync()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

        case .notDetermined:
            Button {
                Task {
                    await syncService.requestAccessAndSync()
                    if syncService.authorization.canReadContacts {
                        hasCompletedOnboarding = true
                    }
                }
            } label: {
                if syncService.syncState == .syncing {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sync Contacts")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(syncService.syncState == .syncing)
        }
    }
}
