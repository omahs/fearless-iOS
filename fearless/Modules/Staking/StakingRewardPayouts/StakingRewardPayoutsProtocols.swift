import SoraFoundation
import SoraUI

protocol StakingRewardPayoutsViewProtocol: ControllerBackedProtocol,
    Localizable,
    LoadableViewProtocol {
    func reload(with state: StakingRewardPayoutsViewState)
}

enum StakingRewardPayoutsViewState {
    case loading(Bool)
    case payoutsList(LocalizableResource<StakingPayoutViewModel>)
    case emptyList
    case error(LocalizableResource<String>)
}

protocol StakingRewardPayoutsPresenterProtocol: AnyObject {
    func setup()
    func handleSelectedHistory(at index: Int)
    func handlePayoutAction()
    func reload()
    func getTimeLeftString(at index: Int) -> LocalizableResource<NSAttributedString>?
}

protocol StakingRewardPayoutsInteractorInputProtocol: AnyObject {
    func setup()
    func reload()
}

protocol StakingRewardPayoutsInteractorOutputProtocol: AnyObject {
    func didReceive(result: Result<PayoutsInfo, PayoutRewardsServiceError>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>)
}

protocol StakingRewardPayoutsWireframeProtocol: AnyObject {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        historyDepth: UInt32,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )
    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        from view: ControllerBackedProtocol?
    )
}

protocol StakingRewardPayoutsViewFactoryProtocol: AnyObject {
    static func createViewForNominator(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol?
    static func createViewForValidator(
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        stashAddress: AccountAddress
    ) -> StakingRewardPayoutsViewProtocol?
}

protocol StakingPayoutViewModelFactoryProtocol {
    func createPayoutsViewModel(
        payoutsInfo: PayoutsInfo,
        priceData: PriceData?,
        eraCountdown: EraCountdown?,
        erasPerDay: UInt32
    ) -> LocalizableResource<StakingPayoutViewModel>

    func timeLeftString(
        at index: Int,
        payoutsInfo: PayoutsInfo,
        eraCountdown: EraCountdown?,
        erasPerDay: UInt32
    ) -> LocalizableResource<NSAttributedString>
}
