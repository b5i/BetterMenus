# BetterMenus

A lightweight Swift helper to build `UIMenu` and `UIMenuElement` hierarchies with a SwiftUI-like DSL using a `@resultBuilder`.
Designed for UIKit apps (iOS 16.0+) - compose menus declaratively, add async/deferred items, and wire context menus that can be reloaded at runtime. All of that in a single file for easy integration.

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fb5i%2FBetterMenus%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/b5i/BetterMenus) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fb5i%2FBetterMenus%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/b5i/BetterMenus)

-----

## Highlights

  * Declarative `@BUIMenuBuilder` DSL for building `UIMenu` trees.
  * Swift-friendly types: `Menu`, `Button`, `Toggle`, `Text`, `Section`, `ControlGroup`, `Stepper`, `ForEach`, `Divider`, etc.
  * **Full Composability**: Build complex menus by calling other `@BUIMenuBuilder` functions.
  * **Conditional Logic**: Use standard Swift control flow (`if-else`, `switch`) to conditionally include elements.
  * **Direct UIKit Integration**: Seamlessly mix with standard `UIMenu` and `UIAction` elements in your builder closures.
  * `Async` (deferred) menu elements with an optional, configurable cache.
  * `BetterContextMenuInteraction` - a `UIContextMenuInteraction` wrapper that constructs menus via the builder and can be reloaded dynamically.
  * Minimal dependencies (uses `OrderedCollections` internally for `Async` cache).
  * Target: **iOS 16.0+**, 15.0 will be supported in a future release.

-----

## Installation

Add the package to your project with Swift Package Manager:

```swift
// Xcode: File → Swift Packages → Add Package Dependency
// Package URL: https://github.com/b5i/BetterMenus.git
```

or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/b5i/BetterMenus.git", from: "1.0.0")
]
```

or put the single file `Sources/BetterMenus/BetterMenus.swift` directly in your project.

Then import:

```swift
import BetterMenus
```

> Note: the package builds on top of UIKit's `UIMenu`/`UIAction` APIs and requires iOS 16.0 or newer at compile time.

-----

# Quick Start

### 1 - Build a simple menu

```swift
@BUIMenuBuilder
func makeMenu() -> UIMenu {
    Menu("Edit") {
        Button("Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
            print("Copy tapped")
        }
        Button("Paste", image: UIImage(systemName: "doc.on.clipboard")) { _ in
            print("Paste tapped")
        }
    }
}
```

The `BUIMenuBuilder` produces a `UIMenu` you can assign directly to `UIButton.menu`, return from a `UIContextMenuInteraction` provider, or present in other UIKit APIs that accept `UIMenu`.

### 2 - Inline items and dividers

```swift
@BUIMenuBuilder
func inlineMenu() -> UIMenu {
    Text("Read-only text row")
    Divider()          // creates an inline separator group
    Button("Action") { _ in /* ... */ }
}
```

### 3 - Mix with native UIKit elements

You can include `UIMenu` and `UIAction` instances directly in the builder.

```swift
func makeNativeSubmenu() -> UIMenu {
    let subAction = UIAction(title: "Native Action", handler: { _ in print("Tapped!") })
    return UIMenu(title: "Native Submenu", children: [subAction])
}

@BUIMenuBuilder
func mixedMenu() -> UIMenu {
    Button("BetterMenus Button") { _ in /* ... */ }
    makeNativeSubmenu() // Include a UIMenu directly
}
```

### 4 - Compose functions and use conditional logic

Call other `@BUIMenuBuilder` functions and use `if-else` to build your menu dynamically.

```swift
var someCondition = true

@BUIMenuBuilder
func featureMenu() -> UIMenu {
    if someCondition {
        Text("Feature is ON")
    } else {
        Text("Feature is OFF")
    }
}

