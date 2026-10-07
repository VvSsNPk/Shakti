# Phase 3: Event Loop & Main Compositor

## Overview

Phase 3 brings everything together into a working Wayland compositor. It implements:
- **Message processing pipeline** - from wire protocol to handler execution
- **Compositor state machine** - tracks clients, objects, and frame timing
- **Main event loop** - drives the compositor iteration by iteration
- **Integration** of all previous phases (Serialization, Connection, StateMachine)

## Architecture

```
┌─────────────────────────────────────────────────┐
│         Main Compositor Loop                    │
├─────────────────────────────────────────────────┤
│                                                 │
│  for each iteration:                            │
│    1. Process messages from each client         │
│    2. Flush pending responses                   │
│    3. Update frame time                         │
│                                                 │
└────────────────┬────────────────────────────────┘
                 │
        ┌────────▼────────┐
        │  Message        │
        │  Processing     │
        └────────┬────────┘
                 │
        ┌────────▼────────────────────┐
        │  1. Decode header           │
        │  2. Find object             │
        │  3. Get interface spec      │
        │  4. Determine message name  │
        │  5. Validate with state     │
        │  6. Log message             │
        │  7. Dispatch to handler     │
        │  8. Queue response          │
        └────────┬────────────────────┘
                 │
        ┌────────▼────────────────┐
        │  Handler Execution      │
        │  (e.g., handleSync)     │
        └────────┬────────────────┘
                 │
        ┌────────▼─────────────────┐
        │  Queue Response Events   │
        │  to Client               │
        └─────────────────────────┘
```

## Core Data Structures

### CompositorState

Represents the complete state of the compositor:

```lean
structure CompositorState where
  pool : ConnectionPool          -- all connected clients
  stateMachine : ObjectStateMachine  -- all objects & their states
  frameTime : Nat               -- elapsed time in ms
  running : Bool                -- is compositor active
```

### ProcessResult

Result of processing a message:

```lean
inductive ProcessResult where
  | success (newState : CompositorState)
  | error (message : String) (state : CompositorState)
```

### HandlerResult

Result from a message handler:

```lean
inductive HandlerResult where
  | ok (events : List (UInt32 × List UInt8))  -- events to send
  | rejected (reason : String)
```

## Main API

### Compositor Lifecycle

```lean
-- Create compositor
def CompositorState.create : CompositorState

-- Run N iterations
def runCompositorLoop (state : CompositorState) (iterations : Nat) : CompositorState

-- Graceful shutdown
def shutdownCompositor (state : CompositorState) : CompositorState
```

### Client Management

```lean
-- Connect new client
def connectNewClient (state : CompositorState) : CompositorState × Nat

-- Disconnect client
def disconnectClient (state : CompositorState) (clientId : Nat) : CompositorState
```

### Message Processing

```lean
-- Process one message from a client
def processClientMessage (state : CompositorState) (clientId : Nat) : ProcessResult

-- Process one message
def processMessage (state : CompositorState) (clientId : Nat) (msgBytes : List UInt8) :
    ProcessResult
```

### Iteration Control

```lean
-- One compositor iteration (process messages, flush, update time)
def compositorIteration (state : CompositorState) : CompositorState

-- Flush pending messages to clients
def flushPendingMessages (state : CompositorState) : CompositorState

-- Update frame time
def updateFrameTime (state : CompositorState) (deltaTime : Nat) : CompositorState
```

### Monitoring

```lean
-- Get statistics
def CompositorState.getStats (state : CompositorState) : CompositorStats

-- Print stats to console
def printCompositorStats (state : CompositorState) : IO Unit

structure CompositorStats where
  totalClients : Nat
  activeObjects : Nat
  pendingMessages : Nat
  frameTime : Nat
```

## Message Processing Pipeline

### Step-by-step flow for a client request:

```
1. READ
   └─ ClientConnection.readMessage() → complete message bytes

2. DECODE
   └─ decodeMessageHeader() → (senderId, opcode, totalBytes)

3. LOOKUP
   ├─ stateMachine.findObject(senderId) → WaylandObject
   └─ getInterfaceSpec(interfaceName) → InterfaceSpec

4. VALIDATE
   ├─ Look up opcode in spec → message name
   ├─ stateMachine.canSendRequest() → bool
   └─ If invalid → .error

5. LOG
   └─ stateMachine.logMessage() → audit trail

6. DISPATCH
   └─ Match (interface, messageName) → handler function

7. EXECUTE
   ├─ Call handler (e.g., handleDisplaySync)
   └─ Get back HandlerResult

8. QUEUE
   ├─ Serialize response events
   ├─ ClientConnection.queueOutgoingMessage()
   └─ Ready to send on next flush

9. FLUSH
   └─ Send queued bytes to client over socket
```

## Handler Functions

Handlers take the current state and request details, return generated events:

### Example: handleDisplaySync

```lean
def handleDisplaySync (state : CompositorState) (clientId : Nat) (callbackId : UInt32) :
    HandlerResult :=
  -- Create callback object (transient, for one "done" event)
  let doneEventBytes : List UInt8 := encodeMessage callbackId 0 [Value.uintV 0]
  .ok [(callbackId, doneEventBytes)]
```

### Example: handleGetRegistry

```lean
def handleGetRegistry (state : CompositorState) (clientId : Nat) (registryId : UInt32) :
    HandlerResult :=
  -- Create registry object (will receive globals)
  .ok []  -- globals come later in compositor loop
```

## Usage Examples

### Example 1: Initialize Compositor

