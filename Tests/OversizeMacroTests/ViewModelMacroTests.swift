//
// Copyright © 2025 Alexander Romanov
// ViewModelMacroTests.swift, created on 12.09.2025
//

import OversizeMacro
import OversizeMacroMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class ViewModelMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "ViewModelMacro": ViewModelMacro.self,
    ]

    func testSimpleOnMethodsGenerateActions() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onTapSave() async {}
                func onDisappear() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onTapSave() async {}
                func onDisappear() async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    case .onTapSave:
                        await onTapSave()
                    case .onDisappear:
                        await onDisappear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                    case onTapSave
                    case onDisappear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testOnMethodsWithParametersGenerateActionsWithAssociatedValues() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onNameChanged(name: String) async {}
                func onValueChanged(_ value: Int) async {}
                func onFocusField(_ field: TestViewState.FocusField?) async {}
                func onUpdateData(id: UUID, name: String) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onNameChanged(name: String) async {}
                func onValueChanged(_ value: Int) async {}
                func onFocusField(_ field: TestViewState.FocusField?) async {}
                func onUpdateData(id: UUID, name: String) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onNameChanged(name):
                        await onNameChanged(name: name)
                    case .onValueChanged(value):
                        await onValueChanged(value)
                    case .onFocusField(field):
                        await onFocusField(field)
                    case .onUpdateData(id, name):
                        await onUpdateData(id: id, name: name)
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onNameChanged(name: String)
                    case onValueChanged(Int)
                    case onFocusField(TestViewState.FocusField?)
                    case onUpdateData(id: UUID, name: String)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testPrivateOnMethodsAreIgnored() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                private func onPrivateMethod() async {}
                func onSave() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                private func onPrivateMethod() async {}
                func onSave() async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    case .onSave:
                        await onSave()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                    case onSave
                }
            }
            """,
            macros: testMacros
        )
    }

    func testNonOnMethodsAreIgnored() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ action: Action) async {}
                func save() async {}
                func load() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ action: Action) async {}
                func save() async {}
                func load() async {}
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testClassSupport() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public class TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}
            }
            """,
            expandedSource: """
            public class TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    case .onSave:
                        await onSave()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                    case onSave
                }
            }
            """,
            macros: testMacros
        )
    }

    func testEmptyActorGeneratesEmptyEnum() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func save() async {}
                func load() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func save() async {}
                func load() async {}

                public func handleAction(_ action: Action) async {
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMacroOnlyAppliesToClassAndActor() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public struct TestStruct {
                func onAppear() async {}
            }
            """,
            expandedSource: """
            public struct TestStruct {
                func onAppear() async {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "@ViewModelMacro can only be applied to classes or actors", line: 1, column: 1, severity: .error),
                DiagnosticSpec(message: "@ViewModelMacro can only be applied to classes or actors", line: 1, column: 1, severity: .error)
            ],
            macros: testMacros
        )
    }

    func testComplexParameterLabels() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onSet(value newValue: String) async {}
                func onUpdate(at index: Int, with value: String) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onSet(value newValue: String) async {}
                func onUpdate(at index: Int, with value: String) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onSet(newValue):
                        await onSet(value: newValue)
                    case .onUpdate(index, value):
                        await onUpdate(at: index, with: value)
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onSet(value: String)
                    case onUpdate(at: Int, with: String)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testRealWorldExample() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor MealProductCategoryEditViewModel: ViewModelProtocol {
                public var state: MealProductCategoryEditViewState

                public init(state: MealProductCategoryEditViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onTapSave() async {}
                func onFocusField(_ field: MealProductCategoryEditViewState.FocusField?) async {}
                func onNameChanged(name: String) async {}
                func onNoteChanged(note: String) async {}
                func onUrlChanged(url: URL?) async {}
                private func updateFormValidation() async {}
            }
            """,
            expandedSource: """
            public actor MealProductCategoryEditViewModel: ViewModelProtocol {
                public var state: MealProductCategoryEditViewState

                public init(state: MealProductCategoryEditViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onTapSave() async {}
                func onFocusField(_ field: MealProductCategoryEditViewState.FocusField?) async {}
                func onNameChanged(name: String) async {}
                func onNoteChanged(note: String) async {}
                func onUrlChanged(url: URL?) async {}
                private func updateFormValidation() async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    case .onTapSave:
                        await onTapSave()
                    case .onFocusField(field):
                        await onFocusField(field)
                    case .onNameChanged(name):
                        await onNameChanged(name: name)
                    case .onNoteChanged(note):
                        await onNoteChanged(note: note)
                    case .onUrlChanged(url):
                        await onUrlChanged(url: url)
                    }
                }
            }

            extension MealProductCategoryEditViewModel {
                public enum Action: Sendable {
                    case onAppear
                    case onTapSave
                    case onFocusField(MealProductCategoryEditViewState.FocusField?)
                    case onNameChanged(name: String)
                    case onNoteChanged(note: String)
                    case onUrlChanged(url: URL?)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHandleActionMethodGeneration() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave(name: String) async {}
                func onDelete(_ id: UUID) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave(name: String) async {}
                func onDelete(_ id: UUID) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    case .onSave(name):
                        await onSave(name: name)
                    case .onDelete(id):
                        await onDelete(id)
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                    case onSave(name: String)
                    case onDelete(UUID)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testEmptyViewModelHandleAction() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor EmptyViewModel: ViewModelProtocol {
                public var state: EmptyViewState

                public init(state: EmptyViewState) {
                    self.state = state
                }
            }
            """,
            expandedSource: """
            public actor EmptyViewModel: ViewModelProtocol {
                public var state: EmptyViewState

                public init(state: EmptyViewState) {
                    self.state = state
                }

                public func handleAction(_ action: Action) async {
                }
            }

            extension EmptyViewModel {
                public enum Action: Sendable {
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInternalClassHasNoPublicModifier() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            class TestViewModel: ViewModelProtocol {
                var state: TestViewState

                init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}
            }
            """,
            expandedSource: """
            class TestViewModel: ViewModelProtocol {
                var state: TestViewState

                init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}

                func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    case .onSave:
                        await onSave()
                    }
                }
            }

            extension TestViewModel {
                enum Action: Sendable {
                    case onAppear
                    case onSave
                }
            }
            """,
            macros: testMacros
        )
    }

    func testOpenClassGeneratesOpenHandleAction() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            open class TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
            }
            """,
            expandedSource: """
            open class TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}

                open func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testUnrelatedHandleActionOverloadDoesNotSuppressGeneration() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction() async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testExistingActionEnumSkipsExtensionAndHandleAction() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                enum Action: Sendable {
                    case custom
                }

                func onAppear() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                enum Action: Sendable {
                    case custom
                }

                func onAppear() async {}
            }
            """,
            macros: testMacros
        )
    }

    func testStaticOnMethodsAreExcluded() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                static func onLoad() async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                static func onLoad() async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testOverloadedOnMethodsEmitDiagnostics() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}
                func onSave(id: UUID) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}
                func onSave(id: UUID) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ViewModel: overloaded 'on...' method 'onSave' cannot be synthesized; rename to disambiguate",
                    line: 10,
                    column: 5,
                    severity: .error
                ),
                DiagnosticSpec(
                    message: "@ViewModel: overloaded 'on...' method 'onSave' cannot be synthesized; rename to disambiguate",
                    line: 11,
                    column: 5,
                    severity: .error
                ),
            ],
            macros: testMacros
        )
    }

    func testExistingHandleActionIsNotDuplicated() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ action: Action) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ action: Action) async {}
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testHandleActionWrongTypeDoesNotSuppressGeneration() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ value: Int) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ value: Int) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testStaticHandleActionDoesNotSuppressSynthesis() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                static func handleAction(_ action: Action) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                static func handleAction(_ action: Action) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSyncHandleActionDoesNotSuppressSynthesis() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ action: Action) {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func handleAction(_ action: Action) {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onAppear:
                        await onAppear()
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testEscapingClosureParamBecomesAtSendableInEnumCase() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onComplete(_ done: @escaping () -> Void) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onComplete(_ done: @escaping () -> Void) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onComplete(done):
                        await onComplete(done)
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onComplete(@Sendable () -> Void)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testInoutParamMethodExcludedFromSynthesis() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onUpdate(_ value: inout Int) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onUpdate(_ value: inout Int) async {}

                public func handleAction(_ action: Action) async {
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                }
            }
            """,
            macros: testMacros
        )
    }

    func testAutoclosureParamMethodExcludedFromSynthesis() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onFlag(_ condition: @autoclosure () -> Bool) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onFlag(_ condition: @autoclosure () -> Bool) async {}

                public func handleAction(_ action: Action) async {
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMainActorEscapingClosurePreservesMainActorInEnumCase() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onComplete(_ done: @MainActor @escaping () -> Void) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onComplete(_ done: @MainActor @escaping () -> Void) async {}

                public func handleAction(_ action: Action) async {
                    switch action {
                    case .onComplete(done):
                        await onComplete(done)
                    }
                }
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onComplete(@MainActor @Sendable () -> Void)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testOverloadDiagnosticsFireEvenWhenHandleActionExists() {
        assertMacroExpansion(
            """
            @ViewModelMacro
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}
                func onSave(id: UUID) async {}
                func handleAction(_ action: Action) async {}
            }
            """,
            expandedSource: """
            public actor TestViewModel: ViewModelProtocol {
                public var state: TestViewState

                public init(state: TestViewState) {
                    self.state = state
                }

                func onAppear() async {}
                func onSave() async {}
                func onSave(id: UUID) async {}
                func handleAction(_ action: Action) async {}
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case onAppear
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ViewModel: overloaded 'on...' method 'onSave' cannot be synthesized; rename to disambiguate",
                    line: 10,
                    column: 5,
                    severity: .error
                ),
                DiagnosticSpec(
                    message: "@ViewModel: overloaded 'on...' method 'onSave' cannot be synthesized; rename to disambiguate",
                    line: 11,
                    column: 5,
                    severity: .error
                ),
            ],
            macros: testMacros
        )
    }
}
