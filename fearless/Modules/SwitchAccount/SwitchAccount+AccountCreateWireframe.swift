import Foundation

extension SwitchAccount {
    final class AccountCreateWireframe: AccountCreateWireframeProtocol {
        func confirm(
            from view: AccountCreateViewProtocol?,
            flow: AccountConfirmFlow
        ) {
            guard let accountConfirmation = AccountConfirmViewFactory
                .createViewForSwitch(flow: flow)?.controller
            else {
                return
            }

            if let navigationController = view?.controller.navigationController {
                navigationController.pushViewController(accountConfirmation, animated: true)
            }
        }

        func presentCryptoTypeSelection(
            from view: AccountCreateViewProtocol?,
            availableTypes: [CryptoType],
            selectedType: CryptoType,
            delegate: ModalPickerViewControllerDelegate?,
            context: AnyObject?
        ) {
            guard let modalPicker = ModalPickerFactory.createPickerForList(
                availableTypes,
                selectedType: selectedType,
                delegate: delegate,
                context: context
            ) else {
                return
            }

            view?.controller.navigationController?.present(
                modalPicker,
                animated: true,
                completion: nil
            )
        }
    }
}
