import Foundation
import SoraFoundation

final class PreparationPresenter {
    // MARK: Private properties

    private weak var view: PreparationViewInput?
    private let router: PreparationRouterInput
    private let interactor: PreparationInteractorInput

    // MARK: - Constructors

    init(
        interactor: PreparationInteractorInput,
        router: PreparationRouterInput,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.localizationManager = localizationManager
    }

    // MARK: - Private methods
}

// MARK: - PreparationViewOutput

extension PreparationPresenter: PreparationViewOutput {
    func didLoad(view: PreparationViewInput) {
        self.view = view
        interactor.setup(with: self)
    }

    func didTapBackButton() {
        router.dismiss(view: view)
    }

    func didTapConfirmButton() {
        router.presentKYC(from: view)
    }
}

// MARK: - PreparationInteractorOutput

extension PreparationPresenter: PreparationInteractorOutput {}

// MARK: - Localizable

extension PreparationPresenter: Localizable {
    func applyLocalization() {}
}

extension PreparationPresenter: PreparationModuleInput {}
