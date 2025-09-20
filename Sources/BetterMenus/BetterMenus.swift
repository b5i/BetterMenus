//
//  BetterMenus.swift
//  BetterMenus
//
//  Created by Antoine Bollengier on 30.08.2025.
//  Copyright © 2025 Antoine Bollengier (github.com/b5i). All rights reserved.
//

/// A lightweight helper library that provides a `@resultBuilder` and convenient Swift-style
/// types to construct UIKit `UIMenu` and `UIMenuElement` hierarchies similarly to SwiftUI's
/// DSL. Intended for iOS 16.0+.

import UIKit
import OrderedCollections

// MARK: - BUIMenuBuilder result builder

@available(iOS 16.0, *)
@resultBuilder
public enum BUIMenuBuilder {
    /// Build a single `UIMenu` from one or more ``BetterMenus/MenuBuilderElement`` components.
    ///
    /// This function walks the provided components, treating ``BetterMenus/Divider`` specially as a
    /// delimiter that creates nested menus. It collects children into an internal
    /// `UIMenuInfo` structure, then composes the final `UIMenu` tree and returns the root menu.
    ///
    /// - Parameter components: The list of elements produced by the builder.
    /// - Returns: A constructed `UIMenu` representing the composed menu hierarchy.
    public static func buildArray(_ components: [MenuBuilderElement]) -> UIMenu {
        let mainMenu: UIMenuInfo = UIMenuInfo(image: UIImage(systemName: "cube"), options: .displayInline)
        var grandParentsQueue: [UIMenuInfo] = []
        var currentParent: UIMenuInfo = mainMenu
        for component in components {
            if let divider = component as? Divider {
                let uiKitEquivalent = divider.uiKitEquivalent
                // push current parent to queue and start a new parent for the divider
                grandParentsQueue.append(currentParent)
                currentParent = uiKitEquivalent.uiMenuInfo
            } else {
                // append normal elements to the active parent
                currentParent.children.append(component.uiKitEquivalent)
            }
        }
        // finalize queue
        grandParentsQueue.append(currentParent)
        var grandParentToAdd: UIMenuInfo? = nil
        // build menus from the bottom up - attach each collected parent as a child of the previous
        for grandParent in grandParentsQueue.reversed() {
            if let grandParentToAdd {
                grandParent.children.append(grandParentToAdd.makeMenu())
            }
            grandParentToAdd = grandParent
        }
        return mainMenu.makeMenu()
    }
    
    public static func buildBlock(_ components: any MenuBuilderElement...) -> UIMenu {
        return Self.buildArray(components)
    }
    
    public static func buildEither(first component: any MenuBuilderElement) -> any MenuBuilderElement {
        return component
    }
    
    public static func buildEither(second component: any MenuBuilderElement) -> any MenuBuilderElement {
        return component
    }
    
    public static func buildFinalResult(_ component: any MenuBuilderElement) -> UIMenu {
        return (component as? UIMenu) ?? UIMenu(options: .displayInline, children: [component.uiKitEquivalent])
    }
    
    // MARK: - Internal helper: UIMenuInfo
    
    /// Internal container representing a `UIMenu` under construction.
    ///
    /// ``UIMenuInfo`` stores the textual and visual metadata plus a list of `UIMenuElement`
    /// children. It is used by the builder implementation to accumulate items before
    /// producing the final `UIMenu` instance.
    class UIMenuInfo {
        /// The menu title.
        var title: String
        
        /// An optional subtitle for the menu (available on platforms that support it).
        var subtitle: String?
        
        /// An optional icon image for the menu.
        var image: UIImage?
        
        /// An optional identifier used to identify the menu.
        var identifier: UIMenu.Identifier?
        
        /// Options that control menu behavior and presentation.
        var options: UIMenu.Options
        
        /// Preferred element size for the menu's children.
        var preferredElementSize: UIMenu.ElementSize
        
        /// The collected children for this menu node.
        var children: [UIMenuElement]
        
        /// Initialize a new ``UIMenuInfo``.
        ///
        /// All parameters mirror the `UIMenu` initializer. The default `preferredElementSize`
        /// is `.automatic` on iOS 17+ and `.large` on older targets to preserve behavior.
        init(title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: UIMenu.Identifier? = nil, options: UIMenu.Options = [], preferredElementSize: UIMenu.ElementSize = { if #available(iOS 17.0, tvOS 17.0, watchOS 10.0, *) { .automatic } else { .large } }(), children: [UIMenuElement] = []) {
            self.title = title
            self.subtitle = subtitle
            self.image = image
            self.identifier = identifier
            self.options = options
            self.preferredElementSize = preferredElementSize
            self.children = children
        }
        
        /// Produce a concrete `UIMenu` from the stored information and children.
        ///
        /// - Returns: A fully constructed `UIMenu` instance.
        func makeMenu() -> UIMenu {
            return UIMenu(title: title, subtitle: subtitle, image: image, identifier: identifier, options: options, preferredElementSize: preferredElementSize, children: children)
        }
    }
}

// MARK: - Convenience extension to read UIMenu metadata

@available(iOS 16.0, *)
extension UIMenu {
    /// Convert a runtime `UIMenu` into the builders' internal `UIMenuInfo` representation.
    ///
    /// This is useful for reusing or composing existing menus within the builder pipeline.
    var uiMenuInfo: BUIMenuBuilder.UIMenuInfo {
        return BUIMenuBuilder.UIMenuInfo(title: title, subtitle: subtitle, image: image, identifier: identifier, options: options, preferredElementSize: preferredElementSize, children: children)
    }
    
    public func findChildren(withIdentifier identifier: UIMenu.Identifier) -> UIMenu? {
        if self.identifier == identifier {
            return self
        } else {
            for child in children.compactMap { $0 as? UIMenu } {
                if let menu = child.findChildren(withIdentifier: identifier) {
                    return menu
                }
            }
            return nil
        }
    }
}

// MARK: - MenuBuilderElement protocol

@available(iOS 16.0, *)
public protocol MenuBuilderElement {
    /// The concrete UIKit type used as the equivalent of the builder element.
    associatedtype MenuElementType: UIMenuElement
    
