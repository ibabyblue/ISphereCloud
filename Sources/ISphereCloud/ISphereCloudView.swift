//
//  ISphereCloudView.swift
//  ISphereCloud
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

#if canImport(UIKit)
import UIKit
import simd

/// 非泛型手势转发器：泛型 UIView 子类无法声明 @objc 方法（Swift 限制），
/// 故用一个非泛型 NSObject 作为手势 target，通过闭包回传给视图。
private final class GestureForwarder: NSObject {
    var onPan: ((UIPanGestureRecognizer) -> Void)?
    var onTap: ((UITapGestureRecognizer) -> Void)?
    @objc func handlePan(_ gr: UIPanGestureRecognizer) { onPan?(gr) }
    @objc func handleTap(_ gr: UITapGestureRecognizer) { onTap?(gr) }
}

/// 3D 球形标签云：节点分布在球面上，拖拽可朝任意方向旋转，近大远小，
/// 带惯性与空闲自转；点击前半球节点回调 `onSelect`。节点视图由使用方提供，组件不加载图片。
///
/// ```swift
/// let sphere = ISphereCloudView<SoulUser>()
/// sphere.setItems(users) { user in AvatarNodeCell(user) }
/// sphere.onSelect = { user in router.pushProfile(user) }
/// ```
public final class ISphereCloudView<Item: Hashable>: UIView {

    // MARK: Public

    public var onSelect: ((Item) -> Void)?

