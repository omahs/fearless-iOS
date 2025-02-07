protocol ChainSelectionViewProtocol: SelectionListViewProtocol {}

protocol ChainSelectionPresenterProtocol: SelectionListPresenterProtocol {
    func setup()
}

protocol ChainSelectionInteractorInputProtocol: AnyObject {
    func setup()
}

protocol ChainSelectionInteractorOutputProtocol: AnyObject {
    func didReceiveChains(result: Result<[ChainModel], Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, for chainAssetKey: ChainAssetKey)
}

protocol ChainSelectionWireframeProtocol: SheetAlertPresentable, ErrorPresentable {
    func complete(on view: ChainSelectionViewProtocol, selecting chain: ChainModel?)
}

protocol ChainSelectionDelegate: AnyObject {
    func chainSelection(view: ChainSelectionViewProtocol, didCompleteWith chain: ChainModel?)
}
