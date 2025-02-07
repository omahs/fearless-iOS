typealias WalletMainContainerModuleCreationResult = (
    view: WalletMainContainerViewInput,
    input: WalletMainContainerModuleInput
)

protocol WalletMainContainerViewInput: ControllerBackedProtocol, HiddableBarWhenPushed {
    func didReceiveViewModel(_ viewModel: WalletMainContainerViewModel)
}

protocol WalletMainContainerViewOutput: AnyObject {
    func didLoad(view: WalletMainContainerViewInput)
    func didTapOnSwitchWallet()
    func didTapOnQR()
    func didTapSearch()
    func didTapSelectNetwork()
    func didTapOnBalance()
    func didTapIssueButton()
    func addressDidCopied()
}

protocol WalletMainContainerInteractorInput: AnyObject {
    func setup(with output: WalletMainContainerInteractorOutput)
    func saveChainIdForFilter(_ chainId: ChainModel.Id?)
}

protocol WalletMainContainerInteractorOutput: AnyObject {
    func didReceiveAccount(_ account: MetaAccountModel)
    func didReceiveSelectedChain(_ chain: ChainModel?)
    func didReceiveError(_ error: Error)
    func didReceiveChainsIssues(chainsIssues: [ChainIssue])
}

protocol WalletMainContainerRouterInput: SheetAlertPresentable, ErrorPresentable, ApplicationStatusPresentable {
    func showWalletManagment(
        from view: WalletMainContainerViewInput?,
        moduleOutput: WalletsManagmentModuleOutput?
    )
    func showScanQr(from view: WalletMainContainerViewInput?, moduleOutput: ScanQRModuleOutput)
    func showSearch(from view: WalletMainContainerViewInput?, wallet: MetaAccountModel)
    func showSelectNetwork(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel,
        selectedChainId: ChainModel.Id?,
        chainModels: [ChainModel]?,
        delegate: SelectNetworkDelegate?
    )
    func showCreateNewWallet(from view: WalletMainContainerViewInput?)
    func showImportWallet(from view: WalletMainContainerViewInput?)
    func showSelectCurrency(
        from view: WalletMainContainerViewInput?,
        wallet: MetaAccountModel
    )
    func showIssueNotification(
        from view: WalletMainContainerViewInput?,
        issues: [ChainIssue],
        wallet: MetaAccountModel
    )

    func showSendFlow(
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        address: String
    )
}

protocol WalletMainContainerModuleInput: AnyObject {}

protocol WalletMainContainerModuleOutput: AnyObject {}
