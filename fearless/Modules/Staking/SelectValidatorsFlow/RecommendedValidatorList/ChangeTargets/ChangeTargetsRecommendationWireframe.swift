import Foundation

final class ChangeTargetsRecommendationWireframe: RecommendedValidatorListWireframe {
    let state: ExistingBonding

    init(state: ExistingBonding) {
        self.state = state
    }

    override func proceed(
        from view: RecommendedValidatorListViewProtocol?,
        flow: SelectValidatorsConfirmFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let confirmView = SelectValidatorsConfirmViewFactory.createChangeTargetsView(
            wallet: wallet,
            chainAsset: chainAsset,
            flow: flow
        ) else {
            return
        }

        view?.controller.navigationController?.pushViewController(
            confirmView.controller,
            animated: true
        )
    }
}
