import Foundation
import FearlessUtils

extension StorageKeyFactoryProtocol {
    func accountInfoKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(
            moduleName: "System",
            storageName: "Account",
            key: identifier,
            hasher: .blake128Concat
        )
    }

    func bondedKeyForId(_ identifier: Data) throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "Bonded",
            key: identifier,
            hasher: .twox64Concat
        )
    }

    func stakingInfoForControllerId(_ identifier: Data) throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "Ledger",
            key: identifier,
            hasher: .blake128Concat
        )
    }

    func locksForId(_ identifier: Data) throws -> Data {
        try createStorageKey(
            moduleName: "Balances",
            storageName: "Locks",
            key: identifier,
            hasher: .blake128Concat
        )
    }

    func activeEra() throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "ActiveEra"
        )
    }

    func currentEra() throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "CurrentEra"
        )
    }

    func totalIssuance() throws -> Data {
        try createStorageKey(
            moduleName: "Balances",
            storageName: "TotalIssuance"
        )
    }

    func historyDepth() throws -> Data {
        try createStorageKey(
            moduleName: "Staking",
            storageName: "HistoryDepth"
        )
    }

    func key(from codingPath: StorageCodingPath) throws -> Data {
        try createStorageKey(moduleName: codingPath.moduleName, storageName: codingPath.itemName)
    }
}
