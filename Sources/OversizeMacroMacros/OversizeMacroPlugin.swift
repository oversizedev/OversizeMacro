import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct OversizeMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        AutoRoutableMacro.self,
    ]
}
