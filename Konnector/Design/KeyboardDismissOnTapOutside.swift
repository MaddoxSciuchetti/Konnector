import SwiftUI

#if canImport(UIKit)
import UIKit

extension View {
    func kDismissKeyboardOnTapOutside() -> some View {
        background(KeyboardDismissTapInstaller())
    }
}

private struct KeyboardDismissTapInstaller: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> InstallerView {
        InstallerView(coordinator: context.coordinator)
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        @objc func dismissKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let currentView = view {
                if currentView is UITextField || currentView is UITextView {
                    return false
                }
                view = currentView.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }

    final class InstallerView: UIView {
        private weak var coordinator: Coordinator?
        private weak var installedWindow: UIWindow?
        private var tapRecognizer: UITapGestureRecognizer?

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installRecognizerIfNeeded()
        }

        deinit {
            uninstallRecognizer()
        }

        private func installRecognizerIfNeeded() {
            guard installedWindow !== window else { return }
            uninstallRecognizer()

            guard let window, let coordinator else { return }

            let recognizer = UITapGestureRecognizer(
                target: coordinator,
                action: #selector(Coordinator.dismissKeyboard)
            )
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = coordinator

            window.addGestureRecognizer(recognizer)
            installedWindow = window
            tapRecognizer = recognizer
        }

        private func uninstallRecognizer() {
            if let tapRecognizer {
                installedWindow?.removeGestureRecognizer(tapRecognizer)
            }
            installedWindow = nil
            tapRecognizer = nil
        }
    }
}
#else
extension View {
    func kDismissKeyboardOnTapOutside() -> some View {
        self
    }
}
#endif
