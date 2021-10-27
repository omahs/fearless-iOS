import UIKit
import FearlessUtils
import RobinHood

final class CrowdloanAgreementConfirmInteractor: AccountFetching, CrowdloanAgreementConfirmInteractorInputProtocol {
    var presenter: CrowdloanAgreementConfirmInteractorOutputProtocol?

    private let signingWrapper: SigningWrapperProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let agreementService: CrowdloanAgreementServiceProtocol
    private var paraId: ParaId
    private var selectedAccountAddress: AccountAddress
    private var chain: Chain
    private var assetId: WalletAssetId
    private var priceProvider: AnySingleValueProvider<PriceData>?
    private var extrinsicService: ExtrinsicServiceProtocol
    private var callFactory: SubstrateCallFactoryProtocol
    private var operationManager: OperationManagerProtocol
    internal var singleValueProviderFactory: SingleValueProviderFactoryProtocol

    init(
        paraId: ParaId,
        selectedAccountAddress: AccountAddress,
        chain: Chain,
        assetId: WalletAssetId,
        extrinsicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        accountRepository: AnyDataProviderRepository<AccountItem>,
        agreementService: CrowdloanAgreementServiceProtocol,
        callFactory: SubstrateCallFactoryProtocol,
        operationManager: OperationManagerProtocol,
        singleValueProviderFactory: SingleValueProviderFactoryProtocol
    ) {
        self.signingWrapper = signingWrapper
        self.accountRepository = accountRepository
        self.agreementService = agreementService
        self.paraId = paraId
        self.selectedAccountAddress = selectedAccountAddress
        self.chain = chain
        self.assetId = assetId
        self.extrinsicService = extrinsicService
        self.callFactory = callFactory
        self.operationManager = operationManager
        self.singleValueProviderFactory = singleValueProviderFactory
    }

    func setup() {
        priceProvider = subscribeToPriceProvider(for: assetId)

        fetchAccount(
            for: selectedAccountAddress,
            from: accountRepository,
            operationManager: operationManager
        ) { [weak self] result in
            guard let strongSelf = self else {
                return
            }

            switch result {
            case let .success(maybeAccountItem):
                let displayAddress = maybeAccountItem.map {
                    DisplayAddress(address: $0.address, username: $0.username)
                } ?? DisplayAddress(address: strongSelf.selectedAccountAddress, username: "")

                strongSelf.presenter?.didReceiveDisplayAddress(result: .success(displayAddress))
            case let .failure(error):
                strongSelf.presenter?.didReceiveDisplayAddress(result: .failure(error))
            }
        }
    }
}

extension CrowdloanAgreementConfirmInteractor {
    func estimateFee() {
//        let callFactory = SubstrateCallFactory()
//
//        let randomBytes = (0...1000).map { _ in UInt8.random(in: 0...UInt8.max) }
//        let data = Data(randomBytes)
//
//        let closure: ExtrinsicBuilderClosure = { builder in
//            let call = callFactory.addRemark(data)
//            _ = try builder.adding(call: call)
//            return builder
//        }
//
//        extrinsicService.estimateFee(closure, runningIn: .main) { result in
//            switch result {
//            case let .success(paymentInfo):
//                if
//                    let feeValue = BigUInt(paymentInfo.fee),
//                    let fee = Decimal.fromSubstrateAmount(feeValue, precision: asset.precision),
//                    fee > 0 {
//
//                } else {
//                }
//            case let .failure(error):
//            }
//        }
    }
}

extension CrowdloanAgreementConfirmInteractor: SingleValueProviderSubscriber, SingleValueSubscriptionHandler {
    func handlePrice(result: Result<PriceData?, Error>, for _: WalletAssetId) {
        presenter?.didReceivePriceData(result: result)
    }
}
