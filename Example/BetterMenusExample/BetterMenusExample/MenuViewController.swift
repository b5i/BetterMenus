//
//  MenuViewController.swift
//  BetterMenusExample
//
//  Created by Antoine Bollengier on 14.09.2025.
//  Copyright © 2025 Antoine Bollengier (github.com/b5i). All rights reserved.
//  

import BetterMenus
import UIKit

final class MenuViewController: UIViewController, BetterUIContextMenuInteractionDelegate {
    private let actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Long-press or tap →", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.configuration = .borderedProminent()
        return b
    }()
    
    var buttonContextMenuInteraction: BetterContextMenuInteraction?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "UIMenu Context Menu Demo"

        view.addSubview(actionButton)
        NSLayoutConstraint.activate([
            actionButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            actionButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Classic: respond to tap (for demonstration)
        actionButton.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        
        // Add a context menu interaction (long-press / right-click)
        let ctxInteraction = BetterContextMenuInteraction(body: makeMenu, delegate: self)
        actionButton.addInteraction(ctxInteraction)
        self.buttonContextMenuInteraction = ctxInteraction

        /*
        // iOS 14+ convenience: attach a UIMenu directly to the button (optional)
        if #available(iOS 14.0, *) {
            actionButton.menu = makeMenu()
            // If you want the menu on tap instead of tap action, set showsMenuAsPrimaryAction = true
            // actionButton.showsMenuAsPrimaryAction = true
        }
         */
    }

    @objc private func didTapButton() {
        let alert = UIAlertController(title: "Tapped",
                                      message: "Button tapped. Try long-press for context menu.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Nice", style: .default))
        present(alert, animated: true)
    }

    // Build the UIMenu used both by UIContextMenuInteraction and button.menu
    
    var toggleState: Toggle.ToggleState = .off {
        didSet {
            self.buttonContextMenuInteraction?.reloadMenu()
        }
    }
    var toggleState2: Toggle.ToggleState = .off {
        didSet {
            self.buttonContextMenuInteraction?.reloadMenu()
        }
    }
    
    var stepperValue: Int = 1 {
        didSet {
            self.buttonContextMenuInteraction?.reloadMenu()
        }
    }
    
    @BUIMenuBuilder private func optionalMenu() -> UIMenu {
        if 1 == 2 {
            Text("1 = 2")
        } else {
            Text("1 != 2")
        }
    }
    
    @BUIMenuBuilder private func stepperMenu() -> UIMenu {
        Stepper(value: stepperValue) { _ in
            self.stepperValue += 1
        } decrementButtonPressed: { _ in
            self.stepperValue -= 1
        } body: { value in
            Text("Amount: \(self.stepperValue)")
        }
    }
    
    @BUIMenuBuilder private func controlGroupMenu() -> UIMenu {
        ControlGroup {
            Button("Undo", image: UIImage(systemName: "arrow.uturn.backward")) {_ in }
            Button("Redo", image: UIImage(systemName: "arrow.uturn.forward")) {_ in }
            Button("Copy", image: UIImage(systemName: "doc.on.doc")) {_ in }
        }
    }
    
    @BUIMenuBuilder private func toggleMenu() -> UIMenu {
        Toggle("Enable", state: toggleState) { _, _ in
            self.toggleState = self.toggleState.opposite
        }
        .style([.keepsMenuPresented])
        Toggle("Enable 2", state: toggleState2) { _, _ in
            self.toggleState2 = self.toggleState2.opposite
        }
        .style([.keepsMenuPresented])
    }
    
    @BUIMenuBuilder private func asyncMenu() -> UIMenu {
        Section("Async stuff") {
            Async { () -> String in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                return "This is not cached"
            } body: { result in
                Text(result)
            }
            
            Async { () -> String in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                return "This is cached"
            } body: { result in
                Text(result)
            }
            .cached(true)
            .identifier("1")
            
            Async { () -> String in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                return "This is also cached"
            } body: { result in
                Text(result)
            }
            .cached(true)
            .identifier(1)
            
            Async { () -> String in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                return "This is also cached but will regenerate"
            } body: { result in
                Text(result)
            }
            .cached(true)
        }
    }
    
    @BUIMenuBuilder private func cachedAsyncMenu() -> UIMenu {
        Section("Async stuff 2") {
            Async { () -> String in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                return "This is cached"
            } body: { result in
                {
                    print("This body (1) is recalculated")
                    return Text(result)
                }()
            }
            .cached(true)
            .identifier("cached async menu 1")
            
            Async { () -> String in
                try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
                return "This is also cached but the body is recalculated"
            } body: { result in
                {
                    print("This body (2) is recalculated")
                    return Text(result)
                }()
            }
            .cached(true)
            .identifier("cached async menu 2")
            .calculateBodyWithCache(true)
        }
    }
    
    @BUIMenuBuilder private func cachedAsyncBodyDemoMenu() -> UIMenu {
        Menu("Async stuff 3") {
            Async { () -> [String] in
                print("This should only be executed once")
                try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
                return ["an element"]
            } body: { elements in
                Button("Add an element") { _ in
                    let added = AsyncStorage.modifyCache(forIdentifier: "cachedAsyncBodyDemoMenu", { (elements: [String]) in
                        var copy = elements
                        copy.append("an element")
                        return copy
                    })
                    if added {
                        print("added new item successfully")
                    } else {
                        print("error while trying to add item")
                    }
                    self.buttonContextMenuInteraction?.reloadMenu(withIdentifier: "CachedAsyncBodyDemoMenu")
                }
                .style(.keepsMenuPresented)
                ForEach(elements) { element in
                    Text(element)
                }
            }
            .cached(true)
            .identifier("cachedAsyncBodyDemoMenu")
            .calculateBodyWithCache(true)
        }
        .identifier("CachedAsyncBodyDemoMenu")
    }
    
    @BUIMenuBuilder private func makeMenu() -> UIMenu {
        /*
        CustomView {
            let label = UILabel()
            label.text = "Hello World"
            return label
        }
         */
        optionalMenu()
        stepperMenu()
        controlGroupMenu()
        Divider()
        Text("some text")
        toggleMenu()
        Divider()
        asyncMenu()
        cachedAsyncMenu()
        cachedAsyncBodyDemoMenu()
        Divider()
        Menu("Action") {
            Button("my button3", image: .init(systemName: "cube")) { _ in
                print("button 3!")
            }
        }
        Menu("ForEach") {
            ForEach([0, 1, 5, 8, 10, 20]) { element in
                Text(String(element))
            }
        }
        makeMenuUIKit()
    }
    
    private func makeMenuUIKit() -> UIMenu {

        // A submenu
        let subAction1 = UIAction(title: "Sub A", handler: { [weak self] _ in self?.showMessage("Sub A") })
        let subAction2 = UIAction(title: "Sub B", handler: { [weak self] _ in self?.showMessage("Sub B") })
        let submenu = UIMenu(title: "More...", options: .displayInline, children: [subAction1, subAction2])

        // Compose the top-level menu
        return submenu
    }

    private func showMessage(_ text: String) {
        let alert = UIAlertController(title: nil, message: text, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Context Menu Delegate
    
    lazy var currentMenu: UIMenu = makeMenu()
    
    lazy var previewProvider: UIContextMenuContentPreviewProvider? = makePreviewController
    
    // Called to create the configuration for the context menu.
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        
        // identifier can be used to identify which view was used; we're not using it here.
        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: { [weak self] in
            // Provide a preview VC (optional). This shows when user long-presses but before action.
            return self?.makePreviewController()
        },
                                          actionProvider: { [weak self] suggested in
            // Provide the actual menu shown for actions
            return self?.currentMenu
        })
    }

    // Optional: handle when the user taps the preview to "commit" (open) it.
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                                animator: UIContextMenuInteractionCommitAnimating) {
        // Example: animate to a detailed view when the preview is committed
        animator.addCompletion {
            // open a simple detail controller
            let detail = UIViewController()
            detail.view.backgroundColor = .systemBackground
            detail.title = "Detail from preview"
            let label = UILabel()
            label.text = "Detailed view opened from preview"
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            detail.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: detail.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: detail.view.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: detail.view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(lessThanOrEqualTo: detail.view.trailingAnchor, constant: -20)
            ])
            self.navigationController?.pushViewController(detail, animated: true)
        }
    }
    
    // Provide a small preview view controller used by the context menu (optional)
    private func makePreviewController() -> UIViewController {
        let vc = UIViewController()
        vc.preferredContentSize = CGSize(width: 200, height: 120)
        vc.view.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
        }
        vc.view.layer.cornerRadius = 12
        vc.view.layer.borderWidth = 1/UIScreen.main.scale
        vc.view.layer.borderColor = UIColor.systemGray4.cgColor

        let label = UILabel()
        label.text = "Preview"
        label.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "Preview of the action"
        subtitle.font = UIFont.systemFont(ofSize: 13)
        subtitle.textColor = .secondaryLabel
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        vc.view.addSubview(label)
        vc.view.addSubview(subtitle)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor, constant: -8),
            subtitle.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            subtitle.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 6)
        ])
        return vc
    }
}