    public init(configuration: ISphereCloudConfiguration = .init()) {
        self.configuration = configuration
        super.init(frame: .zero)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 设置数据与节点渲染闭包。使用方在闭包内自行加载图片。
    public func setItems(_ items: [Item], cellProvider: @escaping (Item) -> UIView) {
        self.items = items
        self.cellProvider = cellProvider
        if configuration.refreshAnimationEnabled {
            runRefreshAnimation()
        } else {
            rebuildNodes()
        }
    }

    /// 重新运行 cellProvider 重建节点，保留当前旋转姿态。
    public func reloadData() {
        if configuration.refreshAnimationEnabled {
            runRefreshAnimation()
        } else {
            rebuildNodes()
        }
    }

    public func startIdleRotation() { animator.start() }

    public func stopRotation() {
        animator.stop()
    }

    // MARK: Internal (testing hooks)

    var nodeViewCount: Int { nodeViews.count }

    struct FrontNode { let item: Item; let center: CGPoint }

    /// 当前最靠前节点（用于测试命中）。
    func frontmostNodeForTesting() -> FrontNode? {
        let proj = currentProjection()
        guard let i = proj.indices.max(by: { proj[$0].depth < proj[$1].depth }) else { return nil }
        return FrontNode(item: items[i], center: proj[i].screenPoint)
    }

    /// 在给定点做命中并返回 item（测试用，等价于 tap 路径）。
    func itemForPointTesting(_ point: CGPoint) -> Item? {
        guard let i = SphereMath.frontmostHit(at: point, in: currentProjection(), hitRadius: hitRadius) else {
            return nil
        }
        return items[i]
    }

    // MARK: Private

    private let configuration: ISphereCloudConfiguration
    private let animator = InertiaAnimator()
    private let gestureForwarder = GestureForwarder()

    private var items: [Item] = []
    private var cellProvider: ((Item) -> UIView)?
    private var nodeViews: [SphereNodeView] = []
    private var basePoints: [SIMD3<Double>] = []
    private var rotation = matrix_identity_double3x3

    private var hitRadius: CGFloat = 30

    private enum RefreshPhase { case idle, collapsing, expanding }
    private var refreshPhase: RefreshPhase = .idle
    private let refreshAnimator = RefreshAnimator()
    /// 视图尚未就绪（无 window/bounds）时设置数据：挂起首帧弹出，待就绪再播放。
    private var pendingRefreshAnimation = false

    // expand 目标（与 nodeViews 同序）
    private var targetCenters: [CGPoint] = []
    private var targetScales: [CGFloat] = []
    private var targetAlphas: [CGFloat] = []
    private var targetDepths: [CGFloat] = []
    private var startOffsets: [CGFloat] = []

    // collapse 起始快照（与旧 nodeViews 同序）
    private var collapseFromCenters: [CGPoint] = []
    private var collapseFromScales: [CGFloat] = []
    private var collapseFromAlphas: [CGFloat] = []
    private var collapseFromDepths: [CGFloat] = []

    private func commonInit() {
        backgroundColor = .clear

        let pan = UIPanGestureRecognizer(target: gestureForwarder,
                                         action: #selector(GestureForwarder.handlePan(_:)))
        addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: gestureForwarder,
                                         action: #selector(GestureForwarder.handleTap(_:)))
        addGestureRecognizer(tap)
        gestureForwarder.onPan = { [weak self] in self?.handlePan($0) }
        gestureForwarder.onTap = { [weak self] in self?.handleTap($0) }

        animator.inertiaEnabled = configuration.inertiaEnabled
        animator.idleRotationEnabled = configuration.idleRotationEnabled
        animator.idleRotationSpeed = configuration.idleRotationSpeed
        animator.onTick = { [weak self] delta in
            guard let self, self.refreshPhase == .idle else { return }  // 刷新期间冻结旋转
            self.applyRotationDelta(delta)
        }
        refreshAnimator.onProgress = { [weak self] elapsed in
            self?.handleRefreshFrame(elapsed: elapsed)
        }
        refreshAnimator.onComplete = { [weak self] in
            self?.handleRefreshComplete()
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            animator.start()
            if pendingRefreshAnimation { playPendingExpandIfReady() }
        } else {
            animator.stop()
        }
    }

    private func rebuildNodes() {
        nodeViews.forEach { $0.removeFromSuperview() }
        nodeViews.removeAll()
        basePoints = SphereMath.fibonacciSphere(count: items.count)
        guard let provider = cellProvider else { return }
        for item in items {
            let node = SphereNodeView(cell: provider(item))
            addSubview(node)
            nodeViews.append(node)
        }
        // 用最大节点估算命中半径。
        hitRadius = max(20, nodeViews.map { max($0.bounds.width, $0.bounds.height) / 2 }.max() ?? 30)
        layoutNodes()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        if refreshPhase != .idle {
            // 动画进行中尺寸变化：重捕获目标，动画继续（球心在帧应用内实时取）
            if refreshPhase == .expanding { captureExpandTargets() }
            return
        }
        if pendingRefreshAnimation {
            playPendingExpandIfReady()
            return
        }
        layoutNodes()
    }

    private var sphereRadius: Double { Double(min(bounds.width, bounds.height)) * 0.42 }
    private var sphereCenter: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }

    private func currentProjection() -> [SphereMath.Projected] {
        SphereMath.project(points: basePoints,
                           rotation: rotation,
                           radius: sphereRadius,
                           center: sphereCenter,
                           minScale: Double(configuration.minScale))
    }

    /// 由 depth(-1...1) 计算节点透明度，与 layoutNodes 的稳态渲染一致。
    private func alpha(forDepth depth: CGFloat) -> CGFloat {
        let t = (depth + 1) / 2
        return configuration.minAlpha + (1 - configuration.minAlpha) * t
    }

    private func layoutNodes() {
        guard !nodeViews.isEmpty else { return }
        let proj = currentProjection()
        for (i, node) in nodeViews.enumerated() where i < proj.count {
            let p = proj[i]
            let alpha = alpha(forDepth: p.depth)
            node.apply(center: p.screenPoint,
                       scale: p.scale,
                       alpha: alpha,
                       perspective: configuration.perspective,
                       depth: p.depth)
        }
    }

    private func applyRotationDelta(_ delta: CGVector) {
        let m = SphereMath.rotationMatrix(deltaX: Double(delta.dx),
                                          deltaY: Double(delta.dy),
                                          sensitivity: Double(configuration.rotationSensitivity))
        rotation = m * rotation
        layoutNodes()
    }

    // MARK: Gestures

    private func handlePan(_ gr: UIPanGestureRecognizer) {
        switch gr.state {
        case .began:
            animator.interrupt()
        case .changed:
            let d = gr.translation(in: self)
            gr.setTranslation(.zero, in: self)
            let k = 1.0 / max(1, CGFloat(sphereRadius))
            applyRotationDelta(CGVector(dx: d.x * k, dy: d.y * k))
        case .ended, .cancelled:
            let v = gr.velocity(in: self)
            let k = 1.0 / max(1, CGFloat(sphereRadius))
            animator.beginInertia(velocity: CGVector(dx: v.x * k / 60, dy: v.y * k / 60))
        default:
            break
        }
    }

    private func handleTap(_ gr: UITapGestureRecognizer) {
        selectItem(at: gr.location(in: self))
    }

    /// tap 命中并回调（内部，供测试直接驱动，等价于 tap 路径）。
    func selectItem(at point: CGPoint) {
        if let item = itemForPointTesting(point) {
            onSelect?(item)
        }
    }

    // MARK: Refresh Animation

    /// 视图是否已就绪到可播放动画（在 window 上且有有效尺寸）。
    private var refreshReady: Bool {
        window != nil && bounds.width > 0 && bounds.height > 0
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
    }

    /// 统一入口：按"是否有旧节点 / 视图是否就绪"决定 collapse→expand、直接 expand 或挂起。
    private func runRefreshAnimation() {
        refreshAnimator.stop()
        let hadNodes = !nodeViews.isEmpty
        guard refreshReady else {
            // 离屏/未就绪时的 reload 跳过收缩，直接重建并挂起首帧弹出（即使存在旧节点）。
            // 尚未就绪：建好新节点并停在球心，待 didMoveToWindow/layoutSubviews 再弹出
            rebuildNodes()
            pendingRefreshAnimation = true
            parkNodesAtCenter()
            return
        }
        if hadNodes {
            startCollapse()
        } else {
            rebuildNodes()
            startExpand()
        }
    }

    /// 把所有节点摆到球心、scale 0、alpha 0（挂起期间不闪现终态）。
    private func parkNodesAtCenter() {
        let center = sphereCenter
        for node in nodeViews {
            node.apply(center: center, scale: 0, alpha: 0,
                       perspective: configuration.perspective, depth: 0)
        }
    }

    private func playPendingExpandIfReady() {
        guard refreshReady else { return }
        pendingRefreshAnimation = false
        startExpand()
    }

    // MARK: Collapse

    private func startCollapse() {
        // 从节点"当前渲染态"快照，使动画进行中再次刷新也能从可见位置平滑收缩
        collapseFromCenters = nodeViews.map { $0.center }
        collapseFromScales = nodeViews.map { CGFloat($0.layer.transform.m11) }
        collapseFromAlphas = nodeViews.map { $0.alpha }
        collapseFromDepths = nodeViews.map { CGFloat($0.layer.zPosition) }
        refreshPhase = .collapsing
        applyCollapseFrame(elapsed: 0)
        refreshAnimator.start(duration: configuration.refreshCollapseDuration)
    }

    private func applyCollapseFrame(elapsed: CGFloat) {
        let d = configuration.refreshCollapseDuration
        let q = RefreshMath.easeIn(d > 0 ? elapsed / d : 1)
        let center = sphereCenter
        for (i, node) in nodeViews.enumerated() where i < collapseFromCenters.count {
            node.apply(center: lerp(collapseFromCenters[i], center, q),
                       scale: collapseFromScales[i] * (1 - q),
                       alpha: collapseFromAlphas[i] * (1 - q),
                       perspective: configuration.perspective,
                       depth: collapseFromDepths[i])
        }
    }

    // MARK: Expand

    private func captureExpandTargets() {
        let proj = currentProjection()
        targetCenters = proj.map { $0.screenPoint }
        targetScales = proj.map { $0.scale }
        targetDepths = proj.map { $0.depth }
        targetAlphas = proj.map { alpha(forDepth: $0.depth) }
    }

    private func startExpand() {
        captureExpandTargets()
        startOffsets = RefreshMath.randomStartOffsets(count: nodeViews.count,
                                                      window: configuration.refreshStaggerWindow) {
            CGFloat.random(in: 0..<1)
        }
        refreshPhase = .expanding
        applyExpandFrame(elapsed: 0)   // 初始：球心、scale 0、alpha 0
        let total = configuration.refreshStaggerWindow + configuration.refreshNodeDuration
        refreshAnimator.start(duration: total)
    }

    private func applyExpandFrame(elapsed: CGFloat) {
        let center = sphereCenter
        for (i, node) in nodeViews.enumerated()
        where i < targetCenters.count && i < startOffsets.count {
            let raw = RefreshMath.nodeProgress(elapsed: elapsed,
                                               startOffset: startOffsets[i],
                                               duration: configuration.refreshNodeDuration)
            let p = RefreshMath.easeOut(raw)
            node.apply(center: lerp(center, targetCenters[i], p),
                       scale: targetScales[i] * p,
                       alpha: targetAlphas[i] * p,
                       perspective: configuration.perspective,
                       depth: targetDepths[i])
        }
    }

    // MARK: Driver callbacks

    private func handleRefreshFrame(elapsed: CGFloat) {
        switch refreshPhase {
        case .collapsing: applyCollapseFrame(elapsed: elapsed)
        case .expanding:  applyExpandFrame(elapsed: elapsed)
        case .idle:       break
        }
    }

    private func handleRefreshComplete() {
        switch refreshPhase {
        case .collapsing:
            // 收缩完成 → 重建新节点 → 弹出（同一调用栈内完成，不渲染中间帧）
            rebuildNodes()
            startExpand()
        case .expanding:
            refreshPhase = .idle
            layoutNodes()   // 落到精确终态；之后旋转重新接管
        case .idle:
            break
        }
    }

    // MARK: Testing hooks

    var isRefreshingForTesting: Bool { refreshPhase != .idle }

    /// 同步把刷新动画推进到终态（测试用，跳过 CADisplayLink 时序）。
    func driveRefreshToEndForTesting() {
        while refreshPhase != .idle {
            switch refreshPhase {
            case .collapsing:
                applyCollapseFrame(elapsed: configuration.refreshCollapseDuration)
                handleRefreshComplete()   // → expanding
            case .expanding:
                let total = configuration.refreshStaggerWindow + configuration.refreshNodeDuration
                applyExpandFrame(elapsed: total)
                handleRefreshComplete()   // → idle
            case .idle:
                break
            }
        }
        refreshAnimator.stop()
    }
}
#endif
