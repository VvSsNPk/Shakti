import ShaktiLean.Protocol

-- Utility functions for Wayland protocol

namespace WaylandProtocol

-- Generic find function using Named type class
def findByName [Named α] (name : String) (items : List α) : Option α :=
  items.find? (fun item => Named.getName item = name)

-- Find an interface by name
def findInterface (name : String) (interfaces : List Interface) : Option Interface :=
  findByName name interfaces

-- Find a request by name in an interface
def findRequest (name : String) (iface : Interface) : Option Message :=
  findByName name iface.requests

-- Find an event by name in an interface
def findEvent (name : String) (iface : Interface) : Option Message :=
  findByName name iface.events

-- Find an enum by name in an interface
def findEnum (name : String) (iface : Interface) : Option Enum :=
  findByName name iface.enums

-- Get all message names (requests + events) for an interface
def messageNames (iface : Interface) : List String :=
  (iface.requests.map (fun m => m.name)) ++ (iface.events.map (fun m => m.name))

-- Check if an interface is versioned
def interfaceVersion (name : String) : Option Nat :=
  match findInterface name allInterfaces with
  | none => none
  | some iface => some iface.version

-- Get all interface names
def interfaceNames : List String :=
  allInterfaces.map (fun iface => iface.name)

-- Type class for validation
class Validatable (α : Type) where
  isValid : α → Bool

instance : Validatable Arg where
  isValid arg := match arg.argType with
    | ArgType.object | ArgType.newId =>
      match arg.interfaceName with
      | none => false
      | some name => (findInterface name allInterfaces).isSome
    | _ => true

instance : Validatable Message where
  isValid msg := msg.args.all Validatable.isValid

instance : Validatable Interface where
  isValid iface :=
    (iface.requests.all Validatable.isValid) && (iface.events.all Validatable.isValid)

-- More idiomatic validation functions
def argTypeValid (arg : Arg) : Bool := Validatable.isValid arg
def messageValid (msg : Message) : Bool := Validatable.isValid msg
def interfaceValid (iface : Interface) : Bool := Validatable.isValid iface

-- Validate entire protocol
def protocolValid : Bool :=
  allInterfaces.all Validatable.isValid

-- Count total requests in protocol
def totalRequests : Nat :=
  allInterfaces.foldl (fun acc iface => acc + iface.requests.length) 0

-- Count total events in protocol
def totalEvents : Nat :=
  allInterfaces.foldl (fun acc iface => acc + iface.events.length) 0

-- Count total messages
def totalMessages : Nat :=
  totalRequests + totalEvents

-- Count items by predicate
def countWhere [Validatable α] (items : List α) (p : α → Bool) : Nat :=
  items.foldl (fun acc item => if p item then acc + 1 else acc) 0

-- Count valid items in a list
def countValid [Validatable α] (items : List α) : Nat :=
  countWhere items Validatable.isValid

end WaylandProtocol
