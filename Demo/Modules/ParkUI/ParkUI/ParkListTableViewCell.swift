//
//  ParkListTableViewCell.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import CombineEx
import Inject
import Mortar
import Strings
import UIKit

public final class ParkListTableViewCell: UITableViewCell, ManagedTableViewCell {
    public struct Model: ManagedTableViewCellModel {
        public typealias Cell = ParkListTableViewCell

        public let id: String
        public let latitude: Double
        public let longitude: Double
        public let name: String
        public let owner: String
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.configure {
            $0.layout.height == 120
            $0.backgroundColor = .red

            UILabel {
                $0.layout.leading == $0.parentLayout.leadingMargin
                $0.layout.top == $0.parentLayout.topMargin
                $0.textColor = .darkGray
                $0.bind(\.text) <~ model.map(\.name)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
