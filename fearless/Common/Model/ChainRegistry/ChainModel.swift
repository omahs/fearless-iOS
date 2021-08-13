import Foundation
import RobinHood

struct ChainModel: Codable, Hashable {
    // swiftlint:disable type_name
    typealias Id = String

    struct TypesSettings: Codable, Hashable {
        let url: URL
        let overridesCommon: Bool
    }

    let chainId: Id
    let assets: [AssetModel]
    let nodes: [ChainNodeModel]
    let addressPrefix: UInt16
    let types: TypesSettings?
    let icon: URL
    let isEthereumBased: Bool
}

extension ChainModel: Identifiable {
    var identifier: String { chainId }
}
