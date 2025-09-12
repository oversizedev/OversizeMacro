//
// Copyright © 2025 Alexander Romanov
// ViewModelMacro.swift, created on 12.09.2025
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ViewModelMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        
        guard let declGroup = declaration.as(ClassDeclSyntax.self) as (any DeclGroupSyntax)? ??
            declaration.as(ActorDeclSyntax.self) as (any DeclGroupSyntax)? else {
            throw ViewModelMacroError.onlyApplicableToClassOrActor
        }
        
        let onMethods = extractOnMethods(from: declGroup)
        let actionCases = generateActionCases(from: onMethods)
        
        let actionEnum = EnumDeclSyntax(
            modifiers: DeclModifierListSyntax {
                DeclModifierSyntax(name: .keyword(.public))
            },
            name: "Action",
            inheritanceClause: InheritanceClauseSyntax {
                InheritedTypeSyntax(type: IdentifierTypeSyntax(name: "Sendable"))
            }
        ) {
            for actionCase in actionCases {
                MemberBlockItemSyntax(decl: actionCase)
            }
        }
        
        let extensionDecl = ExtensionDeclSyntax(
            extendedType: type,
            memberBlock: MemberBlockSyntax {
                MemberBlockItemSyntax(decl: actionEnum)
            }
        )
        
        return [extensionDecl]
    }
    
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        
        guard let declGroup = declaration.as(ClassDeclSyntax.self) as (any DeclGroupSyntax)? ??
            declaration.as(ActorDeclSyntax.self) as (any DeclGroupSyntax)? else {
            throw ViewModelMacroError.onlyApplicableToClassOrActor
        }
        
        let onMethods = extractOnMethods(from: declGroup)
        let handleActionMethod = generateHandleActionMethod(from: onMethods)
        
        return [DeclSyntax(handleActionMethod)]
    }
    
    private static func extractOnMethods(from declaration: some DeclGroupSyntax) -> [FunctionDeclSyntax] {
        return declaration.memberBlock.members.compactMap { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                  function.name.text.hasPrefix("on"),
                  !function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }) else {
                return nil
            }
            return function
        }
    }
    
    private static func generateActionCases(from methods: [FunctionDeclSyntax]) -> [EnumCaseDeclSyntax] {
        return methods.compactMap { method in
            let methodName = method.name.text
            let caseName = methodName
            
            let caseElement: EnumCaseElementSyntax
            
            if method.signature.parameterClause.parameters.isEmpty {
                caseElement = EnumCaseElementSyntax(name: TokenSyntax.identifier(caseName))
            } else {
                let parameters = method.signature.parameterClause.parameters
                
                var enumParameters: [EnumCaseParameterSyntax] = []
                
                for (index, param) in parameters.enumerated() {
                    let labelText = param.firstName.text
                    
                    let enumParam: EnumCaseParameterSyntax
                    if labelText == "_" {
                        enumParam = EnumCaseParameterSyntax(type: param.type)
                    } else {
                        enumParam = EnumCaseParameterSyntax(
                            firstName: TokenSyntax.identifier(labelText),
                            colon: .colonToken(),
                            type: param.type
                        )
                    }

                    if index < parameters.count - 1 {
                        enumParameters.append(enumParam.with(\.trailingComma, .commaToken()))
                    } else {
                        enumParameters.append(enumParam)
                    }
                }
                
                caseElement = EnumCaseElementSyntax(
                    name: TokenSyntax.identifier(caseName),
                    parameterClause: EnumCaseParameterClauseSyntax(
                        parameters: EnumCaseParameterListSyntax(enumParameters)
                    )
                )
            }
            
            return EnumCaseDeclSyntax(
                elements: EnumCaseElementListSyntax {
                    caseElement
                }
            )
        }
    }
    
    private static func generateHandleActionMethod(from methods: [FunctionDeclSyntax]) -> FunctionDeclSyntax {
        if methods.isEmpty {
            return try! FunctionDeclSyntax(
                """
                public func handleAction(_ action: Action) async {
                }
                """
            )
        }
        
        var caseStatements: [String] = []
        
        for method in methods {
            let methodName = method.name.text
            let caseName = methodName
            
            if method.signature.parameterClause.parameters.isEmpty {
                caseStatements.append("case .\(caseName):")
                caseStatements.append("    await \(methodName)()")
            } else {
                let parameters = method.signature.parameterClause.parameters
                
                var caseParams: [String] = []
                var callArgs: [String] = []
                
                for param in parameters {
                    let firstName = param.firstName.text
                    if firstName == "_" {
                        let paramName = param.secondName?.text ?? "value"
                        caseParams.append(paramName)
                        callArgs.append(paramName)
                    } else {
                        caseParams.append(firstName)
                        callArgs.append(firstName)
                    }
                }
                
                let casePattern = caseParams.joined(separator: ", ")
                let callPattern = callArgs.joined(separator: ", ")
                
                caseStatements.append("case .\(caseName)(\(casePattern)):")
                caseStatements.append("    await \(methodName)(\(callPattern))")
            }
        }
        
        let switchBody = caseStatements.joined(separator: "\n    ")
        
        return try! FunctionDeclSyntax(
            """
            public func handleAction(_ action: Action) async {
                switch action {
                \(raw: switchBody)
                }
            }
            """
        )
    }
}

enum ViewModelMacroError: Error, CustomStringConvertible {
    case onlyApplicableToClassOrActor
    
    var description: String {
        switch self {
        case .onlyApplicableToClassOrActor:
            return "@ViewModelMacro can only be applied to classes or actors"
        }
    }
}

extension String {
    func lowercasingFirst() -> String {
        guard !isEmpty else { return self }
        return prefix(1).lowercased() + dropFirst()
    }
}
