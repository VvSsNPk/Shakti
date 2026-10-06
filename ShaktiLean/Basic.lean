-- Core Wayland Protocol Formalization

-- Argument type in Wayland protocol
inductive ArgType where
  | int | uint | fixed | string | object | newId | fd | array
  deriving Repr, BEq, Hashable

-- Represents an enum entry
structure EnumEntry where
  name : String
  value : Nat
  summary : String
  deriving Repr, BEq

-- Represents an enum definition
structure Enum where
  name : String
  description : String
  entries : List EnumEntry
  deriving Repr, BEq

-- Type class for types that have a searchable name field
class Named (α : Type) where
  getName : α → String

instance : Named String where
  getName s := s

instance : Named Enum where
  getName e := e.name

instance : Named EnumEntry where
  getName e := e.name

mutual
  -- Represents an argument in a request/event
  structure Arg where
    name : String
    argType : ArgType
    interfaceName : Option String  -- For "object" or "newId" types
    summary : String
    deriving Repr, BEq

  -- Represents a request or event message
  structure Message where
    name : String
    description : String
    destructor : Bool
    args : List Arg
    deriving Repr, BEq

  -- Represents a Wayland interface
  structure Interface where
    name : String
    version : Nat
    description : String
    requests : List Message
    events : List Message
    enums : List Enum
    deriving Repr, BEq
end

instance : Named Arg where
  getName a := a.name

instance : Named Message where
  getName m := m.name

instance : Named Interface where
  getName i := i.name

-- Represents a runtime Wayland object instance
structure WlObject where
  interfaceName : String  -- name of the interface
  id : Nat
  deriving Repr, BEq
