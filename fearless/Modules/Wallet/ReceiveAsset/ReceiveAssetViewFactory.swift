import CommonWallet
import SoraFoundation

struct ReceiveAssetViewFactory {
    static func createView(
        account: MetaAccountModel,
        chain: ChainModel,
        asset: AssetModel
    ) -> ReceiveAssetViewProtocol? {
        guard let chainAccount = account.fetch(for: chain.accountRequest()) else {
            return nil
        }
        let wireframe = ReceiveAssetWireframe()

        let qrEncoder = WalletQREncoder(
            addressPrefix: chain.addressPrefix,
            publicKey: chainAccount.publicKey,
            username: chainAccount.name
        )
        let qrService = WalletQRService(
            operationFactory: WalletQROperationFactory(),
            encoder: qrEncoder
        )
        let sharingFactory = AccountShareFactory()
        let presenter = ReceiveAssetPresenter(
            wireframe: wireframe,
            qrService: qrService,
            sharingFactory: sharingFactory,
            account: account,
            chain: chain,
            asset: asset,
            localizationManager: LocalizationManager.shared
        )

        let view = ReceiveAssetViewController(presenter: presenter)
        presenter.view = view

        return view
    }
}
