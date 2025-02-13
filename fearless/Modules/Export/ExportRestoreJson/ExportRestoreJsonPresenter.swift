import Foundation
import SoraFoundation

final class ExportRestoreJsonPresenter {
    weak var view: ExportGenericViewProtocol?
    var wireframe: ExportRestoreJsonWireframeProtocol!

    let localizationManager: LocalizationManager
    let models: [RestoreJson]
    let flow: ExportFlow

    init(
        models: [RestoreJson],
        flow: ExportFlow,
        localizationManager: LocalizationManager
    ) {
        self.models = models
        self.flow = flow
        self.localizationManager = localizationManager
    }

    private func activateExport(model: RestoreJson) {
        let items: [JsonExportAction] = [.file, .text]
        let selectionCallback: ModalPickerSelectionCallback = { [weak self] selectedIndex in
            guard let self = self else { return }
            let action = items[selectedIndex]
            switch action {
            case .file:
                self.wireframe.share(sources: [model.fileURL], from: self.view, with: nil)
            case .text:
                self.wireframe.share(sources: [model.data], from: self.view, with: nil)
            }
        }

        wireframe.presentExportActionsFlow(
            from: view,
            items: items,
            callback: selectionCallback
        )
    }
}

extension ExportRestoreJsonPresenter: ExportGenericPresenterProtocol {
    func didLoadView() {}

    func setup() {
        let viewModels = models.compactMap { model in
            ExportStringViewModel(
                option: .keystore,
                chain: model.chain,
                cryptoType: model.cryptoType,
                derivationPath: nil,
                data: model.data,
                ethereumBased: model.chain.isEthereumBased
            )
        }

        let multipleExportViewModel = MultiExportViewModel(
            viewModels: viewModels,
            option: .keystore,
            flow: flow
        )

        view?.set(viewModel: multipleExportViewModel)
    }

    func didTapExportEthereumButton() {
        if let model = models.first(where: { $0.chain.isEthereumBased }) {
            activateExport(model: model)
        }
    }

    func didTapExportSubstrateButton() {
        if let model = models.first(where: { !$0.chain.isEthereumBased }) {
            activateExport(model: model)
        }
    }

    func activateAccessoryOption() {
        wireframe.showChangePassword(from: view)
    }
}
