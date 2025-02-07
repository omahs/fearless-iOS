import Foundation
@testable import fearless

enum ChainModelGenerator {
    static func generate(
        count: Int,
        withTypes: Bool = true,
        staking: StakingType? = nil,
        hasCrowdloans: Bool = false
    ) -> [ChainModel] {
        (0..<count).map { index in
            let chainId = Data.random(of: 32)!.toHex()

            let node = ChainNodeModel(
                url: URL(string: "wss://node.io/\(chainId)")!,
                name: chainId,
                apikey: nil
            )

            let types = withTypes ? ChainModel.TypesSettings(
                url: URL(string: "https://github.com")!,
                overridesCommon: false
            ) : nil

            var options: [ChainOptions] = []

            if hasCrowdloans {
                options.append(.crowdloans)
            }

            let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
                for: chainId,
                staking: staking,
                hasCrowdloans: hasCrowdloans
            )

            let chain = ChainModel(
                            chainId: chainId,
                            parentId: nil,
                            name: String(chainId.reversed()),
                            assets: [],
                            nodes: [node],
                            addressPrefix: UInt16(index),
                            types: types,
                            icon: URL(string: "https://github.com")!,
                            options: options.isEmpty ? nil : options,
                            externalApi: externalApi,
                            customNodes: nil,
                            iosMinAppVersion: nil,
                            unused: false
                        )
            let asset = generateAssetWithId("", assetPresicion: 12, chainId: chainId)
            let chainAsset = generateChainAsset(asset, chain: chain, staking: staking)
            let chainAssets = Set(arrayLiteral: chainAsset)
            chain.assets = chainAssets
            return chain
        }
    }

    static func generateChain(
        generatingAssets count: Int,
        addressPrefix: UInt16,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        staking: StakingType? = nil,
        hasCrowdloans: Bool = false
    ) -> ChainModel {
        let chainId = Data.random(of: 32)!.toHex()

        let urlString = "node\(Data.random(of: 32)!.toHex()).io"

        let node = ChainNodeModel(
            url: URL(string: urlString)!,
            name: UUID().uuidString,
            apikey: nil
        )

        var options: [ChainOptions] = []

        if hasCrowdloans {
            options.append(.crowdloans)
        }

        let externalApi: ChainModel.ExternalApiSet? = generateExternaApis(
            for: chainId,
            staking: staking,
            hasCrowdloans: hasCrowdloans
        )

        let chain = ChainModel(
            chainId: chainId,
            parentId: nil,
            name: UUID().uuidString,
            assets: [],
            nodes: [node],
            addressPrefix: addressPrefix,
            types: nil,
            icon: Constants.dummyURL,
            options: options.isEmpty ? nil : options,
            externalApi: externalApi,
            customNodes: nil,
            iosMinAppVersion: nil,
            unused: false
        )
        let chainAssetsArray: [ChainAssetModel] = (0..<count).map { index in
            let asset = generateAssetWithId(
                AssetModel.Id(index),
                assetPresicion: assetPresicion
            )
            return generateChainAsset(asset, chain: chain, staking: staking)
        }
        let chainAssets = Set(chainAssetsArray)
        chain.assets = chainAssets
        return chain
    }
    
    static func generateChainAsset(_ asset: AssetModel, chain: ChainModel, staking: StakingType? = nil) -> ChainAssetModel {
        ChainAssetModel(assetId: asset.id,
                        staking: staking,
                        purchaseProviders: nil,
                        asset: asset,
                        chain: chain)
    }

    static func generateAssetWithId(
        _ identifier: AssetModel.Id,
        assetPresicion: UInt16 = (9...18).randomElement()!,
        chainId: String = ""
    ) -> AssetModel {
        AssetModel(
            id: identifier,
            chainId: chainId,
            precision: 12,
            icon: nil,
            priceId: nil,
            price: nil
        )
    }

    private static func generateExternaApis(
        for chainId: ChainModel.Id,
        staking: StakingType?,
        hasCrowdloans: Bool
    ) -> ChainModel.ExternalApiSet? {
        let crowdloanApi: ChainModel.ExternalApi?

        if hasCrowdloans {
            crowdloanApi = ChainModel.ExternalApi(
                type: "test",
                url: URL(string: "https://crowdloan.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            crowdloanApi = nil
        }

        let stakingApi: ChainModel.ExternalApi?

        if staking != nil {
            stakingApi = ChainModel.ExternalApi(
                type: "test",
                url: URL(string: "https://staking.io/\(chainId)-\(UUID().uuidString).json")!
            )
        } else {
            stakingApi = nil
        }

        if crowdloanApi != nil || stakingApi != nil {
            return ChainModel.ExternalApiSet(staking: stakingApi, history: nil, crowdloans: crowdloanApi)
        } else {
            return nil
        }
    }
}
