//
//  ParkListTableViewCell.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import CombineEx
import Inject
import MapKit
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
            $0.layout.width == $0.parentLayout.width

            UIContainer {
                $0.backgroundColor = .init(white: 0.9, alpha: 1)
                $0.layout.top == $0.parentLayout.topMargin
                $0.layout.bottom == $0.parentLayout.bottomMargin
                $0.layout.leading == $0.parentLayout.leadingMargin
                $0.layout.trailing == $0.parentLayout.trailingMargin
                $0.layer.cornerRadius = 8

                UILabel {
                    $0.layout.leading == $0.parentLayout.leadingMargin
                    $0.layout.top == $0.parentLayout.topMargin
                    $0.textColor = .darkText
                    $0.bind(\.text) <~ model.map(\.name)
                }

                MKMapView {
                    $0.layout.trailing == $0.parentLayout.trailing
                    $0.layout.top == $0.parentLayout.top
                    $0.layout.bottom == $0.parentLayout.bottom
                    $0.layout.width == $0.layout.height
                    $0.setRegion(.init(center: CLLocationCoordinate2D(latitude: 0, longitude: 0), latitudinalMeters: 3000, longitudinalMeters: 3000), animated: false)

                    $0.sink(model.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }) { mapView, coordinate in
                        mapView.setCenter(coordinate, animated: false)
                    }
                }
            }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
