import Foundation
@testable import fearless
import RobinHood
import BigInt

final class WalletLocalSubscriptionFactoryStub: WalletLocalSubscriptionFactoryProtocol {
    let accountInfo: AccountInfo?
    let ormlAccountInfo: OrmlAccountInfo?

    init(balance: BigUInt? = nil) {
        self.accountInfo = balance.map { value in
            AccountInfo(
                nonce: 0,
                consumers: 1,
                providers: 2,
                data: AccountData(
                    free: value,
                    reserved: 0,
                    miscFrozen: 0,
                    feeFrozen: 0
                )
            )
        }
        
        self.ormlAccountInfo = balance.map { value in
            OrmlAccountInfo(free: value, reserved: 0, frozen: 0)
        }
    }

    func getAccountProvider(
        for accountId: AccountId,
        chainId: ChainModel.Id
    ) throws -> AnyDataProvider<DecodedAccountInfo> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let accountInfoModel: DecodedAccountInfo = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .account,
                accountId: accountId,
                chainId: chainId
            )

            if let accountInfo = accountInfo {
                return DecodedAccountInfo(identifier: localKey, item: accountInfo)
            } else {
                return DecodedAccountInfo(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [accountInfoModel]))
    }
    
    func getOrmlAccountProvider(for accountId: AccountId, chain: ChainModel) throws -> AnyDataProvider<DecodedOrmlAccountInfo> {
        let localIdentifierFactory = LocalStorageKeyFactory()

        let ormlAccountInfoModel: DecodedOrmlAccountInfo = try {
            let localKey = try localIdentifierFactory.createFromStoragePath(
                .account,
                accountId: accountId,
                chainId: chain.chainId
            )

            if let accountInfo = ormlAccountInfo {
                return DecodedOrmlAccountInfo(identifier: localKey, item: accountInfo)
            } else {
                return DecodedOrmlAccountInfo(identifier: localKey, item: nil)
            }
        }()

        return AnyDataProvider(DataProviderStub(models: [ormlAccountInfoModel]))
    }
}