    /// A UIKit equivalent of this builder element. Implementers must return a concrete
    /// `UIMenuElement` (for example `UIAction` or `UIMenu`) to be inserted into the constructed tree.
    var uiKitEquivalent: MenuElementType { get }
        
    /// A method to store the ``uiKitEquivalent`` in a variable.
    // TODO: func store(location in: inout MenuElementType?)
}

extension UIMenuElement: MenuBuilderElement {
    public var uiKitEquivalent: UIMenuElement { self }
}

extension Array: MenuBuilderElement where Element: MenuBuilderElement {
    public var uiKitEquivalent: UIMenu {
        return BUIMenuBuilder.buildArray(self)
    }
}

/// A protocol defining the minimum states of a state type.
public protocol UIActionBackedMenuBuilderElementState {
    static var on: Self { get }
    static var off: Self { get }
}

extension UIMenuElement.State: UIActionBackedMenuBuilderElementState {}

/// A protocol providing useful methods to customize an element whose UIKit type is a UIAction.
public protocol UIActionBackedMenuBuilderElement: MenuBuilderElement where MenuElementType: UIAction {
    associatedtype StateType: UIActionBackedMenuBuilderElementState
    
    /// Optional identifier for the action, can be set using ``UIActionBackedMenuBuilderElement/identifier(_:)-6auaj``.
    var identifier: UIAction.Identifier? { get set }
    
    /// An optional discoverability title used by assistive features, can be set using ``UIActionBackedMenuBuilderElement/discoverabilityTitle(_:)-7qrbe``.
    var discoverabilityTitle: String? { get set }
    
    /// Attributes such as `.destructive` or `.disabled`, can be set using ``UIActionBackedMenuBuilderElement/style(_:)-rtxf``.
    var style: UIMenuElement.Attributes { get set }
    
    /// The on/off state for actions that represent a stateful element, can be set using ``UIActionBackedMenuBuilderElement/state(_:)-12gq6``.
    var state: StateType { get set }
    
    /// Sets an identifier for the action.
    func identifier(_ identifier: UIAction.Identifier?) -> Self
    
    /// Sets a discoverability title used by assistive features.
    func discoverabilityTitle(_ discoverabilityTitle: String?) -> Self
    
    /// Sets attributes such as `.destructive` or `.disabled`.
    func style(_ style: UIMenuElement.Attributes) -> Self
    
    /// Sets the on/off state for actions that represent a stateful element.
    func state(_ state: StateType) -> Self
}

public extension UIActionBackedMenuBuilderElement {
    func identifier(_ identifier: UIAction.Identifier?) -> Self {
        var copy = self
        copy.identifier = identifier
        return copy
    }
    
    func discoverabilityTitle(_ discoverabilityTitle: String?) -> Self {
        var copy = self
        copy.discoverabilityTitle = discoverabilityTitle
        return copy
    }
    
    func style(_ style: UIMenuElement.Attributes) -> Self {
        var copy = self
        copy.style = style
        return copy
    }
    
    func state(_ state: StateType) -> Self {
        var copy = self
        copy.state = state
        return copy
    }
}

/*

@available(iOS 16.0, *)
public struct CustomView: MenuBuilderElement {
    // investigate rt_createSubclassNamed https://www.mikeash.com/pyblog/friday-qa-2010-11-19-creating-classes-at-runtime-for-fun-and-profit.html
 
    public var uiKitEquivalent: UIMenuElement {
        guard let customViewClass = NSClassFromString("UICustomViewMenuElement") as? NSObject.Type else { print("CustomView doesn't work"); return UIMenu() }
        
        guard let menuElement = (customViewClass.perform(NSSelectorFromString("elementWithViewProvider:"), with: viewProvider).takeUnretainedValue() as? UIMenuElement) else { print("Couldn't create CustomView"); return UIMenu()}
        
        if self.style.contains(.keepsMenuPresented) {
            let provider: @convention(block) (UIMenuElement) -> Bool = { _ in
                return true
            }
            
            
            
            menuElement.setValue(true, forKey: "keepsMenuPresented")
        }
        
        return menuElement
    }
    
    public let viewProvider: @convention(block) () -> UIView
    public let style: UIAction.Attributes
    
    init(viewProvider: @escaping () -> UIView, style: UIAction.Attributes = .keepsMenuPresented) {
        self.viewProvider = viewProvider
        self.style = style
    }
}
*/

// MARK: - Divider

/// A ``BetterMenus/Divider`` separates elements of a menu (gray line).
///
/// Example - using a divider to create between two buttons:
/// ```swift
/// let menu = Menu("Root") {
///     Button("One") { _ in }
///     Divider()
///     Button("Two") { _ in }
/// }
/// ```
@available(iOS 16.0, *)
public struct Divider: MenuBuilderElement {
    public var uiKitEquivalent: UIMenu { UIMenu(title: "", image: .init(systemName: "cube"), options: .displayInline) } // arbitrary image otherwise it won't show the divider
    
    public init() {}
}

// MARK: - Menu (group)

/// This is the primary grouping type. A ``BetterMenus/Menu`` creates titled submenus and to host nested `@BUIMenuBuilder` content.
///
/// Example - titled submenu:
/// ```swift
/// Menu("File") {
///     Button("New") { _ in /*...*/ }
///     Button("Open") { _ in /*...*/ }
/// }
/// ```
@available(iOS 16.0, *)
public struct Menu: MenuBuilderElement {
    public var uiKitEquivalent: UIMenu {
        UIMenu(title: title, subtitle: subtitle, image: image, identifier: identifier, options: options, preferredElementSize: preferredElementSize, children: body().children)
    }
    
    /// The menu's title.
    public let title: String
    
