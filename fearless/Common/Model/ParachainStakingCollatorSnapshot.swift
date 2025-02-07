import Foundation
import FearlessUtils
import BigInt

struct ParachainStakingCollatorSnapshot: Codable, Equatable {
    @StringCodable var bond: BigUInt
    @StringCodable var total: BigUInt
    let delegations: [ParachainStakingDelegation]
}
