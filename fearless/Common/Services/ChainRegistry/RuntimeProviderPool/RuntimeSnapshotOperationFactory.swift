import Foundation
import FearlessUtils
import RobinHood

protocol RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher,
        commonTypes: Data?,
        chainTypes: Data,
        chainMetadata: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?>
}

final class RuntimeSnapshotFactory {
    private let chainId: ChainModel.Id
    private let filesOperationFactory: RuntimeFilesOperationFactoryProtocol
    private let repository: AnyDataProviderRepository<RuntimeMetadataItem>

    init(
        chainId: ChainModel.Id,
        filesOperationFactory: RuntimeFilesOperationFactoryProtocol,
        repository: AnyDataProviderRepository<RuntimeMetadataItem>
    ) {
        self.chainId = chainId
        self.filesOperationFactory = filesOperationFactory
        self.repository = repository
    }

    private func createWrapperForCommonAndChainTypes(
        _ dataHasher: StorageHasher,
        commonTypes: Data?,
        chainTypes: Data,
        runtimeMetadataItem: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            guard let commonTypes = commonTypes else {
                return nil
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                commonTypes,
                versioningData: chainTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: commonTypes).toHex(),
                localChainTypes: chainTypes,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }

    private func createWrapperForCommonTypes(
        _ dataHasher: StorageHasher,
        commonTypes: Data?,
        runtimeMetadataItem: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            guard let commonTypes = commonTypes else {
                return nil
            }

            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                commonTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: try dataHasher.hash(data: commonTypes).toHex(),
                localChainTypes: nil,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }

    private func createWrapperForChainTypes(
        ownTypes: Data,
        runtimeMetadataItem: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        let snapshotOperation = ClosureOperation<RuntimeSnapshot?> {
            let decoder = try ScaleDecoder(data: runtimeMetadataItem.metadata)
            let runtimeMetadata = try RuntimeMetadata(scaleDecoder: decoder)

            // TODO: think about it
            let json: JSON = .dictionaryValue(["types": .dictionaryValue([:])])
            let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
                try JSONEncoder().encode(json),
                versioningData: ownTypes,
                runtimeMetadata: runtimeMetadata,
                usedRuntimePaths: usedRuntimePaths
            )

            return RuntimeSnapshot(
                localCommonHash: nil,
                localChainTypes: ownTypes,
                typeRegistryCatalog: catalog,
                specVersion: runtimeMetadataItem.version,
                txVersion: runtimeMetadataItem.txVersion,
                metadata: runtimeMetadata
            )
        }

        return snapshotOperation
    }
}

extension RuntimeSnapshotFactory: RuntimeSnapshotFactoryProtocol {
    func createRuntimeSnapshotWrapper(
        for typesUsage: ChainModel.TypesUsage,
        dataHasher: StorageHasher,
        commonTypes: Data?,
        chainTypes: Data,
        chainMetadata: RuntimeMetadataItem,
        usedRuntimePaths: [String: [String]]
    ) -> ClosureOperation<RuntimeSnapshot?> {
        switch typesUsage {
        case .onlyCommon:
            return createWrapperForCommonTypes(
                dataHasher,
                commonTypes: commonTypes,
                runtimeMetadataItem: chainMetadata,
                usedRuntimePaths: usedRuntimePaths
            )
        case .onlyOwn:
            return createWrapperForChainTypes(
                ownTypes: chainTypes,
                runtimeMetadataItem: chainMetadata,
                usedRuntimePaths: usedRuntimePaths
            )
        case .both:
            return createWrapperForCommonAndChainTypes(
                dataHasher,
                commonTypes: commonTypes,
                chainTypes: chainTypes,
                runtimeMetadataItem: chainMetadata,
                usedRuntimePaths: usedRuntimePaths
            )
        }
    }
}
