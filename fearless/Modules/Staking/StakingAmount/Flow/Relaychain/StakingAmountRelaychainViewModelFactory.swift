import Foundation
import SoraFoundation
import CommonWallet

final class StakingAmountRelaychainViewModelFactory: StakingAmountViewModelFactoryProtocol {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        rewardDestViewModelFactory: RewardDestinationViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.rewardDestViewModelFactory = rewardDestViewModelFactory
    }

    func buildViewModel(
        viewModelState: StakingAmountViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) -> StakingAmountMainViewModel? {
        guard let relaychainViewModelState = viewModelState as? StakingAmountRelaychainViewModelState else {
            return nil
        }

        let rewardDestinationViewModel = try? buildRewardDestinationViewModel(
            viewModelState: relaychainViewModelState,
            priceData: priceData,
            calculator: calculator
        )

        return StakingAmountMainViewModel(
            assetViewModel: nil,
            rewardDestinationViewModel: rewardDestinationViewModel,
            feeViewModel: nil,
            inputViewModel: nil
        )
    }

    private func buildRewardDestinationViewModel(
        viewModelState: StakingAmountRelaychainViewModelState,
        priceData: PriceData?,
        calculator: RewardCalculatorEngineProtocol?
    ) throws -> LocalizableResource<RewardDestinationViewModelProtocol>? {
        do {
            let reward: CalculatedReward?

            if let calculator = calculator {
                let restake = calculator.calculateMaxReturn(
                    isCompound: true,
                    period: .year
                )

                let payout = calculator.calculateMaxReturn(
                    isCompound: false,
                    period: .year
                )

                let curAmount = viewModelState.amount ?? 0.0
                reward = CalculatedReward(
                    restakeReturn: restake * curAmount,
                    restakeReturnPercentage: restake,
                    payoutReturn: payout * curAmount,
                    payoutReturnPercentage: payout
                )
            } else {
                reward = nil
            }

            switch viewModelState.rewardDestination {
            case .restake:
                return rewardDestViewModelFactory.createRestake(
                    from: reward,
                    priceData: priceData
                )
            case .payout:
                if let payoutAccount = viewModelState.payoutAccount,
                   let address = payoutAccount.toAddress() {
                    return try rewardDestViewModelFactory
                        .createPayout(
                            from: reward,
                            priceData: priceData,
                            address: address,
                            title: (try? payoutAccount.toDisplayAddress().username) ?? address
                        )
                }
            }
        } catch {}

        return nil
    }
}
