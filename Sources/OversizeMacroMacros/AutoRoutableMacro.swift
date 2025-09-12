import SwiftSyntax
import SwiftSyntaxMacros

public struct AutoRoutableMacro: MemberMacro {
    public static func expansion<Declaration: DeclGroupSyntax, Context: MacroExpansionContext>(
        of node: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        conformingTo _: [TypeSyntax],
        in context: Context
    ) throws -> [DeclSyntax] {
        try expansion(of: node, providingMembersOf: declaration, in: context)
    }

    public static func expansion<Declaration: DeclGroupSyntax, Context: MacroExpansionContext>(
        of _: AttributeSyntax,
        providingMembersOf declaration: Declaration,
        in _: Context
    ) throws -> [DeclSyntax] {
        let caseNames: [String] = declaration.memberBlock.members
            .compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
            .flatMap { $0.elements.map { $0.name.text } }

        let cases = caseNames.map { name in
            """
                    case .\(name):
                        return "\(name)"
            """
        }.joined(separator: "\n")

        return [
            """
            var id: String {
                switch self {
            \(raw: cases)
                }
            }
            """,
        ]
    }
}
