import ShaktiLean.Basic
import ShaktiLean.Utils

namespace WaylandProtocol

-- Subtype for interfaces that exist in the protocol
def ExistingInterface := { i : Interface // i ∈ allInterfaces }

-- Subtype for valid messages in an interface
def ValidMessageInInterface (iface : Interface) :=
  { m : Message // m ∈ (iface.requests ++ iface.events) }

-- Subtype for arguments with valid type references
def ValidArgumentType :=
  { a : Arg // match a.argType with
    | ArgType.object | ArgType.newId =>
      ∃ name, a.interfaceName = some name ∧ name ∈ (allInterfaces.map Interface.name)
    | _ => True
  }

-- Find an existing interface
def getExistingInterface (name : String) : Option ExistingInterface :=
  match findInterface name allInterfaces with
  | none => none
  | some iface => some ⟨iface, by sorry⟩

-- Get message from interface
def getMessageInInterface (iface : ExistingInterface) (msgName : String) :
    Option (ValidMessageInInterface iface.val) :=
  match findByName msgName (iface.val.requests ++ iface.val.events) with
  | none => none
  | some msg => some ⟨msg, by sorry⟩

-- Type-safe argument validation
def validateArgumentType (arg : Arg) : Option ValidArgumentType :=
  match arg.argType with
  | ArgType.object | ArgType.newId =>
    match arg.interfaceName with
    | none => none
    | some name =>
      if (findInterface name allInterfaces).isSome then
        some ⟨arg, by sorry⟩
      else
        none
  | _ => some ⟨arg, by sorry⟩

-- Type-level property assertions
def allInterfacesNamingConvention : Prop :=
  ∀ i ∈ allInterfaces, (Interface.name i).startsWith "wl_"

def allMessagesHaveDescriptions : Prop :=
  ∀ i ∈ allInterfaces,
    (i.requests.all (fun m => (Message.description m).length > 0)) ∧
    (i.events.all (fun m => (Message.description m).length > 0))

def allInterfacesHaveVersions : Prop :=
  ∀ i ∈ allInterfaces, Interface.version i > 0

-- Example property we can verify
theorem protocolHasInterfaces : allInterfaces.length > 0 := by
  decide

-- Guarantee that ExistingInterface values are truly in the protocol
theorem existingInterfaceInProtocol (ei : ExistingInterface) : ei.val ∈ allInterfaces :=
  ei.property

end WaylandProtocol
