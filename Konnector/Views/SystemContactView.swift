import Contacts
import ContactsUI
import SwiftUI

struct SystemContactView: UIViewControllerRepresentable {
    let contact: CNContact

    func makeUIViewController(context: Context) -> UINavigationController {
        let contactController = CNContactViewController(for: contact)
        contactController.allowsEditing = false
        contactController.allowsActions = true
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
