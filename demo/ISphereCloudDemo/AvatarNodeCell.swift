//
//  AvatarNodeCell.swift
//  ISphereCloudDemo
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import UIKit

/// 演示用节点：圆形色块头像 + 昵称（不联网，头像用生成的纯色 + 首字）。
final class AvatarNodeCell: UIView {

    private let avatar = UILabel()
    private let nameLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let size: CGFloat = 44

        avatar.frame = CGRect(x: 8, y: 0, width: size, height: size)
        avatar.layer.cornerRadius = size / 2
        avatar.layer.masksToBounds = true
        avatar.textAlignment = .center
        avatar.textColor = .white
        avatar.font = .systemFont(ofSize: 18, weight: .semibold)
        addSubview(avatar)

        nameLabel.frame = CGRect(x: 0, y: size + 2, width: size + 16, height: 16)
        nameLabel.textAlignment = .center
        nameLabel.textColor = .white
        nameLabel.font = .systemFont(ofSize: 11)
        addSubview(nameLabel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: CGSize { CGSize(width: 60, height: 62) }

    func configure(name: String, colorSeed: Int) {
        nameLabel.text = name
        avatar.text = String(name.prefix(1)).uppercased()
        let hue = CGFloat((colorSeed * 47) % 360) / 360.0
        avatar.backgroundColor = UIColor(hue: hue, saturation: 0.5, brightness: 0.9, alpha: 1)
    }
}