    /// Optional subtitle for the menu.
    public let subtitle: String?
    
    /// Optional image for the menu.
    public let image: UIImage?
    
    /// Optional identifier for the menu.  Can be used to refresh the menu only.
    public var identifier: UIMenu.Identifier? = nil
    
    /// Options that affect presentation and behavior.
    public var options: UIMenu.Options = []
    
    /// Preferred element size for children.
    public var preferredElementSize: UIMenu.ElementSize = { if #available(iOS 17.0, tvOS 17.0, watchOS 10.0, *) { .automatic } else { .large } }()
    
    /// The body closure producing nested menu content. Annotated with ``BetterMenus/BUIMenuBuilder``.
    @BUIMenuBuilder public let body: () -> UIMenu
    
    /// Create a new ``BetterMenus/Menu`` node.
    ///
    /// - Parameters:
    ///   - title: The menu title.
    ///   - subtitle: Optional subtitle.
    ///   - image: Optional icon.
    ///   - identifier: Optional identifier.
    ///   - options: Menu options.
    ///   - preferredElementSize: Preferred element size for children.
    ///   - body: A `@BUIMenuBuilder` closure that constructs the menu's children.
    @available(*, deprecated, message: "Use init(_ title: String, subtitle: String?, image: UIImage?, @BUIMenuBuilder body: @escaping () -> UIMenu) and the inline modifiers instead. This method will be removed in a future version of BetterMenus.")
    public init(_ title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: UIMenu.Identifier? = nil, options: UIMenu.Options = [], preferredElementSize: UIMenu.ElementSize = { if #available(iOS 17.0, tvOS 17.0, watchOS 10.0, *) { .automatic } else { .large } }(), @BUIMenuBuilder body: @escaping () -> UIMenu) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.identifier = identifier
        self.options = options
        self.preferredElementSize = preferredElementSize
        self.body = body
    }
    
    /// Create a new ``BetterMenus/Menu`` node.
    ///
    /// - Parameters:
    ///   - title: The menu title.
    ///   - subtitle: Optional subtitle.
    ///   - image: Optional icon.
    ///   - body: A `@BUIMenuBuilder` closure that constructs the menu's children.
    public init(_ title: String = "", subtitle: String? = nil, image: UIImage? = nil, @BUIMenuBuilder body: @escaping () -> UIMenu) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.body = body
    }
    
    public func identifier(_ identifier: UIMenu.Identifier?) -> Self {
        var copy = self
        copy.identifier = identifier
        return copy
    }
    
    public func identifier(_ identifier: String) -> Self {
        var copy = self
        copy.identifier = UIMenu.Identifier(rawValue: identifier)
        return copy
    }
    
    public func options(_ options: UIMenu.Options?) -> Self {
        var copy = self
        copy.options = options ?? []
        return copy
    }
    
    public func preferredElementSize(_ preferredElementSize: UIMenu.ElementSize) -> Self {
        var copy = self
        copy.preferredElementSize = preferredElementSize
        return copy
    }
}

// MARK: - Button (action)

/// A ``BetterMenus/Button`` creates a tappable menu item. The `handler` receives the action that's executed on tap of the button.
///
/// Example:
/// ```swift
/// Button("Copy", image: UIImage(systemName: "doc.on.doc")) { action in
///     UIPasteboard.general.string = "Copied!"
/// }
/// ```
@available(iOS 16.0, *)
public struct Button: UIActionBackedMenuBuilderElement {
    public var uiKitEquivalent: UIAction {
        UIAction(title: title, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle, attributes: style, state: state, handler: handler)
    }
    
    /// The action title displayed in the menu.
    public let title: String
    
    /// Optional icon for the action.
    public let image: UIImage?
    
    /// Optional identifier for the action, can be set using ``UIActionBackedMenuBuilderElement/identifier(_:)-6auaj``.
    public var identifier: UIAction.Identifier? = nil
    
    /// An optional discoverability title used by assistive features, can be set using ``UIActionBackedMenuBuilderElement/discoverabilityTitle(_:)-7qrbe``.
    public var discoverabilityTitle: String? = nil
    
    /// Attributes such as `.destructive` or `.disabled`, can be set using ``UIActionBackedMenuBuilderElement/style(_:)-rtxf``.
    public var style: UIMenuElement.Attributes = []
    
    /// The on/off state for actions that represent a stateful element, can be set using ``UIActionBackedMenuBuilderElement/state(_:)-12gq6``.
    public var state: UIMenuElement.State = .off
    
    /// Handler invoked when the action is selected.
    public let handler: (UIAction) -> Void
    
    /// Create a ``BetterMenus/Button``.
    public init(_ title: String = "", image: UIImage? = nil, _ handler: @escaping (UIAction) -> Void) {
        self.title = title
        self.image = image
        self.handler = handler
    }
}

// MARK: - Toggle (stateful action)

/// A toggle action (label with a tick if on state).
///
/// - Warning: You must manage and persist the toggle state yourself and refresh the menu
///   when the underlying state changes; the builder does not automatically store app state.
///
/// Example - simple toggle:
/// ```swift
/// var showGrid = true
///
/// let toggle = Toggle("Show Grid", state: showGrid ? .on : .off) { _, newValue in
///     showGrid = newValue
/// }
/// ```
@available(iOS 16.0, *)
public struct Toggle: UIActionBackedMenuBuilderElement {
    /// Convert the builder `Toggle` into a `UIAction` with a handler that provides the new value.
    public var uiKitEquivalent: UIAction {
        UIAction(title: title, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle, attributes: style, state: state.uiMenuElementState, handler: { action in
            handler(action, !state.boolValue)
        })
    }
    
    /// The toggle's title.
    public let title: String
    
    /// Optional icon for the toggle.
    public let image: UIImage?
    
    /// Optional identifier for the action, can be set using ``UIActionBackedMenuBuilderElement/identifier(_:)-6auaj``.
    public var identifier: UIAction.Identifier? = nil
    
