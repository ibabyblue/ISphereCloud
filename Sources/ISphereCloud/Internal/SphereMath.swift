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

    /// 绕 X 轴旋转矩阵（列主序，与 simd 一致）。
    static func rotationX(_ a: Double) -> simd_double3x3 {
        let c = cos(a), s = sin(a)
        return simd_double3x3(columns: (
            SIMD3(1, 0, 0),
            SIMD3(0, c, s),
            SIMD3(0, -s, c)
        ))
    }

    /// 绕 Y 轴旋转矩阵（列主序，与 simd 一致）。
    static func rotationY(_ a: Double) -> simd_double3x3 {
        let c = cos(a), s = sin(a)
        return simd_double3x3(columns: (
            SIMD3(c, 0, -s),
            SIMD3(0, 1, 0),
            SIMD3(s, 0, c)
        ))
    }

    /// 把一次拖拽位移映射为增量旋转：水平位移绕 Y 轴、垂直位移绕 X 轴。
    /// 由于结果为 `Ry * Rx`，应用时先绕 X 后绕 Y。
    /// 返回值用于左乘累积旋转矩阵：`accumulated = rotationMatrix(...) * accumulated`。
    static func rotationMatrix(deltaX: Double, deltaY: Double, sensitivity: Double) -> simd_double3x3 {
        rotationY(deltaX * sensitivity) * rotationX(deltaY * sensitivity)
    }

    /// 单个节点投影结果。
    struct Projected {
        let screenPoint: CGPoint  // 屏幕坐标（正交投影，含 center 偏移；不含 scale）
        let scale: CGFloat        // [minScale, 1]，近大远小
        let depth: CGFloat        // 相机空间 z，-1...1，越大越近
    }

    /// 把旋转后的单位球点正交投影到屏幕：位置只取 (x, y)，不含透视位移。
    /// `scale` 仅用于节点大小/透明度（近大远小）；真正的透视由视图层以 CATransform3D.m34 体现，
    /// 因此此处不把 scale 乘进屏幕坐标，避免透视被叠加两次。
    static func project(points: [SIMD3<Double>],
                        rotation: simd_double3x3,
                        radius: Double,
                        center: CGPoint,
                        minScale: Double) -> [Projected] {
        points.map { p in
            let r = rotation * p
            let depth = r.z                       // -1 (远) .. 1 (近)
            let t = (depth + 1.0) / 2.0           // 0 (远) .. 1 (近)
            let scale = minScale + (1.0 - minScale) * t
            let sx = center.x + CGFloat(r.x * radius)
            let sy = center.y - CGFloat(r.y * radius)   // 翻转 y 到屏幕坐标（正交投影）
            return Projected(screenPoint: CGPoint(x: sx, y: sy),
                             scale: CGFloat(scale),
                             depth: CGFloat(depth))
        }
    }

    /// 命中判定：在投影结果里，找出落在 `point` 的 `hitRadius`（按节点 scale 缩放）内、
    /// 且位于前半球（depth >= 0）的、最靠前的那个节点索引。背面节点不参与命中。
    static func frontmostHit(at point: CGPoint,
                             in projected: [Projected],
                             hitRadius: CGFloat) -> Int? {
        var best: Int?
        var bestDepth = -CGFloat.infinity
        for (i, p) in projected.enumerated() where p.depth >= 0 {
            let dx = p.screenPoint.x - point.x
            let dy = p.screenPoint.y - point.y
            let r = hitRadius * p.scale
            if dx * dx + dy * dy <= r * r, p.depth > bestDepth {
                bestDepth = p.depth
                best = i
            }
        }
        return best
    }
}
