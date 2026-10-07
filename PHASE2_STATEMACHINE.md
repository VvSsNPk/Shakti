# Phase 2: State Machines & Validation

## Overview

Phase 2 provides object lifecycle management and message validation. It ensures:
- Objects transition through valid states
- Messages are only sent/received at appropriate times
- Protocol invariants are maintained

## Architecture

```
Message Flow with State Machine:
                    ┌─────────────┐
                    │   Client    │
                    └──────┬──────┘
                           │
                  ┌────────▼────────┐
                  │ Connection Pool │
                  └────────┬────────┘
                           │
                  ┌────────▼──────────────────┐
                  │   State Machine Checks    │
                  ├───────────────────────────┤
                  │ 1. Object exists?         │
                  │ 2. State allows message?  │
                  │ 3. Message in spec?       │
                  └────────┬──────────────────┘
                           │
              ┌────────────▼────────────────┐
              │  Execute Request/Event      │
              │ (transition state if needed)│
              └─────────────────────────────┘
```

## Object Lifecycle

Every Wayland object goes through these states:

```
created
  │
  ├──► initialized (bound to interface)
  │        │
  │        ├──► active (ready for messages)
  │        │       │
  │        │       └──► destroyed
  │        │
  │        └──► destroyed
  │
  └──► destroyed
```

### Valid Transitions

```
created → initialized ✅
created → destroyed ✅
created → active ❌
created → created ❌

initialized → active ✅
initialized → destroyed ✅
initialized → created ❌
initialized → initialized ❌

active → active ✅ (stay active)
active → destroyed ✅
active → created ❌
active → initialized ❌

destroyed → * ❌ (no transitions out)
```

## Core Data Structures

### ObjectState

```lean
inductive ObjectState where
  | created      -- just allocated
  | initialized  -- bound to interface
  | active       -- ready for communication
  | destroyed    -- cleanup complete
```

### WaylandObject

```lean
structure WaylandObject where
  id : UInt32          -- unique object ID
  interfaceName : String  -- "wl_display", "wl_surface", etc
  version : Nat        -- interface version
  state : ObjectState  -- current lifecycle state
```

### MessageMetadata

```lean
structure MessageMetadata where
  name : String                    -- "sync", "attach", etc
  msgType : MessageType            -- request or event
  requiresState : ObjectState      -- recommended state
  allowedInStates : List ObjectState  -- allowed states for this message
```

### InterfaceSpec

Complete specification for an interface:

```lean
structure InterfaceSpec where
  name : String                    -- "wl_display"
  version : Nat                    -- version number
  requests : List MessageMetadata  -- what clients can send
  events : List MessageMetadata    -- what server sends
```

## API

### State Transitions

```lean
-- Check if transition is valid
def ObjectState.canTransitionTo (src dst : ObjectState) : Bool

-- Perform transition (returns None if invalid)
def ObjectState.transitionTo (src dst : ObjectState) : Option ObjectState
```

### State Machine Creation & Query

```lean
-- Create empty state machine
def ObjectStateMachine.create : ObjectStateMachine

-- Create new object (starts in created state)
def ObjectStateMachine.createObject (sm : ObjectStateMachine) (objId : UInt32) 
    (interfaceName : String) (version : Nat) : ObjectStateMachine

-- Find object by ID
def ObjectStateMachine.findObject (sm : ObjectStateMachine) (objId : UInt32) : 
    Option WaylandObject

-- Get all active objects
def ObjectStateMachine.getActiveObjects (sm : ObjectStateMachine) : List WaylandObject

-- Get objects by interface type
def ObjectStateMachine.getObjectsByInterface (sm : ObjectStateMachine) 
    (interfaceName : String) : List WaylandObject
```

### State Updates

