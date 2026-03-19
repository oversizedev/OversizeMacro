import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct OversizeMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ViewModelMacro.self,
        AutoRoutableMacro.self
    ]
}
