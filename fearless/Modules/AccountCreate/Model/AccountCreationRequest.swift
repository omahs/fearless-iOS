import Foundation
import IrohaCrypto

@available(*, deprecated, message: "Use MetaAccountCreationRequest instead")
struct AccountCreationRequest {
    let username: String
    let type: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct MetaAccountCreationRequest {
    let username: String
    let substrateDerivationPath: String
    let substrateCryptoType: MultiassetCryptoType
    let ethereumDerivationPath: String
}
