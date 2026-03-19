//
// Copyright © 2025 Alexander Romanov
// ViewModelMacro.swift, created on 12.09.2025
//

import SwiftCompilerPlugin
import SwiftDiagnostics
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
            declaration.as(ActorDeclSyntax.self) as (any DeclGroupSyntax)?
        else {
            throw ViewModelMacroError.onlyApplicableToClassOrActor
        }

        let actionExists = declGroup.memberBlock.members.contains {
            $0.decl.as(EnumDeclSyntax.self)?.name.text == "Action"
        }
        guard !actionExists else { return [] }

        let onMethods = filteredOnMethods(from: extractOnMethods(from: declGroup))
        let actionCases = generateActionCases(from: onMethods)

        let actionEnum = EnumDeclSyntax(
            modifiers: enumModifiers(from: declGroup),
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
            declaration.as(ActorDeclSyntax.self) as (any DeclGroupSyntax)?
        else {
            throw ViewModelMacroError.onlyApplicableToClassOrActor
        }

        let actionEnumExists = declGroup.memberBlock.members.contains {
            $0.decl.as(EnumDeclSyntax.self)?.name.text == "Action"
        }
        guard !actionEnumExists else { return [] }

        let access = accessModifier(from: declGroup)
        let rawMethods = extractOnMethods(from: declGroup)
        let nameCounts = Dictionary(grouping: rawMethods, by: \.name.text)
        for (_, methods) in nameCounts where methods.count > 1 {
            for method in methods {
                context.diagnose(Diagnostic(node: method, message: ViewModelMacroDiagnostic.overloadedOnMethod(method.name.text)))
            }
        }

        let typeName = (declGroup as? ClassDeclSyntax)?.name.text
            ?? (declGroup as? ActorDeclSyntax)?.name.text
            ?? ""
        let alreadyExists = declGroup.memberBlock.members.contains {
            guard let fn = $0.decl.as(FunctionDeclSyntax.self),
                  fn.name.text == "handleAction" else { return false }
            let params = fn.signature.parameterClause.parameters
            guard params.count == 1, params.first?.firstName.text == "_" else { return false }
            let typeDesc = params.first?.type.trimmedDescription ?? ""
            return typeDesc == "Action"
                || typeDesc == "Self.Action"
                || typeDesc == "\(typeName).Action"
                || (typeDesc.hasPrefix("\(typeName)<") && typeDesc.hasSuffix(".Action"))
        }
        guard !alreadyExists else { return [] }

        let onMethods = filteredOnMethods(from: rawMethods)
        let handleActionMethod = generateHandleActionMethod(from: onMethods, access: access)

        return [DeclSyntax(handleActionMethod)]
    }

    private static func extractOnMethods(from declaration: some DeclGroupSyntax) -> [FunctionDeclSyntax] {
        declaration.memberBlock.members.compactMap { member in
            guard let function = member.decl.as(FunctionDeclSyntax.self),
                  function.name.text.hasPrefix("on"),
                  !function.modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }),
                  !function.modifiers.contains(where: {
                      $0.name.tokenKind == .keyword(.static) ||
                          $0.name.tokenKind == .keyword(.class)
                  })
            else {
                return nil
            }
            return function
        }
    }

    private static func filteredOnMethods(from methods: [FunctionDeclSyntax]) -> [FunctionDeclSyntax] {
        let nameCounts = Dictionary(grouping: methods, by: \.name.text)
        return methods.filter { nameCounts[$0.name.text]!.count == 1 }
    }

    private static func generateActionCases(from methods: [FunctionDeclSyntax]) -> [EnumCaseDeclSyntax] {
        methods.compactMap { method in
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

                    let enumParam = if labelText == "_" {
                        EnumCaseParameterSyntax(type: param.type)
                    } else {
                        EnumCaseParameterSyntax(
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

    private static func generateHandleActionMethod(from methods: [FunctionDeclSyntax], access: String) -> FunctionDeclSyntax {
        let accessPrefix = access.isEmpty ? "" : "\(access) "
        if methods.isEmpty {
            return try! FunctionDeclSyntax(
                """
                \(raw: accessPrefix)func handleAction(_ action: Action) async {
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
                        let varName = param.secondName?.text ?? "value"
                        caseParams.append(varName)
                        callArgs.append(varName)
                    } else {
                        let varName = param.secondName?.text ?? firstName
                        caseParams.append(varName)
                        callArgs.append("\(firstName): \(varName)")
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
            \(raw: accessPrefix)func handleAction(_ action: Action) async {
                switch action {
                \(raw: switchBody)
                }
            }
            """
        )
    }

    private static func accessModifier(from decl: some DeclGroupSyntax) -> String {
        let accessKeywords: Set<Keyword> = [.public, .open, .internal, .fileprivate, .private]
        for mod in decl.modifiers {
            if case let .keyword(kw) = mod.name.tokenKind, accessKeywords.contains(kw) {
                // open is valid for class members but map to public for clarity
                return kw == .open ? "public" : mod.name.text
            }
        }
        return ""
    }

    private static func enumModifiers(from decl: some DeclGroupSyntax) -> DeclModifierListSyntax {
        let accessKeywords: Set<Keyword> = [.public, .open, .internal, .fileprivate, .private]
        for mod in decl.modifiers {
            if case let .keyword(kw) = mod.name.tokenKind, accessKeywords.contains(kw) {
                // open is not valid on enums — cap at public
                let name: TokenSyntax = kw == .open ? .keyword(.public) : mod.name
                return DeclModifierListSyntax {
                    DeclModifierSyntax(name: name.with(\.trailingTrivia, .space))
                }
            }
        }
        return DeclModifierListSyntax()
    }
}

struct ViewModelMacroDiagnostic: DiagnosticMessage {
    let message: String
    let diagnosticID: MessageID
    let severity: DiagnosticSeverity

    static func overloadedOnMethod(_ name: String) -> Self {
        .init(
            message: "@ViewModel: overloaded 'on...' method '\(name)' cannot be synthesized; rename to disambiguate",
            diagnosticID: MessageID(domain: "ViewModelMacro", id: "overloadedOnMethod"),
            severity: .error
        )
    }
}

enum ViewModelMacroError: Error, CustomStringConvertible {
    case onlyApplicableToClassOrActor

    var description: String {
        switch self {
        case .onlyApplicableToClassOrActor:
            "@ViewModelMacro can only be applied to classes or actors"
        }
    }
}

extension String {
    func lowercasingFirst() -> String {
        guard !isEmpty else { return self }
        return prefix(1).lowercased() + dropFirst()
    }
}
