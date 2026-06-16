//
//  RefreshAnimator.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/16.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

#if canImport(UIKit)
import UIKit

/// CADisplayLink 弱引用代理：避免 link 强引用 animator。与 InertiaAnimator 的范式一致。
private final class RefreshLinkProxy: NSObject {
    weak var animator: RefreshAnimator?
    @MainActor @objc func frame(_ link: CADisplayLink) {
        if let animator {
            animator.onFrame(link)
        } else {
            link.invalidate()
        }
    }
}

/// 定长动画驱动器：`start(duration:)` 后每帧回调 `onProgress(elapsed)`；
/// elapsed 到达 duration 时回调一次 `onProgress(duration)`，随后 `onComplete` 并自动停止。
/// 与 `InertiaAnimator`（只管旋转）完全解耦，互不引用。
@MainActor
final class RefreshAnimator {

    /// 每帧进度回调，参数为已累计秒数（0...duration）。
    var onProgress: ((CGFloat) -> Void)?
    /// 动画结束回调（在最后一次 onProgress(duration) 之后）。
    var onComplete: (() -> Void)?

    private var displayLink: CADisplayLink?
    private var duration: CGFloat = 0
    private var elapsed: CGFloat = 0
    private var isActive = false

    var running: Bool { isActive }

    /// 启动一段时长 `duration` 秒的动画。duration <= 0 时立即完成（progress(0) + complete）。
    func start(duration: CGFloat) {
        stop()
        guard duration > 0 else {
            onProgress?(0)
            onComplete?()
            return
        }
        self.duration = duration
        elapsed = 0
        isActive = true
        let proxy = RefreshLinkProxy()
        proxy.animator = self
        let link = CADisplayLink(target: proxy, selector: #selector(RefreshLinkProxy.frame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isActive = false
        elapsed = 0
    }

    func onFrame(_ link: CADisplayLink) {
        guard isActive else { return }
        let dt = CGFloat(link.targetTimestamp - link.timestamp)
        elapsed += dt
        if elapsed >= duration {
            onProgress?(duration)
            stop()
            onComplete?()
        } else {
            onProgress?(elapsed)
        }
    }
}
#endif
