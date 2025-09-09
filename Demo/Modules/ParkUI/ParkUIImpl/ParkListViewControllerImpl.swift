//
//  ParkListViewControllerImpl.swift
//  Copyright © 2025 Jason Fieldman.
//

import CoasterDataManager
import CoasterModels
import ColorsResources
import CombineEx
import Inject
import Mortar
import ParkUI
import StringsResources
import UIKit

public final class ParkListViewControllerImpl: UIViewController, ParkListViewController {
    fileprivate let model = ParkListViewControllerModel()

    public required init(builder: ParkListViewControllerBuilder) {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadView() {
        view = UIContainer {
            ManagedTableView {
                $0.backgroundColor = .Colors.background
                $0.separatorStyle = .none
                $0.layout.edges == $0.parentLayout.edges
                $0.sections <~ model.sections
            }
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        title = .Strings.parksNavigationTitle
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .Colors.background.withAlphaComponent(0.8)
        appearance.largeTitleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.Colors.foreground,
        ]
        appearance.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.Colors.foreground,
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
