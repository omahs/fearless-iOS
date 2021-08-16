import Foundation
import RobinHood
import FearlessUtils

protocol RuntimeProviderProtocol: AnyObject {
    var chainId: ChainModel.Id { get }

    func setup()
    func replaceTypesUsage(_ newTypeUsage: ChainModel.TypesUsage)
    func cleanup()
}

protocol RuntimeCodingProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol>
}

enum RuntimeProviderError: Error {
    case providerUnavailable
}

final class RuntimeProvider {
    struct PendingRequest {
        let resultClosure: (RuntimeCoderFactoryProtocol?) -> Void
        let queue: DispatchQueue?
    }

    let chainId: ChainModel.Id
    private(set) var typesUsage: ChainModel.TypesUsage

    let snapshotOperationFactory: RuntimeSnapshotFactoryProtocol
    let eventCenter: EventCenterProtocol
    let operationQueue: OperationQueue
    let dataHasher: StorageHasher

    private(set) var snapshot: RuntimeSnapshot?
    private(set) var pendingRequests: [PendingRequest] = []
    private(set) var currentWrapper: CompoundOperationWrapper<RuntimeSnapshot?>?
    private var mutex = NSLock()

    init(
        chainModel: ChainModel,
        snapshotOperationFactory: RuntimeSnapshotFactoryProtocol,
        eventCenter: EventCenterProtocol,
        operationQueue: OperationQueue,
        dataHasher: StorageHasher = .twox256
    ) {
        chainId = chainModel.chainId
        typesUsage = chainModel.typesUsage
        self.snapshotOperationFactory = snapshotOperationFactory
        self.eventCenter = eventCenter
        self.operationQueue = operationQueue
        self.dataHasher = dataHasher
    }

    private func buildSnapshot(with typesUsage: ChainModel.TypesUsage, dataHasher: StorageHasher) {
        let wrapper = snapshotOperationFactory.createRuntimeSnapshotWrapper(
            for: typesUsage,
            dataHasher: dataHasher
        )

        wrapper.targetOperation.completionBlock = { [weak self] in
            DispatchQueue.global(qos: .userInitiated).async {
                self?.handleCompletion(result: wrapper.targetOperation.result)
            }
        }

        currentWrapper = wrapper

        operationQueue.addOperations(wrapper.allOperations, waitUntilFinished: false)
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
                resolveRequests()

                DispatchQueue.main.async {
                    let event = RuntimeCoderCreated(chainId: self.chainId)
                    self.eventCenter.notify(with: event)
                }
            }
        case let .failure(error):
            currentWrapper = nil

            DispatchQueue.main.async {
                let event = RuntimeCoderCreationFailed(chainId: self.chainId, error: error)
                self.eventCenter.notify(with: event)
            }
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
}

extension RuntimeProvider: RuntimeProviderProtocol {
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
    func processRuntimeChainTypesSyncCompleted(event: RuntimeChainTypesSyncCompleted) {
        guard event.chainId == chainId else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localNetworkHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

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

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }

    func processRuntimeBaseTypesSyncCompleted(event: RuntimeBaseTypesSyncCompleted) {
        guard typesUsage != .onlyOwn else {
            return
        }

        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard snapshot?.localBaseHash != event.fileHash else {
            return
        }

        currentWrapper?.cancel()
        currentWrapper = nil

        buildSnapshot(with: typesUsage, dataHasher: dataHasher)
    }
}

extension RuntimeProvider: RuntimeCodingProtocol {
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { [weak self] in
            var fetchedFactory: RuntimeCoderFactoryProtocol?

            let semaphore = DispatchSemaphore(value: 0)

            self?.fetchCoderFactory(runCompletionIn: nil) { [weak semaphore] factory in
                fetchedFactory = factory
                semaphore?.signal()
            }

            semaphore.wait()

            guard let factory = fetchedFactory else {
                throw RuntimeProviderError.providerUnavailable
            }

            return factory
        }
    }
}
