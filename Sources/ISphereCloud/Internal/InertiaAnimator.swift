//
//  InertiaAnimator.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

#if canImport(UIKit)
import UIKit

/// CADisplayLink 弱引用代理：避免 link 强引用 animator。animator 释放后，
/// 下一帧自动 invalidate，无需在 deinit 中触碰 @MainActor 状态。
private final class DisplayLinkProxy: NSObject {
    weak var animator: InertiaAnimator?
    @MainActor @objc func frame(_ link: CADisplayLink) {
        if let animator {
            animator.onFrame(link)
        } else {
            link.invalidate()
        }
    }
}

/// 用 `CADisplayLink` 每帧回调；维护松手惯性衰减与空闲自转。
/// 旋转增量以 `CGVector`(dx=水平→绕Y, dy=垂直→绕X) 表示，单位为"每帧的角度位移"。
@MainActor
final class InertiaAnimator {

    /// 速度低于该阈值即视为停止。
    nonisolated static let stallThreshold: CGFloat = 0.001
    /// 每帧惯性摩擦系数。注意：惯性按"每帧"衰减（非按时间），摩擦系数是针对帧节奏调校的，
    /// 不要给惯性分支加 dt 缩放，否则会破坏手感调校。
    nonisolated static let defaultFriction: CGFloat = 0.92

    /// 纯函数：对速度施加一帧摩擦衰减；低于阈值归零。
    nonisolated static func step(velocity: CGVector, friction: CGFloat) -> CGVector {
        let next = CGVector(dx: velocity.dx * friction, dy: velocity.dy * friction)
        return isStalled(next) ? .zero : next
    }

    /// 纯函数：是否已停止。
    nonisolated static func isStalled(_ v: CGVector) -> Bool {
        abs(v.dx) < stallThreshold && abs(v.dy) < stallThreshold
    }

    /// 纯函数：计算一帧应输出的旋转增量与新的惯性速度。
    /// - 交互中（isInteracting）：输出 nil，速度清零（手指按住时冻结，不自转、不惯性）。
    /// - 有惯性：输出当前速度，速度按摩擦衰减。
    /// - 静止且允许空闲自转：输出按 dt 缩放的匀速增量（绕 Y），速度保持为零。
    /// - 否则：输出 nil。
    nonisolated static func tickDelta(velocity: CGVector,
                                      dt: CGFloat,
                                      idleSpeed: CGFloat,
                                      idleEnabled: Bool,
                                      isInteracting: Bool) -> (delta: CGVector?, newVelocity: CGVector) {
        if isInteracting {
            return (nil, .zero)
        }
        if !isStalled(velocity) {
            return (velocity, step(velocity: velocity, friction: defaultFriction))
        }
        if idleEnabled {
            return (CGVector(dx: idleSpeed * dt, dy: 0), velocity)
        }
        return (nil, velocity)
    }

    /// 每帧回调，参数为本帧应施加的旋转增量（dx 绕 Y、dy 绕 X，弧度）。
    var onTick: ((CGVector) -> Void)?

    var inertiaEnabled = true
    var idleRotationEnabled = true
    var idleRotationSpeed: CGFloat = 0.15   // 弧度/秒

    private var displayLink: CADisplayLink?
    private var velocity: CGVector = .zero   // 惯性速度（弧度/帧）
    private var isInteracting = false        // 触摸进行中：冻结惯性与空闲自转

    func start() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy()
        proxy.animator = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.frame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        velocity = .zero
        isInteracting = false
    }

    /// 拖拽松手：结束交互并注入惯性初速度（弧度/帧）。
    func beginInertia(velocity: CGVector) {
        isInteracting = false
        self.velocity = inertiaEnabled ? velocity : .zero
    }

    /// 触摸开始：进入交互态，打断惯性与空闲自转（在 tick 中被冻结，直到 beginInertia/stop）。
    func interrupt() {
        isInteracting = true
        velocity = .zero
    }

    func onFrame(_ link: CADisplayLink) {
        let dt = CGFloat(link.targetTimestamp - link.timestamp)
        let result = InertiaAnimator.tickDelta(velocity: velocity,
                                               dt: dt,
                                               idleSpeed: idleRotationSpeed,
                                               idleEnabled: idleRotationEnabled,
                                               isInteracting: isInteracting)
        velocity = result.newVelocity
        if let delta = result.delta { onTick?(delta) }
    }
}
#endif