```lean
-- Update object state with validation
def ObjectStateMachine.updateObjectState (sm : ObjectStateMachine) (objId : UInt32) 
    (newState : ObjectState) : Option ObjectStateMachine

-- Initialize object (created → initialized → active)
def ObjectStateMachine.initializeObject (sm : ObjectStateMachine) (objId : UInt32) :
    Option ObjectStateMachine

-- Destroy object
def ObjectStateMachine.destroyObject (sm : ObjectStateMachine) (objId : UInt32) : 
    Option ObjectStateMachine
```

### Message Validation

```lean
-- Check if request can be sent from object
def ObjectStateMachine.canSendRequest (sm : ObjectStateMachine) (objId : UInt32) 
    (requestName : String) : Bool

-- Check if event can be received by object
def ObjectStateMachine.canReceiveEvent (sm : ObjectStateMachine) (objId : UInt32) 
    (eventName : String) : Bool

-- Full validation of message in context
def ObjectStateMachine.validateMessage (sm : ObjectStateMachine) (objId : UInt32)
    (msgName : String) (msgType : MessageType) : Option String
```

### Audit & Monitoring

```lean
-- Log message for audit trail
def ObjectStateMachine.logMessage (sm : ObjectStateMachine) (objId : UInt32) 
    (msgName : String) (msgType : MessageType) : ObjectStateMachine

-- Get statistics
def ObjectStateMachine.getStats (sm : ObjectStateMachine) : StateMachineStats

structure StateMachineStats where
  totalObjects : Nat
  activeObjects : Nat
  createdObjects : Nat
  initializedObjects : Nat
  destroyedObjects : Nat
  totalMessages : Nat
```

## Interface Specifications

Built-in specifications for common interfaces:

### wl_display (Global)

**Requests**:
- `sync` - allowed in: active, initialized
- `get_registry` - allowed in: active, initialized

**Events**:
- `error` - allowed in: active, initialized
- `delete_id` - allowed in: active, initialized

### wl_registry (Global)

**Requests**:
- `bind` - allowed in: active, initialized

**Events**:
- `global` - allowed in: active
- `global_remove` - allowed in: active

### wl_surface (Per-Client)

**Requests**:
- `attach` - allowed in: active
- `damage` - allowed in: active
- `frame` - allowed in: active
- `commit` - allowed in: active

**Events**:
- `enter` - allowed in: active
- `leave` - allowed in: active

## Usage Examples

### Example 1: Create Object and Initialize

```lean
open WaylandProtocol

-- Start with empty state machine
let sm := ObjectStateMachine.create

-- Create new display object (ID 1)
let sm1 := sm.createObject 1 "wl_display" 1

-- Verify it's in created state
match ObjectStateMachine.findObject sm1 1 with
| some obj => 
  #eval obj.state  -- ObjectState.created
| none => ()

-- Initialize it
match ObjectStateMachine.initializeObject sm1 1 with
| some sm2 =>
  match ObjectStateMachine.findObject sm2 1 with
  | some obj =>
    #eval obj.state  -- ObjectState.initialized
  | none => ()
| none => ()
```

### Example 2: Validate Message Can Be Sent

```lean
-- Check if we can send "sync" request
let canSendSync := ObjectStateMachine.canSendRequest sm2 1 "sync"
#eval canSendSync  -- true (initialized state allows sync)

-- Check if we can send a random request
let canSendFake := ObjectStateMachine.canSendRequest sm2 1 "unknown"
#eval canSendFake  -- false (not in spec)
```

### Example 3: Activate Object

```lean
-- After initialization, activate to active state
match ObjectStateMachine.initializeObject sm2 1 with
| some sm3 =>
  match ObjectStateMachine.findObject sm3 1 with
  | some obj =>
    #eval obj.state  -- ObjectState.active
  | none => ()
| none => ()
```

### Example 4: Create Multiple Objects

```lean
-- Create registry object (ID 2)
let sm4 := ObjectStateMachine.createObject sm3 2 "wl_registry" 1

-- Create surface object (ID 3)
let sm5 := ObjectStateMachine.createObject sm4 3 "wl_surface" 7

-- Get all objects of type wl_surface
let surfaces := ObjectStateMachine.getObjectsByInterface sm5 "wl_surface"
#eval surfaces.length  -- 1
```

