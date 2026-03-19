import OversizeMacro
import OversizeMacroMacros
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// MARK: - Macro Expansion Tests

final class AutoRoutableMacroExpansionTests: XCTestCase {
    private let testMacros: [String: any Macro.Type] = [
        "AutoRoutable": AutoRoutableMacro.self,
    ]

    func testExpansion_basic() {
        assertMacroExpansion(
            """
            @AutoRoutable
            enum Screens {
                case main
                case settings
                case about
                case event(id: String)
            }
            """,
            expandedSource:
            """
            enum Screens {
                case main
                case settings
                case about
                case event(id: String)

                var id: String {
                    switch self {
                        case .main:
                            return "main"
                        case .settings:
                            return "settings"
                        case .about:
                            return "about"
                        case .event:
                            return "event"
                    }
                }
            }
            """,
            macros: testMacros
        )
    }

    func testExpansion_multipleElementsInOneLine() {
        assertMacroExpansion(
            """
            @AutoRoutable
            enum Screens {
                case main
                case settings, about
                case event(id: String)
            }
            """,
            expandedSource:
            """
            enum Screens {
                case main
                case settings, about
                case event(id: String)

                var id: String {
                    switch self {
                        case .main:
                            return "main"
                        case .settings:
                            return "settings"
                        case .about:
                            return "about"
                        case .event:
                            return "event"
                    }
                }
            }
            """,
            macros: testMacros
        )
    }
}

// MARK: - End-to-End Tests

final class AutoRoutableMacroEndToEndTests: XCTestCase {
    @AutoRoutable
    enum Screens {
        case main
        case settings, about
        case event(id: String)
    }

    func testRuntime_propertyValues() {
        XCTAssertEqual(Screens.main.id, "main")
        XCTAssertEqual(Screens.settings.id, "settings")
        XCTAssertEqual(Screens.about.id, "about")
        XCTAssertEqual(Screens.event(id: "0").id, "event")
    }
}
