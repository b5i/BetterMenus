//
//  AppDelegate.swift
//  BetterMenusExample
//
//  Created by Antoine Bollengier on 30.08.2025.
//  Copyright © 2025 Antoine Bollengier (github.com/b5i). All rights reserved.
//

import BetterMenus
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // This single AppDelegate creates the window and root view controller.
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        let nav = UINavigationController(rootViewController: MenuViewController())
        window?.rootViewController = nav
        window?.makeKeyAndVisible()
        return true
    }
}