    /// An optional discoverability title used by assistive features, can be set using ``UIActionBackedMenuBuilderElement/discoverabilityTitle(_:)-7qrbe``.
    public var discoverabilityTitle: String? = nil
    
    /// Attributes such as `.destructive` or `.disabled`, can be set using ``UIActionBackedMenuBuilderElement/style(_:)-rtxf``.
    public var style: UIMenuElement.Attributes = []
    
    /// The on/off state for actions that represent a stateful element, can be set using ``UIActionBackedMenuBuilderElement/state(_:)-12gq6``.
    public var state: ToggleState = .off
    
    /// Handler called when the toggle is activated; provides the new boolean value.
    public let handler: (UIAction, _ newValue: Bool) -> Void
    
    /// Creates a Toggle.
    public init(_ title: String = "", image: UIImage? = nil, state: ToggleState = .off, _ handler: @escaping (UIAction, _ newValue: Bool) -> Void) {
        self.title = title
        self.image = image
        self.state = state
        self.handler = handler
    }
    
    // MARK: ToggleState
    public enum ToggleState: UIActionBackedMenuBuilderElementState {
        case on, off
        
        /// Convert to `UIMenuElement.State` used by `UIAction`.
        public var uiMenuElementState: UIMenuElement.State {
            return self == .on ? .on : .off
        }
        
        /// The opposite state.
        public var opposite: ToggleState {
            return self == .on ? .off : .on
        }
        
        /// A boolean representation of the state.
        public var boolValue: Bool {
            return self == .on ? true : false
        }
        
        /// Create a ``BetterMenus/Toggle/ToggleState`` from a `UIMenuElement.State` when possible.
        ///
        /// - Parameter state: A `UIMenuElement.State`.
        /// - Returns: `.on` or `.off` if the state maps, otherwise `nil`.
        public static func fromUIMenuElementState(_ state: UIMenuElement.State) -> Self? {
            switch state {
            case .off:
                return .off
            case .on:
                return .on
            default:
                return nil
            }
        }
    }
}

// MARK: - ForEach (collection mapping)

/// A ``BetterMenus/ForEach`` element produces many elements in the menu.
///
/// `ForEach` is handy when converting arrays or other collections into menu rows.
///
/// Example:
/// ```swift
/// let fruits = ["Apple", "Pear", "Banana"]
/// let menu = Menu("Fruits") {
///     ForEach(fruits) { name in
///         Button(name) { _ in print("Picked \(name)") }
///     }
/// }
/// ```
@available(iOS 16.0, *)
public struct ForEach<T>: MenuBuilderElement {
    public var uiKitEquivalent: UIMenu {
        let children: [UIMenuElement] = self.elements.map(body).map(\.children).reduce([], {
            var copy = $0
            copy.append(contentsOf: $1)
            return copy
        })
        return UIMenu(options: .displayInline, children: children)
    }
    
    /// The collection of elements to iterate over.
    public let elements: [T]
    
    /// The mapping closure that builds a `UIMenu` for each element.
    @BUIMenuBuilder public let body: (T) -> UIMenu
    
    /// Create a ``BetterMenus/ForEach`` that maps `elements` using `body`.
    public init(_ elements: [T], @BUIMenuBuilder body: @escaping (T) -> UIMenu) {
        self.elements = elements
        self.body = body
    }
}

// MARK: - Text (simple label/action placeholder)

/// Build a label representing text.
///
/// Use  ``BetterMenus/Text`` when you want a simple label inside your menu.
///
/// Example:
/// ```swift
/// Text("No recent files", image: UIImage(systemName: "doc"))
/// ```
@available(iOS 16.0, *)
public struct Text: UIActionBackedMenuBuilderElement {
    public var uiKitEquivalent: UIAction {
        UIAction(title: text, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle, attributes: style, state: state, handler: {_ in})
    }
    
    /// The displayed text.
    public let text: String
    
    /// Optional image for the text row.
    public let image: UIImage?
    
    /// Optional identifier for the action, can be set using ``UIActionBackedMenuBuilderElement/identifier(_:)-6auaj``.
    public var identifier: UIAction.Identifier? = nil
    
    /// An optional discoverability title used by assistive features, can be set using ``UIActionBackedMenuBuilderElement/discoverabilityTitle(_:)-7qrbe``.
    public var discoverabilityTitle: String? = nil
    
    /// Attributes such as `.destructive` or `.disabled`, can be set using ``UIActionBackedMenuBuilderElement/style(_:)-rtxf``.
    public var style: UIMenuElement.Attributes = [.keepsMenuPresented]
    
    /// The on/off state for actions that represent a stateful element, can be set using ``UIActionBackedMenuBuilderElement/state(_:)-12gq6``.
    public var state: UIMenuElement.State = .off
    
    /// An optional tag that can be used by consumers for selection or identification.
    // public var tag: (any Hashable)? will be used by the picker
    
    /// Create a text-only menu element.
    public init(_ text: String, image: UIImage? = nil) {
        self.text = text
        self.image = image
    }
}

// MARK: - Stepper

/// Build a small inline menu that contains decrement and increment ``BetterMenus/Button``s.
///
/// Example:
/// ```swift
/// var value = 3
/// let stepper = Stepper(value: value, closeMenuOnTap: false, incrementButtonPressed: { v in value += 1 }, decrementButtonPressed: { v in value -= 1 }) { current in
///     Text("\(current)")
/// }
/// ```
@available(iOS 16.0, *)
public struct Stepper<T>: MenuBuilderElement where T: Strideable {
    public var uiKitEquivalent: UIMenu {
        let processedBody = body(value)
        return Menu(processedBody.text, image: processedBody.image, options: [.displayInline], preferredElementSize: .small) {
            Button(image: UIImage(systemName: "minus")) { _ in
                decrementButtonPressed(value)
            }
            .style(closeMenuOnTap ? [] : [.keepsMenuPresented])
            Button(image: UIImage(systemName: "plus")) { _ in
                incrementButtonPressed(value)
            }
            .style(closeMenuOnTap ? [] : [.keepsMenuPresented])
        }.uiKitEquivalent
    }
    
