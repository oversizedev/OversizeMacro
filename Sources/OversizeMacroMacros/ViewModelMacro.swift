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
        let effectiveRank = effectiveAccessRank(typeRank: accessRank(ofDecl: declGroup), methods: onMethods)

        let actionEnum = EnumDeclSyntax(
            modifiers: enumModifiers(forRank: effectiveRank),
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
                  fn.name.text == "handleAction",
                  !fn.modifiers.contains(where: {
                      $0.name.tokenKind == .keyword(.static) ||
                      $0.name.tokenKind == .keyword(.class)
                  }),
                  fn.signature.effectSpecifiers?.asyncSpecifier != nil
            else { return false }
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
        let effectiveRank = effectiveAccessRank(typeRank: accessRank(ofDecl: declGroup), methods: onMethods)
        let access = accessKeyword(forRank: effectiveRank)
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
                  }),
                  !function.signature.parameterClause.parameters.contains(where: hasSpecifierParam(_:))
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
                        EnumCaseParameterSyntax(type: sanitizedEnumCaseType(param.type))
                    } else {
                        EnumCaseParameterSyntax(
                            firstName: TokenSyntax.identifier(labelText),
                            colon: .colonToken(),
                            type: sanitizedEnumCaseType(param.type)
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

    private static func hasSpecifierParam(_ param: FunctionParameterSyntax) -> Bool {
        guard let attributed = param.type.as(AttributedTypeSyntax.self) else { return false }
        if !attributed.specifiers.isEmpty { return true }
        return attributed.attributes.contains {
            guard case let .attribute(attr) = $0,
                  let ident = attr.attributeName.as(IdentifierTypeSyntax.self)
            else { return false }
            return ident.name.text == "autoclosure"
        }
    }

    private static func sanitizedEnumCaseType(_ type: TypeSyntax) -> TypeSyntax {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return TypeSyntax(optional.with(\.wrappedType, sanitizedEnumCaseType(optional.wrappedType)))
        }
        if let iuo = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return TypeSyntax(iuo.with(\.wrappedType, sanitizedEnumCaseType(iuo.wrappedType)))
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            return TypeSyntax(array.with(\.element, sanitizedEnumCaseType(array.element)))
        }
        if let dict = type.as(DictionaryTypeSyntax.self) {
            return TypeSyntax(dict
                .with(\.key, sanitizedEnumCaseType(dict.key))
                .with(\.value, sanitizedEnumCaseType(dict.value)))
        }
        if let tuple = type.as(TupleTypeSyntax.self) {
            let newElements = tuple.elements.map { el in
                el.with(\.type, sanitizedEnumCaseType(el.type))
            }
            return TypeSyntax(tuple.with(\.elements, TupleTypeElementListSyntax(newElements)))
        }
        if type.is(FunctionTypeSyntax.self) {
            return TypeSyntax("@Sendable \(raw: type.trimmedDescription)")
        }
        guard let attributed = type.as(AttributedTypeSyntax.self) else { return type }
        let keptAttributes: AttributeListSyntax = attributed.attributes.filter {
            guard case let .attribute(attr) = $0,
                  let ident = attr.attributeName.as(IdentifierTypeSyntax.self)
            else { return true }
            return ident.name.text != "escaping"
        }
        let hadEscaping = keptAttributes.count < attributed.attributes.count
        let hasSendable = keptAttributes.contains {
            guard case let .attribute(attr) = $0,
                  let ident = attr.attributeName.as(IdentifierTypeSyntax.self)
            else { return false }
            return ident.name.text == "Sendable"
        }
        if hadEscaping && !hasSendable && attributed.baseType.is(FunctionTypeSyntax.self) {
            let otherAttrs = keptAttributes.map(\.trimmedDescription).joined(separator: " ")
            let prefix = otherAttrs.isEmpty ? "@Sendable " : "\(otherAttrs) @Sendable "
            let base = attributed.baseType.trimmedDescription
            return TypeSyntax("\(raw: prefix)\(raw: base)")
        }
        let cleaned = attributed
            .with(\.specifiers, TypeSpecifierListSyntax([]))
            .with(\.attributes, keptAttributes)
        if cleaned.specifiers.isEmpty, cleaned.attributes.isEmpty {
            return TypeSyntax(attributed.baseType.trimmed)
        }
        return TypeSyntax(cleaned.trimmed)
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
                        let rawSecond = param.secondName?.text
                        let varName = (rawSecond == nil || rawSecond == "_") ? firstName : rawSecond!
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

    // MARK: - Access Level Helpers

    private static func accessRank(ofDecl decl: some DeclGroupSyntax) -> Int {
        for mod in decl.modifiers {
            if case let .keyword(kw) = mod.name.tokenKind {
                if let rank = keywordRank[kw] { return rank }
            }
        }
        return 2
    }

    private static func accessRank(ofMethod fn: FunctionDeclSyntax) -> Int {
        for mod in fn.modifiers {
            if case let .keyword(kw) = mod.name.tokenKind {
                if let rank = keywordRank[kw] { return rank }
            }
        }
        return 2
    }

    private static let keywordRank: [Keyword: Int] = [
        .private: 0, .fileprivate: 1, .internal: 2,
        .package: 3, .public: 4, .open: 5,
    ]

    private static func effectiveAccessRank(typeRank: Int, methods: [FunctionDeclSyntax]) -> Int {
        guard !methods.isEmpty else { return typeRank }
        let minMethodRank = methods.map { accessRank(ofMethod: $0) }.min() ?? typeRank
        return min(typeRank, minMethodRank)
    }

    private static func accessKeyword(forRank rank: Int) -> String {
        switch rank {
        case 0: "private"
        case 1: "fileprivate"
        case 3: "package"
        case 4: "public"
        case 5: "open"
        default: ""
        }
    }

    private static func enumModifiers(forRank rank: Int) -> DeclModifierListSyntax {
        let cappedRank = min(rank, 4)
        guard cappedRank != 2 else { return DeclModifierListSyntax() }
        let token: TokenSyntax = switch cappedRank {
        case 0: .keyword(.private)
        case 1: .keyword(.fileprivate)
        case 3: .keyword(.package)
        case 4: .keyword(.public)
        default: .keyword(.internal)
        }
        return DeclModifierListSyntax {
            DeclModifierSyntax(name: token.with(\.trailingTrivia, .space))
        }
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
