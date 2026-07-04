import Contacts
import ContactsUI
import SwiftUI

struct SystemContactView: UIViewControllerRepresentable {
    let contact: SystemContact

    func makeUIViewController(context: Context) -> UINavigationController {
        let contactController: CNContactViewController
        switch contact.presentation {
        case .existing:
            contactController = CNContactViewController(for: contact.value)
        case .preview:
            contactController = CNContactViewController(forUnknownContact: contact.value)
        }
        contactController.allowsEditing = false
        contactController.allowsActions = contact.presentation == .existing
        contactController.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak contactController] _ in
                contactController?.dismiss(animated: true)
            }
        )
        return UINavigationController(rootViewController: contactController)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
