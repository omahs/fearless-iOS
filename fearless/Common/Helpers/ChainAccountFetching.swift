import Foundation

struct ChainAccountRequest {
    let chainId: ChainModel.Id
    let addressPrefix: UInt16
    let isEthereumBased: Bool
    let accountId: AccountId?
}

struct ChainAccountResponse: Equatable {
    let chainId: ChainModel.Id
    let accountId: AccountId
    let publicKey: Data
    let name: String
    let cryptoType: CryptoType
    let addressPrefix: UInt16
    let isEthereumBased: Bool
    let isChainAccount: Bool
    let walletId: String
}

enum ChainAccountFetchingError: Error {
    case accountNotExists
}

extension ChainAccountResponse {
    func toAccountItem() throws -> AccountItem {
        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
        let address = try accountId.toAddress(using: chainFormat)
        let cryptoType = CryptoType(rawValue: cryptoType.rawValue) ?? .ecdsa

        return AccountItem(
            address: address,
            cryptoType: cryptoType,
            username: name,
            publicKeyData: publicKey
        )
    }

    func toDisplayAddress() throws -> DisplayAddress {
        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
        let address = try accountId.toAddress(using: chainFormat)

        return DisplayAddress(address: address, username: name)
    }

    func toAddress() -> AccountAddress? {
        let chainFormat: ChainFormat = isEthereumBased ? .ethereum : .substrate(addressPrefix)
        return try? accountId.toAddress(using: chainFormat)
    }

    func chainFormat() -> ChainFormat {
        isEthereumBased ? .ethereum : .substrate(addressPrefix)
    }
}

extension MetaAccountModel {
    func fetch(for request: ChainAccountRequest) -> ChainAccountResponse? {
        if let chainAccount = chainAccounts.first(where: { $0.chainId == request.chainId }) {
            guard let cryptoType = CryptoType(rawValue: chainAccount.cryptoType) else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: chainAccount.accountId,
                publicKey: chainAccount.publicKey,
                name: name,
                cryptoType: cryptoType,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: true,
                walletId: metaId
            )
        }

        if request.isEthereumBased {
            guard let publicKey = ethereumPublicKey, let accountId = ethereumAddress else {
                return nil
            }

            return ChainAccountResponse(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey,
                name: name,
                cryptoType: .ecdsa,
                addressPrefix: request.addressPrefix,
                isEthereumBased: request.isEthereumBased,
                isChainAccount: false,
                walletId: metaId
            )
        }

        guard let cryptoType = CryptoType(rawValue: substrateCryptoType) else {
            return nil
        }

        return ChainAccountResponse(
            chainId: request.chainId,
            accountId: substrateAccountId,
            publicKey: substratePublicKey,
            name: name,
            cryptoType: cryptoType,
            addressPrefix: request.addressPrefix,
            isEthereumBased: false,
            isChainAccount: false,
            walletId: metaId
        )
    }
}

extension ChainModel {
    func accountRequest(_ accountId: AccountId? = nil) -> ChainAccountRequest {
        ChainAccountRequest(
            chainId: chainId,
            addressPrefix: addressPrefix,
            isEthereumBased: isEthereumBased,
            accountId: accountId
        )
    }
}
