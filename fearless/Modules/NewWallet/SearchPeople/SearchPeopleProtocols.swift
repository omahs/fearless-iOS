import CommonWallet
protocol SearchPeopleViewProtocol: ControllerBackedProtocol {
    func didReceive(state: SearchPeopleViewState)
    func didReceive(title: String?)
    func didReceive(locale: Locale)
    func didReceive(input: String)
}

protocol SearchPeoplePresenterProtocol: AnyObject {
    func setup()
    func searchTextDidChanged(_ text: String)
    func didTapBackButton()
    func didSelectViewModel(viewModel: SearchPeopleTableCellViewModel)
    func didTapScanButton()
}

protocol SearchPeopleInteractorInputProtocol: AnyObject {
    func performSearch(query: String)
}

protocol SearchPeopleInteractorOutputProtocol: AnyObject {
    func didReceive(searchResult: Result<[SearchData]?, Error>)
}

protocol SearchPeopleWireframeProtocol: AnyObject {
    func close(_ view: ControllerBackedProtocol?)
    func presentSend(
        from view: ControllerBackedProtocol?,
        to address: String,
        asset: AssetModel,
        chain: ChainModel
    )

    func presentScan(
        from view: ControllerBackedProtocol?,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        moduleOutput: WalletScanQRModuleOutput?
    )
}
