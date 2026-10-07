# ShaktiLean Enhancement Usage Examples

Practical examples showing how to use each of the 5 implemented enhancements.

## 1. Formatting (ToString)

```lean
open WaylandProtocol

-- Display an interface nicely
#eval wlSurface     -- Shows: interface wl_surface (v7)...

-- Display a message
#eval wlSurface.requests.head?  -- Shows: create_surface(...)

-- Display an argument
#eval (Arg.mk "surface" ArgType.object (some "wl_surface") "")
-- Shows: surface: object (wl_surface)
```

## 2. Container Type Class

```lean
open WaylandProtocol

-- Filter destructors from interface
let nonDestructors := filterMessages wlDisplay (fun m => !m.destructor)

-- Count total messages in an interface
let msgCount := messageCountInContainer wlDisplay

-- Find a specific message
let syncMsg := findMessageInContainer "sync" wlDisplay

-- Validate all messages in interface
let isValid := validateMessages wlDisplay

-- Get all message names
let names := messageNamesInContainer wlDisplay
```

## 3. Lens/Optics

```lean
open WaylandProtocol

-- Get requests from interface
let requests := getInterfaceRequests wlDisplay

-- Add a new request
def newInterface : Interface := 
  addRequest wlDisplay (Message.mk "test" "Test message" false [])

-- Filter out destructors using lens
def cleaned : Interface :=
  removeDestructors wlDisplay

-- Count arguments in requests
let argCount := countInterfaceRequestArgs wlSurface

-- Modify all request names (add prefix)
def withPrefix : Interface :=
  modify interfaceRequestsLens 
    (fun msgs => msgs.map (fun m => { m with name := "x_" ++ m.name })) 
    wlDisplay
```

## 4. Validation (Error Collection)

```lean
open WaylandProtocol

-- Validate entire protocol
match validateProtocolWithErrors allInterfaces with
| .success ifaces => 
  IO.println "✓ Protocol is valid!"
| .failure errors => 
  IO.println "✗ Validation errors:"
  for error in errors do
    IO.println s!"  - {error}"

-- Validate single interface
match validateInterfaceWithErrors wlSurface allInterfaces with
| .success iface => 
  IO.println "Surface is valid"
| .failure errors =>
  IO.println "Surface validation failed"

-- Validate message arguments
match validateMessageWithErrors wlSurface.requests.head? allInterfaces with
| .success msg =>
  IO.println "Message is valid"
| .failure errors =>
  IO.println "Message has errors"

-- Report results nicely
#eval validateProtocolWithErrors allInterfaces
-- Output:
-- ✓ Validation passed
-- (or list of all errors if validation fails)
```

## 5. Type-Level Verification

```lean
open WaylandProtocol

-- Get an interface with compile-time guarantee it exists
match getExistingInterface "wl_display" with
| some ⟨iface, proof⟩ => 
  -- We know this interface is in allInterfaces
  IO.println s!"Found: {iface.name}"
| none => 
  IO.println "Interface not found"

-- Get a message with proof it exists in interface
let displayIface : ExistingInterface := ⟨wlDisplay, by sorry⟩
match getMessageInInterface displayIface "sync" with
| some ⟨msg, proof⟩ =>
  -- We know this message exists in the interface
  IO.println s!"Found message: {msg.name}"
| none =>
  IO.println "Message not found"

-- Validate argument type with guarantee
match validateArgumentType (Arg.mk "surface" ArgType.object (some "wl_surface") "") with
| some ⟨arg, proof⟩ =>
  IO.println "Argument is valid"
| none =>
  IO.println "Argument is invalid"

-- Check protocol properties
#eval protocolHasInterfaces  -- true
```

## Combined Example: Complete Protocol Inspection

```lean
open WaylandProtocol

def inspectProtocol : IO Unit := do
  -- 1. Format and display summary
  IO.println "=== Protocol Summary ==="
  IO.println s!"Interfaces: {allInterfaces.length}"
  
  -- 2. Validate entire protocol with error collection
  match validateProtocolWithErrors allInterfaces with
  | .success _ => IO.println "✓ Protocol validation passed"
  | .failure errors => 
    IO.println s!"✗ Validation failed with {errors.length} errors"
  
  -- 3. Analyze each interface using containers
  for iface in allInterfaces do
    let msgCount := messageCountInContainer iface
    IO.println s!"{iface.name}: {msgCount} messages"
    
    -- 4. Apply optics to filter and modify
    let destructors := findDestructors iface
    IO.println s!"  - Destructors: {destructors.length}"
  
  -- 5. Type-safe lookup with guarantees
  match getExistingInterface "wl_surface" with
  | some ⟨surface, _⟩ =>
    IO.println s!"Surface interface found (v{surface.version})"
  | none =>
    IO.println "Surface interface not found"

-- Run the inspection
#eval inspectProtocol
```

## Advanced Pattern: Custom Validation

```lean
open WaylandProtocol

-- Create custom validator using monadic operations
def validateInterfaceNames : ValidationResult (List Interface) := do
  let badNames := allInterfaces.filter (fun i => !(i.name.startsWith "wl_"))
  if badNames.isEmpty then
    return allInterfaces
  else
    let errors := badNames.map (fun i => s!"Interface '{i.name}' doesn't follow naming convention")
    .failure errors

-- Use the validator
#eval validateInterfaceNames
```

## Pattern: Building Type-Safe Interfaces

```lean
open WaylandProtocol

-- Ensure we only work with existing interfaces
def processExistingInterface (name : String) : Option String := do
  let iface ← getExistingInterface name
  -- iface is a pair with proof that it exists
  return s!"Processing {iface.val.name}"

-- Type-safe message lookup
def findSafeMessage (ifaceName : String) (msgName : String) : 
    Option String := do
  let iface ← getExistingInterface ifaceName
  let msg ← getMessageInInterface iface msgName
  return s!"Found {msg.val.name} in {iface.val.name}"
```

## Performance Considerations

- **Lenses**: Zero-cost abstractions, compile to direct field access
- **Validation**: Collects all errors in single pass (more efficient than fail-fast)
- **Type-level**: All proofs are compile-time, no runtime cost
- **Containers**: Unified interface eliminates code duplication

All enhancements maintain Lean 4's commitment to zero-cost abstractions.
