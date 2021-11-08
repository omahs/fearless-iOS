import UIKit
import SoraFoundation
import SoraUI

final class ReferralCrowdloanViewController: UIViewController, ViewHolder {
    typealias RootViewType = ReferralCrowdloanViewLayout

    let presenter: ReferralCrowdloanPresenterProtocol

    private var referralViewModel: ReferralCrowdloanViewModel?
    private var codeInputViewModel: InputViewModelProtocol?

    private var state = ReferralCrowdloanViewState.loading

    init(presenter: ReferralCrowdloanPresenterProtocol, localizationManager: LocalizationManagerProtocol) {
        self.presenter = presenter
        super.init(nibName: nil, bundle: nil)

        self.localizationManager = localizationManager
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = ReferralCrowdloanViewLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()

        presenter.setup()
    }

    private func configure() {
        rootView.codeInputView.animatedInputField.textField.returnKeyType = .done
        rootView.codeInputView.animatedInputField.textField.autocapitalizationType = .none
        rootView.codeInputView.animatedInputField.textField.autocorrectionType = .no
        rootView.codeInputView.animatedInputField.textField.spellCheckingType = .no

        rootView.codeInputView.animatedInputField.delegate = self
        rootView.codeInputView.animatedInputField.addTarget(
            self, action: #selector(actionCodeChanged(_:)),
            for: .editingChanged
        )

        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(actionTapTerms(_:)))
        rootView.termsLabel.addGestureRecognizer(tapGestureRecognizer)

        rootView.termsSwitchView.addTarget(self, action: #selector(actionSwitchTerms), for: .valueChanged)

        rootView.actionButton.addTarget(self, action: #selector(actionApplyInputCode), for: .touchUpInside)
        rootView.applyAppBonusButton.addTarget(self, action: #selector(actionApplyDefaultCode), for: .touchUpInside)

        rootView.learnMoreView.addTarget(self, action: #selector(actionLearnMore), for: .touchUpInside)
    }

    private func setupLocalization() {
        title = R.string.localizable.commonBonus(preferredLanguages: selectedLocale.rLanguages)

        rootView.locale = selectedLocale

        applyState()
    }

    private func applyState() {
        rootView.contentView.stackView.arrangedSubviews.forEach { arrangedSubview in
            arrangedSubview.isHidden = true
        }

        var visibleViews: [UIView] = []

        switch state {
        case .loading:
            visibleViews = [rootView.codeInputView]
        case let .loadedDefaultFlow(referralCrowdloanViewModel):
            visibleViews = [rootView.codeInputView, rootView.bonusView, rootView.privacyView, rootView.learnMoreView, rootView.actionButton]
            rootView.bind(to: referralCrowdloanViewModel)
        case let .loadedAstarFlow(astarReferralCrowdloanViewModel):
            visibleViews = [rootView.codeInputView, rootView.applyAppBonusButton, rootView.learnMoreView, rootView.actionButton]
            rootView.bind(to: astarReferralCrowdloanViewModel)
        }

        visibleViews.forEach { visibleView in
            visibleView.isHidden = false
        }
    }

    private func applyReferralViewModel() {
        guard let referralViewModel = referralViewModel else {
            return
        }

        rootView.bonusView.valueLabel.text = referralViewModel.bonusValue
        rootView.myBonusView.valueLabel.text = referralViewModel.bonusValue

        if referralViewModel.canApplyDefaultCode {
            rootView.applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.applyFearlessWalletBonus(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()

            rootView.applyAppBonusButton.isEnabled = true
            rootView.applyAppBonusButton.applyDisabledStyle()
        } else {
            rootView.applyAppBonusButton.imageWithTitleView?.title = R.string.localizable.appliedFearlessWalletBonus(
                preferredLanguages: selectedLocale.rLanguages
            ).uppercased()

            rootView.applyAppBonusButton.isEnabled = false
            rootView.applyAppBonusButton.applyDefaultStyle()
        }

        rootView.applyAppBonusButton.invalidateLayout()

        rootView.termsSwitchView.isOn = referralViewModel.isTermsAgreed

        if !referralViewModel.isCodeReceived {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.karuraReferralCodeAction(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else if !referralViewModel.isTermsAgreed {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.karuraTermsAction(
                preferredLanguages: selectedLocale.rLanguages
            )
        } else {
            rootView.actionButton.imageWithTitleView?.title = R.string.localizable.commonApply(
                preferredLanguages: selectedLocale.rLanguages
            )
        }

        rootView.actionButton.invalidateLayout()

        rootView.setNeedsLayout()
    }

    @objc private func actionSwitchTerms() {
        presenter.setTermsAgreed(value: rootView.termsSwitchView.isOn)
    }

    @objc private func actionApplyDefaultCode() {
        presenter.applyDefaultCode()

        rootView.codeInputView.animatedInputField.textField.resignFirstResponder()
    }

    @objc private func actionCodeChanged(_ sender: UITextField) {
        if codeInputViewModel?.inputHandler.value != sender.text {
            sender.text = codeInputViewModel?.inputHandler.value
        }

        presenter.update(referralCode: codeInputViewModel?.inputHandler.value ?? "")
    }

    @objc private func actionApplyInputCode() {
        presenter.applyInputCode()
    }

    @objc private func actionTapTerms(_ sender: UIGestureRecognizer) {
        if sender.state == .ended {
            presenter.presentTerms()
        }
    }

    @objc private func actionLearnMore() {
        presenter.presentLearnMore()
    }
}

extension ReferralCrowdloanViewController: AnimatedTextFieldDelegate {
    func animatedTextField(
        _ textField: AnimatedTextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let viewModel = codeInputViewModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }

    func animatedTextFieldShouldReturn(_ textField: AnimatedTextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }
}

extension ReferralCrowdloanViewController: ReferralCrowdloanViewProtocol {
    func didReceiveState(state: ReferralCrowdloanViewState) {
        self.state = state
        applyState()
    }

    func didReceiveLearnMore(viewModel: LearnMoreViewModel) {
        rootView.learnMoreView.bind(viewModel: viewModel)
    }

    func didReceiveInput(viewModel: InputViewModelProtocol) {
        codeInputViewModel = viewModel

        rootView.codeInputView.animatedInputField.text = viewModel.inputHandler.value
    }

    func didReceiveShouldInputCode() {
        rootView.codeInputView.animatedInputField.becomeFirstResponder()
    }

    func didReceiveShouldAgreeTerms() {
        ShakeAnimator(
            duration: 0.5,
            options: [.curveEaseInOut]
        ).animate(view: rootView.termsSwitchView, completionBlock: nil)
    }
}

extension ReferralCrowdloanViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
        }
    }
}
