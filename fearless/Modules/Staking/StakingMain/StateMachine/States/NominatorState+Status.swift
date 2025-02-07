import Foundation
import IrohaCrypto
import BigInt

extension NominatorState {
    var status: NominationViewStatus {
        guard let eraStakers = commonData.eraStakersInfo else {
            return .undefined
        }

        do {
            let accountId = try SS58AddressFactory().accountId(from: stashItem.stash)

            let allNominators = eraStakers.validators.map(\.exposure.others)
                .flatMap { (nominators) -> [IndividualExposure] in
                    if let maxNominatorsPerValidator = commonData.maxNominatorsPerValidator {
                        return Array(nominators.prefix(Int(maxNominatorsPerValidator)))
                    } else {
                        return nominators
                    }
                }
                .reduce(into: Set<Data>()) { $0.insert($1.who) }

            if allNominators.contains(accountId) {
                return .active(era: eraStakers.activeEra)
            }

            if nomination.submittedIn >= eraStakers.activeEra {
                return .waiting(eraCountdown: commonData.eraCountdown, nominationEra: nomination.submittedIn)
            }

            return .inactive(era: eraStakers.activeEra)

        } catch {
            return .undefined
        }
    }

    var allValidatorsWithoutReward: Bool {
        guard
            let eraStakers = commonData.eraStakersInfo,
            let maxNominatorsPerValidator = commonData.maxNominatorsPerValidator else {
            return false
        }

        do {
            let accountId = try SS58AddressFactory().accountId(from: stashItem.stash)
            let nominatorPositions = eraStakers.validators.compactMap { validator in
                validator.exposure.others.firstIndex(where: { $0.who == accountId })
            }

            guard !nominatorPositions.isEmpty else {
                return false
            }

            return nominatorPositions.allSatisfy { $0 >= maxNominatorsPerValidator }

        } catch {
            return false
        }
    }

    func createStatusPresentableViewModel(
        locale: Locale?
    ) -> SheetAlertPresentableViewModel? {
        switch status {
        case .active:
            return createActiveStatus(locale: locale)
        case .inactive:
            return createInactiveStatus(locale: locale)
        case .waiting:
            return createWaitingStatus(locale: locale)
        case .undefined:
            return createUndefinedStatus(locale: locale)
        case .validatorsNotSelected:
            return createValidatorsAreNotSelectedStatus(locale: locale)
        }
    }

    private func createActiveStatus(locale: Locale?) -> SheetAlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertActiveTitle(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertActiveMessage(preferredLanguages: locale?.rLanguages)

        return SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createInactiveStatus(
        locale: Locale?
    ) -> SheetAlertPresentableViewModel? {
        guard let minStake = commonData.minStake else {
            return nil
        }

        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusAlertInactiveTitle(preferredLanguages: locale?.rLanguages)
        let message: String

        if ledgerInfo.active < minStake {
            message = R.string.localizable
                .stakingNominatorStatusAlertLowStake(preferredLanguages: locale?.rLanguages)
        } else if allValidatorsWithoutReward {
            message = R.string.localizable
                .stakingYourOversubscribedMessage(preferredLanguages: locale?.rLanguages)
        } else {
            message = R.string.localizable
                .stakingNominatorStatusAlertNoValidators(preferredLanguages: locale?.rLanguages)
        }

        return SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createWaitingStatus(locale: Locale?) -> SheetAlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable
            .stakingNominatorStatusWaiting(preferredLanguages: locale?.rLanguages)
        let message = R.string.localizable
            .stakingNominatorStatusAlertWaitingMessage(preferredLanguages: locale?.rLanguages)

        return SheetAlertPresentableViewModel(
            title: title,
            message: message,
            actions: [],
            closeAction: closeAction
        )
    }

    private func createUndefinedStatus(locale _: Locale?) -> SheetAlertPresentableViewModel? {
        nil
    }

    private func createValidatorsAreNotSelectedStatus(locale: Locale?) -> SheetAlertPresentableViewModel? {
        let closeAction = R.string.localizable.commonClose(preferredLanguages: locale?.rLanguages)
        let title = R.string.localizable.stakingSetValidatorsMessage(preferredLanguages: locale?.rLanguages)

        return SheetAlertPresentableViewModel(
            title: title,
            message: nil,
            actions: [],
            closeAction: closeAction
        )
    }
}
