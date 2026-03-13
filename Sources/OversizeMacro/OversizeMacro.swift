@attached(extension, conformances: Sendable, names: named(Action))
@attached(member, names: named(handleAction))
public macro ViewModel() = #externalMacro(module: "OversizeMacroMacros", type: "ViewModelMacro")

@attached(member, names: arbitrary)
public macro AutoRoutable() = #externalMacro(module: "OversizeMacroMacros", type: "AutoRoutableMacro")
