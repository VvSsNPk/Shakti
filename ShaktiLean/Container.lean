import ShaktiLean.Basic
import ShaktiLean.Utils

namespace WaylandProtocol

-- Type class for containers of messages
class MessageContainer (C : Type) where
  getMessages : C → List Message
  setMessages : C → List Message → C
  countMessages : C → Nat := fun c => (getMessages c).length

-- Instance for Interface - messages are requests + events
instance : MessageContainer Interface where
  getMessages i := i.requests ++ i.events
  setMessages i msgs :=
    let reqCount := i.requests.length
    let (reqs, events) := msgs.splitAt reqCount
    { i with requests := reqs, events := events }
  countMessages i := i.requests.length + i.events.length

-- Instance for Message wrapper
instance : MessageContainer Message where
  getMessages m := [m]
  setMessages m msgs := match msgs with
    | [newMsg] => newMsg
    | _ => m

-- Operations over message containers
def filterMessages (c : C) [MessageContainer C] (pred : Message → Bool) : List Message :=
  (MessageContainer.getMessages c).filter pred

def mapMessages (c : C) [MessageContainer C] (f : Message → Message) : C :=
  let newMsgs := (MessageContainer.getMessages c).map f
  MessageContainer.setMessages c newMsgs

def findMessageInContainer (name : String) (c : C) [MessageContainer C] : Option Message :=
  findByName name (MessageContainer.getMessages c)

def validateMessages (c : C) [MessageContainer C] [Validatable Message] : Bool :=
  (MessageContainer.getMessages c).all Validatable.isValid

def messageCountInContainer (c : C) [MessageContainer C] : Nat :=
  MessageContainer.countMessages c

-- Find all destructors in a container
def findDestructors (c : C) [MessageContainer C] : List Message :=
  filterMessages c (fun m => m.destructor)

-- Find all non-destructors in a container
def findNonDestructors (c : C) [MessageContainer C] : List Message :=
  filterMessages c (fun m => !m.destructor)

-- Get message names from container
def messageNamesInContainer (c : C) [MessageContainer C] : List String :=
  (MessageContainer.getMessages c).map (fun m => m.name)

end WaylandProtocol