### Example 5: Message Logging & Statistics

```lean
-- Log some messages
let sm6 := ObjectStateMachine.logMessage sm5 1 "sync" MessageType.request
let sm7 := ObjectStateMachine.logMessage sm6 1 "get_registry" MessageType.request

-- Get statistics
let stats := ObjectStateMachine.getStats sm7
#eval stats.totalObjects     -- 3
#eval stats.activeObjects    -- 1
#eval stats.totalMessages    -- 2
```

## Message Flow Example

### Complete lifecycle of a surface creation:

```
1. Client connects
   - wl_display (ID 1) created
   - state: created

2. Client sends sync request
   - Message validation checks:
     ✓ Object 1 exists?
     ✓ created → sync allowed? No
   - Invalid! Wait for initialization

3. Server initializes display
   - updateObjectState 1 to initialized
   - state: created → initialized ✅

4. Client sends sync request again
   - Message validation checks:
     ✓ Object 1 exists?
     ✓ initialized → sync allowed? Yes ✅
   - Request processed
   - Server creates callback (ID 4)
   - Callback state: created

5. Server initializes callback
   - updateObjectState 4 to active
   - state: created → active ✅

6. Server sends "done" event to callback
   - Message validation checks:
     ✓ Object 4 exists?
     ✓ active → done allowed? Yes ✅
   - Event delivered

7. Server destroys callback
   - destroyObject 4
   - state: active → destroyed ✅
```

## Error Handling

### Invalid State Transition

```lean
match ObjectStateMachine.updateObjectState sm 1 ObjectState.destroyed with
| some sm' => ()  -- success
| none =>         -- state transition not allowed
  IO.println "Cannot transition object from current state"
```

### Message Not Allowed

```lean
if ObjectStateMachine.canSendRequest sm objId "unknown_request" then
  ()  -- can send
else
  IO.println "Message not allowed in current state or not in interface spec"
```

### Object Not Found

```lean
match ObjectStateMachine.findObject sm unknownId with
| some obj => ()  -- object exists
| none =>         -- object not found
  IO.println "Object does not exist"
```

## Monitoring & Debugging

### Get Pool Statistics

```lean
let stats := ObjectStateMachine.getStats sm
IO.println s!"Active objects: {stats.activeObjects}"
IO.println s!"Total messages logged: {stats.totalMessages}"
```

### Audit Trail

The state machine maintains a message log for debugging:

```lean
-- sm.messageLog is List (UInt32 × String × MessageType)
-- Access it to trace all messages sent/received
for (objId, msgName, msgType) in sm.messageLog do
  IO.println s!"{objId}: {msgName}"
```

## Integration with Previous Phases

### With Serialization (Phase 0)

```lean
-- Deserialize incoming bytes
let (msgBytes, newConn) ← ClientConnection.readMessage conn

-- Decode the message
let (senderId, opcode, _) ← decodeMessageHeader msgBytes

-- Validate with state machine BEFORE processing
if ObjectStateMachine.canReceiveEvent sm senderId "some_event" then
  -- Process the event
  ()
```

### With Connection (Phase 1)

```lean
-- For each message from client
match ClientConnection.readMessage conn with
| some (msgBytes, updatedConn) =>
  -- Validate state BEFORE executing
  if ObjectStateMachine.canSendRequest sm clientId "sync" then
    -- Process request
    let smUpdated := ObjectStateMachine.logMessage sm clientId "sync" MessageType.request
    ()
| none => ()
```

## Next Phase

Phase 3 will implement the Event Loop that:
- Continuously processes messages from all clients
- Uses state machine to validate each message
- Dispatches to appropriate handlers
- Generates response events
- Manages frame scheduling

---

**Phase 2 provides the guarantees that make Wayland reliable and predictable!** ✅