    /// Current value shown by the stepper.
    public let value: T
    
    /// Controls whether the menu is dismissed on tap of +/- buttons.
    public let closeMenuOnTap: Bool
    
    /// Handler called when increment button is pressed.
    public let incrementButtonPressed: (T) -> Void
    
    /// Handler called when decrement button is pressed.
    public let decrementButtonPressed: (T) -> Void
    
    /// Body closure used to render the current value as `Text` inside the stepper.
    public let body: (T) -> Text
    
    /// Create a ``BetterMenus/Stepper``.
    ///
    /// - Parameters:
    ///   - value: Current value.
    ///   - closeMenuOnTap: Whether pressing buttons closes the menu.
    ///   - incrementButtonPressed: Increment callback.
    ///   - decrementButtonPressed: Decrement callback.
    ///   - body: Closure returning a `Text` representation of the value.
    public init(value: T, closeMenuOnTap: Bool = false, incrementButtonPressed: @escaping (T) -> Void, decrementButtonPressed: @escaping (T) -> Void, body: @escaping (T) -> Text) {
        self.value = value
        self.closeMenuOnTap = closeMenuOnTap
        self.incrementButtonPressed = incrementButtonPressed
        self.decrementButtonPressed = decrementButtonPressed
        self.body = body
    }
}

/*
// TODO: allow no selection or multiple selection
// The selection is the tag of one of the Text
@available(iOS 16.0, *)
public struct Picker<SelectionValue>: MenuBuilderElement where SelectionValue: Hashable {
    public var uiKitEquivalent: UIMenuElement {
        func modifyStateWithSelectionRecursively(element: UIMenu) {
            for children
        }
        
        body().children.for
    }
    
    public let currentValue: SelectionValue
    public let didSelect: (SelectionValue) -> Void
    @BUIMenuBuilder public let body: () -> UIMenu
    
    init(currentValue: SelectionValue, didSelect: @escaping (SelectionValue) -> Void, @BUIMenuBuilder body: @escaping () -> UIMenu) {
        self.currentValue = currentValue
        self.didSelect = didSelect
        self.body = body
    }
}
 */

// MARK: - Section

/// A ``BetterMenus/Section`` provides a labeled grouping.
///
/// Example:
/// ```swift
/// Section("Preferences") {
///     Toggle("Enable X", state: .off) { _, _ in }
///     Toggle("Enable Y", state: .on) { _, _ in }
/// }
/// ```
@available(iOS 16.0, *)
public struct Section: MenuBuilderElement {
    public var uiKitEquivalent: UIMenu {
        UIMenu(title: title, options: .displayInline, children: body().children)
    }
    
    /// The section title.
    public let title: String
    
    /// Optional identifier for the section. Can be used to refresh the section only.
    var identifier: UIMenu.Identifier? = nil
    
    /// The body closure producing the content of the section.
    @BUIMenuBuilder public let body: () -> UIMenu
    
    /// Create a new `Section`.
    public init(_ title: String = "", @BUIMenuBuilder body: @escaping () -> UIMenu) {
        self.title = title
        self.body = body
    }
    
    /// Optional identifier for the section. Can be used to refresh the section only.
    public func identifier(_ identifier: UIMenu.Identifier?) -> Self {
        var copy = self
        copy.identifier = identifier
        return copy
    }
    
    /// Optional identifier for the section. Can be used to refresh the section only.
    public func identifier(_ identifier: String) -> Self {
        var copy = self
        copy.identifier = UIMenu.Identifier(rawValue: identifier)
        return copy
    }
}

// MARK: - ControlGroup

/// A ``BetterMenus/`ControlGroup`` indicates a related set of controls that should be displayed
/// with a medium element size (for example, a set of formatting actions).
///
/// Example:
/// ```swift
/// ControlGroup {
///     Button("Bold") { _ in }
///     Button("Italic") { _ in }
///     Button("Underline") { _ in }
/// }
/// ```
@available(iOS 16.0, *)
public struct ControlGroup: MenuBuilderElement {
    public var uiKitEquivalent: UIMenu {
        UIMenu(options: [.displayInline], preferredElementSize: .medium, children: controls().children)
    }
    
    /// A builder closure that returns the controls to include in the group.
    @BUIMenuBuilder public let controls: () -> UIMenu
    
    /// Create a control group from the provided `controls` closure.
    public init(@BUIMenuBuilder controls: @escaping () -> UIMenu) {
        self.controls = controls
    }
}

// MARK: - Async support

@available(iOS 16.0, *)
public enum AsyncStorage {
    static var AsyncCache: OrderedDictionary<AnyHashable, CacheType> = .init()
    static let AsyncStorageQueue = DispatchQueue(label: "bettermenus.async-storage")

    
    enum CacheType {
        case uiDeferredElement(UIDeferredMenuElement)
        case deferredContent(Any)
    }
    
    static func updateValueAndPutOnTop(withIdentifier identifier: AnyHashable, value: CacheType) {
        AsyncStorageQueue.async {
            if AsyncCache.keys.contains(identifier) {
                _ = AsyncCache.removeValue(forKey: identifier)
            }
            AsyncCache[identifier] = value
            AsyncStorage.cleanCacheSurplus()
        }
    }
    
    static func cleanCacheSurplus() {
        AsyncStorageQueue.async {
            if AsyncStorage.AsyncCache.count > AsyncStorage.AsyncCacheMaxSize {
                AsyncStorage.AsyncCache.removeFirst(AsyncStorage.AsyncCache.count - AsyncStorage.AsyncCacheMaxSize)
            }
        }
    }
    
