import Foundation
import SoraFoundation
import SoraKeystore

final class ProfilePresenter {
    private weak var view: ProfileViewProtocol?
    private var interactor: ProfileInteractorInputProtocol
    private var wireframe: ProfileWireframeProtocol
    private let logger: LoggerProtocol
    private let settings: SettingsManagerProtocol
    private let viewModelFactory: ProfileViewModelFactoryProtocol
    private let eventCenter: EventCenter

    private var selectedWallet: MetaAccountModel?
    private var selectedCurrency: Currency?
    private var balance: WalletBalanceInfo?

    init(
        viewModelFactory: ProfileViewModelFactoryProtocol,
        interactor: ProfileInteractorInputProtocol,
        wireframe: ProfileWireframeProtocol,
        logger: LoggerProtocol,
        settings: SettingsManagerProtocol,
        eventCenter: EventCenter,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.viewModelFactory = viewModelFactory
        self.interactor = interactor
        self.wireframe = wireframe
        self.logger = logger
        self.settings = settings
        self.eventCenter = eventCenter
        self.localizationManager = localizationManager

        self.eventCenter.add(
            observer: self,
            dispatchIn: .main
        )
    }

    private func receiveState() {
        guard
            let wallet = selectedWallet,
            let language = localizationManager?.selectedLanguage,
            let currency = selectedCurrency
        else { return }

        let viewModel = viewModelFactory.createProfileViewModel(
            from: wallet,
            locale: selectedLocale,
            language: language,
            currency: currency,
            balance: balance
        )
        let state = ProfileViewState.loaded(viewModel)
        view?.didReceive(state: state)
    }
}

extension ProfilePresenter: ProfilePresenterProtocol {
    func didLoad(view: ProfileViewProtocol) {
        self.view = view
        interactor.setup(with: self)
    }

    func activateAccountDetails() {
        guard let wallet = selectedWallet else {
            return
        }
        wireframe.showAccountDetails(from: view, metaAccount: wallet)
    }

    func activateOption(_ option: ProfileOption) {
        switch option {
        case .accountList:
            wireframe.showAccountSelection(from: view)
        case .changePincode:
            wireframe.showPincodeChange(from: view)
        case .language:
            wireframe.showLanguageSelection(from: view)
        case .about:
            wireframe.showAbout(from: view)
        case .currency:
            guard let selectedWallet = selectedWallet else { return }
            wireframe.showSelectCurrency(from: view, with: selectedWallet)
        case .biometry:
            break
        }
    }

    func switcherValueChanged(isOn: Bool) {
        settings.biometryEnabled = isOn
    }

    func logout() {
        let removeTitle = R.string.localizable
            .profileLogoutTitle(preferredLanguages: selectedLocale.rLanguages)

        let removeAction = SheetAlertPresentableAction(
            title: removeTitle,
            button: UIFactory.default.createDestructiveButton()
        ) { [weak self] in
            guard let self = self else { return }
            self.wireframe.showCheckPincode(
                from: self.view,
                output: self
            )
        }

        let cancelTitle = R.string.localizable.commonCancel(preferredLanguages: selectedLocale.rLanguages)
        let cancelAction = SheetAlertPresentableAction(
            title: cancelTitle,
            button: UIFactory.default.createAccessoryButton()
        )

        let title = R.string.localizable
            .profileLogoutTitle(preferredLanguages: selectedLocale.rLanguages)
        let details = R.string.localizable
            .profileLogoutDescription(preferredLanguages: selectedLocale.rLanguages)
        let viewModel = SheetAlertPresentableViewModel(
            title: title,
            message: details,
            actions: [cancelAction, removeAction],
            closeAction: nil
        )

        wireframe.present(viewModel: viewModel, from: view)
    }
}

extension ProfilePresenter: CheckPincodeModuleOutput {
    func close(view: ControllerBackedProtocol?) {
        wireframe.close(view: view)
    }

    func didCheck() {
        interactor.logout { [weak self] in
            DispatchQueue.main.async {
                self?.wireframe.logout(from: self?.view)
            }
        }
    }
}

extension ProfilePresenter: ProfileInteractorOutputProtocol {
    func didReceive(wallet: MetaAccountModel) {
        selectedWallet = wallet
        receiveState()
    }

    func didReceiveUserDataProvider(error: Error) {
        logger.debug("Did receive user data provider \(error)")

        if !wireframe.present(error: error, from: view, locale: selectedLocale) {
            _ = wireframe.present(
                error: CommonError.undefined,
                from: view,
                locale: selectedLocale
            )
        }
    }

    func didRecieve(selectedCurrency: Currency) {
        self.selectedCurrency = selectedCurrency
        receiveState()
    }

    func didReceiveWalletBalances(_ balances: Result<[MetaAccountId: WalletBalanceInfo], Error>) {
        switch balances {
        case let .success(balances):
            if let wallet = selectedWallet {
                balance = balances[wallet.metaId]
                receiveState()
            }
        case let .failure(error):
            logger.error("WalletsManagmentPresenter error: \(error.localizedDescription)")
        }
    }
}

extension ProfilePresenter: Localizable {
    func applyLocalization() {
        if view?.isSetup == true {
            receiveState()
        }
    }
}

extension ProfilePresenter: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        let currency = event.account.selectedCurrency
        selectedWallet = event.account
        interactor.update(currency: currency)
    }
}
