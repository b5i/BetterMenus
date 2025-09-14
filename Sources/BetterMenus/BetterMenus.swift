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

// MARK: - UIMenuBuilder result builder

@available(iOS 16.0, *)
@resultBuilder
public struct UIMenuBuilder {
    /// Build a single `UIMenu` from one or more ``BetterMenus/MenuBuilderElement`` components.
    ///
    /// This function walks the provided components, treating ``BetterMenus/Divider`` specially as a
    /// delimiter that creates nested menus. It collects children into an internal
    /// `UIMenuInfo` structure, then composes the final `UIMenu` tree and returns the root menu.
    ///
    /// - Parameter components: The variadic list of elements produced by the builder.
    /// - Returns: A constructed `UIMenu` representing the composed menu hierarchy.
    public static func buildBlock(_ components: any MenuBuilderElement...) -> UIMenu {
        let mainMenu: UIMenuInfo = UIMenuInfo(options: .displayInline)
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
    var uiMenuInfo: UIMenuBuilder.UIMenuInfo {
        return UIMenuBuilder.UIMenuInfo(title: title, subtitle: subtitle, image: image, identifier: identifier, options: options, preferredElementSize: preferredElementSize, children: children)
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
}

// MARK: - Menu (group)

/// This is the primary grouping type. A ``BetterMenus/Menu`` creates titled submenus and to host nested `@UIMenuBuilder` content.
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
    public var uiKitEquivalent: UIMenuElement {
        UIMenu(title: title, subtitle: subtitle, image: image, identifier: identifier, options: options, preferredElementSize: preferredElementSize, children: body().children)
    }
    
    /// The menu's title.
    public let title: String
    
    /// Optional subtitle for the menu.
    public let subtitle: String?
    
    /// Optional image for the menu.
    public let image: UIImage?
    
    /// Optional identifier for the menu.
    public let identifier: UIMenu.Identifier?
    
    /// Options that affect presentation and behavior.
    public let options: UIMenu.Options
    
    /// Preferred element size for children.
    public let preferredElementSize: UIMenu.ElementSize
    
    /// The body closure producing nested menu content. Annotated with ``BetterMenus/UIMenuBuilder``.
    @UIMenuBuilder public let body: () -> UIMenu
    
    /// Create a new `BetterMenus/Menu` node.
    ///
    /// - Parameters:
    ///   - title: The menu title.
    ///   - subtitle: Optional subtitle.
    ///   - image: Optional icon.
    ///   - identifier: Optional identifier.
    ///   - options: Menu options.
    ///   - preferredElementSize: Preferred element size for children.
    ///   - body: A `@UIMenuBuilder` closure that constructs the menu's children.
    public init(_ title: String = "", subtitle: String? = nil, image: UIImage? = nil, identifier: UIMenu.Identifier? = nil, options: UIMenu.Options = [], preferredElementSize: UIMenu.ElementSize = { if #available(iOS 17.0, tvOS 17.0, watchOS 10.0, *) { .automatic } else { .large } }(), @UIMenuBuilder body: @escaping () -> UIMenu) {
        self.title = title
        self.subtitle = subtitle
        self.image = image
        self.identifier = identifier
        self.options = options
        self.preferredElementSize = preferredElementSize
        self.body = body
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
public struct Button: MenuBuilderElement {
    public var uiKitEquivalent: UIMenuElement {
        UIAction(title: title, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle, attributes: style, state: state, handler: handler)
    }
    
    /// The action title displayed in the menu.
    public let title: String
    
    /// Optional icon for the action.
    public let image: UIImage?
    
    /// Optional identifier for the action.
    public let identifier: UIAction.Identifier?
    
    /// An optional discoverability title used by assistive features.
    public let discoverabilityTitle: String?
    
    /// Attributes such as `.destructive` or `.disabled`.
    public let style: UIMenuElement.Attributes
    
    /// The on/off state for actions that represent a stateful element.
    public let state: UIMenuElement.State
    
    /// Handler invoked when the action is selected.
    public let handler: (UIAction) -> Void
    
    /// Create a ``BetterMenus/Button``.
    public init(_ title: String = "", image: UIImage? = nil, identifier: UIAction.Identifier? = nil, discoverabilityTitle: String? = nil, style: UIMenuElement.Attributes = [], state: UIMenuElement.State = .off, _ handler: @escaping (UIAction) -> Void) {
        self.title = title
        self.image = image
        self.identifier = identifier
        self.discoverabilityTitle = discoverabilityTitle
        self.style = style
        self.state = state
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
public struct Toggle: MenuBuilderElement {
    /// Convert the builder `Toggle` into a `UIAction` with a handler that provides the new value.
    public var uiKitEquivalent: UIMenuElement {
        UIAction(title: title, image: image, identifier: identifier, discoverabilityTitle: discoverabilityTitle, attributes: style, state: state.uiMenuElementState, handler: { action in
            handler(action, !state.boolValue)
        })
    }
    
    /// The toggle's title.
    public let title: String
    
    /// Optional icon for the toggle.
    public let image: UIImage?
    
    /// Optional identifier.
    public let identifier: UIAction.Identifier?
    
    /// Optional discoverability title.
    public let discoverabilityTitle: String?
    
    /// Attributes such as `.keepsMenuPresented`.
    public let style: UIMenuElement.Attributes
    
    /// Current toggle state.
    public let state: ToggleState
    
    /// Handler called when the toggle is activated; provides the new boolean value.
    public let handler: (UIAction, _ newValue: Bool) -> Void
    
    /// Creates a Toggle.
    public init(_ title: String = "", image: UIImage? = nil, identifier: UIAction.Identifier? = nil, discoverabilityTitle: String? = nil, style: UIMenuElement.Attributes = [], state: ToggleState = .off, _ handler: @escaping (UIAction, _ newValue: Bool) -> Void) {
        self.title = title
        self.image = image
        self.identifier = identifier
        self.discoverabilityTitle = discoverabilityTitle
        self.style = style
        self.state = state
        self.handler = handler
    }
    
    // MARK: ToggleState
    public enum ToggleState {
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
    public var uiKitEquivalent: UIMenuElement {
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
    @UIMenuBuilder public let body: (T) -> UIMenu
    
    /// Create a ``BetterMenus/ForEach`` that maps `elements` using `body`.
    public init(_ elements: [T], @UIMenuBuilder body: @escaping (T) -> UIMenu) {
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
public struct Text: MenuBuilderElement {
    public var uiKitEquivalent: UIMenuElement {
        UIAction(title: text, image: image, handler: {_ in})
    }
    
    /// The displayed text.
    public let text: String
    
    /// Optional image for the text row.
    public let image: UIImage?
    
    /// An optional tag that can be used by consumers for selection or identification.
    // public var tag: (any Hashable)? will be used by the picker
    
    /// Create a text-only menu element.
    public init(_ text: String, image: UIImage? = nil, /* tag: (any Hashable)? = nil */ ) {
        self.text = text
        self.image = image
        //self.tag = tag
    }
    
    /// Attach a tag to the ``BetterMenus/Text`` element and return the updated value.
    /*
    public mutating func tag(_ value: any Hashable) -> Text {
        self.tag = value
        return self
    }
     */
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
    public var uiKitEquivalent: UIMenuElement {
        let processedBody = body(value)
        return Menu(processedBody.text, image: processedBody.image, options: [.displayInline], preferredElementSize: .small) {
            Button(image: UIImage(systemName: "minus"), style: closeMenuOnTap ? [] : [.keepsMenuPresented]) { _ in
                decrementButtonPressed(value)
            }
            Button(image: UIImage(systemName: "plus"), style: closeMenuOnTap ? [] : [.keepsMenuPresented]) { _ in
                incrementButtonPressed(value)
            }
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
    @UIMenuBuilder public let body: () -> UIMenu
    
    init(currentValue: SelectionValue, didSelect: @escaping (SelectionValue) -> Void, @UIMenuBuilder body: @escaping () -> UIMenu) {
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
    public var uiKitEquivalent: UIMenuElement {
        UIMenu(title: title, options: .displayInline, children: body().children)
    }
    
    /// The section title.
    public let title: String
    
    /// The body closure producing the content of the section.
    @UIMenuBuilder public let body: () -> UIMenu
    
    /// Create a new `Section`.
    public init(_ title: String = "", @UIMenuBuilder body: @escaping () -> UIMenu) {
        self.title = title
        self.body = body
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
    public var uiKitEquivalent: UIMenuElement {
        UIMenu(options: [.displayInline], preferredElementSize: .medium, children: controls().children)
    }
    
    /// A builder closure that returns the controls to include in the group.
    @UIMenuBuilder public let controls: () -> UIMenu
    
    /// Create a control group from the provided `controls` closure.
    public init(@UIMenuBuilder controls: @escaping () -> UIMenu) {
        self.controls = controls
    }
}

// MARK: - Async support

@available(iOS 16.0, *)
enum AsyncStorage {
    static var AsyncCache: OrderedDictionary<AnyHashable, UIDeferredMenuElement> = .init()
    static var AsyncCacheMaxSize: Int = .max
}

/// Create a deferred menu element that will run `asyncFetch` and then render `body(result)`
/// While `asyncFetch` runs, a loading placeholder with a progressview is shown.
///
/// If `cached` is true and an `identifier` is provided, cached `UIDeferredMenuElement`s are stored
/// in an internal `AsyncCache` to avoid re-fetching identical async data repeatedly.
///
/// Example:
/// ```swift
/// Async(cached: true, identifier: "recentFiles", {
///     return await loadRecentFiles()
/// }) { files in
///     ForEach(files) { file in
///         Button(file.name) { _ in open(file) }
///     }
/// }
/// ```
@available(iOS 16.0, *)
public struct Async<Result>: MenuBuilderElement {
    public var uiKitEquivalent: UIMenuElement {
        let completionHandler: (@escaping ([UIMenuElement]) -> Void) -> Void = { completion in
            Task {
                let result = await asyncFetch()
                await completion(body(result).children)
            }
        }
                
        if cached {
            if let identifier = self.identifier, let element = AsyncStorage.AsyncCache.removeValue(forKey: identifier) {
                AsyncStorage.AsyncCache[identifier] = element
                return element
            } else {
                let newElement = UIDeferredMenuElement(completionHandler)
                if let identifier = self.identifier {
                    AsyncStorage.AsyncCache[identifier] = newElement
                    if AsyncStorage.AsyncCache.count > AsyncStorage.AsyncCacheMaxSize {
                        AsyncStorage.AsyncCache.removeFirst(AsyncStorage.AsyncCache.count - AsyncStorage.AsyncCacheMaxSize)
                    }
                }
                return newElement
            }
        } else {
            return UIDeferredMenuElement.uncached(completionHandler)
        }
    }
    
    /// A variable to set the maximum size cache for the cache of async elements.
    public static var asyncCacheMaxSize: Int {
        get {
            return AsyncStorage.AsyncCacheMaxSize
        }
        set {
            AsyncStorage.AsyncCacheMaxSize = newValue
        }
    }
    
    /// A static method to clean the cache for a certain identifier. Returns true if an element was removed from the cache.
    public static func cleanCache(forIdentifier identifier: AnyHashable) -> Bool {
        return AsyncStorage.AsyncCache.removeValue(forKey: identifier) != nil
    }
    
    /// A static method to clean the cache for identifiers and elements that match a certain condition.
    public static func cleanCache(where condition: (AnyHashable, UIMenuElement) -> Bool) {
        return AsyncStorage.AsyncCache.removeAll(where: condition)
    }
    
    /// When true use an internal cache for deferred elements (when `identifier` is set).
    public let cached: Bool
    
    /// Optional key used to cache the deferred menu element, beware that the
    public let identifier: AnyHashable?

    /// The asynchronous fetching closure that returns a `Result` used by `body` to build children.
    public let asyncFetch: () async -> Result

    /// A builder closure that maps the fetched `Result` into a `UIMenu`.
    @UIMenuBuilder public let body: (Result) -> UIMenu
    
    /// Create an `Async` deferred menu element.
    ///
    /// - Parameters:
    ///   - cached: Whether to cache the deferred menu element.
    ///   - identifier: Optional cache key.
    ///   - asyncFetch: The asynchronous fetch closure.
    ///   - body: Builder that returns a `UIMenu` given the fetch result.
    public init(cached: Bool = false, identifier: AnyHashable? = nil, _ asyncFetch: @escaping () async -> Result, @UIMenuBuilder body: @escaping (Result) -> UIMenu) {
        self.cached = cached
        self.identifier = identifier
        self.asyncFetch = asyncFetch
        self.body = body
    }
}

// MARK: - BetterContextMenuInteraction

@available(iOS 16.0, *)
public class BetterContextMenuInteraction: UIContextMenuInteraction {
    /// Delegate that returns a dynamically-updatable menu. Subclass it to have more customizability.
    public class Delegate: NSObject, UIContextMenuInteractionDelegate {
        /// The current menu to present.
        public var currentMenu: UIMenu
        
        public var previewProvider: UIContextMenuContentPreviewProvider? = nil
        
        public func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
            return UIContextMenuConfiguration(identifier: nil,
                                              previewProvider: previewProvider,
                                              actionProvider: { [weak self] suggested in
                // Provide the actual menu shown for actions
                return self?.currentMenu
            })
        }
        
        public init(currentMenu: UIMenu, previewProvider: UIContextMenuContentPreviewProvider?) {
            self.currentMenu = currentMenu
            self.previewProvider = previewProvider
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
    
    private var _delegate: Delegate
        
    /// Update the currently visible menu by calling the `body` builder and replacing the menu.
    ///
    /// Call `reloadMenu()` when your underlying application state changes and you want
    /// the presented context menu to reflect new data (for example after toggling an item).
    public func reloadMenu() {
        self.updateVisibleMenu({ menu in
            self.currentMenu = self.body()
            return self.currentMenu
        })
    }
    
    /// A method to change the delegate of the interaction. Note that the currentMenu and the preview provider of the delegate will be overwritten by the one from the interaction.
    public func setDelegate(_ delegate: Delegate) {
        delegate.currentMenu = currentMenu
        delegate.previewProvider = previewProvider
        self._delegate = delegate
    }
    
    /// Create a context menu interaction backed by a `@UIMenuBuilder` body that can be reloaded.
    ///
    /// - Parameter body: A `@UIMenuBuilder` closure returning the menu to display.
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
    public init(@UIMenuBuilder body: @escaping () -> UIMenu, previewProvider: UIContextMenuContentPreviewProvider? = nil, delegate: Delegate? = nil) {
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
