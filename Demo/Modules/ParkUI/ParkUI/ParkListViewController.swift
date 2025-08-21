//
//  ParkListViewController.swift
//  Copyright © 2025 Jason Fieldman.
//

import Mortar
import UIKit

public final class ParkListViewController: UIViewController {
    override public func loadView() {
        view = UIContainer {
            $0.backgroundColor = .red
        }
    }
}
