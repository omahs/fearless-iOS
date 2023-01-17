import Foundation

protocol VerificationStatusViewModelFactoryProtocol {
    func buildStatusViewModel(from status: SCVerificationStatus?) -> SoraCardStatus
}

final class VerificationStatusViewModelFactory: VerificationStatusViewModelFactoryProtocol {
    func buildStatusViewModel(from status: SCVerificationStatus?) -> SoraCardStatus {
        guard let status = status else {
            return .failure
        }

        switch status {
        case .none:
            return .failure
        case .pending:
            return .pending
        case .accepted:
            return .success
        case .rejected:
            return .rejected
        }
    }
}
