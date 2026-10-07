import ShaktiLean.Basic
import ShaktiLean.Utils

namespace WaylandProtocol

-- Validation result that collects all errors
inductive ValidationResult (α : Type) where
  | success (value : α) : ValidationResult α
  | failure (errors : List String) : ValidationResult α
  deriving Repr

-- Functor instance for ValidationResult
instance : Functor ValidationResult where
  map f r := match r with
    | .success v => .success (f v)
    | .failure es => .failure es

-- Applicative instance for ValidationResult
instance : Applicative ValidationResult where
  pure := ValidationResult.success
  seq f v := match f with
    | .success fn =>
      match v () with
      | .success val => .success (fn val)
      | .failure es => .failure es
    | .failure es =>
      match v () with
      | .success _ => .failure es
      | .failure es' => .failure (es ++ es')

-- Monad instance for ValidationResult
instance : Monad ValidationResult where
  bind r f := match r with
    | .success v => f v
    | .failure es => .failure es

-- Validate an argument with error collection
def validateArgWithError (arg : Arg) (allInterfaces : List Interface) : ValidationResult Arg :=
  match arg.argType with
  | ArgType.object | ArgType.newId =>
    match arg.interfaceName with
    | none => .failure [s!"Arg '{arg.name}': object/newId type requires interfaceName"]
    | some name =>
      if (findInterface name allInterfaces).isSome then
        .success arg
      else
        .failure [s!"Arg '{arg.name}': interface '{name}' not found"]
  | _ => .success arg

-- Validate all arguments in a message
def validateMessageWithErrors (msg : Message) (allInterfaces : List Interface) : ValidationResult Message :=
  let results := msg.args.map (fun arg => validateArgWithError arg allInterfaces)
  let errors := results.filterMap (fun r => match r with
    | .failure es => some es
    | _ => none)
  let allErrors := errors.flatten

  if allErrors.isEmpty then
    .success msg
  else
    .failure allErrors

-- Validate an interface and collect all errors
def validateInterfaceWithErrors (iface : Interface) (allInterfaces : List Interface) : ValidationResult Interface :=
  let reqResults := iface.requests.map (fun msg => validateMessageWithErrors msg allInterfaces)
  let eventResults := iface.events.map (fun msg => validateMessageWithErrors msg allInterfaces)

  let reqErrors := reqResults.filterMap (fun r => match r with
    | .failure es => some es
    | _ => none)
  let eventErrors := eventResults.filterMap (fun r => match r with
    | .failure es => some es
    | _ => none)

  let allErrors := (reqErrors ++ eventErrors).flatten

  if allErrors.isEmpty then
    .success iface
  else
    .failure (allErrors.map (fun e => s!"{iface.name}: {e}"))

-- Validate entire protocol and collect all errors
def validateProtocolWithErrors (allInterfaces : List Interface) : ValidationResult (List Interface) :=
  let results := allInterfaces.map (fun iface => validateInterfaceWithErrors iface allInterfaces)
  let errors := results.filterMap (fun r => match r with
    | .failure es => some es
    | _ => none)
  let allErrors := errors.flatten

  if allErrors.isEmpty then
    .success allInterfaces
  else
    .failure allErrors

-- Pretty print validation results
def ValidationResult.toMessage : ValidationResult α → String := fun r => match r with
  | .success _ => "✓ Validation passed"
  | .failure errors =>
    let errorList := errors.map (fun e => s!"  ✗ {e}") |> String.intercalate "\n"
    s!"✗ Validation failed with {errors.length} error(s):\n{errorList}"

instance : ToString (ValidationResult α) where
  toString := ValidationResult.toMessage

-- Report validation status
def reportValidation (r : ValidationResult α) (descr : String) : IO Unit :=
  IO.println s!"{descr}\n{toString r}"

end WaylandProtocol
