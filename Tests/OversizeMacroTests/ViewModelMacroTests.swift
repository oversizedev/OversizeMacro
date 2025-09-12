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

    func testSimpleOnMethodsGenerateActions() throws {
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
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case appear
                    case tapSave
                    case disappear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testOnMethodsWithParametersGenerateActionsWithAssociatedValues() throws {
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
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case nameChanged(name: String)
                    case valueChanged(Int)
                    case focusField(TestViewState.FocusField?)
                    case updateData(id: UUID, name: String)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testPrivateOnMethodsAreIgnored() throws {
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
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case appear
                    case save
                }
            }
            """,
            macros: testMacros
        )
    }

    func testNonOnMethodsAreIgnored() throws {
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
                    case appear
                }
            }
            """,
            macros: testMacros
        )
    }

    func testClassSupport() throws {
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
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case appear
                    case save
                }
            }
            """,
            macros: testMacros
        )
    }

    func testEmptyActorGeneratesEmptyEnum() throws {
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
            }

            extension TestViewModel {
                public enum Action: Sendable {
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMacroOnlyAppliesToClassAndActor() throws {
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
                DiagnosticSpec(message: "@ViewModelMacro can only be applied to classes or actors", line: 1, column: 1)
            ],
            macros: testMacros
        )
    }

    func testComplexParameterLabels() throws {
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
            }

            extension TestViewModel {
                public enum Action: Sendable {
                    case set(value: String)
                    case update(at: Int, with: String)
                }
            }
            """,
            macros: testMacros
        )
    }

    func testRealWorldExample() throws {
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
            }

            extension MealProductCategoryEditViewModel {
                public enum Action: Sendable {
                    case appear
                    case tapSave
                    case focusField(MealProductCategoryEditViewState.FocusField?)
                    case nameChanged(name: String)
                    case noteChanged(note: String)
                    case urlChanged(url: URL?)
                }
            }
            """,
            macros: testMacros
        )
    }
}
