import SoraKeystore
import RobinHood
import IrohaCrypto
import FearlessUtils

final class StakingRewardDestSetupInteractor: AccountFetching {
    weak var presenter: StakingRewardDestSetupInteractorOutputProtocol!

    let priceLocalSubscriptionFactory: PriceProviderFactoryProtocol
    let stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol

    private let accountRepository: AnyDataProviderRepository<MetaAccountModel>
    var extrinsicService: ExtrinsicServiceProtocol?
    let substrateProviderFactory: SubstrateDataProviderFactoryProtocol
    let calculatorService: RewardCalculatorServiceProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let feeProxy: ExtrinsicFeeProxyProtocol
    let chainAsset: ChainAsset
    let selectedAccount: MetaAccountModel
    let connection: JSONRPCEngine

    private var stashItemProvider: StreamableProvider<StashItem>?
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var accountInfoProvider: AnyDataProvider<DecodedAccountInfo>?
    private var payeeProvider: AnyDataProvider<DecodedPayee>?
    private var ledgerProvider: AnyDataProvider<DecodedLedgerInfo>?
    private var nominationProvider: AnyDataProvider<DecodedNomination>?

    private var stashItem: StashItem?
    private var rewardDestination: RewardDestination<AccountAddress>?

    private lazy var callFactory = SubstrateCallFactory()
    private lazy var addressFactory = SS58AddressFactory()

    init(
        accountRepository: AnyDataProviderRepository<MetaAccountModel>,
        priceLocalSubscriptionFactory: PriceProviderFactoryProtocol,
        stakingLocalSubscriptionFactory: RelaychainStakingLocalSubscriptionFactoryProtocol,
        accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol,
        substrateProviderFactory: SubstrateDataProviderFactoryProtocol,
        calculatorService: RewardCalculatorServiceProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        operationManager: OperationManagerProtocol,
        feeProxy: ExtrinsicFeeProxyProtocol,
        chainAsset: ChainAsset,
        selectedAccount: MetaAccountModel,
        connection: JSONRPCEngine
    ) {
        self.priceLocalSubscriptionFactory = priceLocalSubscriptionFactory
        self.stakingLocalSubscriptionFactory = stakingLocalSubscriptionFactory
        self.accountInfoSubscriptionAdapter = accountInfoSubscriptionAdapter
        self.substrateProviderFactory = substrateProviderFactory
        self.calculatorService = calculatorService
        self.runtimeService = runtimeService
        self.operationManager = operationManager
        self.feeProxy = feeProxy
        self.chainAsset = chainAsset
        self.selectedAccount = selectedAccount
        self.accountRepository = accountRepository
        self.connection = connection
    }

    private func provideRewardCalculator() {
        let operation = calculatorService.fetchCalculatorOperation()

        operation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                do {
                    let engine = try operation.extractNoCancellableResultData()
                    self?.presenter.didReceiveCalculator(result: .success(engine))
                } catch {
                    self?.presenter.didReceiveCalculator(result: .failure(error))
                }
            }
        }

        operationManager.enqueue(
            operations: [operation],
            in: .transient
        )
    }

    private func setupExtrinsicServiceIfNeeded(_ accountItem: ChainAccountResponse) {
        guard extrinsicService == nil else {
            return
        }

        extrinsicService = ExtrinsicService(
            accountId: accountItem.accountId,
            chainFormat: chainAsset.chain.chainFormat,
            cryptoType: accountItem.cryptoType,
            runtimeRegistry: runtimeService,
            engine: connection,
            operationManager: operationManager
        )

        if let rewardDestination = rewardDestination {
            estimateFee(rewardDestination: rewardDestination)
        }
    }
}

extension StakingRewardDestSetupInteractor: StakingRewardDestSetupInteractorInputProtocol {
    func estimateFee(rewardDestination: RewardDestination<AccountAddress>) {
        self.rewardDestination = rewardDestination

        guard let extrinsicService = extrinsicService,
              let stashItem = stashItem else {
            return
        }
        do {
            let setPayeeCall = try callFactory.setRewardDestination(rewardDestination, stashItem: stashItem)

            feeProxy.estimateFee(
                using: extrinsicService,
                reuseIdentifier: UUID().uuidString
            ) { builder in
                try builder.adding(call: setPayeeCall)
            }
        } catch {
            presenter.didReceiveFee(result: .failure(error))
        }
    }

    func setup() {
        calculatorService.setup()

        if let address = selectedAccount.fetch(for: chainAsset.chain.accountRequest())?.toAddress() {
            stashItemProvider = subscribeStashItemProvider(for: address)
        }

        if let priceId = chainAsset.asset.priceId {
            priceProvider = subscribeToPrice(for: priceId)
        }

        provideRewardCalculator()

        feeProxy.delegate = self
    }

    func fetchPayoutAccounts() {
        fetchChainAccounts(
            chain: chainAsset.chain,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            self?.presenter.didReceiveAccounts(result: result)
        }
    }
}

