import ShaktiLean.Basic
import ShaktiLean.Utils

namespace WaylandProtocol

-- Simplified Lens type: getter and setter for a field
structure Lens (S T : Type) (A B : Type) where
  get : S → A
  set : S → B → T

-- Lens that doesn't change the type
def SimpleLens (S : Type) (A : Type) := Lens S S A A

-- Lens for Interface.requests
def interfaceRequestsLens : SimpleLens Interface (List Message) where
  get i := i.requests
  set i msgs := { i with requests := msgs }

-- Lens for Interface.events
def interfaceEventsLens : SimpleLens Interface (List Message) where
  get i := i.events
  set i msgs := { i with events := msgs }

-- Lens for Interface.enums
def interfaceEnumsLens : SimpleLens Interface (List Enum) where
  get i := i.enums
  set i enums := { i with enums := enums }

-- Lens for Message.args
def messageArgsLens : SimpleLens Message (List Arg) where
  get m := m.args
  set m args := { m with args := args }

-- Lens for Message.name
def messageNameLens : SimpleLens Message String where
  get m := m.name
  set m name := { m with name := name }

-- Lens for Arg.argType
def argTypeLens : SimpleLens Arg ArgType where
  get a := a.argType
  set a t := { a with argType := t }

-- Modify a value through a lens
def modify (l : SimpleLens S A) (f : A → A) (s : S) : S :=
  l.set s (f (l.get s))

-- Map over a list through a lens
def mapList (l : SimpleLens S (List A)) (f : A → A) (s : S) : S :=
  modify l (List.map f) s

-- Filter a list through a lens
def filterList (l : SimpleLens S (List A)) (pred : A → Bool) (s : S) : S :=
  modify l (List.filter pred) s

-- Count items in a list through a lens
def countList (l : SimpleLens S (List A)) (s : S) : Nat :=
  (l.get s).length

-- Find item in list through a lens
def findInList [Named A] (l : SimpleLens S (List A)) (name : String) (s : S) : Option A :=
  findByName name (l.get s)

-- Practical examples

-- Get all requests from an interface
def getInterfaceRequests (i : Interface) : List Message :=
  interfaceRequestsLens.get i

-- Add a request to an interface
def addRequest (i : Interface) (msg : Message) : Interface :=
  modify interfaceRequestsLens (fun msgs => msgs ++ [msg]) i

-- Filter out destructor messages from an interface
def removeDestructors (i : Interface) : Interface :=
  let reqFiltered := modify interfaceRequestsLens (fun msgs => msgs.filter (fun m => !m.destructor)) i
  modify interfaceEventsLens (fun msgs => msgs.filter (fun m => !m.destructor)) reqFiltered

-- Count total arguments in interface requests
def countInterfaceRequestArgs (i : Interface) : Nat :=
  interfaceRequestsLens.get i
    |> List.foldl (fun acc msg => acc + msg.args.length) 0

end WaylandProtocol