```lean
open WaylandProtocol

-- Create empty compositor
let comp := CompositorState.create

#eval comp.frameTime        -- 0
#eval comp.running          -- true
#eval comp.pool.connections.length  -- 0
```

### Example 2: Connect Client

```lean
-- Client connects
let (comp1, clientId) := connectNewClient comp
#eval clientId              -- 0
#eval comp1.pool.connections.length  -- 1

-- Get stats
let stats := comp1.getStats
#eval stats.totalClients    -- 1
```

### Example 3: Run Compositor Loop

```lean
-- Run 1000 iterations
let comp2 := runCompositorLoop comp1 1000

#eval comp2.frameTime       -- 16000 ms (16 ms per iteration)
#eval comp2.running         -- true (still running)
```

### Example 4: Shutdown

```lean
-- Graceful shutdown
let comp3 := shutdownCompositor comp2

#eval comp3.running         -- false
#eval comp3.pool.connections.length  -- 0
```

### Example 5: Full Workflow

```lean
-- Create and run a simple compositor
let comp := CompositorState.create
  |> fun c => let (c', _) := connectNewClient c; c'
  |> fun c => runCompositorLoop c 100
  |> fun c => shutdownCompositor c

IO.println s!"Ran for {comp.frameTime}ms"
IO.println s!"Active: {comp.running}"
```

## Iteration Cycle

Each `compositorIteration`:

```
Iteration 0:
  frameTime = 0ms
  1. Process client messages (max 1 per client)
  2. Flush pending messages
  3. Update time → frameTime = 16ms

Iteration 1:
  frameTime = 16ms
  1. Process client messages
  2. Flush pending messages
  3. Update time → frameTime = 32ms

...

Iteration 62:
  frameTime = 992ms
  1. Process client messages
  2. Flush pending messages
  3. Update time → frameTime = 1008ms
  [1000 iterations = ~1 second at 60fps]
```

## Integration with Previous Phases

### Phase 0 (Serialization)

```lean
-- ENCODING (server → client)
let eventBytes : List UInt8 := encodeMessage objId opcode args
ClientConnection.queueOutgoingMessage conn eventBytes

-- DECODING (client → server)
let (msgBytes, updatedConn) := ClientConnection.readMessage conn
let (senderId, opcode, _, _) := decodeMessageHeader msgBytes
```

### Phase 1 (Connection)

```lean
-- QUEUE INCOMING
ClientConnection.queueIncomingMessage(msgBytes)

-- READ MESSAGES
let (completeMsg, updatedConn) := ClientConnection.readMessage conn

-- QUEUE OUTGOING
ClientConnection.queueOutgoingMessage(responseBytes)

-- FLUSH
ClientConnection.flushOutgoing conn
```

### Phase 2 (StateMachine)

```lean
-- FIND OBJECT
let obj := stateMachine.findObject objId

-- VALIDATE MESSAGE
stateMachine.canSendRequest(objId, msgName)

-- UPDATE STATE
stateMachine.updateObjectState(objId, newState)

-- LOG MESSAGE
stateMachine.logMessage(objId, msgName, MessageType.request)
```

## Performance Characteristics

- **Per-iteration cost**: O(n) where n = number of connected clients
- **Message processing**: O(1) per message (no loops within)
- **Memory**: O(c + o + m) where c = clients, o = objects, m = messages

### Optimizations in Production

1. **Batch processing**: Handle multiple messages per client per iteration
2. **Async I/O**: Non-blocking socket read/write
3. **Object pooling**: Reuse allocation for frequently created objects
4. **Frame skipping**: Skip iterations if behind on frame time
5. **Priority queues**: Process critical clients first

## Testing & Debugging

### Print statistics

```lean
#eval comp.getStats
-- CompositorStats:
--   totalClients: 1
--   activeObjects: 2
--   pendingMessages: 0
--   frameTime: 1600
```

### Debug iteration

```lean
let comp' := compositorIteration comp
let stats := comp'.getStats
IO.println s!"Iteration complete: {stats}"
```

### Trace message flow

Add logging to handlers:

```lean
def handleDisplaySync (state : CompositorState) (clientId : Nat) (callbackId : UInt32) :
    HandlerResult := do
  IO.println s!"[{state.frameTime}ms] Sync from client {clientId}"
  let doneEventBytes : List UInt8 := encodeMessage callbackId 0 [Value.uintV 0]
  .ok [(callbackId, doneEventBytes)]
```

## Real-world Extensions Needed

For a production compositor, add:

1. **Socket I/O**: Actual network I/O instead of in-memory buffers
2. **Frame callbacks**: Track frame timing and send "frame" events
3. **Damage tracking**: Track dirty regions for efficient rendering
4. **Buffer management**: Handle wl_buffer lifecycle
5. **Input handling**: Mouse, keyboard, touch events
6. **Output management**: Multiple monitors
7. **Surface management**: Per-surface state tracking
8. **Rendering**: Graphics pipeline integration

## Next Steps

Phase 3 complete! The compositor now:
- ✅ Accepts client connections
- ✅ Processes messages from wire protocol
- ✅ Validates state transitions
- ✅ Dispatches to handlers
- ✅ Generates response events
- ✅ Maintains audit trail
- ✅ Tracks frame timing

To extend further:
1. Implement actual socket I/O (replace in-memory buffers)
2. Add graphics rendering pipeline
3. Implement frame scheduling with callbacks
4. Add input device handling
5. Implement complete XDG shell support
6. Add data transfer (copy/paste)

---

**You now have a type-safe, composable Wayland compositor framework in Lean 4!** 🎉
