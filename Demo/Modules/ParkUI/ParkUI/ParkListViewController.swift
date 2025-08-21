//
//  ParkListViewController.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import CombineEx
import Inject
import Mortar
import Strings
import UIKit

public final class ParkListViewController: UIViewController {
    fileprivate let model = ParkListViewControllerModel()

    override public func loadView() {
        view = UIContainer {
            ManagedTableView {
                $0.backgroundColor = .themeBackgroundPrimary
                $0.separatorStyle = .none
                $0.layout.edges == $0.parentLayout.edges
                $0.sections <~ model.sections
            }
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = Z.general.coasterPal
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .themeBackgroundPrimary.withAlphaComponent(0.8)
        appearance.largeTitleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.themeForegroundPrimary,
        ]
        appearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.themeForegroundPrimary,
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }
}

private final class ParkListViewControllerModel {
    private let coasterDataManager: CoasterDataManager = Inject()

    init() {
        coasterDataManager.refreshParksAction.applyIfPossible(())
            .sink(duringLifetimeOf: self)
    }

    private(set) lazy var sections: Property<[ManagedTableViewSection]> = Property(
        initial: [],
        then: coasterDataManager.streamParks().map { [weak self] parks in
            self?.convertParksToSections(parks) ?? []
        }.demoteFailure()
    )

    private func convertParksToSections(_ parks: [Park]) -> [ManagedTableViewSection] {
        guard parks.count > 0 else {
            return []
        }

        var result: [ManagedTableViewSection] = []
        var currentOwner = parks[0].owner
        var currentRows: [ParkListTableViewCell.Model] = []

        for park in parks {
            if park.owner != currentOwner {
                result.append(
                    ManagedTableViewSection(
                        id: currentOwner,
                        rows: currentRows
                    )
                )

                currentRows = []
                currentOwner = park.owner
            }

            currentRows.append(
                ParkListTableViewCell.Model(
                    id: "park_\(park.id)",
                    latitude: park.latitude,
                    longitude: park.longitude,
                    name: park.name,
                    owner: park.owner
                )
            )
        }

        result.append(
            ManagedTableViewSection(
                id: currentOwner,
                rows: currentRows
            )
        )

        return result
    }
}
