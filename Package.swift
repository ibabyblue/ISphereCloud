// swift-tools-version: 6.2
//
//  Package.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "ISphereCloud",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "ISphereCloud", targets: ["ISphereCloud"]),
    ],
    targets: [
        .target(name: "ISphereCloud"),
        .testTarget(name: "ISphereCloudTests", dependencies: ["ISphereCloud"]),
    ]
)
