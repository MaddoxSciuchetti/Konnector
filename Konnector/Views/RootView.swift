import SwiftUI

enum AppMode: Equatable {
    case live
    case demo
}

enum AppRoute: Equatable {
    case onboarding
    case contacts

    static func resolve(
        hasCompletedOnboarding: Bool,
        authorization: ContactAuthorization,
        appMode: AppMode
    ) -> AppRoute {
        if appMode == .demo {
            return .contacts
        }
        return hasCompletedOnboarding && authorization.canReadContacts ? .contacts : .onboarding
    }
}

struct RootView: View {
    let appMode: AppMode
    @Environment(ContactSyncService.self) private var syncService
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if AppRoute.resolve(
                hasCompletedOnboarding: hasCompletedOnboarding,
                authorization: syncService.authorization,
                appMode: appMode
            ) == .contacts {
                MainTabView()
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .kDismissKeyboardOnTapOutside()
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
