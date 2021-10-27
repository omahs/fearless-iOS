protocol CrowdloanAgreementConfirmViewProtocol: ControllerBackedProtocol {
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveAccount(viewModel: CrowdloanAccountViewModel?)
}

protocol CrowdloanAgreementConfirmPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanAgreementConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee()
}

protocol CrowdloanAgreementConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveDisplayAddress(result: Result<DisplayAddress, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol CrowdloanAgreementConfirmWireframeProtocol: AnyObject {}
