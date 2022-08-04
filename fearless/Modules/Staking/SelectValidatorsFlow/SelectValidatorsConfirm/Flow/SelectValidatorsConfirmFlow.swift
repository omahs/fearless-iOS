import UIKit
import SoraFoundation

enum SelectValidatorsConfirmFlow {
    case relaychainInitiated(targets: [SelectedValidatorInfo], maxTargets: Int, bonding: InitiatedBonding)
    case relaychainExisting(targets: [SelectedValidatorInfo], maxTargets: Int, bonding: ExistingBonding)
    case parachain(target: ParachainStakingCandidateInfo, maxTargets: Int, bonding: InitiatedBonding)
}

protocol SelectValidatorsConfirmModelStateListener: AnyObject {
    func didReceiveError(error: Error)
    func didStartNomination()
    func didCompleteNomination(txHash: String)
    func didFailNomination(error: Error)
    func feeParametersUpdated()

    func provideConfirmationState(viewModelState: SelectValidatorsConfirmViewModelState)
    func provideHints(viewModelState: SelectValidatorsConfirmViewModelState)
    func provideFee(viewModelState: SelectValidatorsConfirmViewModelState)
    func provideAsset(viewModelState: SelectValidatorsConfirmViewModelState)
}

protocol SelectValidatorsConfirmViewModelState {
    var stateListener: SelectValidatorsConfirmModelStateListener? { get set }
    var amount: Decimal? { get }
    var fee: Decimal? { get }
    var payoutAccountAddress: String? { get }
    var walletAccountAddress: String? { get }
    var collatorAddress: String? { get }

    func setStateListener(_ stateListener: SelectValidatorsConfirmModelStateListener?)
    func validators(using locale: Locale) -> [DataValidating]
    func createExtrinsicBuilderClosure() -> ExtrinsicBuilderClosure?
}

extension SelectValidatorsConfirmViewModelState {
    var payoutAccountAddress: String? { nil }
    var walletAccountAddress: String? { nil }
    var collatorAddress: String? { nil }
}

struct SelectValidatorsConfirmDependencyContainer {
    let viewModelState: SelectValidatorsConfirmViewModelState
    let strategy: SelectValidatorsConfirmStrategy
    let viewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol
}

protocol SelectValidatorsConfirmViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        asset: AssetModel
    ) throws -> LocalizableResource<SelectValidatorsConfirmViewModel>?
    func buildHintsViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState
    ) -> LocalizableResource<[TitleIconViewModel]>?
    func buildFeeViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>?
    func buildAssetBalanceViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        priceData: PriceData?,
        balance: Decimal?
    ) -> LocalizableResource<AssetBalanceViewModelProtocol>?
}

protocol SelectValidatorsConfirmStrategy {
    func setup()
    func estimateFee(closure: ExtrinsicBuilderClosure?)
    func submitNomination(closure: ExtrinsicBuilderClosure?)
}
