//
//  ViewController.swift
//  ISphereCloudDemo
//
//  Created by ibabyblue on 2026/06/15.
//  Copyright © 2026 ibabyblue. All rights reserved.
//

import UIKit
import ISphereCloud

struct DemoUser: Hashable {
    let id: Int
    let name: String
}

final class ViewController: UIViewController {

    private let sphere: ISphereCloudView<DemoUser> = {
        var config = ISphereCloudConfiguration()
        config.refreshAnimationEnabled = true
        return ISphereCloudView<DemoUser>(configuration: config)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        sphere.frame = view.bounds
        sphere.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sphere)

        let names = ["亿人类的梦", "better me", "又开始笑了", "找对象", "茶靡", "机没电了",
                     "一期一会", "JUST DO IT", "随意", "neko", "酿小怪女", "Otaku", "长发",
                     "小糖块", "多敢A梦", "咕噜豆包儿", "长安归故里", "爱旅行", "氪系女孩",
                     "王小盆", "柔顺天使", "的男朋友", "以聊天的人", "张小喵Zz", "酱油饼",
                     "乔碧梦", "太重", "冷型", "芝士汉堡", "健身爱好者", "万千少女", "Eleven",
                     "Alis", "奶嘴旺仔", "奶油小宝宝", "以聊天", "豆包", "小盆友", "梦旅行", "星月"]
        let users = names.enumerated().map { DemoUser(id: $0.offset, name: $0.element) }

        sphere.setItems(users) { user in
            let cell = AvatarNodeCell()
            cell.configure(name: user.name, colorSeed: user.id)
            return cell
        }

        sphere.onSelect = { [weak self] user in
            let alert = UIAlertController(title: "选中", message: user.name, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }

        let refreshButton = UIButton(type: .system)
        refreshButton.setTitle("刷新", for: .normal)
        refreshButton.setTitleColor(.white, for: .normal)
        refreshButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        refreshButton.addTarget(self, action: #selector(didTapRefresh), for: .touchUpInside)
        view.addSubview(refreshButton)
        NSLayoutConstraint.activate([
            refreshButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            refreshButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    @objc private func didTapRefresh() {
        sphere.reloadData()
    }
}
