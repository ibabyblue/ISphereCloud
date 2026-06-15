//
//  ISphereCloudConfiguration.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import CoreGraphics

/// 球形云的交互与外观配置。所有字段都有合理默认值。
public struct ISphereCloudConfiguration {

    /// 松手后按抛速继续旋转并衰减。
    public var inertiaEnabled: Bool = true
    /// 无操作时缓慢自动旋转。
    public var idleRotationEnabled: Bool = true
    /// 空闲自转角速度（弧度/秒，绕 Y 轴）。
    public var idleRotationSpeed: CGFloat = 0.15
    /// 透视强度，作为 `CATransform3D.m34` 的量级。
    public var perspective: CGFloat = 1.0 / 1500.0
    /// 最远端节点的缩放下限。
    public var minScale: CGFloat = 0.4
    /// 最远端节点的透明度下限。
    public var minAlpha: CGFloat = 0.3
    /// 拖拽位移到旋转角度的灵敏度系数。
    public var rotationSensitivity: CGFloat = 1.0

    public init() {}
}
