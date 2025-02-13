import SoraFoundation
import CommonWallet
import BigInt

protocol StakingBondMoreViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveInput(viewModel: LocalizableResource<AmountInputViewModelProtocol>)
    func didReceiveAsset(viewModel: LocalizableResource<AssetBalanceViewModelProtocol>)
    func didReceiveFee(viewModel: LocalizableResource<NetworkFeeFooterViewModelProtocol>?)
    func didReceiveAccount(viewModel: AccountViewModel)
    func didReceiveCollator(viewModel: AccountViewModel)
    func didReceiveHints(viewModel: LocalizableResource<String>?)
}

protocol StakingBondMorePresenterProtocol: AnyObject {
    func setup()
    func handleContinueAction()
    func updateAmount(_ newValue: Decimal)
    func selectAmountPercentage(_ percentage: Float)
    func didTapBackButton()
}

protocol StakingBondMoreInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(reuseIdentifier: String?, builderClosure: ExtrinsicBuilderClosure?)
}

protocol StakingBondMoreInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingBondMoreWireframeProtocol: SheetAlertPresentable, ErrorPresentable, StakingErrorPresentable, AnyDismissable {
    func showConfirmation(
        from view: ControllerBackedProtocol?,
        flow: StakingBondMoreConfirmationFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}
