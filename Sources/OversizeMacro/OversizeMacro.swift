@attached(member, names: arbitrary)
public macro AutoRoutable() = #externalMacro(module: "OversizeMacroMacros", type: "AutoRoutableMacro")

@attached(member, names: arbitrary)
public macro ViewModel() = #externalMacro(module: "OversizeMacroMacros", type: "ViewModelMacro")
