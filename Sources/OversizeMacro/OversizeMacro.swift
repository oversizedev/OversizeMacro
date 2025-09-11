// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A macro that produces both a value and a string containing the
/// source code that generated the value. For example,
///
///     #stringify(x + y)
///
/// produces a tuple `(x + y, "x + y")`.
@freestanding(expression)
public macro stringify<T>(_ value: T) -> (T, String) = #externalMacro(module: "OversizeMacroMacros", type: "StringifyMacro")

/// A macro that generates an Action enum and handleAction method for actor-based ViewModels.
/// Applied to actor types to automatically generate action handling based on public methods
/// starting with "on".
///
/// Example:
///
///     @Actions
///     actor ViewModel {
///         public func onAppear() { }
///         public func onTapSave(name: String) { }
///     }
///
/// Generates:
///
///     public enum Action {
///         case appear
///         case tapSave(name: String)
///     }
///
///     public func handleAction(_ action: Action) async {
///         switch action {
///         case .appear:
///             onAppear()
///         case .tapSave(let name):
///             await onTapSave(name: name)
///         }
///     }
@attached(member, names: arbitrary)
public macro Actions() = #externalMacro(module: "OversizeMacroMacros", type: "ActionsMacro")