@BUIMenuBuilder
func masterMenu() -> UIMenu {
    // Call another builder function to compose menus
    featureMenu()
    Divider()
    Button("Another Action") { _ in /* ... */ }
}
```

### 5 - Toggle actions (stateful appearance handled by you)

`Toggle` converts to a `UIAction` with `.on`/`.off` states. You are responsible for managing the underlying app state and calling `reloadMenu()` if you want the visible menu to reflect changes.

```swift
var isOn: Toggle.ToggleState = .off

@BUIMenuBuilder
func toggleMenu() -> UIMenu {
    Toggle("Enable feature", state: isOn) { _, newValue in
        // Update your model
        isOn = isOn.opposite
    }
    .style([.keepsMenuPresented])
}
```

### 6 - ForEach

Map arrays into menu elements:

```swift
ForEach(["Alice", "Bob", "Eve"]) { name in
    Text("User: \(name)")
}
```

### 7 - Stepper (inline ± controls)

```swift
var count: Int = 1

Stepper(value: count, closeMenuOnTap: false,
        incrementButtonPressed: { _ in count += 1 /* then reload */ },
        decrementButtonPressed: { _ in count -= 1 /* then reload */ }) { value in
    Text("Amount: \(value)")
}
```

### 8 - Async / Deferred menu elements

Create `UIDeferredMenuElement`-backed items that fetch content asynchronously.

```swift
Async {
    // This closure runs in an async context
    try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
    return ["Alice", "Bob", "Eve"]
} body: { users in
    // This closure builds the menu once the data is fetched
    Menu("Users") {
        ForEach(users) { user in
            Text(user)
        }
    }
}
.cached(true)
.identifier("user-list")
```

#### Managing the Async Cache

When `cached == true` and an `identifier` is provided, the result is stored in a global cache to avoid re-fetching. You can manage this cache statically:

  * **Set Cache Size**: Adjust the maximum number of items in the cache (LRU policy).
    ```swift
    Async.asyncCacheMaxSize = 50 // Default is no limit
    ```
  * **Clear by Identifier**: Manually remove a specific cached element.
    ```swift
    // Returns true if an element was removed
    let didClean = Async.cleanCache(forIdentifier: "user-list")
    ```
  * **Clear by Condition**: Remove all cached elements that satisfy a condition.
    ```swift
    Async.cleanCache { identifier, element in
        // e.g., clean all caches representing elements with users
        return (identifier as? String)?.hasPrefix("user-") ?? false
    }
    ```

-----

## BetterContextMenuInteraction

`BetterContextMenuInteraction` is a convenience wrapper around `UIContextMenuInteraction` that accepts a `@BUIMenuBuilder` body and supports dynamic menu reloading.

It uses a public, nested `Delegate` class (`BetterContextMenuInteraction.Delegate`) to manage the menu presentation. While you can provide a `previewProvider` directly in the initializer for most cases, you can also subclass the delegate to gain more advanced control over the `UIContextMenuConfiguration` and other delegate behaviors.

### Usage

```swift
// In your UIViewController
var ctx: BetterContextMenuInteraction?

func setupView() {
    let myView = UIView()

    // Provide the body and an optional preview provider directly.
    ctx = BetterContextMenuInteraction(
        body: makeMenu,
        previewProvider: {
            let previewVC = UIViewController()
            previewVC.view.backgroundColor = .systemBlue
            previewVC.preferredContentSize = CGSize(width: 120, height: 120)
            return previewVC
        }
    )

    myView.addInteraction(ctx!)
    // Store `ctx` to call `ctx.reloadMenu()` when underlying state changes.
}

@BUIMenuBuilder
func makeMenu() -> UIMenu {
    // ... your menu definition
}
```

### Constructor

```swift
public init(
    @BUIMenuBuilder body: @escaping () -> UIMenu,
    previewProvider: UIContextMenuContentPreviewProvider? = nil,
    delegate: Delegate? = nil
)
```

### Customizing the Delegate

For advanced behaviors beyond providing a menu and a preview (e.g., custom animations), you can subclass `BetterContextMenuInteraction.Delegate` and override its methods. You can then pass an instance of your custom delegate during initialization.

```swift
class CustomDelegate: NSObject, BetterUIContextMenuInteractionDelegate {
    var currentMenu: UIMenu
    
