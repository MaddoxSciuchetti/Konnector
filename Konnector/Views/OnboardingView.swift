import SwiftUI

struct OnboardingView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Environment(\.openURL) private var openURL
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        VStack(spacing: K.Layout.sectionSpacing) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: K.Size.Avatar.lg, weight: .light))
                .foregroundStyle(K.Color.primary)
                .frame(width: K.Size.Avatar.lg + K.Spacing.xxxl, height: K.Size.Avatar.lg + K.Spacing.xxxl)
                .background(K.Color.primarySoft, in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: K.Spacing.md) {
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
        .kScreenPadding()
        .background(K.Color.screenBackground)
    }

    @ViewBuilder
    private var actionContent: some View {
        switch syncService.authorization {
        case .denied:
            VStack(spacing: K.Spacing.md) {
                Text("Contacts access is turned off. Enable it in Settings to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
                .buttonStyle(.kPrimary)
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
            .buttonStyle(.kPrimary)

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
                }
            }
            .buttonStyle(.kPrimary)
            .disabled(syncService.syncState == .syncing)
        }
    }
}
