import SoraFoundation

protocol AnalyticsRewardsViewProtocol: AnalyticsEmbeddedViewProtocol {
    func reload(viewState: AnalyticsViewState<AnalyticsRewardsViewModel>)
}

protocol AnalyticsRewardsPresenterProtocol: AnalyticsPresenterBaseProtocol {
    func handlePendingRewardsAction()
}

protocol AnalyticsRewardsInteractorInputProtocol: AnyObject {
    func setup()
    func fetchRewards(address: AccountAddress)
}

protocol AnalyticsRewardsInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol AnalyticsRewardsWireframeProtocol: AnyObject {
    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    )

    func showRewardPayoutsForNominator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )

    func showRewardPayoutsForValidator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )
}

protocol AnalyticsRewardsViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubqueryRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        selectedChartIndex: Int?,
        hasPendingRewards: Bool
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}
