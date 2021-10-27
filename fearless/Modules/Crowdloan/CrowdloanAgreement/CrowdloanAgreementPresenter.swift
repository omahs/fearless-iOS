import Foundation
import SwiftUI
import SoraFoundation
import RobinHood

final class CrowdloanAgreementPresenter {
    weak var view: CrowdloanAgreementViewProtocol?
    let wireframe: CrowdloanAgreementWireframeProtocol
    let interactor: CrowdloanAgreementInteractorInputProtocol

    private var agreementTextResult: Result<String, Error>?
    private var isTermsAgreed: Bool = false
    private var paraId: ParaId
    private var crowdloanTitle: String
    private var logger: LoggerProtocol
    private var customFlow: CustomCrowdloanFlow

    init(
        interactor: CrowdloanAgreementInteractorInputProtocol,
        wireframe: CrowdloanAgreementWireframeProtocol,
        paraId: ParaId,
        crowdloanTitle: String,
        logger: LoggerProtocol,
        customFlow: CustomCrowdloanFlow
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.paraId = paraId
        self.crowdloanTitle = crowdloanTitle
        self.logger = logger
        self.customFlow = customFlow
    }

    private func updateView() {
        guard let agreementTextResult = agreementTextResult else {
            view?.didReceive(state: .error)
            return
        }

        guard case let .success(text) = agreementTextResult else {
            view?.didReceive(state: .error)
            return
        }

        let viewModel = CrowdloanAgreementViewModel(
            title: crowdloanTitle,
            agreementText: text,
            isTermsAgreed: isTermsAgreed
        )

        view?.didReceive(state: .loaded(viewModel: viewModel))
    }
}

extension CrowdloanAgreementPresenter: CrowdloanAgreementPresenterProtocol {
    func confirmAgreement() {
        switch customFlow {
        case let .moonbeam(data):
            wireframe.showMoonbeamAgreementConfirm(
                from: view,
                paraId: paraId,
                moonbeamFlowData: data
            )
        default: break
        }
    }

    func setTermsAgreed(value: Bool) {
        isTermsAgreed = value
        updateView()
    }

    func setup() {
        view?.didReceive(state: .loading)

        interactor.setup()
    }
}

extension CrowdloanAgreementPresenter: CrowdloanAgreementInteractorOutputProtocol {
    func didReceiveAgreementText(result: Result<String, Error>) {
        logger.info("Did receive agreement text: \(result)")

        agreementTextResult = result
        updateView()
    }

    func didReceiveVerified(result: Result<Bool, Error>) {
        switch result {
        case let .success(verified):
            if verified {
                wireframe.presentContributionSetup(from: view, paraId: paraId)
            }
        case let .failure(error):
            logger.error(error.localizedDescription)

            if let view = view,
               let error = error as? NetworkResponseError,
               error == .unexpectedStatusCode {
                wireframe.presentUnavailableWarning(
                    message: R.string.localizable.crowdloanLocationUnsupportedError(crowdloanTitle, preferredLanguages: selectedLocale.rLanguages),
                    view: view,
                    locale: selectedLocale
                )
            }
        }
    }
}

extension CrowdloanAgreementPresenter: Localizable {
    func applyLocalization() {}
}
