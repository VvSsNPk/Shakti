import ShaktiLean.Basic
import ShaktiLean.Connection

namespace WaylandProtocol

-- Object lifecycle states
inductive ObjectState where
  | created
  | initialized
  | active
  | destroyed
  deriving Repr, BEq

-- Object metadata including state
structure WaylandObject where
  id : UInt32
  interfaceName : String
  version : Nat
  state : ObjectState
  deriving Repr

-- Valid state transitions
def ObjectState.canTransitionTo (src dst : ObjectState) : Bool :=
  match (src, dst) with
  | (.created, .initialized) => true
  | (.initialized, .active) => true
  | (.active, .active) => true
  | (.active, .destroyed) => true
  | (.initialized, .destroyed) => true
  | (.created, .destroyed) => true
  | _ => false

-- Perform state transition with validation
def ObjectState.transitionTo (src dst : ObjectState) : Option ObjectState :=
  if src.canTransitionTo dst then some dst else none

-- Message type (request or event)
inductive MessageType where
  | request
  | event
  deriving Repr, BEq

-- Message metadata
structure MessageMetadata where
  name : String
  msgType : MessageType
  requiresState : ObjectState
  allowedInStates : List ObjectState

-- Check if message is allowed in given state
def MessageMetadata.isAllowedInState (metadata : MessageMetadata) (state : ObjectState) : Bool :=
  metadata.allowedInStates.contains state

-- Object state machine for managing lifecycle
structure ObjectStateMachine where
  objects : List WaylandObject
  messageLog : List (UInt32 × String × MessageType)

def ObjectStateMachine.create : ObjectStateMachine :=
  ⟨[], []⟩

-- Create new object in created state
def ObjectStateMachine.createObject (sm : ObjectStateMachine) (objId : UInt32)
    (interfaceName : String) (version : Nat) : ObjectStateMachine :=
  let newObj : WaylandObject := ⟨objId, interfaceName, version, ObjectState.created⟩
  { sm with objects := sm.objects ++ [newObj] }

-- Find object by ID
def ObjectStateMachine.findObject (sm : ObjectStateMachine) (objId : UInt32) :
    Option WaylandObject :=
  sm.objects.find? (fun obj => obj.id == objId)

-- Update object state
def ObjectStateMachine.updateObjectState (sm : ObjectStateMachine) (objId : UInt32)
    (newState : ObjectState) : Option ObjectStateMachine := do
  let obj ← sm.findObject objId

  let _ ← obj.state.transitionTo newState

  let newObjects := sm.objects.map (fun o =>
    if o.id == objId then { o with state := newState } else o)

  some { sm with objects := newObjects }

-- Log message for audit trail
def ObjectStateMachine.logMessage (sm : ObjectStateMachine) (objId : UInt32)
    (msgName : String) (msgType : MessageType) : ObjectStateMachine :=
  { sm with messageLog := sm.messageLog ++ [(objId, msgName, msgType)] }

-- Check if request can be sent from object in given state
def ObjectStateMachine.canSendRequest (sm : ObjectStateMachine) (objId : UInt32)
    (requestName : String) : Bool :=
  match sm.findObject objId with
  | some obj =>
    match obj.state with
    | ObjectState.active => true
    | ObjectState.initialized =>
      requestName == "bind" || requestName == "sync"
    | _ => false
  | none => false

-- Check if event can be received to object in given state
def ObjectStateMachine.canReceiveEvent (sm : ObjectStateMachine) (objId : UInt32)
    (eventName : String) : Bool :=
  match sm.findObject objId with
  | some obj =>
    match obj.state with
    | ObjectState.active => true
    | ObjectState.initialized =>
      eventName == "done"
    | _ => false
  | none => false

-- Destroy object
def ObjectStateMachine.destroyObject (sm : ObjectStateMachine) (objId : UInt32) :
    Option ObjectStateMachine := do
  let _ ← sm.findObject objId
  sm.updateObjectState objId ObjectState.destroyed

-- Get all active objects
def ObjectStateMachine.getActiveObjects (sm : ObjectStateMachine) : List WaylandObject :=
  sm.objects.filter (fun obj => obj.state == ObjectState.active)

-- Get objects by interface
def ObjectStateMachine.getObjectsByInterface (sm : ObjectStateMachine)
    (interfaceName : String) : List WaylandObject :=
  sm.objects.filter (fun obj => obj.interfaceName == interfaceName)

