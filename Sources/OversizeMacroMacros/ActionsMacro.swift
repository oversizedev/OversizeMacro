import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

/// Implementation of the `@Actions` macro that generates an Action enum and handleAction method
/// for actor-based ViewModels with methods starting with "on".
public struct ActionsMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // Validate that this is applied to an actor
        guard let actorDecl = declaration.as(ActorDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: node,
                message: ActionsDiagnostic.notActor
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Find all public methods starting with "on"
        let actionMethods = findActionMethods(in: actorDecl)
        
        // Generate warning if no methods found
        if actionMethods.isEmpty {
            let diagnostic = Diagnostic(
                node: node,
                message: ActionsDiagnostic.noMethods
            )
            context.diagnose(diagnostic)
            return []
        }
        
        // Generate enum cases and check for conflicts
        let enumCases = try generateEnumCases(from: actionMethods, in: context, node: node)
        
        // Generate the Action enum and handleAction method
        let actionEnum = try generateActionEnum(with: enumCases)
        let handleActionMethod = try generateHandleActionMethod(for: actionMethods, enumCases: enumCases)
        
        return [
            DeclSyntax(actionEnum),
            DeclSyntax(handleActionMethod)
        ]
    }
    
    /// Find all public instance methods starting with "on"
    private static func findActionMethods(in actorDecl: ActorDeclSyntax) -> [FunctionDeclSyntax] {
        return actorDecl.memberBlock.members.compactMap { member in
            guard let functionDecl = member.decl.as(FunctionDeclSyntax.self) else { return nil }
            
            // Check if it's public
            let isPublic = functionDecl.modifiers.contains { modifier in
                modifier.name.tokenKind == .keyword(.public)
            }
            guard isPublic else { return nil }
            
            // Check if it's not static
            let isStatic = functionDecl.modifiers.contains { modifier in
                modifier.name.tokenKind == .keyword(.static)
            }
            guard !isStatic else { return nil }
            
            // Check if name starts with "on"
            let functionName = functionDecl.name.text
            guard functionName.hasPrefix("on") && functionName.count > 2 else { return nil }
            
            return functionDecl
        }
    }
    
    /// Generate enum cases from action methods
    private static func generateEnumCases(
        from methods: [FunctionDeclSyntax],
        in context: some MacroExpansionContext,
        node: AttributeSyntax
    ) throws -> [(caseName: String, method: FunctionDeclSyntax)] {
        var caseNames: Set<String> = []
        var enumCases: [(String, FunctionDeclSyntax)] = []
        
        for method in methods {
            let functionName = method.name.text
            let caseName = convertToCaseName(functionName)
            
            // Check for conflicts
            if caseNames.contains(caseName) {
                let diagnostic = Diagnostic(
                    node: node,
                    message: ActionsDiagnostic.conflictingCases(caseName)
                )
                context.diagnose(diagnostic)
                throw ActionsMacroError.conflictingCaseNames
            }
            caseNames.insert(caseName)
            
            enumCases.append((caseName, method))
        }
        
        return enumCases
    }
    
    /// Convert method name to enum case name (onTapSave -> tapSave)
    private static func convertToCaseName(_ methodName: String) -> String {
        let remainder = String(methodName.dropFirst(2)) // Remove "on"
        
        if remainder.isEmpty {
            return "action"
        }
        
        // Handle case where remainder starts with multiple uppercase letters
        var result = remainder
        if let firstChar = remainder.first, firstChar.isUppercase {
            let firstCharLower = String(firstChar).lowercased()
            result = firstCharLower + String(remainder.dropFirst())
        }
        
        return result
    }
    
    /// Generate the Action enum declaration
    private static func generateActionEnum(with cases: [(String, FunctionDeclSyntax)]) throws -> EnumDeclSyntax {
        var enumCasesCode = ""
        
        for (caseName, method) in cases {
            let parameters = method.signature.parameterClause.parameters
            
            if parameters.isEmpty {
                enumCasesCode += "case \(caseName)\n"
            } else {
                let associatedValues = parameters.map { param in
                    let label = param.firstName.text == "_" ? "" : param.firstName.text
                    let type = param.type.trimmed.description
                    return label.isEmpty ? type : "\(label): \(type)"
                }.joined(separator: ", ")
                
                enumCasesCode += "case \(caseName)(\(associatedValues))\n"
            }
        }
        
        let enumCode = """
        public enum Action {
        \(enumCasesCode)
        }
        """
        
        return try EnumDeclSyntax("\(raw: enumCode)")
    }
    
    /// Generate the handleAction method
    private static func generateHandleActionMethod(
        for methods: [FunctionDeclSyntax],
        enumCases: [(caseName: String, method: FunctionDeclSyntax)]
    ) throws -> FunctionDeclSyntax {
        var switchCasesCode = ""
        
        for (caseName, method) in enumCases {
            let parameters = method.signature.parameterClause.parameters
            let isAsync = method.signature.effectSpecifiers?.asyncSpecifier != nil
            let isThrows = method.signature.effectSpecifiers?.throwsClause?.throwsSpecifier != nil
            let methodName = method.name.text
            
            if parameters.isEmpty {
                switchCasesCode += "case .\(caseName):\n"
                if isThrows && isAsync {
                    switchCasesCode += "    try? await \(methodName)()\n"
                } else if isThrows {
                    switchCasesCode += "    try? \(methodName)()\n"
                } else if isAsync {
                    switchCasesCode += "    await \(methodName)()\n"
                } else {
                    switchCasesCode += "    \(methodName)()\n"
                }
            } else {
                let parameterPatterns = parameters.map { param in
                    let label = param.firstName.text == "_" ? "" : param.firstName.text
                    return label.isEmpty ? "let value" : "let \(label)"
                }.joined(separator: ", ")
                
                let argumentList = parameters.map { param in
                    let label = param.firstName.text == "_" ? "" : param.firstName.text
                    let argName = label.isEmpty ? "value" : label
                    return label.isEmpty ? argName : "\(label): \(argName)"
                }.joined(separator: ", ")
                
                switchCasesCode += "case .\(caseName)(\(parameterPatterns)):\n"
                if isThrows && isAsync {
                    switchCasesCode += "    try? await \(methodName)(\(argumentList))\n"
                } else if isThrows {
                    switchCasesCode += "    try? \(methodName)(\(argumentList))\n"
                } else if isAsync {
                    switchCasesCode += "    await \(methodName)(\(argumentList))\n"
                } else {
                    switchCasesCode += "    \(methodName)(\(argumentList))\n"
                }
            }
        }
        
        let functionCode = """
        public func handleAction(_ action: Action) async {
            switch action {
            \(switchCasesCode)
            }
        }
        """
        
        return try FunctionDeclSyntax("\(raw: functionCode)")
    }
}

/// Error type for ActionsMacro
private enum ActionsMacroError: Error {
    case conflictingCaseNames
}

/// Diagnostic messages for ActionsMacro
private enum ActionsDiagnostic {
    case notActor
    case noMethods
    case conflictingCases(String)
}

extension ActionsDiagnostic: DiagnosticMessage {
    var message: String {
        switch self {
        case .notActor:
            return "@Actions can only be applied to actor types"
        case .noMethods:
            return "No public methods starting with 'on' found"
        case .conflictingCases(let caseName):
            return "Conflicting case name '\(caseName)' would be generated from multiple methods"
        }
    }
    
    var diagnosticID: MessageID {
        switch self {
        case .notActor:
            return MessageID(domain: "ActionsMacro", id: "notActor")
        case .noMethods:
            return MessageID(domain: "ActionsMacro", id: "noMethods")
        case .conflictingCases:
            return MessageID(domain: "ActionsMacro", id: "conflictingCases")
        }
    }
    
    var severity: DiagnosticSeverity {
        switch self {
        case .notActor, .conflictingCases:
            return .error
        case .noMethods:
            return .warning
        }
    }
}