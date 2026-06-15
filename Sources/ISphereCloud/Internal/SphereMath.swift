//
//  SphereMath.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import CoreGraphics
import simd

/// 纯函数集合：球面布点、旋转矩阵、透视投影、命中判定。
/// 不依赖 UIKit，便于单元测试。
enum SphereMath {

    /// 用斐波那契球（黄金角）在单位球面上均匀生成 `count` 个点，避免极点扎堆。
    static func fibonacciSphere(count: Int) -> [SIMD3<Double>] {
        guard count > 0 else { return [] }
        var points: [SIMD3<Double>] = []
        points.reserveCapacity(count)
        let goldenAngle = Double.pi * (3.0 - 5.0.squareRoot())
        let denom = Double(max(count - 1, 1))
        for i in 0..<count {
            let y = 1.0 - (Double(i) / denom) * 2.0          // 1 (顶) .. -1 (底)
            let radiusAtY = (max(0.0, 1.0 - y * y)).squareRoot()
            let theta = goldenAngle * Double(i)
            let x = cos(theta) * radiusAtY
            let z = sin(theta) * radiusAtY
            points.append(SIMD3(x, y, z))
        }
        return points
    }
}
