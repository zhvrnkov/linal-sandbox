//
//  AppDelegate.swift
//  game-of-life
//
//  Created by Zhavoronkov Vlad on 11/15/22.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    lazy var window: UIWindow? = .init(frame: UIScreen.main.bounds)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()
        (application.connectedScenes.first! as! UIWindowScene).sizeRestrictions?.minimumSize = CGSize(width: 1080, height: 1080 + 36)
        return true
    }
}

