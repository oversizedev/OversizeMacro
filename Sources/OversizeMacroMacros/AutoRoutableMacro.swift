import SwiftSyntax
import SwiftSyntaxMacros

public struct AutoRoutableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        try expansion(of: node, providingMembersOf: declaration, in: context)
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
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
