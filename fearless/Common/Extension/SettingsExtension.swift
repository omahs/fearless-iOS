import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case selectedLocalization
    case selectedAccount
    case biometryEnabled
    case selectedConnection
    case crowdloadChainId
    case stakingAsset
    case stakingNetworkExpansion
    case referralEthereumAccount
    case selectedCurrency
}

extension SettingsManagerProtocol {
    var hasSelectedAccount: Bool {
        selectedAccount != nil
    }

    var selectedAccount: AccountItem? {
        get {
            value(of: AccountItem.self, for: SettingsKey.selectedAccount.rawValue)
        }

        set {
            if let newValue = newValue {
                set(value: newValue, for: SettingsKey.selectedAccount.rawValue)
            } else {
                removeValue(for: SettingsKey.selectedAccount.rawValue)
            }
        }
    }

    var biometryEnabled: Bool? {
        get {
            bool(for: SettingsKey.biometryEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }
    }

    var selectedConnection: ConnectionItem {
        get {
            if let nodeItem = value(of: ConnectionItem.self, for: SettingsKey.selectedConnection.rawValue) {
                return nodeItem
            } else {
                return .defaultConnection
            }
        }

        set {
            set(value: newValue, for: SettingsKey.selectedConnection.rawValue)
        }
    }

    var crowdloanChainId: String? {
        get {
            string(for: SettingsKey.crowdloadChainId.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.crowdloadChainId.rawValue)
            } else {
                removeValue(for: SettingsKey.crowdloadChainId.rawValue)
            }
        }
    }

    var stakingAsset: ChainAssetId? {
        get {
            value(of: ChainAssetId.self, for: SettingsKey.stakingAsset.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.stakingAsset.rawValue)
            } else {
                removeValue(for: SettingsKey.stakingAsset.rawValue)
            }
        }
    }

    var stakingNetworkExpansion: Bool {
        get {
            bool(for: SettingsKey.stakingNetworkExpansion.rawValue) ?? true
        }

        set {
            set(value: newValue, for: SettingsKey.stakingNetworkExpansion.rawValue)
        }
    }

    func saveReferralEthereumAddressForSelectedAccount(_ ethereumAccountAddress: String?) {
        guard let selectedAccount = selectedAccount else { return }

        let key = SettingsKey.referralEthereumAccount.rawValue.appending(selectedAccount.address)

        guard let ethereumAccountAddress = ethereumAccountAddress else {
            removeValue(for: key)
            return
        }

        set(value: ethereumAccountAddress, for: key)
    }

    func referralEthereumAddressForSelectedAccount() -> String? {
        guard let selectedAccount = selectedAccount else { return nil }

        let key = SettingsKey.referralEthereumAccount.rawValue.appending(selectedAccount.address)
        return string(for: key)
    }
}
