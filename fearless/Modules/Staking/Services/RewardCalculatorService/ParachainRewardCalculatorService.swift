import Foundation
import RobinHood
import FearlessUtils
import BigInt

enum ParachainRewardCalculatorServiceError: Error {
    case timedOut
    case unexpectedInfo
}

final class ParachainRewardCalculatorService {
    static let queueLabelPrefix = "jp.co.fearless.rewcalculator"

    private struct PendingRequest {
        let resultClosure: (RewardCalculatorEngineProtocol) -> Void
        let queue: DispatchQueue?
    }

    private let syncQueue = DispatchQueue(
        label: "\(queueLabelPrefix).\(UUID().uuidString)",
        qos: .userInitiated
    )

    private var isActive: Bool = false
    private var snapshot: BigUInt?
    private var totalIssuanceDataProvider: StreamableProvider<ChainStorageItem>?
    private var pendingRequests: [PendingRequest] = []
    private let chainAsset: ChainAsset
    private let assetPrecision: Int16
    private let collatorOperationFactory: ParachainCollatorOperationFactory
    private let logger: LoggerProtocol?
    private let operationManager: OperationManagerProtocol
    private let providerFactory: SubstrateDataProviderFactoryProtocol
    private let storageFacade: StorageFacadeProtocol
    private let runtimeCodingService: RuntimeCodingServiceProtocol

    init(
        chainAsset: ChainAsset,
        assetPrecision: Int16,
        operationManager: OperationManagerProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        runtimeCodingService: RuntimeCodingServiceProtocol,
        storageFacade: StorageFacadeProtocol,
        logger: LoggerProtocol? = nil,
        collatorOperationFactory: ParachainCollatorOperationFactory
    ) {
        self.chainAsset = chainAsset
        self.assetPrecision = assetPrecision
        self.storageFacade = storageFacade
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.runtimeCodingService = runtimeCodingService
        self.logger = logger
        self.collatorOperationFactory = collatorOperationFactory
    }

    // MARK: - Private

