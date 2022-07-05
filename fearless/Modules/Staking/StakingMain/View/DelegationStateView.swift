import SoraFoundation
class DelegationStateView: StakingStateView, LocalizableViewProtocol {
    private lazy var timer = CountdownTimer()
    private lazy var timeFormatter = TotalTimeFormatter()
    private var localizableViewModel: LocalizableResource<DelegationViewModelProtocol>?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    deinit {
        timer.stop()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        timer.delegate = self
    }

    func bind(viewModel: LocalizableResource<DelegationViewModelProtocol>) {
        localizableViewModel = viewModel

        timer.stop()
        applyViewModel()
    }

    private func applyLocalization() {
        stakeTitleLabel.text = R.string.localizable
            .stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingTotalRewards_v190(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            titleLabel.text = R.string.localizable
                .stakingYourStake(preferredLanguages: locale.rLanguages)
            return
        }

        if let interval = viewModel.nextRoundInterval {
            timer.start(with: interval, runLoop: RunLoop.current, mode: .tracking)
        }

        statusView.valueView.detailsLabel.isHidden = viewModel.nextRoundInterval == nil

        titleLabel.text = viewModel.name == nil ?
            R.string.localizable.stakingYourStake(preferredLanguages: locale.rLanguages) : viewModel.name
        stakeAmountView.valueTop.text = viewModel.totalStakedAmount
        stakeAmountView.valueBottom.text = viewModel.totalStakedPrice
        rewardAmountView.valueTop.text = viewModel.totalRewardAmount
        rewardAmountView.valueBottom.text = viewModel.totalRewardPrice

        toggleStatus(true)

        var skeletonOptions: StakingStateSkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        if viewModel.totalRewardAmount.isEmpty {
            skeletonOptions.insert(.rewards)
        }

        switch viewModel.status {
        case let .active(countdown):
            presentActiveStatus(countdown: countdown)
        case let .idle(countdown):
            presentIdleStatus(countdown: countdown)
        case let .leaving(countdown):
            presentLeavingState(countdown: countdown)
        case .undefined:
            skeletonOptions.insert(.status)
        }

        if !skeletonOptions.isEmpty, viewModel.hasPrice {
            skeletonOptions.insert(.price)
        }

        setupSkeleton(options: skeletonOptions)
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusView.isHidden = !shouldShow
        statusButton.isUserInteractionEnabled = shouldShow
    }

    private func presentActiveStatus(countdown: TimeInterval?) {
        statusView.titleView.indicatorColor = R.color.colorGreen()!
        statusView.titleView.titleLabel.textColor = R.color.colorGreen()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages).uppercased()
        if let remainingTime = countdown {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        }
    }

    private func presentIdleStatus(countdown: TimeInterval?) {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusIdle(preferredLanguages: locale.rLanguages).uppercased()
        if let remainingTime = countdown {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        }
    }

    private func presentLeavingState(countdown: TimeInterval?) {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusLeaving(preferredLanguages: locale.rLanguages).uppercased()
        if let remainingTime = countdown {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        }
    }
}

extension DelegationStateView: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        let intervalString = (try? timeFormatter.string(from: interval)) ?? ""
        statusView.valueView.detailsLabel.text = "\(R.string.localizable.stakingNextRound(preferredLanguages: locale.rLanguages)): \(intervalString)"
    }

    func didCountdown(remainedInterval: TimeInterval) {
        let intervalString = (try? timeFormatter.string(from: remainedInterval)) ?? ""
        statusView.valueView.detailsLabel.text = "\(R.string.localizable.stakingNextRound(preferredLanguages: locale.rLanguages)): \(intervalString)"
    }

    func didStop(with _: TimeInterval) {
        statusView.valueView.detailsLabel.text = ""
    }
}
