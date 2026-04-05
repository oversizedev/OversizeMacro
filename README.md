# OversizeMacro

Swift macro package providing attached macros for SwiftUI development.

[![Swift](https://img.shields.io/badge/Swift-6.1-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2013+%20|%20macOS%2010.15+%20|%20tvOS%2013+%20|%20watchOS%206+%20|%20Mac%20Catalyst%2013+-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

OversizeMacro provides two Swift macros that reduce boilerplate in SwiftUI projects:

- **`@ViewModel`** — Automatically generates an `Action` enum and `handleAction` method from `on`-prefixed methods in your view model.
- **`@AutoRoutable`** — Generates a computed `id` property for enum types, returning the case name as a `String`.

## Installation

Add OversizeMacro to your project via Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/oversizedev/OversizeMacro.git", from: "0.1.0")
]
```

Then add `OversizeMacro` to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: ["OversizeMacro"]
)
```

## Macros

### @ViewModel

Applied to `class` or `actor` types. Scans non-private methods prefixed with `on` and generates:

- An `Action` enum with cases matching each `on` method
- A `handleAction(_ action: Action) async` method that dispatches actions to the corresponding methods

#### Usage

```swift
import OversizeMacro

@ViewModel
class SettingsViewModel: ObservableObject {
    func onAppear() {
        // load data
    }

    func onTapSave(id: String) {
        // save item
    }

    func onDelete(at index: Int) {
        // delete item
    }
}
```

#### Generated Code

The macro generates the following:

```swift
extension SettingsViewModel {
    enum Action: Sendable {
        case onAppear
        case onTapSave(id: String)
        case onDelete(at: Int)
    }
}

// Inside SettingsViewModel:
func handleAction(_ action: Action) async {
    switch action {
    case .onAppear:
        onAppear()
    case .onTapSave(id):
        onTapSave(id: id)
    case .onDelete(at):
        onDelete(at: at)
    }
}
```

#### Notes

- Methods with `private` access, `static`/`class` modifiers, generic parameters, variadic parameters, or `inout`/`@autoclosure` parameters are excluded.
- If a method is `async` or `throws`, the generated `handleAction` method handles it accordingly.
- Access level of generated code matches the most restrictive access level among the type and its `on` methods.
- Overloaded `on` method names produce a compile-time error.

### @AutoRoutable

Applied to `enum` types. Generates a computed `var id: String` that returns the case name as a string, regardless of associated values.

#### Usage

```swift
import OversizeMacro

@AutoRoutable
enum Screens {
    case meta
    case instagram
    case twitter
}

print(Screens.meta.id) // "meta"
```

#### Generated Code

```swift
var id: String {
    switch self {
    case .meta: "meta"
    case .instagram: "instagram"
    case .twitter: "twitter"
    }
}
```

## Requirements

- Swift 6.1+
- macOS 10.15+ / iOS 13+ / tvOS 13+ / watchOS 6+ / Mac Catalyst 13+

## License

MIT License. See [LICENSE](LICENSE) for details.