    var previewProvider: UIContextMenuContentPreviewProvider?
    
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionCommitAnimating
    ) {
        print("Preview action committed!")
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(actionProvider: { [weak self] _ in self?.currentMenu })
    }
    
    init(currentMenu: UIMenu, previewProvider: UIContextMenuContentPreviewProvider? = nil) {
        self.currentMenu = currentMenu
        self.previewProvider = previewProvider
    }
}

let delegate = CustomDelegate(
    currentMenu: UIMenu(title: "", children: []),
    previewProvider: nil
)

let myInteraction = BetterContextMenuInteraction(body: makeMenu, delegate: delegate)
```

-----

## API Reference (summary)

> All types require iOS 16.0+

  * `@resultBuilder public struct BUIMenuBuilder`
    Build a `UIMenu` from declarative elements.
  * `protocol MenuBuilderElement`
    Conformance bridge to `UIMenuElement`. **`UIMenu` and `UIAction` conform by default**, so you can use them directly in the builder.
  * `struct Menu`: A grouped `UIMenu` node with a `@BUIMenuBuilder` body.
  * `struct Button`: Builds a `UIAction`.
  * `struct Toggle`: Builds a stateful `UIAction` (on/off).
  * `struct ForEach<T>`: Maps collections to menu children.
  * `struct Text`: A simple, inert text row.
  * `struct Stepper<T: Strideable>`: Inline menu with increment/decrement buttons.
  * `struct Section`: Inline submenu with a title.
  * `struct ControlGroup`: Groups controls with a `.medium` preferred element size.
  * `struct Async<Result>`: `UIDeferredMenuElement` builder with configurable caching.
  * `struct Divider`: A visual separator.
  * `class BetterContextMenuInteraction: UIContextMenuInteraction`: Context menu interaction that uses a builder `body`, supports `reloadMenu()`, and allows for delegate customization.

-----

## Practical example: state updates

```swift
final class MyViewController: UIViewController {
    private let button = UIButton(type: .system)
    private var ctx: BetterContextMenuInteraction?
    private var isEnabled: Toggle.ToggleState = .off {
        didSet {
            // When the state changes, reload the visible menu
            ctx?.reloadMenu()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(button)
        // ... layout button ...
        ctx = BetterContextMenuInteraction(body: makeMenu)
        button.addInteraction(ctx!)
    }

    @BUIMenuBuilder
    func makeMenu() -> UIMenu {
        Toggle("Enable", state: isEnabled) { _, _ in
            self.isEnabled = self.isEnabled.opposite
        }
        Button("Do something") { _ in /* ... */ }
    }
}
```

-----

## Notes & Gotchas

  * The builder produces standard `UIMenu`/`UIMenuElement` instances - all UIKit rendering rules and behaviors still apply.
  * Stateful elements like `Toggle` and `Stepper` **do not** persist state automatically. You must manage the state in your model and call `reloadMenu()` to reflect changes.
  * The `Async` cache is a global, static resource. Its size and contents can be managed via the static properties and methods on the `Async` type.
  * The package targets iOS 16+ because it relies on modern menu APIs. Some appearance defaults may change on iOS 17+ (e.g., `preferredElementSize` uses `.automatic`).
  * When using a `Toggle`, you might encounter a weird UI behavior where the menu gets translated to the right or left after tapping the toggle (this happens when a checkmark is shown or dismissed). This is a known UIKit behavior.

-----

## Contributing

Contributions, bug reports and feature requests are welcome. Open an issue or submit a PR.

-----

## License & Author

**Author:** Antoine Bollengier - [github.com/b5i](https://github.com/b5i)
License: MIT

### Dependencies
- Apple's [Swift Collections](https://github.com/apple/swift-collections) to make the cache for `Async` elements. Licensed with [Apache License 2.0](https://github.com/apple/swift-collections?tab=Apache-2.0-1-ov-file#readme).