    private func fetchInfoFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RewardCalculatorEngineProtocol) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request, chainId: chainAsset.chain.chainId, assetPrecision: assetPrecision)
        } else {
            pendingRequests.append(request)
        }
    }

    private func deliver(
        snapshot: BigUInt,
        to request: PendingRequest,
        chainId: ChainModel.Id,
        assetPrecision: Int16
    ) {
        let stakedWrapper = collatorOperationFactory.staked()
        let commissionWrapper = collatorOperationFactory.commission()
        let collatorsWrapper = collatorOperationFactory.allElectedOperation()

        let mapOperation = ClosureOperation<RewardCalculatorEngineProtocol> { [weak self] in
            guard let strongSelf = self else {
                throw ParachainRewardCalculatorServiceError.unexpectedInfo
            }
            let staked = try stakedWrapper.targetOperation.extractNoCancellableResultData()
            let commission = try commissionWrapper.targetOperation.extractNoCancellableResultData()
            let collators = try collatorsWrapper.targetOperation.extractNoCancellableResultData()

            let stakedValue = BigUInt(staked ?? "") ?? BigUInt.zero
            let comissionValue = BigUInt(commission ?? "")

            let eraDurationInSeconds = TimeInterval(24 / strongSelf.chainAsset.chain.erasPerDay * 3600)

            return ParachainRewardCalculatorEngine(
                chainId: chainId,
                assetPrecision: assetPrecision,
                totalIssuance: snapshot,
                totalStaked: stakedValue,
                eraDurationInSeconds: eraDurationInSeconds,
                commission: Decimal.fromSubstratePerbill(value: comissionValue ?? BigUInt.zero) ?? Decimal.zero,
                collators: collators ?? []
            )
        }

        mapOperation.addDependency(stakedWrapper.targetOperation)
        mapOperation.addDependency(commissionWrapper.targetOperation)
        mapOperation.addDependency(collatorsWrapper.targetOperation)

        mapOperation.completionBlock = { [weak self] in
            dispatchInQueueWhenPossible(request.queue) {
                switch mapOperation.result {
                case let .success(calculator):
                    request.resultClosure(calculator)
                case let .failure(error):
                    self?.logger?.error("Era stakers info fetch error: \(error)")
                case .none:
                    self?.logger?.warning("Era stakers info fetch cancelled")
                }
            }
        }

        operationManager.enqueue(
            operations: stakedWrapper.allOperations + commissionWrapper.allOperations + collatorsWrapper.allOperations + [mapOperation],
            in: .transient
        )
    }

    private func notifyPendingClosures(with totalIssuance: BigUInt) {
        logger?.debug("Attempt fulfill pendings \(pendingRequests.count)")

        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach {
            deliver(
                snapshot: totalIssuance,
                to: $0,
                chainId: chainAsset.chain.chainId,
                assetPrecision: assetPrecision
            )
        }

        logger?.debug("Fulfilled pendings")
    }

    private func handleTotalIssuanceDecodingResult(
        result: Result<StringScaleMapper<BigUInt>, Error>?
    ) {
        switch result {
        case let .success(totalIssuance):
            snapshot = totalIssuance.value
            notifyPendingClosures(with: totalIssuance.value)
        case let .failure(error):
            logger?.error("Did receive total issuance decoding error: \(error)")
        case .none:
            logger?.warning("Error decoding operation canceled")
        }
    }

    private func didUpdateTotalIssuanceItem(_ totalIssuanceItem: ChainStorageItem?) {
        guard let totalIssuanceItem = totalIssuanceItem else {
            return
        }

        let codingFactoryOperation = runtimeCodingService.fetchCoderFactoryOperation()
        let decodingOperation =
            StorageDecodingOperation<StringScaleMapper<BigUInt>>(
                path: .totalIssuance,
                data: totalIssuanceItem.data
            )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation
                    .extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        decodingOperation.completionBlock = { [weak self] in
            self?.syncQueue.async {
                self?.handleTotalIssuanceDecodingResult(result: decodingOperation.result)
            }
        }

        operationManager.enqueue(
            operations: [codingFactoryOperation, decodingOperation],
            in: .transient
        )
    }

    private func subscribe() {
        do {
            let localKey = try LocalStorageKeyFactory().createFromStoragePath(
                .totalIssuance,
                chainId: chainAsset.chain.chainId
            )

            let totalIssuanceDataProvider = providerFactory.createStorageProvider(for: localKey)

            let updateClosure: ([DataProviderChange<ChainStorageItem>]) -> Void = { [weak self] changes in
                let finalValue: ChainStorageItem? = changes.reduce(nil) { _, item in
                    switch item {
                    case let .insert(newItem), let .update(newItem):
                        return newItem
                    case .delete:
                        return nil
                    }
                }

                self?.didUpdateTotalIssuanceItem(finalValue)
            }

            let failureClosure: (Error) -> Void = { [weak self] error in
                self?.logger?.error("Did receive error: \(error)")
            }

            totalIssuanceDataProvider.addObserver(
                self,
                deliverOn: syncQueue,
                executing: updateClosure,
                failing: failureClosure,
                options: StreamableProviderObserverOptions.substrateSource()
            )

            self.totalIssuanceDataProvider = totalIssuanceDataProvider
        } catch {
            logger?.error("Can't make subscription")
        }
    }

    private func unsubscribe() {
        totalIssuanceDataProvider?.removeObserver(self)
        totalIssuanceDataProvider = nil
    }
}

extension ParachainRewardCalculatorService: RewardCalculatorServiceProtocol {
    func setup() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = true

            self.subscribe()
        }
    }

    func throttle() {
        syncQueue.async {
            guard !self.isActive else {
                return
            }

            self.isActive = false

            self.unsubscribe()
        }
    }

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation {
            var fetchedInfo: RewardCalculatorEngineProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            let queue = DispatchQueue(label: "jp.co.soramitsu.fearless.fetchCalculator.\(self.chainAsset.chain.chainId)", qos: .userInitiated)

            self.syncQueue.async {
                self.fetchInfoFactory(runCompletionIn: queue) { [weak semaphore] info in
                    fetchedInfo = info
                    semaphore?.signal()
                }
            }

            semaphore.wait()

            guard let info = fetchedInfo else {
                throw RewardCalculatorServiceError.unexpectedInfo
            }

            return info
        }
    }
}
