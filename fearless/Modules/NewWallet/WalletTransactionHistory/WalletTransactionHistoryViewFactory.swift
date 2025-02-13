import Foundation
import FearlessUtils
import CommonWallet
import RobinHood
import SoraFoundation

struct WalletTransactionHistoryModule {
    let view: WalletTransactionHistoryViewProtocol?
    let moduleInput: WalletTransactionHistoryModuleInput?
}

enum WalletTransactionHistoryViewFactory {
    static func createView(
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    ) -> WalletTransactionHistoryModule? {
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let dependencyContainer = WalletTransactionHistoryDependencyContainer(selectedAccount: selectedAccount)

        let interactor = WalletTransactionHistoryInteractor(
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            dependencyContainer: dependencyContainer,
            logger: Logger.shared,
            defaultFilter: WalletHistoryRequest(assets: [asset.identifier]),
            selectedFilter: WalletHistoryRequest(assets: [asset.identifier]),
            filters: transactionHistoryFilters(for: chain),
            eventCenter: EventCenter.shared,
            applicationHandler: ApplicationHandler()
        )
        let wireframe = WalletTransactionHistoryWireframe()

        let viewModelFactory = WalletTransactionHistoryViewModelFactory(
            balanceFormatterFactory: AssetBalanceFormatterFactory(),
            includesFeeInAmount: false,
            transactionTypes: [.incoming, .outgoing],
            chainAsset: ChainAsset(chain: chain, asset: asset),
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = WalletTransactionHistoryPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chain,
            asset: asset,
            logger: Logger.shared,
            localizationManager: LocalizationManager.shared
        )

        let view = WalletTransactionHistoryViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return WalletTransactionHistoryModule(view: view, moduleInput: presenter)
    }

    static func transactionHistoryFilters(for chain: ChainModel) -> [FilterSet] {
        var filters: [WalletTransactionHistoryFilter] = [
            WalletTransactionHistoryFilter(type: .transfer, selected: true),
            WalletTransactionHistoryFilter(type: .other, selected: true)
        ]
        if chain.hasStakingRewardHistory {
            filters.insert(WalletTransactionHistoryFilter(type: .reward, selected: true), at: 1)
        }
        if chain.hasPolkaswap {
            filters.insert(WalletTransactionHistoryFilter(type: .swap, selected: true), at: 0)
            filters.removeAll(where: { $0.type == .other })
        }

        return [FilterSet(
            title: R.string.localizable.walletFiltersHeader(
                preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages
            ),
            items: filters
        )]
    }

    private static func createHistoryDeps(
        for chainAsset: ChainAsset
    ) -> (HistoryServiceProtocol, HistoryDataProviderFactoryProtocol)? {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
            return nil
        }

        let txStorage: CoreDataRepository<TransactionHistoryItem, CDTransactionHistoryItem> =
            SubstrateDataStorageFacade.shared.createRepository()

        let operationFactory: HistoryOperationFactoryProtocol
        switch chainAsset.chainAssetType {
        case .soraAsset:
            operationFactory = SoraHistoryOperationFactory(txStorage: AnyDataProviderRepository(txStorage))
        default:
            operationFactory = HistoryOperationFactory(
                txStorage: AnyDataProviderRepository(txStorage),
                runtimeService: runtimeService
            )
        }
        let dataProviderFactory = HistoryDataProviderFactory(
            cacheFacade: SubstrateDataStorageFacade.shared,
            operationFactory: operationFactory
        )

        let service = HistoryService(operationFactory: operationFactory, operationQueue: OperationQueue())
        return (service, dataProviderFactory)
    }
}
