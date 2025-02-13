import Foundation
import UIKit

protocol PolkaswapSwapConfirmationViewModelFactoryProtocol {
    func createViewModel(
        with params: PolkaswapPreviewParams,
        locale: Locale
    ) -> PolkaswapSwapConfirmationViewModel
}

final class PolkaswapSwapConfirmationViewModelFactory: PolkaswapSwapConfirmationViewModelFactoryProtocol {
    private enum Constants {
        static let imageWidth: CGFloat = 8
        static let imageHeight: CGFloat = 14
        static let imageVerticalPosition: CGFloat = 6
    }

    func createViewModel(
        with params: PolkaswapPreviewParams,
        locale: Locale
    ) -> PolkaswapSwapConfirmationViewModel {
        let doubleImageViewViewModel = PolkaswapDoubleSymbolViewModel(
            leftViewModel: params.swapFromChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) },
            rightViewModel: params.swapToChainAsset.asset.icon.map { RemoteImageViewModel(url: $0) }
        )

        let amountsText = buildAmountsText(for: params, locale: locale)

        let viewModel = PolkaswapSwapConfirmationViewModel(
            amountsText: amountsText,
            doubleImageViewViewModel: doubleImageViewViewModel,
            adjustmentDetailsViewModel: params.detailsViewModel,
            networkFee: params.networkFee
        )
        return viewModel
    }

    private func buildAmountsText(
        for params: PolkaswapPreviewParams,
        locale: Locale
    ) -> NSMutableAttributedString {
        let fromAmount = params.fromAmount.toString(locale: locale)
        let fromName = params.swapFromChainAsset.asset.name
        let leftText = [fromAmount, fromName]
            .compactMap { $0 }
            .joined(separator: " ")

        let rightAmount = params.toAmount.toString(locale: locale)
        let rightName = params.swapToChainAsset.asset.name
        let rightText = [rightAmount, rightName]
            .compactMap { $0 }
            .joined(separator: " ")

        let amountsTitle = insertArrow(in: [leftText, rightText])
        return amountsTitle
    }

    private func insertArrow(in texts: [String]) -> NSMutableAttributedString {
        let attributedString = NSMutableAttributedString()

        texts.enumerated().forEach { index, text in
            attributedString.append(NSAttributedString(string: text))
            if index % 2 == 0 {
                let imageAttachment = NSTextAttachment()
                imageAttachment.image = R.image.iconSmallArrow()
                imageAttachment.bounds = CGRect(
                    x: 0,
                    y: -Constants.imageVerticalPosition,
                    width: imageAttachment.image?.size.width ?? Constants.imageWidth,
                    height: imageAttachment.image?.size.height ?? Constants.imageHeight
                )

                let imageString = NSAttributedString(attachment: imageAttachment)
                attributedString.append(imageString)
                attributedString.append(NSAttributedString(string: "  "))
            }
        }

        return attributedString
    }
}
