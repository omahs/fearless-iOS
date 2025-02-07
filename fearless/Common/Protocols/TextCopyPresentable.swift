import UIKit

protocol TextCopyPresentable {
    func presentCopy(
        with text: String,
        locale: Locale,
        from view: ControllerBackedProtocol?
    )
}

extension TextCopyPresentable {
    func presentCopy(
        with text: String,
        locale: Locale,
        from view: ControllerBackedProtocol?
    ) {
        let alertController = UIAlertController(
            title: text,
            message: nil,
            preferredStyle: .actionSheet
        )

        let copyTitle = R.string.localizable
            .commonCopyId(preferredLanguages: locale.rLanguages)

        let copy = UIAlertAction(title: copyTitle, style: .default) { _ in
            UIPasteboard.general.string = text

            let title = R.string.localizable.commonCopied(preferredLanguages: locale.rLanguages)
            let controller = ModalAlertFactory.createSuccessAlert(title)

            view?.controller.present(controller, animated: true)
        }

        alertController.addAction(copy)

        view?.controller.present(alertController, animated: true)
    }
}
