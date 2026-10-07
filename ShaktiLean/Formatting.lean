import ShaktiLean.Basic
import ShaktiLean.Protocol

namespace WaylandProtocol

-- Custom Show instances for prettier formatting

instance : ToString ArgType where
  toString t := match t with
    | ArgType.int => "int"
    | ArgType.uint => "uint"
    | ArgType.fixed => "fixed"
    | ArgType.string => "string"
    | ArgType.object => "object"
    | ArgType.newId => "newId"
    | ArgType.fd => "fd"
    | ArgType.array => "array"

instance : ToString EnumEntry where
  toString e := e.name ++ " = " ++ toString e.value ++ " (" ++ e.summary ++ ")"

instance : ToString Enum where
  toString e :=
    let entries := e.entries.map toString |> String.intercalate ", "
    "enum " ++ e.name ++ " { " ++ entries ++ " }"

instance : ToString Arg where
  toString a :=
    let typeStr := toString a.argType
    let ifaceStr := match a.interfaceName with
      | none => ""
      | some name => " (" ++ name ++ ")"
    a.name ++ ": " ++ typeStr ++ ifaceStr

instance : ToString Message where
  toString m :=
    let argsStr := m.args.map toString |> String.intercalate ", "
    let destroyStr := if m.destructor then " [destructor]" else ""
    m.name ++ "(" ++ argsStr ++ ")" ++ destroyStr

instance : ToString Interface where
  toString i :=
    let requests := i.requests.map toString |> String.intercalate ", "
    let events := i.events.map toString |> String.intercalate ", "
    let requestsStr := if i.requests.isEmpty then "" else "\n  Requests: " ++ requests
    let eventsStr := if i.events.isEmpty then "" else "\n  Events: " ++ events
    "interface " ++ i.name ++ " (v" ++ toString i.version ++ ")" ++ requestsStr ++ eventsStr

instance : ToString WlObject where
  toString obj := obj.interfaceName ++ "@" ++ toString obj.id

end WaylandProtocol
