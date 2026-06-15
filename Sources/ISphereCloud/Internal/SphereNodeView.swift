//
//  SphereNodeView.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

#if canImport(UIKit)
import UIKit

/// 单个球面节点的容器：内嵌使用方返回的 cell，按帧应用位置/缩放/透明度/层级。
final class SphereNodeView: UIView {

    let cell: UIView

    init(cell: UIView) {
        self.cell = cell
        // 容器尺寸取 cell 的固有尺寸；无固有尺寸时给一个回退值。
        var size = cell.intrinsicContentSize
        if size.width <= 0 || size.height <= 0 {
            size = cell.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        }
        if size.width <= 0 || size.height <= 0 {
            size = CGSize(width: 60, height: 80)
        }
        super.init(frame: CGRect(origin: .zero, size: size))
        isUserInteractionEnabled = false   // 命中由父视图统一处理
        cell.frame = bounds
        cell.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(cell)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 应用一帧的投影结果。
    func apply(center: CGPoint, scale: CGFloat, alpha: CGFloat, perspective: CGFloat, depth: CGFloat) {
        self.center = center
        self.alpha = alpha
        layer.zPosition = depth      // 画家算法：近的盖远的
        var t = CATransform3DIdentity
        t.m34 = -perspective
        t = CATransform3DScale(t, scale, scale, 1)
        layer.transform = t
    }
}
#endif
