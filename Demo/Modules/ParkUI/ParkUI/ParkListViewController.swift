//
//  ParkListViewController.swift
//  Copyright © 2025 Jason Fieldman.
//

import Inject
import UIKit

public protocol ParkListViewController: UIViewController, MainActorBuildable {}

public struct ParkListViewControllerBuilder: Builder {
    public typealias BuildResult = ParkListViewController

    public init() {}
}