    static func getValue(forIdentifier identifier: AnyHashable) -> CacheType? {
        return AsyncStorageQueue.sync {
            return AsyncCache[identifier]
        }
    }
        
    /// A variable to set the maximum size cache for the cache of async elements.
    public static var AsyncCacheMaxSize: Int = .max
    
    /// A static method to clean the cache for a certain identifier. Returns true if an element was removed from the cache.
    public static func cleanCache(forIdentifier identifier: AnyHashable) -> Bool {
        return AsyncStorageQueue.asyncAndWait {
            return AsyncStorage.AsyncCache.removeValue(forKey: identifier) != nil
        }
    }

    /// A static method to clean the cache for identifiers that match a certain condition.
    public static func cleanCache(where condition: (AnyHashable) -> Bool) {
        return AsyncStorageQueue.asyncAndWait {
            return AsyncStorage.AsyncCache.removeAll(where: { element in
                condition(element.key)
            })
        }
    }
    
    /// A method to modify the raw cache of a cache element that comes from an ``Async`` structure where ``Async/calculateBodyWithCache(_:)`` was enabled, ``Async/cached(_:)`` was enabled and the ``Async/identifier(_:)`` was given.
    /// - Generic: T is the type of element that should be present in the cache for the identifier to give (i.e. the `Result` type of your ``Async`` structure).
    /// - Returns: a  boolean indicating whether the change took place or not.
    ///
    /// Once a result is cached (via `calculateBodyWithCache`), you can modify it at runtime without refetching.
    ///
    /// ```swift
    /// AsyncStorage.modifyCache(forIdentifier: "menu-cache") { (data: [Item]) in
    ///     var copy = data
    ///     copy.append(Item(name: "Injected item"))
    ///     return copy
    /// }
    /// ```
    ///
    /// * The closure receives the cached value and return a value of type `T` (the same type your `asyncFetch` returns otherwise the modification will be rejected).
    /// * Returns `true` if the cache was successfully updated, otherwise `false`.
    ///
    /// This is useful for:
    ///
    /// * Injecting items into the menu without hitting the network again.
    /// * Adjusting cached data after a background update.
    /// * Fixing up cached state when identifiers collide.
    public static func modifyCache<T>(forIdentifier identifier: AnyHashable, _ handler: (T) -> T) -> Bool {
        if case .deferredContent(var content) = getValue(forIdentifier: identifier) {
            if let content = content as? T {
                let updatedContent = handler(content)
                updateValueAndPutOnTop(withIdentifier: identifier, value: .deferredContent(updatedContent))
                cleanCacheSurplus()
                return true
            } else {
                print("[BetterMenus] Tried to modify the cache for identifier \(identifier), but the type present in the cache is not the same as the one you specified (given: \(T.self), present in the cache: \(type(of: content))).")
            }
        } else {
            print("[BetterMenus] Tried to modify the cache for identifier \(identifier), but the cache is a menu element and not a custom type of data, use Async.calculateBodyWithCache.")
        }
        return false
    }
}

/// Create a deferred menu element that will run `asyncFetch` and then render `body(result)`
/// While `asyncFetch` runs, a loading placeholder with a progressview is shown.
///
/// If ``Async/cached(_:)`` is true and an ``Async/identifier(_:)`` is provided, cached `UIDeferredMenuElement`s are stored
/// in an internal `AsyncCache` to avoid re-fetching identical async data repeatedly.
///
/// Example:
/// ```swift
/// Async {
///     // This closure runs in an async context
///     try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
///     return ["Alice", "Bob", "Eve"]
/// } body: { users in
///     // This closure builds the menu once the data is fetched
///     ForEach(users) { user in
///         Text(user)
///     }
/// }
/// ```
@available(iOS 16.0, *)
public struct Async<Result>: MenuBuilderElement {
    public var uiKitEquivalent: UIDeferredMenuElement {
        let completionHandler: (@escaping ([UIMenuElement]) -> Void) -> Void = { completion in
            Task {
                let result = await asyncFetch()
                
                // if we cache the result of this fetch instead of the resulting UIMenuElement
                if let identifier = self.identifier, self.calculateBodyWithCache {
                    AsyncStorage.updateValueAndPutOnTop(withIdentifier: identifier, value: .deferredContent(result))
                }
                
                DispatchQueue.main.async {
                    completion(self.body(result).children)
                }
            }
        }
                
        if cached {
            if let identifier = self.identifier,
               let element = AsyncStorage.getValue(forIdentifier: identifier) {
                   AsyncStorage.updateValueAndPutOnTop(withIdentifier: identifier, value: element)
                   switch element {
                   case .uiDeferredElement(let uIDeferredMenuElement):
                       return uIDeferredMenuElement
                   case .deferredContent(let result as Result):
                       // we use uncached to make sure that the body is going to be recalculated and be displayed
                       return UIDeferredMenuElement.uncached { completion in
                           completion(body(result).children)
                       }
                   case .deferredContent(let result):
                       print("[BetterMenus] The cached result should never be of a different type than the original one. Result:", result, "Expected type:", Result.self)
                       return UIDeferredMenuElement({ $0([]) })
                   }
               } else {
                   var newElement = UIDeferredMenuElement(completionHandler)
                   if let identifier = self.identifier {
                       let newCacheElement: AsyncStorage.CacheType
                       if self.calculateBodyWithCache {
                           newElement = UIDeferredMenuElement.uncached(completionHandler) // we cache manually
                       } else {
                           AsyncStorage.updateValueAndPutOnTop(withIdentifier: identifier, value: .uiDeferredElement(newElement))
                       }
                   }
                   return newElement
               }
        } else {
            return UIDeferredMenuElement.uncached(completionHandler)
        }
    }
    
    /// A variable to set the maximum size cache for the cache of async elements
    @available(*, deprecated, message: "Use AsyncStorage.AsyncCacheMaxSize instead. This variable will be removed in a future version of BetterMenus.")
    public static var asyncCacheMaxSize: Int {
        get {
            return AsyncStorage.AsyncCacheMaxSize
        }
        set {
            AsyncStorage.AsyncCacheMaxSize = newValue
        }
    }
    
