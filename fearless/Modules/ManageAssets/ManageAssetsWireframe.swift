import Foundation

final class ManageAssetsWireframe: ManageAssetsWireframeProtocol {
    func showImport(uniqueChainModel: UniqueChainModel, from view: ControllerBackedProtocol?) {
        guard let importController = AccountImportViewFactory.createViewForOnboarding(.chain(model: uniqueChainModel))?.controller else {
            return
        }

        view?.controller.navigationController?.pushViewController(importController, animated: true)
    }

    func presentAccountOptions(
        from view: ControllerBackedProtocol?,
        locale: Locale?,
        options: [MissingAccountOption],
        uniqueChainModel: UniqueChainModel,
        skipBlock: @escaping (ChainModel) -> Void
    ) {
        let cancelTitle = R.string.localizable
            .commonCancel(preferredLanguages: locale?.rLanguages)

        let actions: [AlertPresentableAction] = options.map { option in
            switch option {
            case .create:
                let title = R.string.localizable.createNewAccount(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showImport(uniqueChainModel: uniqueChainModel, from: view)
                }
            case .import:
                let title = R.string.localizable.alreadyHaveAccount(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    self?.showImport(uniqueChainModel: uniqueChainModel, from: view)
                }
            case .skip:
                let title = R.string.localizable.missingAccountSkip(preferredLanguages: locale?.rLanguages)
                return AlertPresentableAction(title: title) { [weak self] in
                    skipBlock(uniqueChainModel.chain)
                }
            }
        }

        let title = R.string.localizable.importSourcePickerTitle(preferredLanguages: locale?.rLanguages)
        let alertViewModel = AlertPresentableViewModel(
            title: title,
            message: nil,
            actions: actions,
            closeAction: cancelTitle
        )

        present(
            viewModel: alertViewModel,
            style: .actionSheet,
            from: view
        )
    }
}
