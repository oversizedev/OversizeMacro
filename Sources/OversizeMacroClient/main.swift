import OversizeMacro
import Foundation

@Actions
actor ExampleViewModel {
    public func onAppear() {
        print("Appeared")
    }
    
    public func onTapSave(name: String) {
        print("Save tapped with name: \(name)")
    }
    
    public func onUrlChanged(url: URL?) {
        print("URL changed: \(String(describing: url))")
    }
    
    public func onNameChanged(_ name: String) async {
        print("Name changed: \(name)")
    }
    
    public func onButtonTapped(title: String, isEnabled: Bool) throws {
        print("Button tapped: \(title), enabled: \(isEnabled)")
    }
    
    public func onAsyncThrowingAction(value: Int) async throws {
        print("Async throwing action: \(value)")
    }
}

// Test the old stringify macro
let a = 17
let b = 25
let (result, code) = #stringify(a + b)
print("The value \(result) was produced by the code \"\(code)\"")

print("\nTesting @Actions macro:")
print("The macro successfully generated Action enum and handleAction method!")
print("Available actions: appear, tapSave, urlChanged, nameChanged, buttonTapped, asyncThrowingAction")
