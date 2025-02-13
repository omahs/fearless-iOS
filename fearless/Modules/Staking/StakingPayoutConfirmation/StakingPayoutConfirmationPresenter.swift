import Foundation
import BigInt
import CommonWallet

final class StakingPayoutConfirmationPresenter {
    weak var view: StakingPayoutConfirmationViewProtocol?
    var wireframe: StakingPayoutConfirmationWireframeProtocol!
    var interactor: StakingPayoutConfirmationInteractorInputProtocol!

    private var priceData: PriceData?

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let payoutConfirmViewModelFactory: StakingPayoutConfirmationViewModelFactoryProtocol
    private let dataValidatingFactory: StakingDataValidatingFactoryProtocol
    private let chainAsset: ChainAsset
    private let logger: LoggerProtocol?
    private let viewModelState: StakingPayoutConfirmationViewModelState

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        payoutConfirmViewModelFactory: StakingPayoutConfirmationViewModelFactoryProtocol,
        dataValidatingFactory: StakingDataValidatingFactoryProtocol,
        chainAsset: ChainAsset,
        logger: LoggerProtocol? = nil,
        viewModelState: StakingPayoutConfirmationViewModelState
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.payoutConfirmViewModelFactory = payoutConfirmViewModelFactory
        self.dataValidatingFactory = dataValidatingFactory
        self.chainAsset = chainAsset
        self.logger = logger
        self.viewModelState = viewModelState
    }

    // MARK: - Private functions

    private func handle(error: Error) {
        let locale = view?.localizationManager?.selectedLocale

        if !wireframe.present(error: error, from: view, locale: locale) {
            _ = wireframe.present(error: CommonError.undefined, from: view, locale: locale)
            logger?.error("Did receive error: \(error)")
        }
    }
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationPresenterProtocol {
    func setup() {
        viewModelState.setStateListener(self)

        provideFee()
        interactor.setup()

        interactor.estimateFee(builderClosure: viewModelState.builderClosure)
    }

    func proceed() {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        DataValidationRunner(validators: viewModelState.validators(using: locale)).runValidation { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.interactor.submitPayout(builderClosure: strongSelf.viewModelState.builderClosure)
        }
    }

    func presentAccountOptions(for viewModel: AccountInfoViewModel) {
        let locale = view?.localizationManager?.selectedLocale ?? Locale.current

        if let view = view {
            wireframe.presentAccountOptions(
                from: view,
                address: viewModel.address,
                chain: chainAsset.chain,
                locale: locale
            )
        }
    }

    func didTapBackButton() {
        wireframe.dismiss(view: view)
    }
}

// MARK: - StakingPayoutConfirmationInteractorOutputProtocol

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationInteractorOutputProtocol {
    func didReceivePriceData(result: Result<PriceData?, Error>) {
        switch result {
        case let .success(priceData):
            self.priceData = priceData
            provideFee()
            provideViewModel()

        case let .failure(error):
            logger?.error("Price data subscription error: \(error)")
        }
    }
}

extension StakingPayoutConfirmationPresenter: StakingPayoutConfirmationModelStateListener {
    func didReceiveError(error: Error) {
        logger?.error("StakingPayoutConfirmationPresenter:didReceiveError: \(error)")
    }

    func didStartPayout() {
        view?.didStartLoading()
    }

    func didCompletePayout(txHashes: [String]) {
        txHashes.forEach { txHash in
            logger?.info("Did send payouts: \(txHash)")
        }

        view?.didStopLoading()

        wireframe.complete(from: view)
    }

    func didCompletePayout(result: SubmitExtrinsicResult) {
        switch result {
        case let .success(txHash):
            logger?.info("Did send payouts \(txHash)")

            view?.didStopLoading()

            wireframe.complete(from: view)
        case let .failure(error):
            view?.didStopLoading()

            handle(error: error)
        }
    }

    func didFailPayout(error: Error) {
        view?.didStopLoading()

        handle(error: error)
    }

    func provideFee() {
        if let fee = viewModelState.fee {
            let viewModel = balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
            view?.didReceive(feeViewModel: viewModel)
        } else {
            view?.didReceive(feeViewModel: nil)
        }
    }

    func provideViewModel() {
        let viewModel = payoutConfirmViewModelFactory.createPayoutConfirmViewModel(
            viewModelState: viewModelState,
            priceData: priceData
        )

        view?.didRecieve(viewModel: viewModel)

        let singleViewModel = payoutConfirmViewModelFactory.createSinglePayoutConfirmationViewModel(
            viewModelState: viewModelState,
            priceData: priceData
        )

        view?.didReceive(singleViewModel: singleViewModel)
    }
}
