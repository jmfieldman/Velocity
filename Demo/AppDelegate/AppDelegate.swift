//
//  AppDelegate.swift
//  Copyright © 2025 Jason Fieldman.
//

import Foundation
import Injection
import ParkUI
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // MARK: - UIApplicationDelegate

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        InjectionManager.registerInjections()

        // Construct the window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ParkListViewController())
        window?.makeKeyAndVisible()

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {}
    func applicationWillResignActive(_ application: UIApplication) {}
    func applicationDidEnterBackground(_ application: UIApplication) {}
    func applicationWillTerminate(_ application: UIApplication) {}
    func applicationWillEnterForeground(_ application: UIApplication) {}
}
