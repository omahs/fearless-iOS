import Foundation
import UIKit

struct PolkaswapDoubleSymbolViewModel {
    let leftViewModel: RemoteImageViewModel?
    let rightViewModel: RemoteImageViewModel?
}

final class PolkaswapDoubleSymbolView: UIView {
    private enum Constants {
        static let imageViewSize = CGSize(width: 41, height: 41)
        static let imageViewInset: CGFloat = 18.0
        static let imagesInset: CGFloat = 22.0
    }

    private let leftContainer = UIView()
    private let rightContainer = UIView()
    private let leftImageView = UIImageView()
    private let rightImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        leftContainer.layer.cornerRadius = leftContainer.frame.height / 2
        rightContainer.layer.cornerRadius = rightContainer.frame.height / 2
    }

    func bind(viewModel: PolkaswapDoubleSymbolViewModel) {
        viewModel.rightViewModel?.loadImage(
            on: rightImageView,
            targetSize: Constants.imageViewSize,
            animated: true
        )
        viewModel.leftViewModel?.loadImage(
            on: leftImageView,
            targetSize: Constants.imageViewSize,
            animated: true
        )
    }

    private func setupLayout() {
        leftContainer.backgroundColor = R.color.colorBlack()
        rightContainer.backgroundColor = R.color.colorBlack()

        leftContainer.addSubview(leftImageView)
        leftImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.imageViewInset)
            make.size.equalTo(Constants.imageViewSize)
        }

        rightContainer.addSubview(rightImageView)
        rightImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(Constants.imageViewInset)
            make.size.equalTo(Constants.imageViewSize)
        }

        [leftContainer, rightContainer].forEach { view in
            view.layer.shadowColor = R.color.colorPink()!.cgColor
            view.layer.shadowRadius = 12
            view.layer.shadowOpacity = 0.5
        }

        addSubview(rightContainer)
        addSubview(leftContainer)

        leftContainer.snp.makeConstraints { make in
            make.top.leading.bottom.equalToSuperview()
            make.trailing.equalTo(rightContainer.snp.leading).offset(Constants.imagesInset)
        }

        rightContainer.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
        }
    }
}