extension StakingRewardDestSetupInteractor: AccountInfoSubscriptionAdapterHandler {
    func handleAccountInfo(result: Result<AccountInfo?, Error>, accountId _: AccountId, chainAsset _: ChainAsset) {
        presenter.didReceiveAccountInfo(result: result)
    }
}

extension StakingRewardDestSetupInteractor: PriceLocalStorageSubscriber, PriceLocalSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, priceId _: AssetModel.PriceId) {
        presenter.didReceivePriceData(result: result)
    }
}

extension StakingRewardDestSetupInteractor: RelaychainStakingLocalStorageSubscriber, RelaychainStakingLocalSubscriptionHandler {
    func handleStashItem(result: Result<StashItem?, Error>, for _: AccountAddress) {
        do {
            stashItem = try result.get()

            accountInfoSubscriptionAdapter.reset()
            clear(dataProvider: &ledgerProvider)
            clear(dataProvider: &payeeProvider)
            clear(dataProvider: &nominationProvider)

            presenter.didReceiveStashItem(result: result)

            if
                let stashItem = stashItem,
                let stashAccountId = try? addressFactory.accountId(
                    fromAddress: stashItem.stash,
                    type: chainAsset.chain.addressPrefix
                ),
                let controllerAccountId = try? addressFactory.accountId(
                    fromAddress: stashItem.controller,
                    type: chainAsset.chain.addressPrefix
                ) {
                ledgerProvider = subscribeLedgerInfo(for: controllerAccountId, chainAsset: chainAsset)
                payeeProvider = subscribePayee(for: stashAccountId, chainAsset: chainAsset)
                nominationProvider = subscribeNomination(for: stashAccountId, chainAsset: chainAsset)
                accountInfoSubscriptionAdapter.subscribe(
                    chainAsset: chainAsset,
                    accountId: controllerAccountId,
                    handler: self
                )

                if let rewardDestination = rewardDestination {
                    estimateFee(rewardDestination: rewardDestination)
                }

                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.stash,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(stash) = result, let stash = stash {
                        self?.setupExtrinsicServiceIfNeeded(stash)
                    }

                    self?.presenter.didReceiveStash(result: result)
                }

                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: stashItem.controller,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    if case let .success(controller) = result, let controller = controller {
                        self?.setupExtrinsicServiceIfNeeded(controller)
                    }

                    self?.presenter.didReceiveController(result: result)
                }

            } else {
                presenter.didReceiveStakingLedger(result: .success(nil))
                presenter.didReceiveAccountInfo(result: .success(nil))
                presenter.didReceiveRewardDestinationAccount(result: .success(nil))
                presenter.didReceiveNomination(result: .success(nil))
                presenter.didReceiveController(result: .success(nil))
            }

        } catch {
            presenter.didReceiveStashItem(result: .failure(error))
            presenter.didReceiveController(result: .failure(error))
            presenter.didReceiveStakingLedger(result: .failure(error))
            presenter.didReceiveAccountInfo(result: .failure(error))
            presenter.didReceiveRewardDestinationAccount(result: .failure(error))
            presenter.didReceiveNomination(result: .failure(error))
        }
    }

    func handleLedgerInfo(result: Result<StakingLedger?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveStakingLedger(result: result)
    }

    func handleNomination(result: Result<Nomination?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        presenter.didReceiveNomination(result: result)
    }

    func handlePayee(result: Result<RewardDestinationArg?, Error>, accountId _: AccountId, chainId _: ChainModel.Id) {
        do {
            guard let payee = try result.get(), let stashItem = stashItem else {
                presenter.didReceiveRewardDestinationAccount(result: .failure(CommonError.undefined))
                return
            }

            let rewardDestination = try RewardDestination(
                payee: payee,
                stashItem: stashItem,
                chainFormat: chainAsset.chain.chainFormat
            )

            switch rewardDestination {
            case .restake:
                presenter.didReceiveRewardDestinationAccount(result: .success(.restake))
            case let .payout(account):
                fetchChainAccount(
                    chain: chainAsset.chain,
                    address: account,
                    from: accountRepository,
                    operationManager: operationManager
                ) { [weak self] result in
                    switch result {
                    case let .success(accountItem):
                        if let accountItem = accountItem {
                            self?.presenter.didReceiveRewardDestinationAccount(
                                result: .success(.payout(account: accountItem))
                            )
                        } else {
                            self?.presenter.didReceiveRewardDestinationAddress(
                                result: .success(.payout(account: account))
                            )
                        }
                    case let .failure(error):
                        self?.presenter.didReceiveRewardDestinationAccount(result: .failure(error))
                    }
                }
            }
        } catch {
            presenter.didReceiveRewardDestinationAccount(result: .failure(error))
        }
    }
}

extension StakingRewardDestSetupInteractor: AnyProviderAutoCleaning {}

extension StakingRewardDestSetupInteractor: ExtrinsicFeeProxyDelegate {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for _: ExtrinsicFeeId) {
        presenter.didReceiveFee(result: result)
    }
}
