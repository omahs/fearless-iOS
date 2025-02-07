import Foundation
import RobinHood
import FearlessUtils

enum SubqueryRewardOperationFactoryError: Error {
    case urlMissing
}

protocol SubqueryRewardOperationFactoryProtocol {
    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData>

    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryDelegatorHistoryData>

    func createAprOperation(
        for idsClosure: @escaping () throws -> [AccountId],
        dependingOn roundIdOperation: BaseOperation<String>
    ) -> BaseOperation<SubqueryCollatorDataResponse>

    func createLastRoundOperation() -> BaseOperation<String>
}

extension SubqueryRewardOperationFactoryProtocol {
    func createHistoryOperation(address: String) -> BaseOperation<SubqueryRewardOrSlashData> {
        createHistoryOperation(address: address, startTimestamp: nil, endTimestamp: nil)
    }
}

final class SubqueryRewardOperationFactory {
    let url: URL?

    init(url: URL?) {
        self.url = url
    }

    private func prepareLastRoundsQuery() -> String {
        """
        {
                  rounds(last: 1) {
                      nodes {
                        id
                      }
                  }
                }
        """
    }

    private func prepareCollatorsAprQuery(collatorIds: [String], roundId: String) -> String {
        """
        {
        collatorRounds(
        filter:
        {
            collatorId: { inInsensitive: \(collatorIds) }
            apr: { isNull: false, greaterThan: 0 }
            roundId: { equalTo: "\(roundId)"}
        }
        )
        {
        nodes {
            collatorId
            apr
            }
          }
        }
        """
    }

    private func prepareDelegatorHistoryRequest(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            guard startTimestamp != nil || endTimestamp != nil else { return "" }
            var result = "timestamp:{"
            if let timestamp = startTimestamp {
                result.append("greaterThanOrEqualTo:\"\(timestamp)\",")
            }
            if let timestamp = endTimestamp {
                result.append("lessThanOrEqualTo:\"\(timestamp)\",")
            }
            result.append("}")
            return result
        }()

        return """
        {
                    delegators(
                         filter: {
                             id: { equalToInsensitive:"\(address)"}
                        }
                     ) {
                        nodes {
                            id
                          delegatorHistoryElements(orderBy: TIMESTAMP_DESC, filter: { amount: {isNull: false}, \(timestampFilter), type: { equalTo: 0 }}) {
                              nodes {
                                id
                                blockNumber
                                amount
                                type
                                timestamp
                                delegator {
                                    id
                                }
                              }
                          }
                        }
                     }
                }
        """
    }

    private func prepareHistoryRequestForAddress(
        _ address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> String {
        let timestampFilter: String = {
            guard startTimestamp != nil || endTimestamp != nil else { return "" }
            var result = "timestamp:{"
            if let timestamp = startTimestamp {
                result.append("greaterThanOrEqualTo:\"\(timestamp)\",")
            }
            if let timestamp = endTimestamp {
                result.append("lessThanOrEqualTo:\"\(timestamp)\",")
            }
            result.append("}")
            return result
        }()

        return """
        {
                                historyElements(
                                     orderBy: TIMESTAMP_DESC,
                                     filter: {
                                         address: { equalTo: \"\(address)\"},
                                         reward: { isNull: false },
                                        \(timestampFilter)
                                     }
                                 ) {
                                    nodes {
                                        id
                                        timestamp
                                        address
                                        reward
                }
             }
        }

        """
    }
}

extension SubqueryRewardOperationFactory: SubqueryRewardOperationFactoryProtocol {
    func createLastRoundOperation() -> BaseOperation<String> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let queryString = strongSelf.prepareLastRoundsQuery()

            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<String> { data in
            var roundId: String = ""

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let collatorRounds = data["rounds"] as? [String: Any],
               let nodesJson = collatorRounds["nodes"] as? [[String: Any]] {
                for nodeJson in nodesJson {
                    if let foundRoundId = nodeJson["id"] as? String {
                        if let roundIdValue = Int(foundRoundId) {
                            roundId = "\(roundIdValue - 1)"
                        }
                    }
                }
            }

            return roundId
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func createAprOperation(
        for idsClosure: @escaping () throws -> [AccountId],
        dependingOn roundIdOperation: BaseOperation<String>
    ) -> BaseOperation<SubqueryCollatorDataResponse> {
        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            guard let strongSelf = self else {
                throw CommonError.internal
            }

            let roundId = (try? roundIdOperation.extractNoCancellableResultData()) ?? ""

            let ids = try? idsClosure()
            let idsFilter = (ids?.compactMap { $0.toHex(includePrefix: true) }) ?? []

            let queryString = strongSelf.prepareCollatorsAprQuery(collatorIds: idsFilter, roundId: roundId)

            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryCollatorDataResponse> { data in
            var nodes: [SubqueryCollatorData] = []

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let data = json["data"] as? [String: Any],
               let collatorRounds = data["collatorRounds"] as? [String: Any],
               let nodesJson = collatorRounds["nodes"] as? [[String: Any]] {
                for nodeJson in nodesJson {
                    if let collatorId = nodeJson["collatorId"] as? String, let apr = nodeJson["apr"] as? Double {
                        let data = SubqueryCollatorData(collatorId: collatorId, apr: apr)
                        nodes.append(data)
                    }
                }
            }

            let response = SubqueryResponse.data(SubqueryCollatorDataResponse(collatorRounds: SubqueryCollatorDataResponse.HistoryElements(nodes: nodes)))

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func createDelegatorRewardsOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryDelegatorHistoryData> {
        let queryString = prepareDelegatorHistoryRequest(
            address: address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryDelegatorHistoryData> { data in
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw SubqueryHistoryOperationFactoryError.incorrectInputData
            }

            guard let dataDict = json["data"] as? [String: Any] else {
                throw SubqueryHistoryOperationFactoryError.incorrectInputData
            }

            let historyData = try SubqueryDelegatorHistoryData(json: dataDict)

            return historyData
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }

    func createHistoryOperation(
        address: String,
        startTimestamp: Int64?,
        endTimestamp: Int64?
    ) -> BaseOperation<SubqueryRewardOrSlashData> {
        let queryString = prepareHistoryRequestForAddress(
            address,
            startTimestamp: startTimestamp,
            endTimestamp: endTimestamp
        )

        let requestFactory = BlockNetworkRequestFactory { [weak self] in
            guard let url = self?.url else {
                throw SubqueryRewardOperationFactoryError.urlMissing
            }

            var request = URLRequest(url: url)

            let info = JSON.dictionaryValue(["query": JSON.stringValue(queryString)])
            request.httpBody = try JSONEncoder().encode(info)
            request.setValue(
                HttpContentType.json.rawValue,
                forHTTPHeaderField: HttpHeaderKey.contentType.rawValue
            )

            request.httpMethod = HttpMethod.post.rawValue
            return request
        }

        let resultFactory = AnyNetworkResultFactory<SubqueryRewardOrSlashData> { data in
            let response = try JSONDecoder().decode(
                SubqueryResponse<SubqueryRewardOrSlashData>.self,
                from: data
            )

            switch response {
            case let .errors(error):
                throw error
            case let .data(response):
                return response
            }
        }

        let operation = NetworkOperation(requestFactory: requestFactory, resultFactory: resultFactory)

        return operation
    }
}
