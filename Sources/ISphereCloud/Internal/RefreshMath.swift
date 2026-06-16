//
//  RefreshMath.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/16.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import CoreGraphics

/// 刷新动画用纯函数：缓动曲线、单节点进度、随机起跳偏移。不依赖 UIKit，便于单测。
enum RefreshMath {

    /// 把值夹到 [0, 1]。
    static func clamp01(_ x: CGFloat) -> CGFloat { min(1, max(0, x)) }

    /// easeOut（减速）：1 - (1-t)^3。端点 0→0、1→1，前快后慢。
    static func easeOut(_ t: CGFloat) -> CGFloat {
        let inv = 1 - clamp01(t)
        return 1 - inv * inv * inv
    }

    /// easeIn（加速）：t^3。端点 0→0、1→1。收缩阶段用。
    static func easeIn(_ t: CGFloat) -> CGFloat {
        let c = clamp01(t)
        return c * c * c
    }

    /// 单节点线性进度：elapsed 在 [startOffset, startOffset+duration] 内 0→1，超出按 clamp 取端点。
    /// duration <= 0 时退化为在 startOffset 处的阶跃。
    static func nodeProgress(elapsed: CGFloat, startOffset: CGFloat, duration: CGFloat) -> CGFloat {
        guard duration > 0 else { return elapsed >= startOffset ? 1 : 0 }
        return clamp01((elapsed - startOffset) / duration)
    }

    /// 生成 count 个 [0, window] 内的随机起跳偏移。`next()` 返回 [0, 1)。
    static func randomStartOffsets(count: Int, window: CGFloat, next: () -> CGFloat) -> [CGFloat] {
        (0..<max(0, count)).map { _ in next() * window }
    }
}