-- Statistics
structure StateMachineStats where
  totalObjects : Nat
  activeObjects : Nat
  createdObjects : Nat
  initializedObjects : Nat
  destroyedObjects : Nat
  totalMessages : Nat

def ObjectStateMachine.getStats (sm : ObjectStateMachine) : StateMachineStats :=
  let active := sm.objects.filter (fun o => o.state == ObjectState.active)
  let created := sm.objects.filter (fun o => o.state == ObjectState.created)
  let initialized := sm.objects.filter (fun o => o.state == ObjectState.initialized)
  let destroyed := sm.objects.filter (fun o => o.state == ObjectState.destroyed)
  ⟨sm.objects.length, active.length, created.length, initialized.length, destroyed.length, sm.messageLog.length⟩

-- Request/Event specifications for different interfaces
structure InterfaceSpec where
  name : String
  version : Nat
  requests : List MessageMetadata
  events : List MessageMetadata

-- Get spec for wl_display
def wl_displaySpec : InterfaceSpec :=
  ⟨"wl_display", 1,
    [
      ⟨"sync", MessageType.request, ObjectState.active, [ObjectState.active, ObjectState.initialized]⟩,
      ⟨"get_registry", MessageType.request, ObjectState.active, [ObjectState.active, ObjectState.initialized]⟩
    ],
    [
      ⟨"error", MessageType.event, ObjectState.active, [ObjectState.active, ObjectState.initialized]⟩,
      ⟨"delete_id", MessageType.event, ObjectState.active, [ObjectState.active, ObjectState.initialized]⟩
    ]⟩

-- Get spec for wl_registry
def wl_registrySpec : InterfaceSpec :=
  ⟨"wl_registry", 1,
    [
      ⟨"bind", MessageType.request, ObjectState.active, [ObjectState.active, ObjectState.initialized]⟩
    ],
    [
      ⟨"global", MessageType.event, ObjectState.active, [ObjectState.active]⟩,
      ⟨"global_remove", MessageType.event, ObjectState.active, [ObjectState.active]⟩
    ]⟩

-- Get spec for wl_surface
def wl_surfaceSpec : InterfaceSpec :=
  ⟨"wl_surface", 7,
    [
      ⟨"attach", MessageType.request, ObjectState.active, [ObjectState.active]⟩,
      ⟨"damage", MessageType.request, ObjectState.active, [ObjectState.active]⟩,
      ⟨"frame", MessageType.request, ObjectState.active, [ObjectState.active]⟩,
      ⟨"commit", MessageType.request, ObjectState.active, [ObjectState.active]⟩
    ],
    [
      ⟨"enter", MessageType.event, ObjectState.active, [ObjectState.active]⟩,
      ⟨"leave", MessageType.event, ObjectState.active, [ObjectState.active]⟩
    ]⟩

-- Lookup interface spec
def getInterfaceSpec (interfaceName : String) : Option InterfaceSpec :=
  match interfaceName with
  | "wl_display" => some wl_displaySpec
  | "wl_registry" => some wl_registrySpec
  | "wl_surface" => some wl_surfaceSpec
  | _ => none

-- Validate message against interface spec
def validateMessageAgainstSpec (spec : InterfaceSpec) (msgName : String)
    (msgType : MessageType) (objectState : ObjectState) : Bool :=
  let messages := if msgType == MessageType.request then spec.requests else spec.events
  match messages.find? (fun m => m.name == msgName) with
  | some m => m.isAllowedInState objectState
  | none => false

-- Full message validation in context of state machine
def ObjectStateMachine.validateMessage (sm : ObjectStateMachine) (objId : UInt32)
    (msgName : String) (msgType : MessageType) : Option String := do
  let obj ← sm.findObject objId
  let spec ← getInterfaceSpec obj.interfaceName

  if validateMessageAgainstSpec spec msgName msgType obj.state then
    some ""
  else
    none

-- Initialize object to active state (after bind)
def ObjectStateMachine.initializeObject (sm : ObjectStateMachine) (objId : UInt32) :
    Option ObjectStateMachine := do
  let obj ← sm.findObject objId
  match obj.state with
  | ObjectState.created =>
    sm.updateObjectState objId ObjectState.initialized
  | ObjectState.initialized =>
    sm.updateObjectState objId ObjectState.active
  | _ => none

end WaylandProtocol