    /// A static method to clean the cache for a certain identifier. Returns true if an element was removed from the cache.
    @available(*, deprecated, message: "Use AsyncStorage.cleanCache(forIdentifier identifier: AnyHashable) -> Bool instead. This method will be removed in a future version of BetterMenus.")
    public static func cleanCache(forIdentifier identifier: AnyHashable) -> Bool {
        return AsyncStorage.cleanCache(forIdentifier: identifier)
    }
    
    /// A static method to clean the cache for identifiers and elements that match a certain condition.
    @available(*, deprecated, message: "Use cleanCache(where condition: (AnyHashable) -> Bool) condition instead. This method will be removed in a future version of BetterMenus.") // TODO: make the AsyncCache private when this gets removed
    public static func cleanCache(where condition: (AnyHashable, UIMenuElement) -> Bool) {
        return AsyncStorage.AsyncStorageQueue.asyncAndWait {
            AsyncStorage.AsyncCache.removeAll(where: { key, element in
                if case .uiDeferredElement(let deferredElement) = element {
                    return condition(key, deferredElement)
                } else {
                    return condition(key, UIMenu())
                }
            })
        }
    }
    
    /// When true, caches the element and reuse in case of menu refresh. You can also set an ``identifier`` to this element for it to be cached even after the menu gets destroyed.
    @available(*, deprecated, message: "Use cached(_:) instead. This variable will become internal in a future version of BetterMenus.")
    public var cached: Bool = false
    
    /// A boolean indicating whether the content of the ``asyncFetch`` query should be cached and be used to recalculate the body or if the body only should be saved (default case). The body is recalculated when a refresh operation takes place.
    var calculateBodyWithCache: Bool = false
    
    /// Optional key used to cache the deferred menu element, beware that the element will be stored in the cache and no limit to it is set by default, see ``Async/asyncCacheMaxSize``. See ``cached``.
    @available(*, deprecated, message: "Use identifier(_:) instead. This variable will become internal in a future version of BetterMenus.")
    public var identifier: AnyHashable? = nil

    /// The asynchronous fetching closure that returns a `Result` used by `body` to build children.
    public let asyncFetch: () async -> Result

    /// A builder closure that maps the fetched `Result` into a `UIMenu`.
    @BUIMenuBuilder public let body: (Result) -> UIMenu
    
    /// Create an `Async` deferred menu element.
    ///
    /// - Parameters:
    ///   - cached: Whether to cache the deferred menu element.
    ///   - identifier: Optional cache key.
    ///   - asyncFetch: The asynchronous fetch closure.
    ///   - body: Builder that returns a `UIMenu` given the fetch result.
    public init(_ asyncFetch: @escaping () async -> Result, @BUIMenuBuilder body: @escaping (Result) -> UIMenu) {
        self.asyncFetch = asyncFetch
        self.body = body
    }
    
    /// Sets a boolean that, when true, caches the element and reuse in case of menu refresh. You can also set an ``identifier`` to this element for it to be cached even after the menu gets destroyed.
    /// | `cached` | `identifier` | Behavior                                                                                                                                                                                                   |
    /// | -------- | ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    /// | `false`  | `nil` or set | The element reloads **every time** it is shown or refreshed. Nothing is stored in the cache.                                                                                                               |
    /// | `true`   | `nil`        | The element is cached only for the current menu lifecycle. It won’t reload when the menu is reopened **without modifications**, but will reload on explicit refresh.                                       |
    /// | `true`   | non-`nil`    | The element persists in the cache across menu lifecycles. It will **not reload on refresh**. To reload, you must explicitly remove it from the cache (e.g. via ``AsyncStorage/cleanCache(forIdentifier:)``). |
    public func cached(_ cached: Bool) -> Self {
        var copy = self
        copy.cached = cached
        return copy
    }
    
    /// Sets a boolean indicating whether the content of the ``asyncFetch`` query should be cached and be used to recalculate the body or if the body only should be saved (default case). The body is recalculated when a refresh operation takes place.
    ///
    /// By default, an `Async` element caches the **final `UIDeferredMenuElement`** (the rendered menu).
    /// If you enable `.calculateBodyWithCache(true)`, the cache will instead store the **raw `Result`** produced by your `asyncFetch` closure.
    /// This allows the menu body to be recalculated later without re-running the async fetch. For example:
    /// ```swift
    /// Async {
    ///     await fetchMenuData()
    /// } body: { data in
    ///     UIMenu(title: "Items", children: data.map(makeMenuItem))
    /// }
    /// .cached(true)
    /// .identifier("menu-cache")
    /// .calculateBodyWithCache(true)
    /// ```
    /// * If `calculateBodyWithCache` is **false** (default):
    ///   The menu is cached as-is, and reused directly on refresh.
    /// * If `calculateBodyWithCache` is **true**:
    ///   The `fetchMenuData()` result is cached, and the `body` builder will be called again when the menu refreshes.
    /// - Note: Refreshing the menu is not automatic. You must call `reloadMenu()` explicitly on your `BetterContextMenuInteraction` (or a custom `UIContextMenuInteraction`) to trigger the rebuild.
    public func calculateBodyWithCache(_ calculateBodyWithCache: Bool) -> Self {
        var copy = self
        copy.calculateBodyWithCache = calculateBodyWithCache
        return copy
    }
    
