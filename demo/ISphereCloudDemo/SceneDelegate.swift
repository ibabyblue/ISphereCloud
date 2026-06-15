//
//  SceneDelegate.swift
//  ISphereCloudDemo
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
}
