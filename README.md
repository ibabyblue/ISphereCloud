# ISphereCloud

A 3D spherical tag cloud for iOS 17+: nodes laid out on a sphere surface, drag to rotate in any
direction, perspective near-large/far-small, release inertia, and idle auto-rotation. Tapping a
front-facing node fires a selection callback. Generic over your data item, node views supplied by
a closure. Pure UIKit, zero third-party dependencies.

Inspired by the Soul app's "people-matching planet" screen.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2%2B-orange)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Features

- **True 3D sphere** — points are distributed with a Fibonacci-sphere layout and projected with
  perspective; nearer nodes are larger and more opaque, farther nodes shrink and fade.
- **Drag to rotate, any direction** — horizontal drag spins about the Y axis, vertical about the X axis.
- **Inertia + idle rotation** — fling and it keeps spinning with decay; when idle it auto-rotates slowly.
- **Generic + closure-rendered nodes** — `ISphereCloudView<Item>`; you return a `UIView` per item and
  load any images yourself (the package does no networking).
- **Front-facing hit testing** — taps select the front-most node under the finger; back-facing nodes are ignored.

## Requirements

| | Minimum |
|---|---|
| iOS | 17.0 |
| Swift | 6.2 |
| Xcode | 16.3 |

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies**, enter the repository URL, or add to `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/ibabyblue/ISphereCloud", from: "0.0.1")
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "ISphereCloud", package: "ISphereCloud")
    ])
]
```

## Quick Start

```swift
let sphere = ISphereCloudView<SoulUser>()
sphere.setItems(users) { user in
    let cell = AvatarNodeCell()   // round avatar + nickname
    cell.load(user)               // you load the image
    return cell
}
sphere.onSelect = { user in router.pushProfile(user) }
view.addSubview(sphere)           // pin its edges however you like
```

Items must be `Hashable`. Provide cells with a real `intrinsicContentSize` so the hit area matches
the visible node.

## Configuration

```swift
var config = ISphereCloudConfiguration()
config.idleRotationEnabled = true
config.idleRotationSpeed   = 0.15        // radians / second
config.inertiaEnabled      = true
config.minScale            = 0.4         // farthest-node scale
config.minAlpha            = 0.3         // farthest-node alpha
config.perspective         = 1.0 / 1500  // CATransform3D.m34 magnitude
config.rotationSensitivity = 1.0
let sphere = ISphereCloudView<SoulUser>(configuration: config)
```

## API Reference

```swift
public final class ISphereCloudView<Item: Hashable>: UIView {
    public init(configuration: ISphereCloudConfiguration = .init())
    public func setItems(_ items: [Item], cellProvider: @escaping (Item) -> UIView)
    public var onSelect: ((Item) -> Void)?
    public func reloadData()
    public func startIdleRotation()
    public func stopRotation()
}
```

## Edge-Case Behavior

| Case | Behavior |
|---|---|
| Empty items | Empty sphere, no nodes; no crash |
| Single node | Placed on the sphere; still rotatable |
| Very many nodes | Cells built once; only transforms update each frame |
| `reloadData` while spinning | Rotation pose preserved; nodes replaced |
| Back-facing node tap | Ignored (low alpha, behind front nodes) |

## Demo

Open `demo/ISphereCloudDemo.xcodeproj` and run on a simulator: ~40 fake users on a black
background, drag to rotate, fling for inertia, idle auto-spin, tap a node to see who you picked.

## Out of Scope

- Image loading / networking (you supply node views)
- SceneKit / Metal / SwiftUI wrapper (UIKit only)
- macOS / Mac Catalyst
- CocoaPods (SPM only)
