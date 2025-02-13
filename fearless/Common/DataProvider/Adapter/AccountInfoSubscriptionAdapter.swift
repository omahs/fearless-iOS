import Foundation
import RobinHood

protocol AccountInfoSubscriptionAdapterHandler: AnyObject {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )
}

protocol AccountInfoSubscriptionAdapterProtocol: AnyObject {
    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    )
    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    )

    func reset()
}

extension AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue? = .main
    ) {
        subscribe(chainAsset: chainAsset, accountId: accountId, handler: handler, deliveryOn: queue)
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue? = .main
    ) {
        subscribe(chainsAssets: chainsAssets, handler: handler, deliveryOn: queue)
    }
}

final class AccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    // MARK: - handler

    private weak var handler: AccountInfoSubscriptionAdapterHandler?

    // MARK: - WalletLocalStorageSubscriber

    internal var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    // MARK: - Private properties

    private var subscriptions: [StreamableProvider<ChainStorageItem>] = []
    private var selectedMetaAccount: MetaAccountModel

    private lazy var wrapper: AccountInfoSubscriptionProviderWrapper = {
        AccountInfoSubscriptionProviderWrapper(factory: walletLocalSubscriptionFactory, handler: self)
    }()

    private var deliveryQueue: DispatchQueue?
    private let lock = ReaderWriterLock()

    // MARK: - Constructor

    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
    }

    // MARK: - Public methods

    func reset() {
        subscriptions.forEach { subscription in
            subscription.removeObserver(wrapper)
        }

        subscriptions.removeAll()
    }

    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    ) {
        reset()
        self.handler = handler
        deliveryQueue = queue

        if let subscription = wrapper.subscribeAccountProvider(for: accountId, chainAsset: chainAsset) {
            subscriptions.append(subscription)
        }
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    ) {
        reset()
        self.handler = handler
        deliveryQueue = queue

        lock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else { return }
            chainsAssets.forEach { chainAsset in
                let accountRequest = chainAsset.chain.accountRequest()
                if let accountId = strongSelf.selectedMetaAccount.fetch(for: accountRequest)?.accountId,
                   let subscription = strongSelf.wrapper.subscribeAccountProvider(
                       for: accountId,
                       chainAsset: chainAsset
                   ) {
                    strongSelf.subscriptions.append(subscription)
                }
            }
        }
    }
}

extension AccountInfoSubscriptionAdapter: AnyProviderAutoCleaning {}

extension AccountInfoSubscriptionAdapter: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        deliveryQueue?.async {
            self.handler?.handleAccountInfo(
                result: result,
                accountId: accountId,
                chainAsset: chainAsset
            )
        }
    }
}
