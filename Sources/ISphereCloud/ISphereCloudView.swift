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
        rebuildNodes()
    }

    /// 重新运行 cellProvider 重建节点，保留当前旋转姿态。
    public func reloadData() {
        rebuildNodes()
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
            self?.applyRotationDelta(delta)
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { animator.start() } else { animator.stop() }
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

    private func layoutNodes() {
        guard !nodeViews.isEmpty else { return }
        let proj = currentProjection()
        for (i, node) in nodeViews.enumerated() where i < proj.count {
            let p = proj[i]
            let t = (p.depth + 1) / 2     // 0 远 .. 1 近
            let alpha = configuration.minAlpha + (1 - configuration.minAlpha) * t
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
}
#endif
