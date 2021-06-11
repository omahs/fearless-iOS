import Foundation
import SoraKeystore
import BigInt
import SoraFoundation

protocol StakingViewModelFacadeProtocol {
    func createBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol
    func createRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol
    func createAnalyticsViewModel(
        from data: [SubqueryRewardItemData],
        period: AnalyticsPeriod,
        priceData: PriceData?,
        chain: Chain
    ) -> LocalizableResource<RewardAnalyticsWidgetViewModel>
}

final class StakingViewModelFacade: StakingViewModelFacadeProtocol {
    let primitiveFactory: WalletPrimitiveFactoryProtocol

    init(primitiveFactory: WalletPrimitiveFactoryProtocol) {
        self.primitiveFactory = primitiveFactory
    }

    func createBalanceViewModelFactory(for chain: Chain) -> BalanceViewModelFactoryProtocol {
        BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )
    }

    func createRewardViewModelFactory(for chain: Chain) -> RewardViewModelFactoryProtocol {
        RewardViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType
        )
    }

    func createAnalyticsViewModel(
        from data: [SubqueryRewardItemData],
        period: AnalyticsPeriod,
        priceData: PriceData?,
        chain: Chain
    ) -> LocalizableResource<RewardAnalyticsWidgetViewModel> {
        let balanceViewModelFactory = createBalanceViewModelFactory(for: chain)
        let viewModelFactory = AnalyticsViewModelFactory(chain: chain, balanceViewModelFactory: balanceViewModelFactory)
        let fullViewModel = viewModelFactory.createRewardsViewModel(from: data, priceData: priceData, period: period)
        return LocalizableResource { locale in
            RewardAnalyticsWidgetViewModel(
                summary: fullViewModel.value(for: locale).summaryViewModel,
                chartData: fullViewModel.value(for: locale).chartData
            )
        }
    }
}
