import Foundation
import IrohaCrypto

final class AccountImportWireframe: AccountImportWireframeProtocol {
    lazy var rootAnimator: RootControllerAnimationCoordinatorProtocol = RootControllerAnimationCoordinator()

    func showSecondStep(from view: AccountImportViewProtocol?, with data: AccountCreationStep.FirstStepData) {
        guard let secondStep = AccountImportViewFactory.createViewForOnboarding(.wallet(step: .second(data: data))) else {
            return
        }

        if let navigationController = view?.controller.navigationController {
            navigationController.pushViewController(secondStep.controller, animated: true)
        }
    }

    func proceed(from _: AccountImportViewProtocol?, flow: AccountImportFlow) {
        switch flow {
        case .wallet:
            guard let pincodeViewController = PinViewFactory.createPinSetupView()?.controller else {
                return
            }
            rootAnimator.animateTransition(to: pincodeViewController)
        case .chain:
            guard let mainViewController = MainTabBarViewFactory.createView()?.controller else {
                return
            }

            rootAnimator.animateTransition(to: mainViewController)
        }
    }

    func presentSourceTypeSelection(
        from view: AccountImportViewProtocol?,
        availableSources: [AccountImportSource],
        selectedSource: AccountImportSource,
        delegate: ModalPickerViewControllerDelegate?,
        context: AnyObject?
    ) {
        guard let modalPicker = ModalPickerFactory.createPickerForList(
            availableSources,
            selectedType: selectedSource,
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

    func presentCryptoTypeSelection(
        from view: AccountImportViewProtocol?,
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

    func presentNetworkTypeSelection(
        from view: AccountImportViewProtocol?,
        availableTypes: [Chain],
        selectedType: Chain,
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
