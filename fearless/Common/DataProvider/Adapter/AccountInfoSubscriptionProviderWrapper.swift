import RobinHood

final class AccountInfoSubscriptionProviderWrapper: WalletLocalStorageSubscriber {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    weak var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler?

    init(factory: WalletLocalSubscriptionFactoryProtocol, handler: WalletLocalSubscriptionHandler) {
        walletLocalSubscriptionFactory = factory
        walletLocalSubscriptionHandler = handler
    }

    func subscribeAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> StreamableProvider<ChainStorageItem>? {
        subscribeToAccountInfoProvider(for: accountId, chainAsset: chainAsset)
    }
}
