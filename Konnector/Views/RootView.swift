import SwiftUI

enum AppRoute: Equatable {
    case onboarding
    case contacts

    static func resolve(hasCompletedOnboarding: Bool, authorization: ContactAuthorization) -> AppRoute {
        hasCompletedOnboarding && authorization.canReadContacts ? .contacts : .onboarding
    }
}

struct RootView: View {
    @Environment(ContactSyncService.self) private var syncService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if AppRoute.resolve(
                hasCompletedOnboarding: hasCompletedOnboarding,
                authorization: syncService.authorization
            ) == .contacts {
                ContactListView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .task {
            await syncService.refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await syncService.refreshAuthorization()
            }
        }
    }
}
