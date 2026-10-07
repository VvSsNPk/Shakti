import ShaktiLean.Basic
import ShaktiLean.Connection
import ShaktiLean.StateMachine
import ShaktiLean.Serialization

namespace WaylandProtocol

-- Compositor state
structure CompositorState where
  pool : ConnectionPool
  stateMachine : ObjectStateMachine
  frameTime : Nat
  running : Bool

def CompositorState.create : CompositorState :=
  ⟨ConnectionPool.create, ObjectStateMachine.create, 0, true⟩

-- Process result
inductive ProcessResult where
  | success (newState : CompositorState)
  | error (message : String) (state : CompositorState)

-- Handler result
inductive HandlerResult where
  | ok (events : List (UInt32 × List UInt8))
  | rejected (reason : String)

-- Handle wl_display.sync
def handleDisplaySync (state : CompositorState) (clientId : Nat) (callbackId : UInt32) :
    HandlerResult :=
  let doneEventBytes : List UInt8 := encodeMessage callbackId 0 [Value.uintV 0]
  .ok [(callbackId, doneEventBytes)]

-- Handle wl_display.get_registry
def handleGetRegistry (state : CompositorState) (clientId : Nat) (registryId : UInt32) :
    HandlerResult :=
  .ok []

-- Main message processing
def processMessage (state : CompositorState) (clientId : Nat) (msgBytes : List UInt8) :
    ProcessResult :=
  match decodeMessageHeader msgBytes with
  | none => .error "Failed to decode message header" state
  | some (senderId, sizeWords, opcode, totalBytes) =>
    match state.stateMachine.findObject senderId with
    | none => .error "Object not found" state
    | some obj =>
      match getInterfaceSpec obj.interfaceName with
      | none => .error "Unknown interface" state
      | some spec =>
        let msgName := match (obj.interfaceName, opcode) with
          | ("wl_display", 0) => "sync"
          | ("wl_display", 1) => "get_registry"
          | ("wl_registry", 0) => "bind"
          | _ => "unknown"

        if not (ObjectStateMachine.canSendRequest state.stateMachine senderId msgName) then
          .error s!"Message '{msgName}' not allowed in current state" state
        else
          let sm1 := ObjectStateMachine.logMessage state.stateMachine senderId msgName MessageType.request
          let handlerResult := match (obj.interfaceName, msgName) with
            | ("wl_display", "sync") => handleDisplaySync state clientId 2
            | ("wl_display", "get_registry") => handleGetRegistry state clientId 3
            | _ => .rejected "No handler"

          match handlerResult with
          | .rejected reason => .error reason state
          | .ok events =>
            let updatedPool := events.foldl (fun pool (objId, eventBytes) =>
              match ConnectionPool.findConnection pool clientId with
              | some conn =>
                match ClientConnection.queueOutgoingMessage conn eventBytes with
                | some updatedConn =>
                  ConnectionPool.updateConnection pool clientId (fun _ => updatedConn)
                | none => pool
              | none => pool
            ) state.pool

            .success ⟨updatedPool, sm1, state.frameTime, state.running⟩

-- Process one message from a client
def processClientMessage (state : CompositorState) (clientId : Nat) : ProcessResult :=
  match ConnectionPool.findConnection state.pool clientId with
  | none => .error "Client not found" state
  | some conn =>
    match ClientConnection.readMessage conn with
    | none => .success state
    | some (msgBytes, updatedConn) =>
      match processMessage state clientId msgBytes with
      | .error reason st => .error reason st
      | .success newState =>
        let finalState := { newState with
          pool := ConnectionPool.updateConnection newState.pool clientId (fun _ => updatedConn)
        }
        .success finalState

-- Flush pending messages to clients
def flushPendingMessages (state : CompositorState) : CompositorState :=
  let updatedConnections := state.pool.connections.map (fun conn =>
    match ClientConnection.flushOutgoing conn with
    | some clearedConn => clearedConn
    | none => conn
  )
  { state with pool := { state.pool with connections := updatedConnections } }

-- Update frame time
def updateFrameTime (state : CompositorState) (deltaTime : Nat) : CompositorState :=
  let newTime := state.frameTime + deltaTime
  { state with frameTime := newTime }

-- One compositor iteration
def compositorIteration (state : CompositorState) : CompositorState :=
  if not state.running then
    state
  else
    -- Process max 1 message per client per iteration
    let stateAfterProcessing := state.pool.connections.foldl (fun currentState conn =>
      match processClientMessage currentState conn.id with
      | .success newState => newState
      | .error _ newState => newState
    ) state

    -- Flush messages
    let stateAfterFlush := flushPendingMessages stateAfterProcessing

    -- Update time
    updateFrameTime stateAfterFlush 16

-- Statistics
structure CompositorStats where
  totalClients : Nat
  activeObjects : Nat
  pendingMessages : Nat
  frameTime : Nat

def CompositorState.getStats (state : CompositorState) : CompositorStats :=
  let poolStats := state.pool.getStats
  let smStats := state.stateMachine.getStats
  let pendingCount := state.pool.getAllPendingMessages.length
  ⟨poolStats.totalConnections, smStats.activeObjects, pendingCount, state.frameTime⟩

-- Connect new client
def connectNewClient (state : CompositorState) : CompositorState × Nat :=
  let (newPool, clientId) := state.pool.addConnection
  let newSm := state.stateMachine.createObject 1 "wl_display" 1
  ({ state with pool := newPool, stateMachine := newSm }, clientId)

-- Disconnect client
def disconnectClient (state : CompositorState) (clientId : Nat) : CompositorState :=
  let newPool := state.pool.removeConnection clientId
  { state with pool := newPool }

-- Run N iterations
def runCompositorLoop (initialState : CompositorState) (iterations : Nat) :
    CompositorState :=
  List.range iterations |> List.foldl (fun state _ =>
    if state.running then compositorIteration state else state
  ) initialState

-- Print stats
def printCompositorStats (state : CompositorState) : IO Unit := do
  let stats := state.getStats
  IO.println s!"=== Compositor Stats ==="
  IO.println s!"Clients: {stats.totalClients}"
  IO.println s!"Active objects: {stats.activeObjects}"
  IO.println s!"Pending messages: {stats.pendingMessages}"
  IO.println s!"Frame time: {stats.frameTime}ms"

-- Shutdown
def shutdownCompositor (state : CompositorState) : CompositorState :=
  let disconnectedState := state.pool.connections.foldl (fun currentState conn =>
    disconnectClient currentState conn.id
  ) state
  { disconnectedState with running := false }

end WaylandProtocol
