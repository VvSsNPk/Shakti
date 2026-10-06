# Wayland Protocol Formalization in Lean 4

This project formalizes the core Wayland protocol specification in Lean 4, providing a type-safe representation of the Wayland client-server protocol.

## Project Structure

### Core Modules

#### `ShaktiLean/Basic.lean`
Defines the fundamental types for the Wayland protocol:

- **`ArgType`**: Enum representing Wayland argument types
  - `int`, `uint`, `fixed`, `string`
  - `object`, `newId`, `fd`, `array`

- **`EnumEntry`**: Represents a single enum value
  - Fields: name, value (Nat), summary

- **`Enum`**: Represents an enum definition in an interface
  - Fields: name, description, entries (list)

- **`Arg`**: Represents an argument in a request/event
  - Fields: name, argType, interfaceName (optional), summary

- **`Message`**: Represents a request or event
  - Fields: name, description, destructor flag, args list

- **`Interface`**: Represents a Wayland interface
  - Fields: name, version, description, requests, events, enums

- **`WlObject`**: Runtime instance of a Wayland object
  - Fields: interfaceName, id (Nat)

#### `ShaktiLean/Protocol.lean`
Defines all 16 core Wayland interfaces with complete specifications:

**Core Interfaces:**
- `wl_display` - Core global object (v1)
- `wl_registry` - Global registry (v1)
- `wl_callback` - Callback object (v1)
- `wl_compositor` - Compositor singleton (v7)

**Surface & Graphics:**
- `wl_surface` - Onscreen surface (v7)
- `wl_buffer` - Buffer content (v1)
- `wl_region` - Rectangular region (v7)

**Input Devices:**
- `wl_seat` - Group of input devices (v11)
- `wl_pointer` - Pointer input (v11)
- `wl_keyboard` - Keyboard input (v11)
- `wl_touch` - Touch input (v11)

**Output:**
- `wl_output` - Display output (v4)

**Memory Management:**
- `wl_shm` - Shared memory pool (v3)
- `wl_shm_pool` - Memory pool (v3)

**Desktop Shell:**
- `wl_shell` - Shell interface (v1)
- `wl_shell_surface` - Desktop shell surface (v1)

#### `ShaktiLean/Utils.lean`
Utility functions for working with the protocol:

- **`findInterface(name, interfaces)`** - Find interface by name
- **`findRequest(name, iface)`** - Find request in interface
- **`findEvent(name, iface)`** - Find event in interface
- **`messageNames(iface)`** - Get all message names
- **`interfaceVersion(name)`** - Get interface version
- **`argTypeValid(arg)`** - Validate argument type
- **`messageValid(msg)`** - Validate message
- **`interfaceValid(iface)`** - Validate interface
- **`protocolValid`** - Validate entire protocol

## Usage Examples

### Access an Interface

```lean
open WaylandProtocol

-- Get wl_display interface
#eval wlDisplay.name        -- "wl_display"
#eval wlDisplay.version     -- 1

-- Get requests
#eval wlDisplay.requests.map (fun m => m.name)
-- ["sync", "get_registry"]

-- Get events
#eval wlDisplay.events.map (fun m => m.name)
-- ["error", "delete_id"]
```

### Find Interface Dynamically

```lean
match findInterface "wl_surface" allInterfaces with
| none => IO.println "Not found"
| some surface =>
  IO.println s!"Found: {surface.name} v{surface.version}"
```

### Validate Protocol

```lean
-- Check if protocol is valid
#eval protocolValid  -- true

-- Check specific interface
#eval interfaceValid wlDisplay  -- true

-- Validate all messages in an interface
#eval wlSurface.requests.all messageValid  -- true
```

### Protocol Statistics

```lean
#eval allInterfaces.length          -- 16
#eval totalRequests                 -- 39
#eval totalEvents                   -- 32
```

## Key Features

### Type Safety
- All interfaces, requests, events, and arguments are fully typed
- Invalid interface references are caught by validation functions
- Enum values are strongly typed

### Completeness
- All 16 core Wayland interfaces defined
- 39 total requests formalized
- 32 total events formalized
- 71 enum values documented

### Extensibility
- Easy to add new interfaces
- Helper functions (mkInterface, mkMessage, mkEnum, etc.) for concise definitions
- Modular structure allows importing subsets

### Validation
- Protocol can be validated for correctness
- Argument type references verified against known interfaces
- Enum consistency checked

## Protocol Statistics

| Metric | Count |
|--------|-------|
| Interfaces | 16 |
| Requests | 39 |
| Events | 32 |
| Total Messages | 71 |
| Enums | 15+ |
| Enum Values | 70+ |

## Formalized Interfaces

### Display & Registry (2)
- wl_display, wl_registry

### Graphics (4)
- wl_compositor, wl_surface, wl_buffer, wl_region

### Input (4)
- wl_seat, wl_pointer, wl_keyboard, wl_touch

### Output (1)
- wl_output

### Memory (2)
- wl_shm, wl_shm_pool

### Shell (3)
- wl_shell, wl_shell_surface, wl_callback

## Building

```bash
cd /home/royaleinstein/Documents/Wayland/skakti_lean
lake build
```

## Running Examples

```bash
lake env .lake/build/bin/skakti_lean
```

This displays:
- wl_display interface details
- All available interfaces
- Protocol statistics
- Example interface lookup

## Future Extensions

The formalization can be extended to:
1. Add remaining Wayland protocol interfaces (data transfer, XDG shell, etc.)
2. Formalize protocol semantics and invariants
3. Create a code generator for bindings
4. Define proof obligations for protocol compliance
5. Add specification of message serialization
6. Formalize state machines for interface lifecycle

## References

- Wayland Protocol: https://wayland.freedesktop.org/
- Protocol XML: `../wayland/protocol/wayland.xml`
