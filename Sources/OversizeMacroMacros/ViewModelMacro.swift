//
// Copyright © 2025 Alexander Romanov
// ViewModelMacro.swift, created on 12.09.2025
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ViewModelMacro: ExtensionMacro {
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
            let caseName = String(methodName.dropFirst(2)).lowercasingFirst()
            
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