    /// Sets an key used to cache the deferred menu element.
    ///
    /// If ``cached(_:)`` is set to true, setting the identifier will make the element persist in the cache across menu lifecycles. It will **not reload on refresh**. To reload, you must explicitly remove it from the cache (e.g. via `AsyncStorage.cleanCache(forIdentifier:)`).
    /// See the table in the documentation of ``cached(_:)`` to know more about the combinations.
    public func identifier(_ identifier: AnyHashable) -> Self {
        var copy = self
        copy.identifier = identifier
        return copy
    }
}

// MARK: - BetterContextMenuInteraction

@available(iOS 16.0, *)
public class BetterContextMenuInteraction: UIContextMenuInteraction {
    /// Delegate that returns a dynamically-updatable menu. Subclass it to have more customizability.
    public class Delegate: NSObject, BetterUIContextMenuInteractionDelegate {
        public var currentMenu: UIMenu
        
        public var previewProvider: UIContextMenuContentPreviewProvider?
        
        public init(currentMenu: UIMenu, previewProvider: UIContextMenuContentPreviewProvider?) {
            self.currentMenu = currentMenu
            self.previewProvider = previewProvider
        }
        
        public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            return UIContextMenuConfiguration(identifier: nil,
                                              previewProvider: previewProvider,
                                              actionProvider: { [weak self] suggested in
                // Provide the actual menu shown for actions
                return self?.currentMenu
            })
        }
    }
    
    /// The body closure used to construct the menu on demand.
    public let body: () -> UIMenu
    
    /// A preview provider for the `UIContextMenuInteractionDelegate`.
    public var previewProvider: UIContextMenuContentPreviewProvider? {
        didSet {
            self._delegate.previewProvider = previewProvider
        }
    }
        
    /// The currently-visible menu. When set it updates the delegate's reference.
    private var currentMenu: UIMenu {
        didSet {
            self._delegate.currentMenu = currentMenu
        }
    }
    
    private var _delegate: BetterUIContextMenuInteractionDelegate
    
    /// Update the currently visible menu by calling the `body` builder and replacing the whole menu or just the one with the specified identifier.
    ///
    /// If you call `reloadMenu()` without specifying an identifier, it will update the root menu. However, if a submenu is currently open, that submenu won't reflect the changes until it is closed and reopened again. This is because the update applies to the visible menus based on UIKit's menu presentation behavior.
    public func reloadMenu(withIdentifier identifier: String) {
        return reloadMenu(withIdentifier: UIMenu.Identifier(rawValue: identifier))
    }

    /// Update the currently visible menu by calling the `body` builder and replacing the whole menu or just the one with the specified identifier.
    ///
    /// If you call `reloadMenu()` without specifying an identifier, it will update the root menu. However, if a submenu is currently open, that submenu won't reflect the changes until it is closed and reopened again. This is because the update applies to the visible menus based on UIKit's menu presentation behavior.
    public func reloadMenu(withIdentifier identifier: UIMenu.Identifier? = nil) {
        
        // documentation from UIKit
        /**
         * @abstract Call to update the currently visible menu. This method does nothing if called before a menu is presented.
         *
         * @param block  Called with a mutable copy of the currently visible menu. Modify and return this menu (or an entirely
         *               new one) to change the currently visible menu items. Starting in iOS 15, this block is called once for
         *               every visible submenu. For example, in the following hierarchy:
         *
         *               *- Root Menu
         *                  *- Submenu A
         *                     *- Submenu B
         *                  *- Submenu C
         *
         *               If Submenu A is visible, the block is called twice (once for the Root Menu and once for Submenu A).
         *               If both A and B are visible, it's called 3 times (for the Root Menu, A, and B).
         */
        DispatchQueue.main.async {
            var didUpdateRoot: Bool = false
            self.currentMenu = self.body()
            self.updateVisibleMenu { menu in
                if let identifier = identifier {
                    if menu.identifier == identifier {
                        if let menuToReplace = self.currentMenu.findChildren(withIdentifier: identifier) {
                            return menuToReplace
                        } else {
                            print("[BetterMenus] Didn't find menu with identifier \(identifier) in the result of body(). Not replacing current menu.")
                        }
                    }
                    return menu
                } else {
                    guard !didUpdateRoot else { return UIMenu() }
                    didUpdateRoot = true
                    return self.currentMenu
                }
            }
        }
    }
    
    /// Create a context menu interaction backed by a `@BUIMenuBuilder` body that can be reloaded.
    ///
    /// - Parameter body: A `@BUIMenuBuilder` closure returning the menu to display.
    /// - Parameter previewProvider: a preview provider for the delegate
    /// - Parameter delegate: an optional delegate
    ///
    /// Example - attaching to a view:
    /// ```swift
    /// let interaction = BetterContextMenuInteraction {
    ///     Menu("Options") {
    ///         Button("Share") { _ in /* ... */ }
    ///         Button("Delete", style: .destructive) { _ in /* ... */ }
    ///     }
    /// }
    /// view.addInteraction(interaction)
    /// ```
    public init(@BUIMenuBuilder body: @escaping () -> UIMenu, previewProvider: UIContextMenuContentPreviewProvider? = nil, delegate: BetterUIContextMenuInteractionDelegate? = nil) {
        self.body = body
        self.previewProvider = previewProvider
        self.currentMenu = body()
        delegate?.currentMenu = currentMenu
        delegate?.previewProvider = previewProvider
        self._delegate = delegate ?? Delegate(currentMenu: currentMenu, previewProvider: previewProvider)
        super.init(delegate: _delegate)
        self.reloadMenu()
    }
    
    @available(*, unavailable)
    override init(delegate: any UIContextMenuInteractionDelegate) {
        self.body = { UIMenu() }
        self.previewProvider = nil
        self.currentMenu = body()
        self._delegate = Delegate(currentMenu: currentMenu, previewProvider: nil)
        super.init(delegate: delegate)
    }
}

/// Delegate protocol that returns a dynamically-updatable menu.
///
/// See the implementation of ``BetterMenus/BetterContextMenuInteraction/Delegate`` to get more details.
public protocol BetterUIContextMenuInteractionDelegate: UIContextMenuInteractionDelegate {
    var currentMenu: UIMenu { get set }
    
    var previewProvider: UIContextMenuContentPreviewProvider? { get set }
        
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration?
}
