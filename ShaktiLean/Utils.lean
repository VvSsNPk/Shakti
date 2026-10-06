import ShaktiLean.Protocol

-- Utility functions for Wayland protocol

namespace WaylandProtocol

-- Find an interface by name
def findInterface (name : String) (interfaces : List Interface) : Option Interface :=
  interfaces.find? (fun iface => iface.name = name)

-- Find a request by name in an interface
def findRequest (name : String) (iface : Interface) : Option Message :=
  iface.requests.find? (fun msg => msg.name = name)

-- Find an event by name in an interface
def findEvent (name : String) (iface : Interface) : Option Message :=
  iface.events.find? (fun msg => msg.name = name)

-- Find an enum by name in an interface
def findEnum (name : String) (iface : Interface) : Option Enum :=
  iface.enums.find? (fun e => e.name = name)

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

-- Count total requests in protocol
def totalRequests : Nat :=
  allInterfaces.foldl (fun acc iface => acc + iface.requests.length) 0

-- Count total events in protocol
def totalEvents : Nat :=
  allInterfaces.foldl (fun acc iface => acc + iface.events.length) 0

-- Validate that an argument type references an existing interface
def argTypeValid (arg : Arg) : Bool :=
  match arg.argType with
  | ArgType.object | ArgType.newId =>
    match arg.interfaceName with
    | none => false
    | some name => (findInterface name allInterfaces).isSome
  | _ => true

-- Check if all arguments in a message are valid
def messageValid (msg : Message) : Bool :=
  msg.args.all argTypeValid

-- Check if an interface is valid
def interfaceValid (iface : Interface) : Bool :=
  (iface.requests.all messageValid) && (iface.events.all messageValid)

-- Validate entire protocol
def protocolValid : Bool :=
  allInterfaces.all interfaceValid

end WaylandProtocol
