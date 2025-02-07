import Foundation
import RobinHood
import FearlessUtils

// swiftlint:disable file_length
protocol RuntimeProviderProtocol: AnyObject, RuntimeCodingServiceProtocol {
    var chainId: ChainModel.Id { get }
    var snapshot: RuntimeSnapshot? { get }

    func setup()
    func setupHot()
    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage)
    func cleanup()
    func fetchCoderFactoryOperation(
        with timeout: TimeInterval,
        closure: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol>
}

enum RuntimeProviderError: Error {
    case providerUnavailable
}

final class RuntimeProvider {
    struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol?) -> Void
        let queue: DispatchQueue?
    }

    internal let chainId: ChainModel.Id
    private let chainName: String
    private var typesUsage: ChainModel.TypesUsage
    private let usedRuntimePaths: [String: [String]]

    private let snapshotOperationFactory: RuntimeSnapshotFactoryProtocol
    private let snapshotHotOperationFactory: RuntimeHotBootSnapshotFactoryProtocol?
    private let eventCenter: EventCenterProtocol
    private let operationQueue: OperationQueue
    private let dataHasher: StorageHasher
    private let logger: LoggerProtocol?
    private let repository: AnyDataProviderRepository<RuntimeMetadataItem>

    private lazy var completionQueue: DispatchQueue = {
        DispatchQueue(
            label: "jp.co.soramitsu.fearless.fetchCoder.\(self.chainId)",
            qos: .userInitiated
        )
    }()

    private(set) var snapshot: RuntimeSnapshot?
    private(set) var pendingRequests: [PendingRequest] = []
    private(set) var currentWrapper: BaseOperation<RuntimeSnapshot?>?
    private var mutex = NSLock()

    private var commonTypes: Data?
    private var chainTypes: Data?
    private var chainMetadata: RuntimeMetadataItem?

    init(
        chainModel: ChainModel,
        snapshotOperationFactory: RuntimeSnapshotFactoryProtocol,
        snapshotHotOperationFactory: RuntimeHotBootSnapshotFactoryProtocol?,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        dataHasher: StorageHasher = .twox256,
        logger: LoggerProtocol? = nil,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>,
        usedRuntimePaths: [String: [String]],
        chainMetadata: RuntimeMetadataItem?,
        chainTypes: Data?
    ) {
        chainId = chainModel.chainId
        typesUsage = chainModel.typesUsage
        chainName = chainModel.name
        self.snapshotOperationFactory = snapshotOperationFactory
        self.snapshotHotOperationFactory = snapshotHotOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
        self.logger = logger
        self.repository = repository
        self.usedRuntimePaths = usedRuntimePaths
        self.chainMetadata = chainMetadata
        self.chainTypes = chainTypes

        self.operationQueue.maxConcurrentOperationCount = 10

        eventCenter.add(observer: self, dispatchIn: DispatchQueue.global())
    }

    private func buildSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        guard
            commonTypes != nil || typesUsage == .onlyOwn,
            let chainTypes = chainTypes,
            let chainMetadata = chainMetadata,
            compareChainsTypes(local: runtimeSnapshot?.localChainTypes, remote: chainTypes)
        else {
            return
        }

        logger?.debug("Will start building snapshot for \(chainName)")

        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher,
            commonTypes: commonTypes,
            chainTypes: chainTypes,
            chainMetadata: chainMetadata,
            usedRuntimePaths: usedRuntimePaths
        )

        wrapper.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperation(wrapper)
    }

    private func compareChainsTypes(local: Data?, remote: Data) -> Bool {
        guard
            let localData = local,
            let localJson = try? JSONDecoder().decode(JSON.self, from: localData),
            let remoteJson = try? JSONDecoder().decode(JSON.self, from: remote)
        else {
            return true
        }

        return localJson != remoteJson
    }

    private func buildHotSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        logger?.debug("Will start building hot snapshot for \(chainName)")

        guard let snapshotHotOperationFactory = snapshotHotOperationFactory,
              let chainTypes = chainTypes
        else {
            return
        }

        let wrapper = snapshotHotOperationFactory.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher,
            usedRuntimePaths: usedRuntimePaths,
            chainTypes: chainTypes
        )

        wrapper.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperation(wrapper)
    }

    private func handleCompletion(result: Result<RuntimeSnapshot?, Error>?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        switch result {
        case let .success(snapshot):
            currentWrapper = nil

            if let snapshot = snapshot {
                self.snapshot = snapshot

                logger?.debug("Did complete snapshot for: \(chainName), Will notify waiters: \(pendingRequests.count)")

                resolveRequests()
            }
        case let .failure(error):
            currentWrapper = nil

            logger?.error("Failed to build snapshot for \(chainName): \(error)")
        case .none:
            break
        }
    }

    private func resolveRequests() {
        guard !pendingRequests.isEmpty else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

        requests.forEach { deliver(snapshot: snapshot, to: $0) }
    }

    private func deliver(snapshot: RuntimeSnapshot?, to request: PendingRequest) {
        let coderFactory = snapshot.map {
            RuntimeCoderFactory(
                catalog: $0.typeRegistryCatalog,
                specVersion: $0.specVersion,
                txVersion: $0.txVersion,
                metadata: $0.metadata
            )
        }

        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(coderFactory)
        }
    }

    private func fetchCoderFactory(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (RuntimeCoderFactoryProtocol?) -> Void
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = PendingRequest(resultClosure: closure, queue: queue)

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw RuntimeProviderError.providerUnavailable
            }

            var fetchedFactory: RuntimeCoderFactoryProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            strongSelf.fetchCoderFactory(runCompletionIn: strongSelf.completionQueue) { factory in
                fetchedFactory = factory
                semaphore.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeProviderError.providerUnavailable
            }

            return factory
        }
    }

    func fetchCoderFactoryOperation(
        with _: TimeInterval,
        closure _: RuntimeMetadataClosure?
    ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            guard let strongSelf = self else {
                throw RuntimeProviderError.providerUnavailable
            }

            var fetchedFactory: RuntimeCoderFactoryProtocol?
            let semaphore = DispatchSemaphore(value: 0)

            strongSelf.fetchCoderFactory(runCompletionIn: strongSelf.completionQueue) { factory in
                fetchedFactory = factory
                semaphore.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeProviderError.providerUnavailable
            }

            return factory
        }
    }
}

extension RuntimeProvider: RuntimeProviderProtocol {
    func setupHot() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildHotSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    var runtimeSnapshot: RuntimeSnapshot? {
        snapshot
    }

    func setup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard currentWrapper == nil else {
            return
        }

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard typesUsage != newTypeUsage else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        typesUsage = newTypeUsage

        buildSnapshot(with: newTypeUsage, dataHasher: dataHasher)
    }

    func cleanup() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        snapshot = nil

        currentWrapper?.cancel()
        currentWrapper = nil

        resolveRequests()
    }
}

extension RuntimeProvider: EventVisitorProtocol {
    func processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted) {
        guard let chainTypes = event.versioningMap[chainId] else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        self.chainTypes = chainTypes

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func processRuntimeChainMetadataSyncCompleted(event: RuntimeMetadataSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        chainMetadata = event.metadata

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func processRuntimeCommonTypesSyncCompleted(event: RuntimeCommonTypesSyncCompleted) {
        guard typesUsage != .onlyOwn else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localCommonHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        commonTypes = event.data

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }
}
