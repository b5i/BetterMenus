//
//  UIKitEquivalent.swift
//  BetterMenusExample
//
//  Created by Antoine Bollengier on 31.08.2025.
//  Copyright © 2025 Antoine Bollengier (github.com/b5i). All rights reserved.
//

import UIKit

func makeMenu(replacingMenuButton menuButton: UIButton? = nil, initialToggleState: Bool = false) -> UIMenu {
    var toggleState = initialToggleState

    let button1 = UIAction(title: "my button", image: UIImage(systemName: "cube")) { _ in
        print("buttons!")
    }

    let button2 = UIAction(title: "my button2", image: UIImage(systemName: "cube")) { _ in
        print("buttons2!")
    }

    let toggleAction = UIAction(title: "Enable", state: toggleState ? .on : .off) { action in
        action.state = (action.state == .on) ? .off : .on
        toggleState = (action.state == .on)
        print("toggle is now \(toggleState ? "ON" : "OFF")")
    }

    let separator = UIMenu(title: "", options: .displayInline, children: [])

    let deferredElement: UIMenuElement
    if #available(iOS 14.0, *) {
        deferredElement = UIDeferredMenuElement { completion in
            Task {
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                let loaded = UIAction(title: "salut tout le monde") { _ in
                    print("async item tapped")
                }
                completion([loaded])
            }
        }
    } else {
        let placeholder = UIAction(title: "Loading...", attributes: .disabled) { _ in }
        deferredElement = placeholder
        DispatchQueue.global().asyncAfter(deadline: .now() + 5.0) {
            DispatchQueue.main.async {
                menuButton?.menu = makeMenu(replacingMenuButton: menuButton, initialToggleState: toggleState)
            }
        }
    }

    let actionsSubmenu = UIMenu(title: "Actions", children: [
        UIAction(title: "my button3", image: UIImage(systemName: "cube")) { _ in print("buttons3!") },
        UIAction(title: "my button4", image: UIImage(systemName: "cube")) { _ in print("buttons4!") }
    ])

    let numbers = [0, 1, 5, 8, 10, 20]
    let forEachChildren: [UIMenuElement] = numbers.map { n in
        UIAction(title: String(n)) { _ in print("selected \(n)") }
    }
    let forEachMenu = UIMenu(title: "ForEach", children: forEachChildren)

    let children: [UIMenuElement] = [
        button1,
        separator,
        button2,
        toggleAction,
        separator,
        deferredElement,
        actionsSubmenu,
        forEachMenu
    ]

    return UIMenu(title: "", children: children)
}
