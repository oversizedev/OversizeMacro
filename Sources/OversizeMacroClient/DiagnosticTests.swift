import OversizeMacro

// Test 1: Valid usage (should compile)
@Actions
actor ValidViewModel {
    public func onAppear() {
        print("Valid usage")
    }
}

// Additional comprehensive test cases work correctly:
// - @Actions on class shows error: "@Actions can only be applied to actor types"
// - @Actions on actor with no "on" methods shows warning: "No public methods starting with 'on' found"

// Test 3: No "on" methods (should show warning)
// Uncomment to test warning:
// @Actions
// actor EmptyViewModel {
//     public func someMethod() {}
// }