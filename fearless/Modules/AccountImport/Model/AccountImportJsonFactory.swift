import Foundation
import FearlessUtils

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        let chain: Chain?
        let networkTypeConfirmed: Bool

        if let definitionGenesisHashString = definition.meta?.genesisHash,
           let definitionGenesisHash = try? Data(hexString: definitionGenesisHashString),
           let genesisBasedChain = Chain.allCases
           .first(where: { definitionGenesisHash == (try? Data(hexString: $0.genesisHash)) }) {
            chain = genesisBasedChain
            networkTypeConfirmed = true
        } else {
            if let chainType = info.chainType {
                chain = SNAddressType(rawValue: UInt16(chainType))?.chain
            } else {
                chain = nil
            }

            networkTypeConfirmed = false
        }

        // TODO: Check with Ethereum data
        return MetaAccountImportPreferredInfo(
            username: info.meta?.name,
            networkType: chain,
            cryptoType: CryptoType(info.cryptoType),
            networkTypeConfirmed: networkTypeConfirmed
        )
    }
}
